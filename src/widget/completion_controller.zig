const std = @import("std");
const parser = @import("../terminal/parser.zig");
const completion = @import("completion.zig");
const editor_mod = @import("editor.zig");

pub const Item = completion.Item;

pub const State = struct {
    popup: completion.State = .{},
    viewport: usize = 8,

    pub const Snapshot = struct {
        selected: usize = 0,
        visible: bool = false,
    };

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        self.popup.deinit(allocator);
    }

    pub fn clear(self: *State, allocator: std.mem.Allocator) void {
        self.popup.clear(allocator);
    }

    pub fn refresh(
        self: *State,
        allocator: std.mem.Allocator,
        editor: *const editor_mod.Editor,
        items: []const Item,
    ) !void {
        try completion.update(allocator, &self.popup, editor, items);
    }

    pub fn sync(
        self: *State,
        allocator: std.mem.Allocator,
        editor: *const editor_mod.Editor,
        items: []const Item,
    ) !void {
        if (!self.popup.visible) return;
        const range = editor.tokenRangeAtCursor() orelse {
            self.clear(allocator);
            return;
        };
        if (range.start != self.popup.anchor_start or range.end != self.popup.anchor_end or editor.cursor < range.start or editor.cursor > range.end) {
            try self.refresh(allocator, editor, items);
        }
    }

    pub fn current(self: *const State) ?completion.Match {
        return self.popup.current();
    }

    pub fn handleKey(
        self: *State,
        allocator: std.mem.Allocator,
        editor: *editor_mod.Editor,
        key: parser.Key,
        items: []const Item,
    ) !bool {
        if (!self.popup.visible) return false;
        switch (key) {
            .up => self.popup.selectPrevious(),
            .down => self.popup.selectNext(),
            .page_up => self.pageUp(),
            .page_down => self.pageDown(),
            .tab, .enter => {
                if (try self.popup.applyCurrent(allocator, editor)) {
                    self.clear(allocator);
                }
            },
            .escape => self.clear(allocator),
            else => return false,
        }
        try self.sync(allocator, editor, items);
        return true;
    }

    pub fn pageUp(self: *State) void {
        if (!self.popup.visible or self.popup.matches.len == 0) return;
        self.popup.selected = self.popup.selected -| @max(self.viewport, 1);
    }

    pub fn pageDown(self: *State) void {
        if (!self.popup.visible or self.popup.matches.len == 0) return;
        self.popup.selected = @min(self.popup.selected + @max(self.viewport, 1), self.popup.matches.len - 1);
    }

    pub fn snapshot(self: *const State) Snapshot {
        return .{
            .selected = self.popup.selected,
            .visible = self.popup.visible,
        };
    }

    pub fn restore(self: *State, saved: Snapshot) void {
        self.popup.selected = saved.selected;
        self.popup.visible = saved.visible;
    }
};

test "completion controller refreshes and applies" {
    var editor = try editor_mod.Editor.init(std.testing.allocator, "co");
    defer editor.deinit(std.testing.allocator);

    const items = [_]Item{
        .{ .label = "const", .value = "const " },
        .{ .label = "continue", .value = "continue" },
        .{ .label = "var", .value = "var " },
    };

    var state: State = .{};
    defer state.deinit(std.testing.allocator);

    try state.refresh(std.testing.allocator, &editor, &items);
    try std.testing.expect(state.popup.visible);
    try std.testing.expectEqualStrings("const", state.current().?.item.label);
    state.popup.selectNext();
    try std.testing.expect(try state.handleKey(std.testing.allocator, &editor, .enter, &items));
    try std.testing.expectEqualStrings("continue", editor.value);
}
