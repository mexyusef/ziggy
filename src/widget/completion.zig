const std = @import("std");
const editor_mod = @import("editor.zig");
const selection_model = @import("selection_model.zig");

pub const Item = struct {
    label: []const u8,
    value: []const u8,
    detail: ?[]const u8 = null,
};

pub const Match = struct {
    item: Item,
};

pub const State = struct {
    matches: []Match = &.{},
    selected: usize = 0,
    visible: bool = false,
    anchor_start: usize = 0,
    anchor_end: usize = 0,

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        allocator.free(self.matches);
        self.* = .{};
    }

    pub fn clear(self: *State, allocator: std.mem.Allocator) void {
        allocator.free(self.matches);
        self.* = .{};
    }

    pub fn current(self: *const State) ?Match {
        if (!self.visible or self.matches.len == 0 or self.selected >= self.matches.len) return null;
        return self.matches[self.selected];
    }

    pub fn selectNext(self: *State) void {
        if (!self.visible or self.matches.len == 0) return;
        selection_model.move(&self.selected, self.matches.len, .next, true);
    }

    pub fn selectPrevious(self: *State) void {
        if (!self.visible or self.matches.len == 0) return;
        selection_model.move(&self.selected, self.matches.len, .previous, true);
    }

    pub fn applyCurrent(self: *State, allocator: std.mem.Allocator, editor: *editor_mod.Editor) !bool {
        const current_match = self.current() orelse return false;
        try editor.replaceRange(allocator, self.anchor_start, self.anchor_end, current_match.item.value);
        return true;
    }
};

pub fn update(
    allocator: std.mem.Allocator,
    state: *State,
    editor: *const editor_mod.Editor,
    items: []const Item,
) !void {
    const range = editor.tokenRangeAtCursor() orelse {
        state.clear(allocator);
        return;
    };
    const token = editor.value[range.start..range.end];

    var matches = std.ArrayList(Match).empty;
    defer matches.deinit(allocator);

    for (items) |item| {
        if (token.len == 0 or std.ascii.startsWithIgnoreCase(item.label, token) or std.ascii.startsWithIgnoreCase(item.value, token)) {
            try matches.append(allocator, .{ .item = item });
        }
    }

    allocator.free(state.matches);
    state.matches = try matches.toOwnedSlice(allocator);
    state.selected = 0;
    state.visible = state.matches.len > 0;
    state.anchor_start = range.start;
    state.anchor_end = range.end;
}

test "completion update and apply" {
    var editor = try editor_mod.Editor.init(std.testing.allocator, "/he");
    defer editor.deinit(std.testing.allocator);

    const items = [_]Item{
        .{ .label = "/help", .value = "/help" },
        .{ .label = "/hello", .value = "/hello" },
        .{ .label = "/exit", .value = "/exit" },
    };

    var state: State = .{};
    defer state.deinit(std.testing.allocator);

    try update(std.testing.allocator, &state, &editor, &items);
    try std.testing.expect(state.visible);
    try std.testing.expectEqual(@as(usize, 2), state.matches.len);
    try std.testing.expectEqualStrings("/help", state.current().?.item.value);

    state.selectNext();
    try std.testing.expectEqualStrings("/hello", state.current().?.item.value);

    try std.testing.expect(try state.applyCurrent(std.testing.allocator, &editor));
    try std.testing.expectEqualStrings("/hello", editor.value);
}
