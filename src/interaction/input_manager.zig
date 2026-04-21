const std = @import("std");
const input_mod = @import("../app/input.zig");
const overlay_runtime = @import("overlay_runtime.zig");
const overlay_mod = @import("../app/overlay.zig");

pub const Layer = enum {
    overlay,
    focused,
    global,
};

pub const Handler = struct {
    ctx: ?*anyopaque = null,
    layer: Layer = .global,
    focus_id: ?[]const u8 = null,
    enabled: ?*const fn (?*anyopaque) bool = null,
    on_key: ?*const fn (?*anyopaque, *input_mod.KeyEvent) void = null,
    on_paste: ?*const fn (?*anyopaque, *input_mod.PasteEvent) void = null,
    on_mouse: ?*const fn (?*anyopaque, *input_mod.MouseEvent) void = null,
};

pub const Manager = struct {
    allocator: std.mem.Allocator,
    handlers: std.ArrayList(Handler) = .empty,
    focus_id: ?[]const u8 = null,
    overlays: ?*const overlay_mod.State = null,

    pub fn init(allocator: std.mem.Allocator) Manager {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Manager) void {
        self.handlers.deinit(self.allocator);
    }

    pub fn add(self: *Manager, handler: Handler) !void {
        try self.handlers.append(self.allocator, handler);
    }

    pub fn clear(self: *Manager) void {
        self.handlers.clearRetainingCapacity();
    }

    pub fn setFocus(self: *Manager, focus_id: ?[]const u8) void {
        self.focus_id = focus_id;
    }

    pub fn setOverlays(self: *Manager, overlays: ?*const overlay_mod.State) void {
        self.overlays = overlays;
    }

    pub fn dispatchKey(self: *Manager, key: @import("../terminal/parser.zig").Key) input_mod.DispatchResult {
        var event: input_mod.KeyEvent = .{ .key = key };
        const handled = self.dispatchImpl(*input_mod.KeyEvent, &event, dispatchKeyHandler);
        return .{
            .handled = handled,
            .default_prevented = event.default_prevented,
            .propagation_stopped = event.propagation_stopped,
        };
    }

    pub fn dispatchPaste(self: *Manager, text: []const u8) input_mod.DispatchResult {
        var event: input_mod.PasteEvent = .{ .text = text };
        const handled = self.dispatchImpl(*input_mod.PasteEvent, &event, dispatchPasteHandler);
        return .{
            .handled = handled,
            .default_prevented = event.default_prevented,
            .propagation_stopped = event.propagation_stopped,
        };
    }

    pub fn dispatchMouse(self: *Manager, mouse: @import("../terminal/parser.zig").Mouse) input_mod.DispatchResult {
        var event: input_mod.MouseEvent = .{ .mouse = mouse };
        const handled = self.dispatchImpl(*input_mod.MouseEvent, &event, dispatchMouseHandler);
        return .{
            .handled = handled,
            .default_prevented = event.default_prevented,
            .propagation_stopped = event.propagation_stopped,
        };
    }

    fn dispatchImpl(self: *Manager, comptime EventPtr: type, event: EventPtr, comptime invoke: fn (Handler, EventPtr) void) bool {
        var handled = false;
        const order = [_]Layer{ .overlay, .focused, .global };
        for (order) |layer| {
            if (self.overlays) |overlays| {
                if (!overlay_runtime.allowsLayer(overlays, @enumFromInt(@intFromEnum(layer)))) continue;
            }
            for (self.handlers.items) |handler| {
                if (!matches(self.focus_id, handler, layer)) continue;
                handled = true;
                invoke(handler, event);
                if (event.propagation_stopped) return true;
            }
        }
        return handled;
    }
};

fn matches(active_focus_id: ?[]const u8, handler: Handler, layer: Layer) bool {
    if (handler.layer != layer) return false;
    if (handler.enabled) |enabled| {
        if (!enabled(handler.ctx)) return false;
    }
    if (layer == .focused) {
        if (handler.focus_id) |focus_id| {
            if (active_focus_id) |active| {
                return std.mem.eql(u8, focus_id, active);
            }
            return false;
        }
    }
    return true;
}

fn dispatchKeyHandler(handler: Handler, event: *input_mod.KeyEvent) void {
    if (handler.on_key) |on_key| on_key(handler.ctx, event);
}

fn dispatchPasteHandler(handler: Handler, event: *input_mod.PasteEvent) void {
    if (handler.on_paste) |on_paste| on_paste(handler.ctx, event);
}

fn dispatchMouseHandler(handler: Handler, event: *input_mod.MouseEvent) void {
    if (handler.on_mouse) |on_mouse| on_mouse(handler.ctx, event);
}

test "focused handlers only fire for the active focus id" {
    const State = struct {
        left: usize = 0,
        right: usize = 0,
    };

    const onLeft = struct {
        fn call(ctx: ?*anyopaque, event: *input_mod.KeyEvent) void {
            _ = event;
            const state: *State = @ptrCast(@alignCast(ctx.?));
            state.left += 1;
        }
    }.call;
    const onRight = struct {
        fn call(ctx: ?*anyopaque, event: *input_mod.KeyEvent) void {
            _ = event;
            const state: *State = @ptrCast(@alignCast(ctx.?));
            state.right += 1;
        }
    }.call;

    var state: State = .{};
    var manager = Manager.init(std.testing.allocator);
    defer manager.deinit();
    try manager.add(.{ .ctx = &state, .layer = .focused, .focus_id = "left", .on_key = onLeft });
    try manager.add(.{ .ctx = &state, .layer = .focused, .focus_id = "right", .on_key = onRight });

    manager.setFocus("left");
    _ = manager.dispatchKey(.enter);
    try std.testing.expectEqual(@as(usize, 1), state.left);
    try std.testing.expectEqual(@as(usize, 0), state.right);
}

test "blocking overlays capture non overlay handlers" {
    const State = struct {
        overlay_hits: usize = 0,
        global_hits: usize = 0,
    };

    const onOverlay = struct {
        fn call(ctx: ?*anyopaque, event: *input_mod.KeyEvent) void {
            const state: *State = @ptrCast(@alignCast(ctx.?));
            state.overlay_hits += 1;
            event.stopPropagation();
        }
    }.call;
    const onGlobal = struct {
        fn call(ctx: ?*anyopaque, event: *input_mod.KeyEvent) void {
            _ = event;
            const state: *State = @ptrCast(@alignCast(ctx.?));
            state.global_hits += 1;
        }
    }.call;

    var overlays = overlay_mod.State.init(std.testing.allocator);
    defer overlays.deinit();
    try overlays.push("dialog", "Dialog", .modal, null);

    var state: State = .{};
    var manager = Manager.init(std.testing.allocator);
    defer manager.deinit();
    manager.setOverlays(&overlays);
    try manager.add(.{ .ctx = &state, .layer = .overlay, .on_key = onOverlay });
    try manager.add(.{ .ctx = &state, .layer = .global, .on_key = onGlobal });

    _ = manager.dispatchKey(.escape);
    try std.testing.expectEqual(@as(usize, 1), state.overlay_hits);
    try std.testing.expectEqual(@as(usize, 0), state.global_hits);
}

test "non blocking overlays still allow global handlers" {
    const State = struct {
        overlay_hits: usize = 0,
        global_hits: usize = 0,
    };

    const onOverlay = struct {
        fn call(ctx: ?*anyopaque, event: *input_mod.KeyEvent) void {
            _ = event;
            const state: *State = @ptrCast(@alignCast(ctx.?));
            state.overlay_hits += 1;
        }
    }.call;
    const onGlobal = struct {
        fn call(ctx: ?*anyopaque, event: *input_mod.KeyEvent) void {
            _ = event;
            const state: *State = @ptrCast(@alignCast(ctx.?));
            state.global_hits += 1;
        }
    }.call;

    var overlays = overlay_mod.State.init(std.testing.allocator);
    defer overlays.deinit();
    try overlays.push("menu", "Menu", .context_menu, null);

    var state: State = .{};
    var manager = Manager.init(std.testing.allocator);
    defer manager.deinit();
    manager.setOverlays(&overlays);
    try manager.add(.{ .ctx = &state, .layer = .overlay, .on_key = onOverlay });
    try manager.add(.{ .ctx = &state, .layer = .global, .on_key = onGlobal });

    _ = manager.dispatchKey(.down);
    try std.testing.expectEqual(@as(usize, 1), state.overlay_hits);
    try std.testing.expectEqual(@as(usize, 1), state.global_hits);
}
