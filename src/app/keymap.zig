const std = @import("std");
const parser = @import("../terminal/parser.zig");

pub fn ActionMap(comptime Action: type) type {
    return struct {
        allocator: std.mem.Allocator,
        bindings: std.ArrayList(Binding) = .empty,

        const Self = @This();

        pub const Binding = struct {
            key: parser.Key,
            action: Action,
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            self.bindings.deinit(self.allocator);
        }

        pub fn bind(self: *Self, key: parser.Key, action: Action) !void {
            try self.bindings.append(self.allocator, .{
                .key = key,
                .action = action,
            });
        }

        pub fn resolve(self: *const Self, key: parser.Key) ?Action {
            for (self.bindings.items) |binding| {
                if (eqlKey(binding.key, key)) return binding.action;
            }
            return null;
        }

        pub fn contains(self: *const Self, key: parser.Key) bool {
            return self.resolve(key) != null;
        }
    };
}

pub fn eqlKey(a: parser.Key, b: parser.Key) bool {
    if (@intFromEnum(a) != @intFromEnum(b)) return false;
    return switch (a) {
        .char => |av| switch (b) {
            .char => |bv| av == bv,
            else => false,
        },
        .unknown => |av| switch (b) {
            .unknown => |bv| av == bv,
            else => false,
        },
        else => true,
    };
}

test "action map resolves exact bindings" {
    const Action = enum { open_palette, move_up };
    var map = ActionMap(Action).init(std.testing.allocator);
    defer map.deinit();
    try map.bind(.ctrl_p, .open_palette);
    try map.bind(.up, .move_up);

    try std.testing.expectEqual(Action.open_palette, map.resolve(.ctrl_p).?);
    try std.testing.expectEqual(Action.move_up, map.resolve(.up).?);
    try std.testing.expect(map.resolve(.down) == null);
}

test "action map distinguishes char values" {
    const Action = enum { slash };
    var map = ActionMap(Action).init(std.testing.allocator);
    defer map.deinit();
    try map.bind(.{ .char = '/' }, .slash);

    try std.testing.expect(map.contains(.{ .char = '/' }));
    try std.testing.expect(!map.contains(.{ .char = ':' }));
}
