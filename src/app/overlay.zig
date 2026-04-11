const std = @import("std");
const surface_mod = @import("../widget/surface.zig");

pub const Kind = enum {
    modal,
    non_modal,
    autocomplete,
    palette,
    tooltip,
    dropdown,
    context_menu,

    pub fn blocksInput(self: Kind) bool {
        return switch (self) {
            .modal, .palette => true,
            .non_modal, .autocomplete, .tooltip, .dropdown, .context_menu => false,
        };
    }

    pub fn isAnchored(self: Kind) bool {
        return switch (self) {
            .autocomplete, .tooltip, .dropdown, .context_menu => true,
            .modal, .non_modal, .palette => false,
        };
    }
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

    pub fn pushOrUpdate(self: *State, id: []const u8, title: ?[]const u8, kind: Kind, anchor: ?surface_mod.Rect) !void {
        if (self.indexOf(id)) |index| {
            var entry = &self.entries.items[index];
            if (entry.title) |existing| self.allocator.free(existing);
            entry.title = if (title) |value| try self.allocator.dupe(u8, value) else null;
            entry.kind = kind;
            entry.anchor = anchor;
            return;
        }
        try self.push(id, title, kind, anchor);
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
        return self.topBlocking();
    }

    pub fn topBlocking(self: *const State) ?Entry {
        var index = self.entries.items.len;
        while (index > 0) {
            index -= 1;
            const entry = self.entries.items[index];
            if (entry.kind.blocksInput()) return entry;
        }
        return null;
    }

    pub fn topAnchored(self: *const State) ?Entry {
        var index = self.entries.items.len;
        while (index > 0) {
            index -= 1;
            const entry = self.entries.items[index];
            if (entry.kind.isAnchored()) return entry;
        }
        return null;
    }

    pub fn hasBlockingOverlay(self: *const State) bool {
        return self.topBlocking() != null;
    }

    pub fn allowsInput(self: *const State) bool {
        return !self.hasBlockingOverlay();
    }

    pub fn isVisible(self: *const State, id: []const u8) bool {
        return self.indexOf(id) != null;
    }

    pub fn indexOf(self: *const State, id: []const u8) ?usize {
        for (self.entries.items, 0..) |entry, index| {
            if (std.mem.eql(u8, entry.id, id)) return index;
        }
        return null;
    }

    pub fn anchoredCount(self: *const State) usize {
        var count: usize = 0;
        for (self.entries.items) |entry| {
            if (entry.kind.isAnchored()) count += 1;
        }
        return count;
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

test "overlay state updates existing entry in place" {
    var state = State.init(std.testing.allocator);
    defer state.deinit();

    try state.push("menu", "Menu", .context_menu, null);
    try state.pushOrUpdate("menu", "Context", .dropdown, .{ .x = 1, .y = 2, .width = 3, .height = 4 });
    try std.testing.expectEqual(@as(usize, 1), state.entries.items.len);
    try std.testing.expectEqual(Kind.dropdown, state.entries.items[0].kind);
    try std.testing.expectEqual(@as(usize, 1), state.anchoredCount());
}
