const std = @import("std");
const command_mod = @import("command.zig");
const context_mod = @import("context.zig");
const input_mod = @import("input.zig");
const overlay_mod = @import("overlay.zig");
const root_mod = @import("root.zig");
const parser = @import("../terminal/parser.zig");
const renderer = @import("../terminal/renderer.zig");
const screen_mod = @import("../terminal/screen.zig");
const tty_mod = @import("../terminal/tty.zig");
const widget_render = @import("../widget/render.zig");

pub fn Program(comptime Model: type, comptime Msg: type) type {
    return struct {
        allocator: std.mem.Allocator,
        model: Model,
        tty: tty_mod.Tty,
        front: screen_mod.Screen,
        back: screen_mod.Screen,
        frame_arena: std.heap.ArenaAllocator,
        root: root_mod.RootState,
        input_dispatcher: input_mod.Dispatcher,
        overlays: overlay_mod.State,
        tick_interval_ms: ?u64 = null,
        next_tick_at_ms: ?u64 = null,
        started: bool = false,

        const Self = @This();
        pub const Cmd = command_mod.Command(Msg);
        pub const Options = root_mod.RootOptions;

        pub fn init(
            allocator: std.mem.Allocator,
            tty: tty_mod.Tty,
            model: Model,
            options: Options,
        ) !Self {
            var self: Self = .{
                .allocator = allocator,
                .model = model,
                .tty = tty,
                .front = try screen_mod.Screen.init(allocator, tty.size),
                .back = try screen_mod.Screen.init(allocator, tty.size),
                .frame_arena = std.heap.ArenaAllocator.init(allocator),
                .root = .{
                    .size = tty.size,
                    .focused = options.focused,
                    .now_ms = options.now_ms,
                    .title = null,
                    .tab_status = options.tab_status,
                    .overlay_count = 0,
                    .blocking_overlay = null,
                },
                .input_dispatcher = input_mod.Dispatcher.init(allocator),
                .overlays = overlay_mod.State.init(allocator),
                .tick_interval_ms = options.tick_interval_ms,
                .next_tick_at_ms = if (options.tick_interval_ms) |interval| options.now_ms + interval else null,
            };
            if (options.title) |title| {
                self.root.title = try allocator.dupe(u8, title);
            }
            return self;
        }

        pub fn deinit(self: *Self) void {
            if (self.root.title) |title| self.allocator.free(title);
            self.input_dispatcher.deinit();
            self.overlays.deinit();
            self.front.deinit();
            self.back.deinit();
            self.frame_arena.deinit();
        }

        pub fn start(self: *Self) !void {
            self.tty.enterRawMode();
            try self.applyRootState();
            var ctx = self.makeContext();
            if (@hasDecl(Model, "init")) {
                const cmd = self.model.init(&ctx);
                try self.applyCommand(cmd, &ctx);
            }
            try self.redraw();
            self.started = true;
        }

        pub fn processEvent(self: *Self, event: Msg) !bool {
            var ctx = self.makeContext();
            const cmd = self.model.update(event, &ctx);
            try self.applyCommand(cmd, &ctx);
            if (ctx.redraw_requested) try self.redraw();
            return !ctx.quit_requested;
        }

        pub fn processTerminalEvent(self: *Self, event: parser.Event) !bool {
            var root_changed = false;
            var blocked = false;
            switch (event) {
                .resize => |size| {
                    try self.handleResize(.{ .width = size.width, .height = size.height });
                    root_changed = true;
                },
                .focus => |focused| {
                    self.root.focused = focused;
                    root_changed = true;
                },
                .key => |key| {
                    const result = self.input_dispatcher.dispatchKey(key);
                    blocked = result.default_prevented or result.propagation_stopped;
                },
                .paste => |text| {
                    const result = self.input_dispatcher.dispatchPaste(text);
                    blocked = result.default_prevented or result.propagation_stopped;
                },
                else => {},
            }
            if (Msg == parser.Event) {
                const keep_running = if (!blocked) try self.processEvent(event) else true;
                if (root_changed) try self.redraw();
                return keep_running;
            }
            if (root_changed) try self.redraw();
            @compileError("processTerminalEvent requires Msg == parser.Event");
        }

        pub fn processTick(self: *Self, delta_ms: u64) !bool {
            self.root.now_ms += delta_ms;
            if (self.tick_interval_ms == null) return true;
            if (self.next_tick_at_ms == null) self.next_tick_at_ms = self.root.now_ms + self.tick_interval_ms.?;
            while (self.next_tick_at_ms != null and self.root.now_ms >= self.next_tick_at_ms.?) {
                var ctx = self.makeContext();
                if (@hasDecl(Model, "tick")) {
                    const cmd = self.model.tick(&ctx);
                    self.applyCommand(cmd, &ctx) catch |err| return err;
                } else {
                    ctx.requestRedraw();
                }
                if (ctx.redraw_requested) try self.redraw();
                if (ctx.quit_requested) return false;
                self.next_tick_at_ms = self.root.now_ms + self.tick_interval_ms.?;
            }
            return true;
        }

        pub fn redraw(self: *Self) !void {
            _ = self.frame_arena.reset(.retain_capacity);
            self.back.clear();
            self.root.frame_index += 1;
            var ctx = self.makeContext();
            if (@hasDecl(Model, "viewNode")) {
                const root = try self.model.viewNode(&ctx);
                widget_render.renderNode(&self.back, .{
                    .x = 0,
                    .y = 0,
                    .width = self.back.size.width,
                    .height = self.back.size.height,
                }, root);
            } else {
                try self.model.view(&ctx, &self.back);
            }
            if (self.tty.writer) |writer| {
                try renderer.renderDiffWithCapabilities(writer, &self.front, &self.back, self.tty.capabilities);
                try writer.flush();
            }
            self.front.copyFrom(&self.back);
        }

        fn makeContext(self: *Self) context_mod.Context {
            self.root.overlay_count = self.overlays.entries.items.len;
            self.root.blocking_overlay = if (self.overlays.topModal()) |entry| entry.kind else null;
            return .{
                .allocator = self.frame_arena.allocator(),
                .persistent_allocator = self.allocator,
                .size = self.tty.size,
                .focused = self.root.focused,
                .frame_index = self.root.frame_index,
                .now_ms = self.root.now_ms,
                .title = self.root.title,
                .tab_status = self.root.tab_status,
                .input_dispatcher = &self.input_dispatcher,
                .overlays = &self.overlays,
            };
        }

        fn handleResize(self: *Self, size: screen_mod.Size) !void {
            self.tty.size = size;
            self.root.size = size;
            try self.front.resize(size);
            try self.back.resize(size);
            try self.applyRootState();
        }

        fn applyRootState(self: *Self) !void {
            if (self.tty.writer) |writer| {
                if (self.root.title) |title| {
                    if (self.tty.capabilities.terminal_title) {
                        try @import("../terminal/ansi.zig").writeSetTitle(writer, title);
                    }
                }
                if (self.root.tab_status) |status| {
                    if (self.tty.capabilities.tab_status) {
                        try @import("../terminal/ansi.zig").writeTabStatus(writer, status);
                    }
                }
                try writer.flush();
            }
        }

        fn applyCommand(self: *Self, cmd: Cmd, ctx: *context_mod.Context) !void {
            switch (cmd) {
                .none => {},
                .quit => ctx.requestQuit(),
                .redraw => ctx.requestRedraw(),
                .set_tick_interval_ms => |interval| {
                    self.tick_interval_ms = interval;
                    self.next_tick_at_ms = self.root.now_ms + interval;
                },
                .clear_tick_interval => {
                    self.tick_interval_ms = null;
                    self.next_tick_at_ms = null;
                },
                .set_title => |title| {
                    if (self.root.title) |existing| self.allocator.free(existing);
                    self.root.title = try self.allocator.dupe(u8, title);
                    if (self.tty.writer) |writer| {
                        if (self.tty.capabilities.terminal_title) {
                            try @import("../terminal/ansi.zig").writeSetTitle(writer, title);
                            try writer.flush();
                        }
                    }
                },
                .clear_title => {
                    if (self.root.title) |existing| self.allocator.free(existing);
                    self.root.title = null;
                    if (self.tty.writer) |writer| {
                        if (self.tty.capabilities.terminal_title) {
                            try @import("../terminal/ansi.zig").writeClearTitle(writer);
                            try writer.flush();
                        }
                    }
                },
                .set_tab_status => |status| {
                    self.root.tab_status = status;
                    if (self.tty.writer) |writer| {
                        if (self.tty.capabilities.tab_status) {
                            try @import("../terminal/ansi.zig").writeTabStatus(writer, status);
                            try writer.flush();
                        }
                    }
                },
                .clear_tab_status => {
                    self.root.tab_status = null;
                    if (self.tty.writer) |writer| {
                        if (self.tty.capabilities.tab_status) {
                            try @import("../terminal/ansi.zig").writeClearTabStatus(writer);
                            try writer.flush();
                        }
                    }
                },
            }
        }
    };
}

test "program init update view cycle renders" {
    const fake = @import("../testing/fake_terminal.zig");
    const style_mod = @import("../style/style.zig");
    const text_widget = @import("../widget/text.zig");

    const Model = struct {
        count: u32 = 0,

        fn init(self: *@This(), ctx: *context_mod.Context) command_mod.Command(parser.Event) {
            _ = self;
            ctx.requestRedraw();
            return .none;
        }

        fn update(self: *@This(), event: parser.Event, ctx: *context_mod.Context) command_mod.Command(parser.Event) {
            switch (event) {
                .key => |key| switch (key) {
                    .char => |c| if (c == '+') {
                        self.count += 1;
                        return .redraw;
                    },
                    .ctrl_c => return .quit,
                    else => {},
                },
                else => {},
            }
            _ = ctx;
            return .none;
        }

        fn viewNode(self: *@This(), ctx: *context_mod.Context) !*const @import("../widget/node.zig").Node {
            var buf: [32]u8 = undefined;
            const text = try std.fmt.bufPrint(&buf, "count:{d}", .{self.count});
            return try text_widget.build(ctx.allocator, try ctx.allocator.dupe(u8, text), style_mod.Style{});
        }
    };

    var term = fake.FakeTerminal.init(std.testing.allocator, .{ .width = 20, .height = 3 });
    defer term.deinit();

    var program = try Program(Model, parser.Event).init(std.testing.allocator, term.tty(), .{}, .{});
    defer program.deinit();
    try program.start();
    try std.testing.expectEqual(@as(u8, 'c'), program.front.getCell(.{ .x = 0, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, '0'), program.front.getCell(.{ .x = 6, .y = 0 }).byte);

    const keep_running = try program.processTerminalEvent(.{ .key = .{ .char = '+' } });
    try std.testing.expect(keep_running);
    try std.testing.expectEqual(@as(u8, '1'), program.front.getCell(.{ .x = 6, .y = 0 }).byte);
}

test "program tick drives timed redraws" {
    const text_widget = @import("../widget/text.zig");
    const style_mod = @import("../style/style.zig");

    const Model = struct {
        tick_count: u32 = 0,

        fn init(self: *@This(), ctx: *context_mod.Context) command_mod.Command(void) {
            _ = self;
            ctx.requestRedraw();
            return .{ .set_tick_interval_ms = 50 };
        }

        fn update(self: *@This(), event: void, ctx: *context_mod.Context) command_mod.Command(void) {
            _ = self;
            _ = event;
            _ = ctx;
            return .none;
        }

        fn tick(self: *@This(), ctx: *context_mod.Context) command_mod.Command(void) {
            _ = ctx;
            self.tick_count += 1;
            return .redraw;
        }

        fn viewNode(self: *@This(), ctx: *context_mod.Context) !*const @import("../widget/node.zig").Node {
            var buf: [32]u8 = undefined;
            const text = try std.fmt.bufPrint(&buf, "tick:{d}", .{self.tick_count});
            return try text_widget.build(ctx.allocator, try ctx.allocator.dupe(u8, text), style_mod.Style{});
        }
    };

    var term = @import("../testing/fake_terminal.zig").FakeTerminal.init(std.testing.allocator, .{ .width = 20, .height = 3 });
    defer term.deinit();

    var program = try Program(Model, void).init(std.testing.allocator, term.tty(), .{}, .{});
    defer program.deinit();
    try program.start();
    try std.testing.expect(try program.processTick(60));
    try std.testing.expectEqual(@as(u8, '1'), program.front.getCell(.{ .x = 5, .y = 0 }).byte);
}

test "program resize updates screen state" {
    const text_widget = @import("../widget/text.zig");
    const style_mod = @import("../style/style.zig");
    const Model = struct {
        fn update(self: *@This(), event: parser.Event, ctx: *context_mod.Context) command_mod.Command(parser.Event) {
            _ = self;
            _ = event;
            _ = ctx;
            return .none;
        }

        fn viewNode(self: *@This(), ctx: *context_mod.Context) !*const @import("../widget/node.zig").Node {
            _ = self;
            return try text_widget.build(ctx.allocator, try ctx.allocator.dupe(u8, "resize"), style_mod.Style{});
        }
    };

    var term = @import("../testing/fake_terminal.zig").FakeTerminal.init(std.testing.allocator, .{ .width = 10, .height = 3 });
    defer term.deinit();

    var program = try Program(Model, parser.Event).init(std.testing.allocator, term.tty(), .{}, .{});
    defer program.deinit();
    try program.start();
    _ = try program.processTerminalEvent(.{ .resize = .{ .width = 22, .height = 7 } });
    try std.testing.expectEqual(@as(u16, 22), program.front.size.width);
    try std.testing.expectEqual(@as(u16, 7), program.back.size.height);
    try std.testing.expectEqual(@as(u16, 22), program.root.size.width);
}

test "program focus updates root state" {
    const text_widget = @import("../widget/text.zig");
    const style_mod = @import("../style/style.zig");
    const Model = struct {
        fn update(self: *@This(), event: parser.Event, ctx: *context_mod.Context) command_mod.Command(parser.Event) {
            _ = self;
            _ = event;
            _ = ctx;
            return .none;
        }

        fn viewNode(self: *@This(), ctx: *context_mod.Context) !*const @import("../widget/node.zig").Node {
            _ = self;
            return try text_widget.build(ctx.allocator, try ctx.allocator.dupe(u8, "focus"), style_mod.Style{});
        }
    };

    var term = @import("../testing/fake_terminal.zig").FakeTerminal.init(std.testing.allocator, .{ .width = 10, .height = 3 });
    defer term.deinit();

    var program = try Program(Model, parser.Event).init(std.testing.allocator, term.tty(), .{}, .{});
    defer program.deinit();
    try program.start();
    _ = try program.processTerminalEvent(.{ .focus = false });
    try std.testing.expect(!program.root.focused);
}

test "program applies title and tab status on start" {
    const text_widget = @import("../widget/text.zig");
    const style_mod = @import("../style/style.zig");
    const fake = @import("../testing/fake_terminal.zig");

    const Model = struct {
        fn update(self: *@This(), event: parser.Event, ctx: *context_mod.Context) command_mod.Command(parser.Event) {
            _ = self;
            _ = event;
            _ = ctx;
            return .none;
        }

        fn viewNode(self: *@This(), ctx: *context_mod.Context) !*const @import("../widget/node.zig").Node {
            _ = self;
            return try text_widget.build(ctx.allocator, try ctx.allocator.dupe(u8, "root"), style_mod.Style{});
        }
    };

    var term = fake.FakeTerminal.init(std.testing.allocator, .{ .width = 12, .height = 3 });
    defer term.deinit();
    term.capabilities.terminal_title = true;
    term.capabilities.tab_status = true;

    var program = try Program(Model, parser.Event).init(std.testing.allocator, term.tty(), .{}, .{
        .title = "ziggy test",
        .tab_status = .busy,
    });
    defer program.deinit();
    try program.start();
    try std.testing.expect(std.mem.indexOf(u8, term.output(), "\x1b]0;ziggy test") != null);
    try std.testing.expect(std.mem.indexOf(u8, term.output(), "\x1b]21337;indicator=#ff9500;status=Working;statusColor=#ff9500") != null);
}
