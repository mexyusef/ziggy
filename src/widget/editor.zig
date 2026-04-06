const std = @import("std");

pub const Editor = struct {
    value: []u8,
    cursor: usize = 0,
    selection_anchor: ?usize = null,

    pub fn init(allocator: std.mem.Allocator, initial: []const u8) !Editor {
        return .{
            .value = try allocator.dupe(u8, initial),
            .cursor = initial.len,
        };
    }

    pub fn initWithCursor(allocator: std.mem.Allocator, initial: []const u8, cursor: usize) !Editor {
        return .{
            .value = try allocator.dupe(u8, initial),
            .cursor = @min(cursor, initial.len),
        };
    }

    pub fn deinit(self: *Editor, allocator: std.mem.Allocator) void {
        allocator.free(self.value);
        self.value = &.{};
        self.cursor = 0;
        self.selection_anchor = null;
    }

    pub fn setText(self: *Editor, allocator: std.mem.Allocator, value: []const u8, cursor: usize) !void {
        allocator.free(self.value);
        self.value = try allocator.dupe(u8, value);
        self.cursor = @min(cursor, value.len);
        self.selection_anchor = null;
    }

    pub fn clear(self: *Editor, allocator: std.mem.Allocator) !void {
        try self.setText(allocator, "", 0);
    }

    pub fn insertChar(self: *Editor, allocator: std.mem.Allocator, byte: u8) !void {
        var buf = try allocator.alloc(u8, self.value.len + 1);
        @memcpy(buf[0..self.cursor], self.value[0..self.cursor]);
        buf[self.cursor] = byte;
        @memcpy(buf[self.cursor + 1 ..], self.value[self.cursor..]);
        allocator.free(self.value);
        self.value = buf;
        self.cursor += 1;
        self.selection_anchor = null;
    }

    pub fn insertText(self: *Editor, allocator: std.mem.Allocator, text: []const u8) !void {
        if (text.len == 0) return;
        var buf = try allocator.alloc(u8, self.value.len + text.len);
        @memcpy(buf[0..self.cursor], self.value[0..self.cursor]);
        @memcpy(buf[self.cursor .. self.cursor + text.len], text);
        @memcpy(buf[self.cursor + text.len ..], self.value[self.cursor..]);
        allocator.free(self.value);
        self.value = buf;
        self.cursor += text.len;
        self.selection_anchor = null;
    }

    pub fn insertNewline(self: *Editor, allocator: std.mem.Allocator) !void {
        try self.insertChar(allocator, '\n');
    }

    pub fn backspace(self: *Editor, allocator: std.mem.Allocator) !void {
        if (self.cursor == 0) return;
        var buf = try allocator.alloc(u8, self.value.len - 1);
        @memcpy(buf[0 .. self.cursor - 1], self.value[0 .. self.cursor - 1]);
        @memcpy(buf[self.cursor - 1 ..], self.value[self.cursor..]);
        allocator.free(self.value);
        self.value = buf;
        self.cursor -= 1;
        self.selection_anchor = null;
    }

    pub fn deleteForward(self: *Editor, allocator: std.mem.Allocator) !void {
        if (self.cursor >= self.value.len) return;
        var buf = try allocator.alloc(u8, self.value.len - 1);
        @memcpy(buf[0..self.cursor], self.value[0..self.cursor]);
        @memcpy(buf[self.cursor..], self.value[self.cursor + 1 ..]);
        allocator.free(self.value);
        self.value = buf;
        self.selection_anchor = null;
    }

    pub fn moveLeft(self: *Editor) void {
        if (self.cursor > 0) self.cursor -= 1;
    }

    pub fn moveRight(self: *Editor) void {
        if (self.cursor < self.value.len) self.cursor += 1;
    }

    pub fn moveHome(self: *Editor) void {
        self.cursor = 0;
    }

    pub fn moveEnd(self: *Editor) void {
        self.cursor = self.value.len;
    }

    pub fn moveWordLeft(self: *Editor) void {
        if (self.cursor == 0) return;
        while (self.cursor > 0 and std.ascii.isWhitespace(self.value[self.cursor - 1])) self.cursor -= 1;
        while (self.cursor > 0 and !std.ascii.isWhitespace(self.value[self.cursor - 1])) self.cursor -= 1;
    }

    pub fn moveWordRight(self: *Editor) void {
        while (self.cursor < self.value.len and !std.ascii.isWhitespace(self.value[self.cursor])) self.cursor += 1;
        while (self.cursor < self.value.len and std.ascii.isWhitespace(self.value[self.cursor])) self.cursor += 1;
    }

    pub fn deleteToStart(self: *Editor, allocator: std.mem.Allocator) !void {
        if (self.cursor == 0) return;
        const buf = try allocator.alloc(u8, self.value.len - self.cursor);
        @memcpy(buf, self.value[self.cursor..]);
        allocator.free(self.value);
        self.value = buf;
        self.cursor = 0;
        self.selection_anchor = null;
    }

    pub fn deleteToEnd(self: *Editor, allocator: std.mem.Allocator) !void {
        if (self.cursor >= self.value.len) return;
        const buf = try allocator.alloc(u8, self.cursor);
        @memcpy(buf[0..self.cursor], self.value[0..self.cursor]);
        allocator.free(self.value);
        self.value = buf;
        self.selection_anchor = null;
    }

    pub fn deletePreviousWord(self: *Editor, allocator: std.mem.Allocator) !void {
        if (self.cursor == 0) return;
        var start = self.cursor;
        while (start > 0 and std.ascii.isWhitespace(self.value[start - 1])) : (start -= 1) {}
        while (start > 0 and !std.ascii.isWhitespace(self.value[start - 1])) : (start -= 1) {}

        const removed = self.cursor - start;
        var buf = try allocator.alloc(u8, self.value.len - removed);
        @memcpy(buf[0..start], self.value[0..start]);
        @memcpy(buf[start..], self.value[self.cursor..]);
        allocator.free(self.value);
        self.value = buf;
        self.cursor = start;
        self.selection_anchor = null;
    }

    pub fn trimmedCopy(self: *const Editor, allocator: std.mem.Allocator) ![]u8 {
        return try allocator.dupe(u8, std.mem.trim(u8, self.value, " \r\t"));
    }

    pub fn clearSelection(self: *Editor) void {
        self.selection_anchor = null;
    }

    pub fn selectAll(self: *Editor) void {
        self.selection_anchor = 0;
        self.cursor = self.value.len;
    }

    pub fn selectLeft(self: *Editor) void {
        if (self.cursor == 0) return;
        if (self.selection_anchor == null) self.selection_anchor = self.cursor;
        self.cursor -= 1;
    }

    pub fn selectRight(self: *Editor) void {
        if (self.cursor >= self.value.len) return;
        if (self.selection_anchor == null) self.selection_anchor = self.cursor;
        self.cursor += 1;
    }

    pub fn selectedRange(self: *const Editor) ?struct { start: usize, end: usize } {
        if (self.selection_anchor == null or self.selection_anchor.? == self.cursor) return null;
        return .{
            .start = @min(self.selection_anchor.?, self.cursor),
            .end = @max(self.selection_anchor.?, self.cursor),
        };
    }

    pub fn setCursor(self: *Editor, cursor: usize) void {
        self.cursor = @min(cursor, self.value.len);
        self.selection_anchor = null;
    }

    pub fn tokenRangeAtCursor(self: *const Editor) ?struct { start: usize, end: usize } {
        if (self.value.len == 0) return null;

        var start = @min(self.cursor, self.value.len);
        var end = start;

        if (start > 0 and isTokenBoundary(self.value[start - 1])) {
            return null;
        }
        if (start < self.value.len and isTokenBoundary(self.value[start])) {
            return null;
        }

        while (start > 0 and !isTokenBoundary(self.value[start - 1])) : (start -= 1) {}
        while (end < self.value.len and !isTokenBoundary(self.value[end])) : (end += 1) {}

        if (start == end) return null;
        return .{ .start = start, .end = end };
    }

    pub fn replaceRange(self: *Editor, allocator: std.mem.Allocator, start: usize, end: usize, replacement: []const u8) !void {
        const safe_start = @min(start, self.value.len);
        const safe_end = @min(@max(safe_start, end), self.value.len);
        const new_len = self.value.len - (safe_end - safe_start) + replacement.len;
        var buf = try allocator.alloc(u8, new_len);
        @memcpy(buf[0..safe_start], self.value[0..safe_start]);
        @memcpy(buf[safe_start .. safe_start + replacement.len], replacement);
        @memcpy(buf[safe_start + replacement.len ..], self.value[safe_end..]);
        allocator.free(self.value);
        self.value = buf;
        self.cursor = safe_start + replacement.len;
        self.selection_anchor = null;
    }

    pub fn replaceTokenAtCursor(self: *Editor, allocator: std.mem.Allocator, replacement: []const u8) !void {
        const range = self.tokenRangeAtCursor() orelse {
            try self.insertText(allocator, replacement);
            return;
        };
        try self.replaceRange(allocator, range.start, range.end, replacement);
    }

    pub fn cursorFromLineColumn(self: *const Editor, line: usize, column: usize) usize {
        var current_line: usize = 0;
        var line_start: usize = 0;
        var index: usize = 0;
        while (index < self.value.len and current_line < line) : (index += 1) {
            if (self.value[index] == '\n') {
                current_line += 1;
                line_start = index + 1;
            }
        }
        var line_end = line_start;
        while (line_end < self.value.len and self.value[line_end] != '\n') : (line_end += 1) {}
        return @min(line_start + column, line_end);
    }
};

fn isTokenBoundary(byte: u8) bool {
    return std.ascii.isWhitespace(byte) or switch (byte) {
        '(', ')', '[', ']', '{', '}', ',', '.', ':', ';', '\\', '"', '\'', '`', '+', '-', '*', '=', '!', '?', '<', '>', '|', '&' => true,
        else => false,
    };
}

test "editor supports inserts deletions and word motion" {
    var editor = try Editor.init(std.testing.allocator, "alpha gamma");
    defer editor.deinit(std.testing.allocator);

    editor.cursor = 6;
    try editor.insertText(std.testing.allocator, "beta ");
    try std.testing.expectEqualStrings("alpha beta gamma", editor.value);

    editor.moveWordLeft();
    try std.testing.expectEqual(@as(usize, 6), editor.cursor);

    editor.moveWordRight();
    try std.testing.expectEqual(@as(usize, 11), editor.cursor);

    try editor.deletePreviousWord(std.testing.allocator);
    try std.testing.expectEqualStrings("alpha gamma", editor.value);
}

test "editor supports trim and line edits" {
    var editor = try Editor.initWithCursor(std.testing.allocator, "abc", 1);
    defer editor.deinit(std.testing.allocator);

    try editor.insertNewline(std.testing.allocator);
    try std.testing.expectEqualStrings("a\nbc", editor.value);
    try std.testing.expectEqual(@as(usize, 2), editor.cursor);

    try editor.deleteToEnd(std.testing.allocator);
    try std.testing.expectEqualStrings("a\n", editor.value);

    editor.moveEnd();
    try editor.deleteToStart(std.testing.allocator);
    try std.testing.expectEqualStrings("", editor.value);

    try editor.setText(std.testing.allocator, "  hello\r\t", 9);
    const trimmed = try editor.trimmedCopy(std.testing.allocator);
    defer std.testing.allocator.free(trimmed);
    try std.testing.expectEqualStrings("hello", trimmed);
}

test "editor supports selection state" {
    var editor = try Editor.init(std.testing.allocator, "hello");
    defer editor.deinit(std.testing.allocator);

    editor.moveEnd();
    editor.selectLeft();
    editor.selectLeft();
    const range = editor.selectedRange().?;
    try std.testing.expectEqual(@as(usize, 3), range.start);
    try std.testing.expectEqual(@as(usize, 5), range.end);

    editor.selectAll();
    const all = editor.selectedRange().?;
    try std.testing.expectEqual(@as(usize, 0), all.start);
    try std.testing.expectEqual(@as(usize, 5), all.end);

    editor.clearSelection();
    try std.testing.expect(editor.selectedRange() == null);
}

test "editor maps line and column to cursor index" {
    var editor = try Editor.init(std.testing.allocator, "ab\ncdef\nxy");
    defer editor.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), editor.cursorFromLineColumn(0, 0));
    try std.testing.expectEqual(@as(usize, 2), editor.cursorFromLineColumn(0, 9));
    try std.testing.expectEqual(@as(usize, 5), editor.cursorFromLineColumn(1, 2));
    try std.testing.expectEqual(@as(usize, 10), editor.cursorFromLineColumn(2, 99));
}

test "editor supports forward delete and token replacement" {
    var editor = try Editor.init(std.testing.allocator, "hello  world");
    defer editor.deinit(std.testing.allocator);

    editor.cursor = 5;
    try editor.deleteForward(std.testing.allocator);
    try std.testing.expectEqualStrings("hello world", editor.value);

    try editor.setText(std.testing.allocator, "hello world", 7);
    editor.cursor = 7;
    const range = editor.tokenRangeAtCursor().?;
    try std.testing.expectEqual(@as(usize, 6), range.start);
    try std.testing.expectEqual(@as(usize, 11), range.end);

    try editor.replaceTokenAtCursor(std.testing.allocator, "ziggy");
    try std.testing.expectEqualStrings("hello ziggy", editor.value);
    try std.testing.expectEqual(@as(usize, 11), editor.cursor);
}
