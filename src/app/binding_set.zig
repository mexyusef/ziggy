const std = @import("std");
const parser = @import("../terminal/parser.zig");
const action_router = @import("action_router.zig");
const command_router = @import("command_router.zig");

pub fn ScopedBindingSpec(comptime Scope: type, comptime Action: type) type {
    return struct {
        scope: ?Scope = null,
        key: parser.Key,
        action: Action,
    };
}

pub fn ActionBindingSpec(comptime Action: type) type {
    return struct {
        key: parser.Key,
        action: Action,
    };
}

pub fn bindRouter(
    comptime Scope: type,
    comptime Action: type,
    router: *action_router.Router(Scope, Action),
    comptime bindings: []const ScopedBindingSpec(Scope, Action),
) !void {
    inline for (bindings) |binding| {
        try router.bind(binding.scope, binding.key, binding.action);
    }
}

pub fn bindActionMap(
    comptime Action: type,
    map: *command_router.Router(Action),
    comptime bindings: []const ActionBindingSpec(Action),
) !void {
    inline for (bindings) |binding| {
        try map.bind(binding.key, binding.action);
    }
}

test "bindRouter applies scoped and global bindings" {
    const Scope = enum { workspace, palette };
    const Action = enum { open_palette, close_overlay, move_next };
    const Binding = ScopedBindingSpec(Scope, Action);

    var router = action_router.Router(Scope, Action).init(std.testing.allocator);
    defer router.deinit();

    try bindRouter(Scope, Action, &router, &[_]Binding{
        .{ .key = .ctrl_p, .action = .open_palette },
        .{ .key = .escape, .action = .close_overlay },
        .{ .scope = .palette, .key = .down, .action = .move_next },
    });

    const palette_move = router.resolve(&.{ .palette, .workspace }, .down).?;
    try std.testing.expectEqual(Action.move_next, palette_move.action);
    try std.testing.expectEqual(Action.open_palette, router.resolve(&.{.workspace}, .ctrl_p).?.action);
    try std.testing.expectEqual(Action.close_overlay, router.resolve(&.{.workspace}, .escape).?.action);
}

test "bindActionMap applies command bindings" {
    const Action = enum { build, test_task };
    const Binding = ActionBindingSpec(Action);

    var router = command_router.Router(Action).init(std.testing.allocator);
    defer router.deinit();

    try bindActionMap(Action, &router, &[_]Binding{
        .{ .key = .ctrl_p, .action = .build },
        .{ .key = .ctrl_r, .action = .test_task },
    });

    try std.testing.expectEqual(Action.build, router.resolve(.ctrl_p).?);
    try std.testing.expectEqual(Action.test_task, router.resolve(.ctrl_r).?);
}
