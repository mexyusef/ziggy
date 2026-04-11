const std = @import("std");
const parser = @import("../terminal/parser.zig");
const input_mod = @import("input.zig");
const keymap_mod = @import("keymap.zig");

pub fn Router(comptime Scope: type, comptime Action: type) type {
    return struct {
        allocator: std.mem.Allocator,
        bindings: std.ArrayList(Binding) = .empty,
        last_scope: ?Scope = null,
        last_action: ?Action = null,

        const Self = @This();

        pub const Binding = struct {
            scope: ?Scope = null,
            key: parser.Key,
            action: Action,
        };

        pub const Resolved = struct {
            scope: ?Scope,
            action: Action,
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            self.bindings.deinit(self.allocator);
        }

        pub fn bindGlobal(self: *Self, key: parser.Key, action: Action) !void {
            try self.bind(null, key, action);
        }

        pub fn bind(self: *Self, scope: ?Scope, key: parser.Key, action: Action) !void {
            try self.bindings.append(self.allocator, .{
                .scope = scope,
                .key = key,
                .action = action,
            });
        }

        pub fn resolve(self: *const Self, scopes: []const Scope, key: parser.Key) ?Resolved {
            for (scopes) |scope| {
                for (self.bindings.items) |binding| {
                    if (binding.scope == null) continue;
                    if (binding.scope.? == scope and keymap_mod.eqlKey(binding.key, key)) {
                        return .{ .scope = scope, .action = binding.action };
                    }
                }
            }
            for (self.bindings.items) |binding| {
                if (binding.scope == null and keymap_mod.eqlKey(binding.key, key)) {
                    return .{ .scope = null, .action = binding.action };
                }
            }
            return null;
        }

        pub fn handleKey(self: *Self, event: *input_mod.KeyEvent, scopes: []const Scope) ?Resolved {
            const resolved = self.resolve(scopes, event.key) orelse return null;
            self.last_scope = resolved.scope;
            self.last_action = resolved.action;
            event.preventDefault();
            event.stopPropagation();
            return resolved;
        }
    };
}

test "action router resolves scoped bindings before globals" {
    const Scope = enum { workspace, palette };
    const Action = enum { close, move_next };

    var router = Router(Scope, Action).init(std.testing.allocator);
    defer router.deinit();
    try router.bindGlobal(.escape, .close);
    try router.bind(.palette, .down, .move_next);

    const resolved = router.resolve(&.{ .palette, .workspace }, .down).?;
    try std.testing.expectEqual(Scope.palette, resolved.scope.?);
    try std.testing.expectEqual(Action.move_next, resolved.action);
    try std.testing.expectEqual(Action.close, router.resolve(&.{.workspace}, .escape).?.action);
}
