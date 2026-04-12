const std = @import("std");

pub const SelectionRange = struct {
    start: usize,
    end: usize,
};

const Snapshot = struct {
    value: []u8,
    cursor: usize,
    selection_anchor: ?usize,
};

pub const TextBuffer = struct {
    value: []u8,
    cursor: usize = 0,
    selection_anchor: ?usize = null,
    undo_stack: std.ArrayList(Snapshot) = .empty,
    redo_stack: std.ArrayList(Snapshot) = .empty,

    pub fn init(allocator: std.mem.Allocator, initial: []const u8) !TextBuffer {
        return .{
            .value = try allocator.dupe(u8, initial),
            .cursor = initial.len,
        };
    }

    pub fn initWithCursor(allocator: std.mem.Allocator, initial: []const u8, cursor: usize) !TextBuffer {
        return .{
            .value = try allocator.dupe(u8, initial),
            .cursor = @min(cursor, initial.len),
        };
    }

    pub fn deinit(self: *TextBuffer, allocator: std.mem.Allocator) void {
        allocator.free(self.value);
        self.value = &.{};
        self.cursor = 0;
        self.selection_anchor = null;
        clearSnapshots(&self.undo_stack, allocator);
        clearSnapshots(&self.redo_stack, allocator);
    }

    pub fn setText(self: *TextBuffer, allocator: std.mem.Allocator, value: []const u8, cursor: usize) !void {
        const next_cursor = @min(cursor, value.len);
        if (std.mem.eql(u8, self.value, value) and self.cursor == next_cursor and self.selection_anchor == null) return;
        try self.pushUndoSnapshot(allocator);
        allocator.free(self.value);
        self.value = try allocator.dupe(u8, value);
        self.cursor = next_cursor;
        self.selection_anchor = null;
    }

    pub fn clear(self: *TextBuffer, allocator: std.mem.Allocator) !void {
        try self.setText(allocator, "", 0);
    }

    pub fn insertChar(self: *TextBuffer, allocator: std.mem.Allocator, byte: u8) !void {
        var temp: [1]u8 = .{byte};
        try self.insertText(allocator, &temp);
    }

    pub fn insertText(self: *TextBuffer, allocator: std.mem.Allocator, text: []const u8) !void {
        if (text.len == 0 and self.selectedRange() == null) return;
        try self.pushUndoSnapshot(allocator);
        _ = try self.deleteSelectionNoHistory(allocator);
        try self.replaceRangeNoHistory(allocator, self.cursor, self.cursor, text);
    }

    pub fn insertNewline(self: *TextBuffer, allocator: std.mem.Allocator) !void {
        try self.insertChar(allocator, '\n');
    }

    pub fn backspace(self: *TextBuffer, allocator: std.mem.Allocator) !void {
        if (self.selectedRange() != null) {
            _ = try self.deleteSelection(allocator);
            return;
        }
        if (self.cursor == 0) return;
        try self.pushUndoSnapshot(allocator);
        const start = previousScalarStart(self.value, self.cursor);
        try self.replaceRangeNoHistory(allocator, start, self.cursor, "");
    }

    pub fn deleteForward(self: *TextBuffer, allocator: std.mem.Allocator) !void {
        if (self.selectedRange() != null) {
            _ = try self.deleteSelection(allocator);
            return;
        }
        if (self.cursor >= self.value.len) return;
        try self.pushUndoSnapshot(allocator);
        const next = nextScalarEnd(self.value, self.cursor);
        try self.replaceRangeNoHistory(allocator, self.cursor, next, "");
    }

    pub fn moveLeft(self: *TextBuffer) void {
        if (self.selectedRange()) |range| {
            self.cursor = range.start;
            self.selection_anchor = null;
            return;
        }
        if (self.cursor > 0) self.cursor = previousScalarStart(self.value, self.cursor);
    }

    pub fn moveRight(self: *TextBuffer) void {
        if (self.selectedRange()) |range| {
            self.cursor = range.end;
            self.selection_anchor = null;
            return;
        }
        if (self.cursor < self.value.len) self.cursor = nextScalarEnd(self.value, self.cursor);
    }

    pub fn moveHome(self: *TextBuffer) void {
        if (self.selectedRange()) |range| {
            self.cursor = range.start;
            self.selection_anchor = null;
            return;
        }
        self.cursor = 0;
    }

    pub fn moveEnd(self: *TextBuffer) void {
        if (self.selectedRange()) |range| {
            self.cursor = range.end;
            self.selection_anchor = null;
            return;
        }
        self.cursor = self.value.len;
    }

    pub fn moveWordLeft(self: *TextBuffer) void {
        if (self.selectedRange()) |range| {
            self.cursor = range.start;
            self.selection_anchor = null;
            return;
        }
        if (self.cursor == 0) return;
        while (self.cursor > 0 and std.ascii.isWhitespace(self.value[previousScalarStart(self.value, self.cursor)])) {
            self.cursor = previousScalarStart(self.value, self.cursor);
        }
        while (self.cursor > 0 and !std.ascii.isWhitespace(self.value[previousScalarStart(self.value, self.cursor)])) {
            self.cursor = previousScalarStart(self.value, self.cursor);
        }
    }

    pub fn moveWordRight(self: *TextBuffer) void {
        if (self.selectedRange()) |range| {
            self.cursor = range.end;
            self.selection_anchor = null;
            return;
        }
        while (self.cursor < self.value.len and !std.ascii.isWhitespace(self.value[self.cursor])) self.cursor = nextScalarEnd(self.value, self.cursor);
        while (self.cursor < self.value.len and std.ascii.isWhitespace(self.value[self.cursor])) self.cursor = nextScalarEnd(self.value, self.cursor);
    }

    pub fn moveLineHome(self: *TextBuffer) void {
        self.cursor = lineStartForIndex(self.value, self.currentLine());
        self.selection_anchor = null;
    }

    pub fn moveLineEnd(self: *TextBuffer) void {
        self.cursor = lineEndForIndex(self.value, self.currentLine());
        self.selection_anchor = null;
    }

    pub fn moveUp(self: *TextBuffer) void {
        const line = self.currentLine();
        if (line == 0) {
            self.moveLineHome();
            return;
        }
        const column = self.currentColumn();
        self.cursor = self.cursorFromLineColumn(line - 1, column);
        self.selection_anchor = null;
    }

    pub fn moveDown(self: *TextBuffer) void {
        const line = self.currentLine();
        if (line + 1 >= self.lineCount()) {
            self.moveLineEnd();
            return;
        }
        const column = self.currentColumn();
        self.cursor = self.cursorFromLineColumn(line + 1, column);
        self.selection_anchor = null;
    }

    pub fn pageUp(self: *TextBuffer, line_count: usize) void {
        if (line_count == 0) return;
        const line = self.currentLine();
        const column = self.currentColumn();
        self.cursor = self.cursorFromLineColumn(line -| line_count, column);
        self.selection_anchor = null;
    }

    pub fn pageDown(self: *TextBuffer, line_count: usize) void {
        if (line_count == 0) return;
        const line = self.currentLine();
        const column = self.currentColumn();
        self.cursor = self.cursorFromLineColumn(@min(line + line_count, self.lineCount() - 1), column);
        self.selection_anchor = null;
    }

    pub fn deleteToStart(self: *TextBuffer, allocator: std.mem.Allocator) !void {
        if (self.cursor == 0) return;
        try self.pushUndoSnapshot(allocator);
        try self.replaceRangeNoHistory(allocator, 0, self.cursor, "");
    }

    pub fn deleteToEnd(self: *TextBuffer, allocator: std.mem.Allocator) !void {
        if (self.cursor >= self.value.len) return;
        try self.pushUndoSnapshot(allocator);
        try self.replaceRangeNoHistory(allocator, self.cursor, self.value.len, "");
    }

    pub fn deletePreviousWord(self: *TextBuffer, allocator: std.mem.Allocator) !void {
        if (self.cursor == 0) return;
        var start = self.cursor;
        while (start > 0 and std.ascii.isWhitespace(self.value[previousScalarStart(self.value, start)])) {
            start = previousScalarStart(self.value, start);
        }
        while (start > 0 and !std.ascii.isWhitespace(self.value[previousScalarStart(self.value, start)])) {
            start = previousScalarStart(self.value, start);
        }
        try self.pushUndoSnapshot(allocator);
        try self.replaceRangeNoHistory(allocator, start, self.cursor, "");
    }

    pub fn trimmedCopy(self: *const TextBuffer, allocator: std.mem.Allocator) ![]u8 {
        return try allocator.dupe(u8, std.mem.trim(u8, self.value, " \r\t"));
    }

    pub fn clearSelection(self: *TextBuffer) void {
        self.selection_anchor = null;
    }

    pub fn selectAll(self: *TextBuffer) void {
        self.selection_anchor = 0;
        self.cursor = self.value.len;
    }

    pub fn selectLeft(self: *TextBuffer) void {
        if (self.cursor == 0) return;
        if (self.selection_anchor == null) self.selection_anchor = self.cursor;
        self.cursor = previousScalarStart(self.value, self.cursor);
    }

    pub fn selectRight(self: *TextBuffer) void {
        if (self.cursor >= self.value.len) return;
        if (self.selection_anchor == null) self.selection_anchor = self.cursor;
        self.cursor = nextScalarEnd(self.value, self.cursor);
    }

    pub fn selectUp(self: *TextBuffer) void {
        if (self.selection_anchor == null) self.selection_anchor = self.cursor;
        const line = self.currentLine();
        if (line == 0) {
            self.cursor = 0;
            return;
        }
        self.cursor = self.cursorFromLineColumn(line - 1, self.currentColumn());
    }

    pub fn selectDown(self: *TextBuffer) void {
        if (self.selection_anchor == null) self.selection_anchor = self.cursor;
        const line = self.currentLine();
        if (line + 1 >= self.lineCount()) {
            self.cursor = self.value.len;
            return;
        }
        self.cursor = self.cursorFromLineColumn(line + 1, self.currentColumn());
    }

    pub fn selectedRange(self: *const TextBuffer) ?SelectionRange {
        if (self.selection_anchor == null or self.selection_anchor.? == self.cursor) return null;
        return .{
            .start = @min(self.selection_anchor.?, self.cursor),
            .end = @max(self.selection_anchor.?, self.cursor),
        };
    }

    pub fn setCursor(self: *TextBuffer, cursor: usize) void {
        self.cursor = @min(cursor, self.value.len);
        self.selection_anchor = null;
    }

    pub fn hasSelection(self: *const TextBuffer) bool {
        return self.selectedRange() != null;
    }

    pub fn selectedText(self: *const TextBuffer) ?[]const u8 {
        const range = self.selectedRange() orelse return null;
        return self.value[range.start..range.end];
    }

    pub fn deleteSelection(self: *TextBuffer, allocator: std.mem.Allocator) !bool {
        const range = self.selectedRange() orelse return false;
        try self.pushUndoSnapshot(allocator);
        try self.replaceRangeNoHistory(allocator, range.start, range.end, "");
        return true;
    }

    pub fn tokenRangeAtCursor(self: *const TextBuffer) ?SelectionRange {
        if (self.value.len == 0) return null;

        var start = @min(self.cursor, self.value.len);
        var end = start;
        if (start > 0 and isTokenBoundary(self.value[start - 1])) return null;
        if (start < self.value.len and isTokenBoundary(self.value[start])) return null;
        while (start > 0 and !isTokenBoundary(self.value[start - 1])) : (start -= 1) {}
        while (end < self.value.len and !isTokenBoundary(self.value[end])) : (end += 1) {}
        if (start == end) return null;
        return .{ .start = start, .end = end };
    }

    pub fn replaceRange(self: *TextBuffer, allocator: std.mem.Allocator, start: usize, end: usize, replacement: []const u8) !void {
        const safe_start = @min(start, self.value.len);
        const safe_end = @min(@max(safe_start, end), self.value.len);
        if (safe_start == safe_end and replacement.len == 0) return;
        try self.pushUndoSnapshot(allocator);
        try self.replaceRangeNoHistory(allocator, safe_start, safe_end, replacement);
    }

    pub fn replaceTokenAtCursor(self: *TextBuffer, allocator: std.mem.Allocator, replacement: []const u8) !void {
        const range = self.tokenRangeAtCursor() orelse {
            try self.insertText(allocator, replacement);
            return;
        };
        try self.replaceRange(allocator, range.start, range.end, replacement);
    }

    pub fn undo(self: *TextBuffer, allocator: std.mem.Allocator) !bool {
        if (self.undo_stack.items.len == 0) return false;
        try self.redo_stack.append(allocator, try self.snapshot(allocator));
        const previous = self.undo_stack.pop().?;
        allocator.free(self.value);
        self.value = previous.value;
        self.cursor = previous.cursor;
        self.selection_anchor = previous.selection_anchor;
        return true;
    }

    pub fn redo(self: *TextBuffer, allocator: std.mem.Allocator) !bool {
        if (self.redo_stack.items.len == 0) return false;
        try self.undo_stack.append(allocator, try self.snapshot(allocator));
        const next = self.redo_stack.pop().?;
        allocator.free(self.value);
        self.value = next.value;
        self.cursor = next.cursor;
        self.selection_anchor = next.selection_anchor;
        return true;
    }

    pub fn cursorFromLineColumn(self: *const TextBuffer, line: usize, column: usize) usize {
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

    pub fn currentLine(self: *const TextBuffer) usize {
        return countLines(self.value[0..self.cursor]) - 1;
    }

    pub fn currentColumn(self: *const TextBuffer) usize {
        return cursorColumn(self.value, self.cursor);
    }

    pub fn lineCount(self: *const TextBuffer) usize {
        return countLines(self.value);
    }

    fn snapshot(self: *const TextBuffer, allocator: std.mem.Allocator) !Snapshot {
        return .{
            .value = try allocator.dupe(u8, self.value),
            .cursor = self.cursor,
            .selection_anchor = self.selection_anchor,
        };
    }

    fn pushUndoSnapshot(self: *TextBuffer, allocator: std.mem.Allocator) !void {
        try self.undo_stack.append(allocator, try self.snapshot(allocator));
        clearSnapshots(&self.redo_stack, allocator);
    }

    fn replaceRangeNoHistory(self: *TextBuffer, allocator: std.mem.Allocator, start: usize, end: usize, replacement: []const u8) !void {
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

    fn deleteSelectionNoHistory(self: *TextBuffer, allocator: std.mem.Allocator) !bool {
        const range = self.selectedRange() orelse return false;
        try self.replaceRangeNoHistory(allocator, range.start, range.end, "");
        return true;
    }
};

fn clearSnapshots(list: *std.ArrayList(Snapshot), allocator: std.mem.Allocator) void {
    for (list.items) |entry| allocator.free(entry.value);
    list.clearAndFree(allocator);
}

fn previousScalarStart(value: []const u8, cursor: usize) usize {
    if (cursor == 0) return 0;
    var index = cursor - 1;
    while (index > 0 and isUtf8Continuation(value[index])) : (index -= 1) {}
    return index;
}

fn nextScalarEnd(value: []const u8, cursor: usize) usize {
    if (cursor >= value.len) return value.len;
    var index = cursor + 1;
    while (index < value.len and isUtf8Continuation(value[index])) : (index += 1) {}
    return index;
}

fn isUtf8Continuation(byte: u8) bool {
    return (byte & 0b1100_0000) == 0b1000_0000;
}

fn isTokenBoundary(byte: u8) bool {
    return std.ascii.isWhitespace(byte) or switch (byte) {
        '(', ')', '[', ']', '{', '}', ',', '.', ':', ';', '\\', '"', '\'', '`', '+', '-', '*', '=', '!', '?', '<', '>', '|', '&' => true,
        else => false,
    };
}

fn countLines(text: []const u8) usize {
    if (text.len == 0) return 1;
    var count: usize = 1;
    for (text) |byte| {
        if (byte == '\n') count += 1;
    }
    return count;
}

fn cursorColumn(value: []const u8, cursor: usize) usize {
    const line_start = std.mem.lastIndexOfScalar(u8, value[0..cursor], '\n') orelse return cursor;
    return cursor - line_start - 1;
}

fn lineStartForIndex(value: []const u8, target_line: usize) usize {
    var current_line: usize = 0;
    var start: usize = 0;
    var index: usize = 0;
    while (index < value.len and current_line < target_line) : (index += 1) {
        if (value[index] == '\n') {
            current_line += 1;
            start = index + 1;
        }
    }
    return start;
}

fn lineEndForIndex(value: []const u8, target_line: usize) usize {
    var index = lineStartForIndex(value, target_line);
    while (index < value.len and value[index] != '\n') : (index += 1) {}
    return index;
}

test "text buffer supports inserts deletions and word motion" {
    var editor = try TextBuffer.init(std.testing.allocator, "alpha gamma");
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

test "text buffer supports trim and line edits" {
    var editor = try TextBuffer.initWithCursor(std.testing.allocator, "abc", 1);
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

test "text buffer supports selection state" {
    var editor = try TextBuffer.init(std.testing.allocator, "hello");
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

test "text buffer replaces active selection when typing" {
    var editor = try TextBuffer.init(std.testing.allocator, "hello");
    defer editor.deinit(std.testing.allocator);

    editor.selectAll();
    try editor.insertText(std.testing.allocator, "ziggy");
    try std.testing.expectEqualStrings("ziggy", editor.value);
    try std.testing.expectEqual(@as(usize, 5), editor.cursor);
}

test "text buffer supports vertical motion" {
    var editor = try TextBuffer.init(std.testing.allocator, "abc\nde\nfghi");
    defer editor.deinit(std.testing.allocator);

    editor.cursor = 6;
    editor.moveDown();
    try std.testing.expectEqual(@as(usize, 9), editor.cursor);

    editor.moveUp();
    try std.testing.expectEqual(@as(usize, 6), editor.cursor);

    editor.moveLineHome();
    try std.testing.expectEqual(@as(usize, 4), editor.cursor);

    editor.moveLineEnd();
    try std.testing.expectEqual(@as(usize, 6), editor.cursor);
}

test "text buffer maps line and column to cursor index" {
    var editor = try TextBuffer.init(std.testing.allocator, "ab\ncdef\nxy");
    defer editor.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), editor.cursorFromLineColumn(0, 0));
    try std.testing.expectEqual(@as(usize, 2), editor.cursorFromLineColumn(0, 9));
    try std.testing.expectEqual(@as(usize, 5), editor.cursorFromLineColumn(1, 2));
    try std.testing.expectEqual(@as(usize, 10), editor.cursorFromLineColumn(2, 99));
}

test "text buffer supports forward delete and token replacement" {
    var editor = try TextBuffer.init(std.testing.allocator, "hello  world");
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

test "text buffer undo redo restores content and selection" {
    var editor = try TextBuffer.init(std.testing.allocator, "one");
    defer editor.deinit(std.testing.allocator);

    try editor.insertText(std.testing.allocator, " two");
    editor.selectLeft();
    editor.selectLeft();
    try std.testing.expect(try editor.undo(std.testing.allocator));
    try std.testing.expectEqualStrings("one", editor.value);
    try std.testing.expectEqual(@as(usize, 3), editor.cursor);
    try std.testing.expect(editor.selection_anchor == null);

    try std.testing.expect(try editor.redo(std.testing.allocator));
    try std.testing.expectEqualStrings("one two", editor.value);
    try std.testing.expectEqual(@as(usize, 5), editor.cursor);
}

test "text buffer moves across utf8 code points" {
    var editor = try TextBuffer.init(std.testing.allocator, "A\xc3\xa9\xe2\x82\xac");
    defer editor.deinit(std.testing.allocator);

    editor.moveLeft();
    try std.testing.expectEqual(@as(usize, 3), editor.cursor);
    editor.moveLeft();
    try std.testing.expectEqual(@as(usize, 1), editor.cursor);
    try editor.backspace(std.testing.allocator);
    try std.testing.expectEqualStrings("\xc3\xa9\xe2\x82\xac", editor.value);
}
