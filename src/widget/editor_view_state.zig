const editor_mod = @import("editor.zig");
const text_area = @import("text_area.zig");

pub const Snapshot = struct {
    cursor: usize,
    selection_anchor: ?usize = null,
    viewport: text_area.Viewport = .{},
};

pub fn capture(editor: *const editor_mod.Editor, viewport: text_area.Viewport) Snapshot {
    return .{
        .cursor = editor.cursor,
        .selection_anchor = editor.selection_anchor,
        .viewport = viewport,
    };
}

pub fn restore(editor: *editor_mod.Editor, snapshot: Snapshot) void {
    editor.cursor = @min(snapshot.cursor, editor.value.len);
    editor.selection_anchor = if (snapshot.selection_anchor) |anchor|
        @min(anchor, editor.value.len)
    else
        null;
}

test "editor view state captures and restores cursor and viewport" {
    var editor: editor_mod.Editor = .{
        .value = @constCast("hello"),
        .cursor = 3,
        .selection_anchor = 1,
    };
    const snapshot = capture(&editor, .{ .offset_line = 2, .offset_column = 4 });
    editor.cursor = 0;
    editor.selection_anchor = null;
    restore(&editor, snapshot);
    try @import("std").testing.expectEqual(@as(usize, 3), editor.cursor);
    try @import("std").testing.expectEqual(@as(?usize, 1), editor.selection_anchor);
    try @import("std").testing.expectEqual(@as(usize, 2), snapshot.viewport.offset_line);
}
