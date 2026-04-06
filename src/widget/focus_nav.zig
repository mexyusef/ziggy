const std = @import("std");
const focus_mod = @import("focus.zig");

pub fn next(targets: []const focus_mod.FocusTarget, current_id: ?[]const u8) ?usize {
    if (targets.len == 0) return null;
    if (current_id) |id| {
        for (targets, 0..) |target, index| {
            if (std.mem.eql(u8, target.id, id)) {
                return (index + 1) % targets.len;
            }
        }
    }
    return 0;
}

pub fn previous(targets: []const focus_mod.FocusTarget, current_id: ?[]const u8) ?usize {
    if (targets.len == 0) return null;
    if (current_id) |id| {
        for (targets, 0..) |target, index| {
            if (std.mem.eql(u8, target.id, id)) {
                return if (index == 0) targets.len - 1 else index - 1;
            }
        }
    }
    return targets.len - 1;
}

test "focus navigation wraps around" {
    const targets = [_]focus_mod.FocusTarget{
        .{ .id = "one" },
        .{ .id = "two" },
        .{ .id = "three" },
    };
    try std.testing.expectEqual(@as(?usize, 1), next(&targets, "one"));
    try std.testing.expectEqual(@as(?usize, 2), previous(&targets, "one"));
    try std.testing.expectEqual(@as(?usize, 0), next(&targets, "missing"));
}
