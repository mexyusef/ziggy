const std = @import("std");
const surface_mod = @import("../widget/surface.zig");

pub const Kind = enum {
    modal,
    non_modal,
    autocomplete,
    palette,
    tooltip,
};

pub const Entry = struct {
    id: []u8,
    title: ?[]u8 = null,
    kind: Kind,
    anchor: ?surface_mod.Rect = null,

    fn deinit(self: *Entry, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        if (self.title) |title| allocator.free(title);
    }
};

pub const State = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(Entry) = .empty,

    pub fn init(allocator: std.mem.Allocator) State {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *State) void {
        for (self.entries.items) |*entry| entry.deinit(self.allocator);
        self.entries.deinit(self.allocator);
    }

    pub fn push(self: *State, id: []const u8, title: ?[]const u8, kind: Kind, anchor: ?surface_mod.Rect) !void {
        try self.entries.append(self.allocator, .{
            .id = try self.allocator.dupe(u8, id),
            .title = if (title) |value| try self.allocator.dupe(u8, value) else null,
            .kind = kind,
            .anchor = anchor,
        });
    }

    pub fn pop(self: *State, id: []const u8) bool {
        var index = self.entries.items.len;
        while (index > 0) {
            index -= 1;
            if (std.mem.eql(u8, self.entries.items[index].id, id)) {
                var removed = self.entries.orderedRemove(index);
                removed.deinit(self.allocator);
                return true;
            }
        }
        return false;
    }

    pub fn clear(self: *State) void {
        while (self.entries.items.len > 0) {
            var entry = self.entries.pop().?;
            entry.deinit(self.allocator);
        }
    }

    pub fn top(self: *const State) ?Entry {
        if (self.entries.items.len == 0) return null;
        return self.entries.items[self.entries.items.len - 1];
    }

    pub fn topModal(self: *const State) ?Entry {
        var index = self.entries.items.len;
        while (index > 0) {
            index -= 1;
            const entry = self.entries.items[index];
            if (entry.kind == .modal or entry.kind == .palette) return entry;
        }
        return null;
    }

    pub fn hasBlockingOverlay(self: *const State) bool {
        return self.topModal() != null;
    }

    pub fn allowsInput(self: *const State) bool {
        return !self.hasBlockingOverlay();
    }

    pub fn isVisible(self: *const State, id: []const u8) bool {
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.id, id)) return true;
        }
        return false;
    }
};

test "overlay state keeps non modal input active" {
    var state = State.init(std.testing.allocator);
    defer state.deinit();

    try state.push("autocomplete", "Autocomplete", .autocomplete, null);
    try std.testing.expect(state.allowsInput());
    try std.testing.expect(state.isVisible("autocomplete"));
}

test "overlay state blocks input for modal" {
    var state = State.init(std.testing.allocator);
    defer state.deinit();

    try state.push("confirm", "Confirm", .modal, null);
    try std.testing.expect(!state.allowsInput());
    try std.testing.expect(state.hasBlockingOverlay());
    try std.testing.expect(state.pop("confirm"));
    try std.testing.expect(state.allowsInput());
}
