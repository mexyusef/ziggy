const std = @import("std");
const parser = @import("../terminal/parser.zig");
const selection_model = @import("../widget/selection_model.zig");

pub const Action = enum {
    none,
    moved,
    changed,
    submitted,
    cancelled,
    opened,
    closed,
};

pub const Response = struct {
    handled: bool = false,
    redraw: bool = false,
    action: Action = .none,
    selected: ?usize = null,
};

pub const SelectState = struct {
    open: bool = false,
    cursor: usize = 0,
    selected: ?usize = null,
    offset: usize = 0,
    focused: bool = true,
    viewport: usize = 8,
    wrap: bool = false,

    pub fn normalize(self: *SelectState, count: usize) void {
        self.cursor = selection_model.clampIndex(self.cursor, count);
        self.selected = selection_model.ensureOptionalIndex(self.selected, count);
        self.offset = selection_model.windowOffset(self.cursor, count, self.viewport, self.offset);
    }

    pub fn openMenu(self: *SelectState, count: usize) Response {
        self.open = true;
        self.normalize(count);
        return .{ .handled = true, .redraw = true, .action = .opened, .selected = self.selected };
    }

    pub fn closeMenu(self: *SelectState) Response {
        self.open = false;
        return .{ .handled = true, .redraw = true, .action = .closed, .selected = self.selected };
    }

    pub fn moveEnabled(self: *SelectState, comptime Item: type, items: []const Item, direction: selection_model.Direction) Response {
        if (!self.focused or items.len == 0) return .{};
        self.normalize(items.len);
        selection_model.moveEnabled(Item, &self.cursor, items, direction, self.wrap);
        self.normalize(items.len);
        return .{ .handled = true, .redraw = true, .action = .moved, .selected = self.selected };
    }

    pub fn activateEnabled(self: *SelectState, comptime Item: type, items: []const Item) Response {
        if (!self.focused or items.len == 0) return .{};
        self.normalize(items.len);
        if (selection_model.activateEnabled(Item, &self.selected, self.cursor, items)) {
            return .{ .handled = true, .redraw = true, .action = .submitted, .selected = self.selected };
        }
        return .{};
    }

    pub fn handleListKey(self: *SelectState, count: usize, key: parser.Key) Response {
        if (!self.focused or count == 0) return .{};
        self.normalize(count);
        switch (key) {
            .up => {
                selection_model.move(&self.cursor, count, .previous, self.wrap);
                self.normalize(count);
                return .{ .handled = true, .redraw = true, .action = .moved, .selected = self.selected };
            },
            .down => {
                selection_model.move(&self.cursor, count, .next, self.wrap);
                self.normalize(count);
                return .{ .handled = true, .redraw = true, .action = .moved, .selected = self.selected };
            },
            .page_up => {
                self.cursor = self.cursor -| @max(self.viewport, 1);
                self.normalize(count);
                return .{ .handled = true, .redraw = true, .action = .moved, .selected = self.selected };
            },
            .page_down => {
                self.cursor = @min(self.cursor + @max(self.viewport, 1), count - 1);
                self.normalize(count);
                return .{ .handled = true, .redraw = true, .action = .moved, .selected = self.selected };
            },
            .home => {
                self.cursor = 0;
                self.normalize(count);
                return .{ .handled = true, .redraw = true, .action = .moved, .selected = self.selected };
            },
            .end => {
                self.cursor = count - 1;
                self.normalize(count);
                return .{ .handled = true, .redraw = true, .action = .moved, .selected = self.selected };
            },
            .enter => {
                self.selected = self.cursor;
                return .{ .handled = true, .redraw = true, .action = .submitted, .selected = self.selected };
            },
            .escape => return .{ .handled = true, .redraw = true, .action = .cancelled, .selected = self.selected },
            else => return .{},
        }
    }
};

test "select state keeps the cursor visible" {
    var state: SelectState = .{ .cursor = 7, .viewport = 4 };
    state.normalize(10);
    try std.testing.expectEqual(@as(usize, 4), state.offset);
}

test "select state handles paging" {
    var state: SelectState = .{ .viewport = 3 };
    _ = state.handleListKey(10, .page_down);
    try std.testing.expectEqual(@as(usize, 3), state.cursor);
    _ = state.handleListKey(10, .page_up);
    try std.testing.expectEqual(@as(usize, 0), state.cursor);
}
