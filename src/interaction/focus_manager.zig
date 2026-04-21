const std = @import("std");
const focus_mod = @import("../widget/focus.zig");
const focus_nav = @import("../widget/focus_nav.zig");

pub const Manager = struct {
    active: bool = true,
    current_id: ?[]const u8 = null,

    pub fn focus(self: *Manager, id: ?[]const u8) void {
        self.current_id = id;
        self.active = id != null;
    }

    pub fn clear(self: *Manager) void {
        self.focus(null);
    }

    pub fn isFocused(self: *const Manager, id: []const u8) bool {
        if (!self.active) return false;
        return if (self.current_id) |current| std.mem.eql(u8, current, id) else false;
    }

    pub fn sync(self: *const Manager, id: []const u8) focus_mod.FocusState {
        return .{
            .active = self.isFocused(id),
            .focus_id = self.current_id,
        };
    }

    pub fn next(self: *Manager, targets: []const focus_mod.FocusTarget) ?[]const u8 {
        const index = focus_nav.next(targets, self.current_id) orelse return null;
        self.focus(targets[index].id);
        return self.current_id;
    }

    pub fn previous(self: *Manager, targets: []const focus_mod.FocusTarget) ?[]const u8 {
        const index = focus_nav.previous(targets, self.current_id) orelse return null;
        self.focus(targets[index].id);
        return self.current_id;
    }
};

test "focus manager cycles through targets" {
    const targets = [_]focus_mod.FocusTarget{
        .{ .id = "menu" },
        .{ .id = "preview" },
        .{ .id = "footer" },
    };

    var manager: Manager = .{};
    try std.testing.expectEqualStrings("menu", manager.next(&targets).?);
    try std.testing.expectEqualStrings("preview", manager.next(&targets).?);
    try std.testing.expectEqualStrings("menu", manager.previous(&targets).?);
}

test "focus manager sync exposes active focus state" {
    var manager: Manager = .{};
    manager.focus("examples");
    const focused = manager.sync("examples");
    const blurred = manager.sync("preview");
    try std.testing.expect(focused.active);
    try std.testing.expect(!blurred.active);
    try std.testing.expectEqualStrings("examples", focused.focus_id.?);
}
