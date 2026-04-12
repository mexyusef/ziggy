const std = @import("std");
const parser = @import("../terminal/parser.zig");
const input_mod = @import("input.zig");
const keymap_mod = @import("keymap.zig");

pub fn Router(comptime Action: type) type {
    return struct {
        keymap: keymap_mod.ActionMap(Action),
        last_action: ?Action = null,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .keymap = keymap_mod.ActionMap(Action).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.keymap.deinit();
        }

        pub fn bind(self: *Self, key: parser.Key, action: Action) !void {
            try self.keymap.bind(key, action);
        }

        pub fn resolve(self: *const Self, key: parser.Key) ?Action {
            return self.keymap.resolve(key);
        }

        pub fn handleKey(self: *Self, event: *input_mod.KeyEvent) ?Action {
            const action = self.resolve(event.key) orelse return null;
            self.last_action = action;
            event.preventDefault();
            event.stopPropagation();
            return action;
        }
    };
}

test "command router resolves and consumes" {
    const Action = enum { open_palette };
    var router = Router(Action).init(std.testing.allocator);
    defer router.deinit();
    try router.bind(.ctrl_p, .open_palette);

    var event: input_mod.KeyEvent = .{ .key = .ctrl_p };
    const action = router.handleKey(&event).?;
    try std.testing.expectEqual(Action.open_palette, action);
    try std.testing.expect(event.default_prevented);
    try std.testing.expect(event.propagation_stopped);
}
