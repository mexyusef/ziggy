const std = @import("std");
const buffer = @import("../text/buffer.zig");

test "redo stack clears after fresh edit" {
    var editor = try buffer.TextBuffer.init(std.testing.allocator, "alpha");
    defer editor.deinit(std.testing.allocator);

    try editor.insertText(std.testing.allocator, " beta");
    try std.testing.expect(try editor.undo(std.testing.allocator));
    try std.testing.expect(try editor.redo(std.testing.allocator));
    try std.testing.expect(try editor.undo(std.testing.allocator));
    try editor.insertText(std.testing.allocator, " gamma");
    try std.testing.expect(!(try editor.redo(std.testing.allocator)));
}

test "selection delete is a single undo step" {
    var editor = try buffer.TextBuffer.init(std.testing.allocator, "hello world");
    defer editor.deinit(std.testing.allocator);

    editor.cursor = 11;
    editor.selectLeft();
    editor.selectLeft();
    editor.selectLeft();
    editor.selectLeft();
    editor.selectLeft();
    try editor.insertText(std.testing.allocator, "ziggy");
    try std.testing.expectEqualStrings("hello ziggy", editor.value);
    try std.testing.expect(try editor.undo(std.testing.allocator));
    try std.testing.expectEqualStrings("hello world", editor.value);
}
