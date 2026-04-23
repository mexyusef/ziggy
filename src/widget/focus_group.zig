const std = @import("std");
const focus_mod = @import("focus.zig");

pub const Entry = struct {
    id: []const u8,
    enabled: bool = true,
    active: bool = false,

    pub fn toTarget(self: Entry) focus_mod.FocusTarget {
        return .{ .id = self.id, .active = self.active };
    }
};

pub fn normalize(entries: []const Entry, current_id: ?[]const u8) ?[]const u8 {
    if (current_id) |id| {
        for (entries) |entry| {
            if (entry.enabled and std.mem.eql(u8, entry.id, id)) return entry.id;
        }
    }
    for (entries) |entry| {
        if (entry.enabled) return entry.id;
    }
    return null;
}

pub fn next(entries: []const Entry, current_id: ?[]const u8) ?[]const u8 {
    const start_id = normalize(entries, current_id) orelse return null;
    var current_index: usize = 0;
    for (entries, 0..) |entry, index| {
        if (entry.enabled and std.mem.eql(u8, entry.id, start_id)) {
            current_index = index;
            break;
        }
    }
    var step: usize = 1;
    while (step <= entries.len) : (step += 1) {
        const candidate = entries[(current_index + step) % entries.len];
        if (candidate.enabled) return candidate.id;
    }
    return start_id;
}

pub fn previous(entries: []const Entry, current_id: ?[]const u8) ?[]const u8 {
    const start_id = normalize(entries, current_id) orelse return null;
    var current_index: usize = 0;
    for (entries, 0..) |entry, index| {
        if (entry.enabled and std.mem.eql(u8, entry.id, start_id)) {
            current_index = index;
            break;
        }
    }
    var step: usize = 1;
    while (step <= entries.len) : (step += 1) {
        const candidate = entries[(current_index + entries.len - step) % entries.len];
        if (candidate.enabled) return candidate.id;
    }
    return start_id;
}

test "focus group normalizes to first enabled entry" {
    const entries = [_]Entry{
        .{ .id = "conversation" },
        .{ .id = "activity", .enabled = false },
        .{ .id = "input" },
    };
    try std.testing.expectEqualStrings("conversation", normalize(&entries, "activity").?);
}

test "focus group skips disabled entries when moving" {
    const entries = [_]Entry{
        .{ .id = "conversation" },
        .{ .id = "activity", .enabled = false },
        .{ .id = "repo", .enabled = false },
        .{ .id = "input" },
    };
    try std.testing.expectEqualStrings("input", next(&entries, "conversation").?);
    try std.testing.expectEqualStrings("conversation", previous(&entries, "input").?);
}
