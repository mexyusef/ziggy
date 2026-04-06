const std = @import("std");
const overlay_mod = @import("overlay.zig");
const surface_mod = @import("../widget/surface.zig");

pub const Manager = struct {
    state: *overlay_mod.State,

    pub fn init(state: *overlay_mod.State) Manager {
        return .{ .state = state };
    }

    pub fn openModal(self: *Manager, id: []const u8, title: ?[]const u8) !void {
        if (!self.state.isVisible(id)) try self.state.push(id, title, .modal, null);
    }

    pub fn openPalette(self: *Manager, id: []const u8, title: ?[]const u8) !void {
        if (!self.state.isVisible(id)) try self.state.push(id, title, .palette, null);
    }

    pub fn openAutocomplete(self: *Manager, id: []const u8, title: ?[]const u8, anchor: ?surface_mod.Rect) !void {
        if (!self.state.isVisible(id)) try self.state.push(id, title, .autocomplete, anchor);
    }

    pub fn openTooltip(self: *Manager, id: []const u8, title: ?[]const u8, anchor: ?surface_mod.Rect) !void {
        if (!self.state.isVisible(id)) try self.state.push(id, title, .tooltip, anchor);
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
