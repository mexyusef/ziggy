const std = @import("std");
const command_mod = @import("command.zig");
const context_mod = @import("context.zig");

pub fn SubProgram(comptime ChildModel: type, comptime ParentMsg: type) type {
    const ChildMsg = ChildModel.Msg;
    return struct {
        model: ChildModel,
        initialized: bool = false,
        quit_msg: ?ParentMsg = null,

        const Self = @This();
        const ChildCmd = command_mod.Command(ChildMsg);
        const ParentCmd = command_mod.Command(ParentMsg);

        pub fn init(self: *Self, ctx: *context_mod.Context) ParentCmd {
            const cmd = self.model.init(ctx);
            self.initialized = true;
            return translate(cmd);
        }

        pub fn update(self: *Self, msg: ChildMsg, ctx: *context_mod.Context) ParentCmd {
            if (!self.initialized) return .none;
            return translate(self.model.update(msg, ctx));
        }

        pub fn viewNode(self: *Self, ctx: *context_mod.Context) !*const @import("../widget/node.zig").Node {
            return self.model.viewNode(ctx);
        }

        fn translate(cmd: ChildCmd) ParentCmd {
            return switch (cmd) {
                .none => .none,
                .quit => .quit,
                .redraw => .redraw,
                .set_tick_interval_ms => |ms| .{ .set_tick_interval_ms = ms },
                .clear_tick_interval => .clear_tick_interval,
                .set_title => |title| .{ .set_title = title },
                .clear_title => .clear_title,
                .set_tab_status => |status| .{ .set_tab_status = status },
                .clear_tab_status => .clear_tab_status,
            };
        }
    };
}

test "sub program forwards redraw" {
    const node_mod = @import("../widget/node.zig");
    const Child = struct {
        pub const Msg = enum { ping };
        pub fn init(self: *@This(), ctx: *context_mod.Context) command_mod.Command(Msg) {
            _ = self;
            _ = ctx;
            return .redraw;
        }
        pub fn update(self: *@This(), msg: Msg, ctx: *context_mod.Context) command_mod.Command(Msg) {
            _ = self;
            _ = msg;
            _ = ctx;
            return .none;
        }
        pub fn viewNode(self: *@This(), ctx: *context_mod.Context) !*const node_mod.Node {
            _ = self;
            return try node_mod.allocNode(ctx.allocator, .empty);
        }
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var dispatcher = @import("input.zig").Dispatcher.init(std.testing.allocator);
    defer dispatcher.deinit();
    var overlays = @import("overlay.zig").State.init(std.testing.allocator);
    defer overlays.deinit();
    var ctx: context_mod.Context = .{
        .allocator = arena.allocator(),
        .persistent_allocator = std.testing.allocator,
        .size = .{ .width = 10, .height = 5 },
        .focused = true,
        .frame_index = 0,
        .now_ms = 0,
        .title = null,
        .tab_status = null,
        .input_dispatcher = &dispatcher,
        .overlays = &overlays,
    };
    var sub = SubProgram(Child, enum { nothing }){ .model = .{} };
    try std.testing.expect(sub.init(&ctx) == .redraw);
}
