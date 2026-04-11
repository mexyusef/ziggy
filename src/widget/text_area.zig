const std = @import("std");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const focus_mod = @import("focus.zig");
const editor_mod = @import("editor.zig");
const surface_mod = @import("surface.zig");

pub const Options = struct {
    prompt: []const u8 = "> ",
    focused: bool = true,
    placeholder: ?[]const u8 = null,
    style: style_mod.Style = .{},
    focus: focus_mod.FocusState = .{},
};

pub const Viewport = struct {
    offset_line: usize = 0,
    offset_column: usize = 0,
    width: usize = 0,
    height: usize = 0,
    scroll_margin: usize = 1,
};

pub fn build(
    allocator: std.mem.Allocator,
    prompt: []const u8,
    value: []const u8,
    cursor: usize,
    focused: bool,
    style: style_mod.Style,
    focus: focus_mod.FocusState,
) !*const node_mod.Node {
    return try node_mod.allocNode(allocator, .{
        .text_area = .{
            .prompt = prompt,
            .value = value,
            .cursor = cursor,
            .selection_start = null,
            .selection_end = null,
            .offset_line = 0,
            .offset_column = 0,
            .scroll_margin = 1,
            .focused = focused,
            .placeholder = null,
            .style = style,
            .focus = focus,
        },
    });
}

pub fn buildWithOptions(
    allocator: std.mem.Allocator,
    value: []const u8,
    cursor: usize,
    options: Options,
) !*const node_mod.Node {
    return try node_mod.allocNode(allocator, .{
        .text_area = .{
            .prompt = options.prompt,
            .value = value,
            .cursor = cursor,
            .selection_start = null,
            .selection_end = null,
            .offset_line = 0,
            .offset_column = 0,
            .scroll_margin = 1,
            .focused = options.focused,
            .placeholder = options.placeholder,
            .style = options.style,
            .focus = options.focus,
        },
    });
}

pub fn buildEditor(
    allocator: std.mem.Allocator,
    editor: *const editor_mod.Editor,
    options: Options,
) !*const node_mod.Node {
    return buildEditorWithViewport(allocator, editor, .{}, options);
}

pub fn buildEditorWithViewport(
    allocator: std.mem.Allocator,
    editor: *const editor_mod.Editor,
    viewport: Viewport,
    options: Options,
) !*const node_mod.Node {
    const selection = editor.selectedRange();
    return try node_mod.allocNode(allocator, .{
        .text_area = .{
            .prompt = options.prompt,
            .value = editor.value,
            .cursor = editor.cursor,
            .selection_start = if (selection) |range| range.start else null,
            .selection_end = if (selection) |range| range.end else null,
            .offset_line = viewport.offset_line,
            .offset_column = viewport.offset_column,
            .scroll_margin = viewport.scroll_margin,
            .focused = options.focused,
            .placeholder = options.placeholder,
            .style = options.style,
            .focus = options.focus,
        },
    });
}

pub fn followCursor(
    editor: *const editor_mod.Editor,
    prompt: []const u8,
    viewport: Viewport,
) Viewport {
    var next = viewport;
    const cursor = editor.cursor;
    const line = countLines(editor.value[0..cursor]) - 1;
    const column = cursorColumn(editor.value, cursor);
    const first_line_prompt = prompt.len;
    const width_budget = if (viewport.width > first_line_prompt) viewport.width - first_line_prompt else viewport.width;

    if (viewport.height > 0) {
        if (line < next.offset_line + next.scroll_margin) {
            next.offset_line = line -| next.scroll_margin;
        } else {
            const bottom_margin = if (viewport.height > next.scroll_margin + 1) viewport.height - next.scroll_margin - 1 else 0;
            if (line > next.offset_line + bottom_margin) {
                next.offset_line = line - bottom_margin;
            }
        }
    }

    if (width_budget > 0) {
        if (column < next.offset_column + next.scroll_margin) {
            next.offset_column = column -| next.scroll_margin;
        } else {
            const right_margin = if (width_budget > next.scroll_margin + 1) width_budget - next.scroll_margin - 1 else 0;
            if (column > next.offset_column + right_margin) {
                next.offset_column = column - right_margin;
            }
        }
    }
    return next;
}

pub fn cursorFromLocalPoint(
    editor: *const editor_mod.Editor,
    prompt: []const u8,
    x: u16,
    y: u16,
    viewport: Viewport,
) usize {
    const line_index: usize = viewport.offset_line + y;
    const prompt_width: usize = if (line_index == 0) prompt.len else 2;
    const column = viewport.offset_column + (if (@as(usize, x) > prompt_width) @as(usize, x) - prompt_width else 0);
    return editor.cursorFromLineColumn(line_index, column);
}

pub fn cursorFromRectPoint(
    rect: surface_mod.Rect,
    editor: *const editor_mod.Editor,
    prompt: []const u8,
    x: u16,
    y: u16,
    viewport: Viewport,
) ?usize {
    const local = rect.localPoint(x, y) orelse return null;
    return cursorFromLocalPoint(editor, prompt, local.x, local.y, viewport);
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

test "cursorFromLocalPoint accounts for prompt width" {
    var editor = try editor_mod.Editor.init(std.testing.allocator, "hello\nworld");
    defer editor.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), cursorFromLocalPoint(&editor, "> ", 0, 0, .{}));
    try std.testing.expectEqual(@as(usize, 2), cursorFromLocalPoint(&editor, "> ", 4, 0, .{}));
    try std.testing.expectEqual(@as(usize, 7), cursorFromLocalPoint(&editor, "> ", 3, 1, .{}));
}

test "cursorFromRectPoint returns null outside rect" {
    var editor = try editor_mod.Editor.init(std.testing.allocator, "hello");
    defer editor.deinit(std.testing.allocator);

    const rect: surface_mod.Rect = .{ .x = 5, .y = 7, .width = 20, .height = 3 };
    try std.testing.expectEqual(@as(?usize, 0), cursorFromRectPoint(rect, &editor, "> ", 5, 7, .{}));
    try std.testing.expectEqual(@as(?usize, null), cursorFromRectPoint(rect, &editor, "> ", 1, 1, .{}));
}

test "followCursor updates viewport offsets" {
    var editor = try editor_mod.Editor.init(std.testing.allocator, "one\ntwo\nthree\nfour");
    defer editor.deinit(std.testing.allocator);
    editor.cursor = 16;
    const viewport = followCursor(&editor, "> ", .{ .width = 8, .height = 2, .scroll_margin = 0 });
    try std.testing.expectEqual(@as(usize, 2), viewport.offset_line);
}
