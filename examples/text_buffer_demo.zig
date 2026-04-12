const std = @import("std");
const ziggy = @import("ziggy");
const support = @import("support.zig");

pub fn main() !void {
    _ = ziggy.prepareConsole();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const theme = ziggy.defaultAgentTheme();

    var editor = try ziggy.TextBuffer.init(allocator, "const greeting = \"hello\";");
    defer editor.deinit(allocator);
    editor.cursor = 6;
    try editor.insertText(allocator, "mut ");
    try editor.deletePreviousWord(allocator);
    try editor.insertText(allocator, "message ");

    const current = try ziggy.TextArea.buildEditorWithViewport(allocator, &editor, .{
        .width = 42,
        .height = 4,
    }, .{
        .prompt = "> ",
        .style = theme.pane,
    });

    _ = try editor.undo(allocator);
    const undone = try ziggy.TextArea.buildEditorWithViewport(allocator, &editor, .{
        .width = 42,
        .height = 4,
    }, .{
        .prompt = "> ",
        .style = theme.pane,
    });

    _ = try editor.redo(allocator);
    const redone = try ziggy.TextArea.buildEditorWithViewport(allocator, &editor, .{
        .width = 42,
        .height = 4,
    }, .{
        .prompt = "> ",
        .style = theme.pane,
    });

    const before = try ziggy.Box.buildWithOptions(allocator, "After Undo", undone, .{
        .style = theme.pane,
        .border_style = theme.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
    const after = try ziggy.Box.buildWithOptions(allocator, "Redo Restored", redone, .{
        .style = theme.pane,
        .border_style = theme.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
    const live = try ziggy.Box.buildWithOptions(allocator, "Current Buffer", current, .{
        .style = theme.pane,
        .border_style = theme.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });

    const intro = try ziggy.Card.build(allocator, "Text Buffer", .{
        .subtitle = "reusable core beneath editor widgets",
        .body =
        \\`TextBuffer` now carries history and UTF-8 aware cursor stepping.
        \\The editor widgets can share this model while higher-level apps
        \\get undo/redo without re-implementing mutation logic.
        ,
        .style = theme.pane,
        .border_style = theme.border_style,
    });

    const row = try ziggy.HStack.buildWithWeights(allocator, &.{ before, live, after }, 1, &.{ 1, 1, 1 });
    const root = try ziggy.VStack.build(allocator, &.{ intro, row }, 1);
    try support.renderStatic(root, support.detectTerminalSize());
}
