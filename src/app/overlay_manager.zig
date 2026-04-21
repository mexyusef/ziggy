const std = @import("std");
const overlay_mod = @import("overlay.zig");
const surface_mod = @import("../widget/surface.zig");
const overlay_runtime = @import("../interaction/overlay_runtime.zig");

pub const Manager = struct {
    state: *overlay_mod.State,

    pub fn init(state: *overlay_mod.State) Manager {
        return .{ .state = state };
    }

    pub fn openModal(self: *Manager, id: []const u8, title: ?[]const u8) !void {
        try self.state.pushOrUpdate(id, title, .modal, null);
    }

    pub fn openPalette(self: *Manager, id: []const u8, title: ?[]const u8) !void {
        try self.state.pushOrUpdate(id, title, .palette, null);
    }

    pub fn openNonModal(self: *Manager, id: []const u8, title: ?[]const u8) !void {
        try self.state.pushOrUpdate(id, title, .non_modal, null);
    }

    pub fn openAutocomplete(self: *Manager, id: []const u8, title: ?[]const u8, anchor: ?surface_mod.Rect) !void {
        try self.state.pushOrUpdate(id, title, .autocomplete, anchor);
    }

    pub fn openTooltip(self: *Manager, id: []const u8, title: ?[]const u8, anchor: ?surface_mod.Rect) !void {
        try self.state.pushOrUpdate(id, title, .tooltip, anchor);
    }

    pub fn openDropdown(self: *Manager, id: []const u8, title: ?[]const u8, anchor: ?surface_mod.Rect) !void {
        try self.state.pushOrUpdate(id, title, .dropdown, anchor);
    }

    pub fn openContextMenu(self: *Manager, id: []const u8, title: ?[]const u8, anchor: ?surface_mod.Rect) !void {
        try self.state.pushOrUpdate(id, title, .context_menu, anchor);
    }

    pub fn placeAnchored(
        self: *Manager,
        id: []const u8,
        title: ?[]const u8,
        kind: overlay_mod.Kind,
        container: surface_mod.Rect,
        anchor: surface_mod.Rect,
        width: u16,
        height: u16,
    ) !surface_mod.Rect {
        const rect = overlay_runtime.resolvePopupRect(container, anchor, .{
            .width = width,
            .height = height,
        });
        try self.state.pushOrUpdate(id, title, kind, rect);
        return rect;
    }

    pub fn close(self: *Manager, id: []const u8) void {
        _ = self.state.pop(id);
    }

    pub fn closeAll(self: *Manager) void {
        self.state.clear();
    }
};

test "overlay manager opens and closes palette" {
    var state = overlay_mod.State.init(std.testing.allocator);
    defer state.deinit();
    var manager = Manager.init(&state);
    try manager.openPalette("palette", "Command Palette");
    try std.testing.expect(state.isVisible("palette"));
    manager.close("palette");
    try std.testing.expect(!state.isVisible("palette"));
}

test "overlay manager updates anchored overlays" {
    var state = overlay_mod.State.init(std.testing.allocator);
    defer state.deinit();
    var manager = Manager.init(&state);

    try manager.openTooltip("hint", "Hint", .{ .x = 0, .y = 0, .width = 1, .height = 1 });
    try manager.openTooltip("hint", "Hint", .{ .x = 4, .y = 3, .width = 2, .height = 1 });
    try std.testing.expectEqual(@as(usize, 1), state.entries.items.len);
    try std.testing.expectEqual(@as(u16, 4), state.entries.items[0].anchor.?.x);
}

test "overlay manager places anchored popup inside container" {
    var state = overlay_mod.State.init(std.testing.allocator);
    defer state.deinit();
    var manager = Manager.init(&state);
    const rect = try manager.placeAnchored("menu", "Menu", .dropdown, .{ .x = 0, .y = 0, .width = 20, .height = 10 }, .{ .x = 18, .y = 8, .width = 2, .height = 1 }, 6, 3);
    try std.testing.expectEqual(@as(u16, 14), rect.x);
    try std.testing.expect(state.isVisible("menu"));
}
