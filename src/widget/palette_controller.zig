const std = @import("std");
const editor_mod = @import("editor.zig");
const selection_model = @import("selection_model.zig");

pub const Entry = struct {
    label: []const u8,
    value: ?[]const u8 = null,
    detail: ?[]const u8 = null,
};

pub const Match = struct {
    index: usize,
};

pub const State = struct {
    query: editor_mod.Editor,
    matches: std.ArrayListUnmanaged(Match) = .{},
    selected: usize = 0,
    offset: usize = 0,
    viewport: usize = 8,
    open: bool = false,

    pub const Snapshot = struct {
        query: []const u8,
        selected: usize = 0,
        offset: usize = 0,
        viewport: usize = 8,
        open: bool = false,

        pub fn deinit(self: *Snapshot, allocator: std.mem.Allocator) void {
            allocator.free(self.query);
            self.* = .{ .query = "" };
        }
    };

    pub fn init(allocator: std.mem.Allocator, initial_query: []const u8) !State {
        return .{
            .query = try editor_mod.Editor.init(allocator, initial_query),
        };
    }

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        self.query.deinit(allocator);
        self.matches.deinit(allocator);
    }

    pub fn refresh(self: *State, allocator: std.mem.Allocator, entries: []const Entry) !void {
        self.matches.clearRetainingCapacity();
        for (entries, 0..) |entry, index| {
            if (matchesQuery(entry.label, self.query.value)) {
                try self.matches.append(allocator, .{ .index = index });
            }
        }
        self.selected = selection_model.clampIndex(self.selected, self.matches.items.len);
        self.offset = selection_model.windowOffset(self.selected, self.matches.items.len, self.viewport, self.offset);
        self.open = self.matches.items.len > 0;
    }

    pub fn labels(self: *const State, allocator: std.mem.Allocator, entries: []const Entry) ![]const []const u8 {
        const out = try allocator.alloc([]const u8, self.matches.items.len);
        for (self.matches.items, 0..) |match, index| out[index] = entries[match.index].label;
        return out;
    }

    pub fn current(self: *const State, entries: []const Entry) ?Entry {
        if (!self.open or self.matches.items.len == 0 or self.selected >= self.matches.items.len) return null;
        return entries[self.matches.items[self.selected].index];
    }

    pub fn currentLabelIndex(self: *const State) ?usize {
        if (!self.open or self.matches.items.len == 0 or self.selected >= self.matches.items.len) return null;
        return self.matches.items[self.selected].index;
    }

    pub fn moveNext(self: *State) void {
        if (!self.open or self.matches.items.len == 0) return;
        selection_model.move(&self.selected, self.matches.items.len, .next, true);
        self.offset = selection_model.windowOffset(self.selected, self.matches.items.len, self.viewport, self.offset);
    }

    pub fn movePrevious(self: *State) void {
        if (!self.open or self.matches.items.len == 0) return;
        selection_model.move(&self.selected, self.matches.items.len, .previous, true);
        self.offset = selection_model.windowOffset(self.selected, self.matches.items.len, self.viewport, self.offset);
    }

    pub fn pageDown(self: *State) void {
        if (!self.open or self.matches.items.len == 0) return;
        self.selected = @min(self.selected + self.viewport, self.matches.items.len - 1);
        self.offset = selection_model.windowOffset(self.selected, self.matches.items.len, self.viewport, self.offset);
    }

    pub fn pageUp(self: *State) void {
        if (!self.open or self.matches.items.len == 0) return;
        self.selected = self.selected -| self.viewport;
        self.offset = selection_model.windowOffset(self.selected, self.matches.items.len, self.viewport, self.offset);
    }

    pub fn clear(self: *State) void {
        self.selected = 0;
        self.offset = 0;
        self.open = false;
        self.matches.clearRetainingCapacity();
    }

    pub fn snapshot(self: *const State, allocator: std.mem.Allocator) !Snapshot {
        return .{
            .query = try allocator.dupe(u8, self.query.value),
            .selected = self.selected,
            .offset = self.offset,
            .viewport = self.viewport,
            .open = self.open,
        };
    }

    pub fn restore(self: *State, allocator: std.mem.Allocator, saved: Snapshot, entries: []const Entry) !void {
        try self.query.setText(allocator, saved.query, saved.query.len);
        self.selected = saved.selected;
        self.offset = saved.offset;
        self.viewport = saved.viewport;
        self.open = saved.open;
        try self.refresh(allocator, entries);
        if (!saved.open) self.open = false;
    }
};

fn matchesQuery(label: []const u8, query: []const u8) bool {
    if (query.len == 0) return true;
    return containsIgnoreCase(label, query);
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;
    var start: usize = 0;
    while (start + needle.len <= haystack.len) : (start += 1) {
        var index: usize = 0;
        while (index < needle.len and std.ascii.toLower(haystack[start + index]) == std.ascii.toLower(needle[index])) : (index += 1) {}
        if (index == needle.len) return true;
    }
    return false;
}

test "palette controller filters and moves selection" {
    const entries = [_]Entry{
        .{ .label = "Open File" },
        .{ .label = "Switch Buffer" },
        .{ .label = "Format Document" },
    };
    var state = try State.init(std.testing.allocator, "f");
    defer state.deinit(std.testing.allocator);
    try state.refresh(std.testing.allocator, &entries);
    try std.testing.expect(state.open);
    try std.testing.expectEqual(@as(usize, 3), state.matches.items.len);
    try std.testing.expectEqualStrings("Open File", state.current(&entries).?.label);
    state.moveNext();
    try std.testing.expectEqualStrings("Switch Buffer", state.current(&entries).?.label);
}

test "palette controller snapshot roundtrip preserves query" {
    const entries = [_]Entry{
        .{ .label = "Open File" },
        .{ .label = "Switch Buffer" },
    };
    var state = try State.init(std.testing.allocator, "sw");
    defer state.deinit(std.testing.allocator);
    try state.refresh(std.testing.allocator, &entries);

    var snapshot = try state.snapshot(std.testing.allocator);
    defer snapshot.deinit(std.testing.allocator);

    var restored = try State.init(std.testing.allocator, "");
    defer restored.deinit(std.testing.allocator);
    try restored.restore(std.testing.allocator, snapshot, &entries);
    try std.testing.expectEqualStrings("sw", restored.query.value);
}
