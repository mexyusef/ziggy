const std = @import("std");
const ziggy = @import("ziggy");

pub const EditorWorkspaceState = struct {
    editor: ziggy.Editor,
    viewport: ziggy.TextArea.Viewport = .{ .scroll_margin = 1 },
    completion: ziggy.CompletionController.State = .{},
    active_tab: usize = 0,
    sidebar_selected: usize = 0,
    show_sidebar: bool = true,
    status_text: []const u8 = "Ready",

    pub fn init(allocator: std.mem.Allocator, initial: []const u8) !EditorWorkspaceState {
        return .{
            .editor = try ziggy.Editor.init(allocator, initial),
        };
    }

    pub fn deinit(self: *EditorWorkspaceState, allocator: std.mem.Allocator) void {
        self.editor.deinit(allocator);
        self.completion.deinit(allocator);
    }

    pub fn syncViewport(self: *EditorWorkspaceState, width: usize, height: usize, prompt: []const u8) void {
        self.viewport.width = width;
        self.viewport.height = height;
        self.viewport = ziggy.TextArea.followCursor(&self.editor, prompt, self.viewport);
    }
};

pub fn handleEditorKey(
    state: *EditorWorkspaceState,
    allocator: std.mem.Allocator,
    key: ziggy.Key,
    suggestions: []const ziggy.Completion.Item,
    visible_editor_height: usize,
) !bool {
    switch (key) {
        .char => |c| {
            try state.editor.insertChar(allocator, c);
            try state.completion.sync(allocator, &state.editor, suggestions);
        },
        .enter, .ctrl_j => {
            try state.editor.insertNewline(allocator);
            state.completion.clear(allocator);
        },
        .backspace => {
            try state.editor.backspace(allocator);
            try state.completion.sync(allocator, &state.editor, suggestions);
        },
        .delete, .ctrl_d => {
            try state.editor.deleteForward(allocator);
            try state.completion.sync(allocator, &state.editor, suggestions);
        },
        .left => {
            state.editor.moveLeft();
            try state.completion.sync(allocator, &state.editor, suggestions);
        },
        .right => {
            state.editor.moveRight();
            try state.completion.sync(allocator, &state.editor, suggestions);
        },
        .shift_left => {
            state.editor.selectLeft();
            state.completion.clear(allocator);
        },
        .shift_right => {
            state.editor.selectRight();
            state.completion.clear(allocator);
        },
        .up, .down, .page_up, .page_down, .tab, .escape => {
            if (try state.completion.handleKey(allocator, &state.editor, key, suggestions)) {} else switch (key) {
                .up => state.editor.moveUp(),
                .down => state.editor.moveDown(),
                .page_up => state.editor.pageUp(@max(visible_editor_height, 1)),
                .page_down => state.editor.pageDown(@max(visible_editor_height, 1)),
                .tab => try state.editor.insertText(allocator, "    "),
                .escape => state.completion.clear(allocator),
                else => unreachable,
            }
        },
        .word_left => {
            state.editor.moveWordLeft();
            state.completion.clear(allocator);
        },
        .word_right => {
            state.editor.moveWordRight();
            state.completion.clear(allocator);
        },
        .home, .ctrl_a => {
            state.editor.moveLineHome();
            state.completion.clear(allocator);
        },
        .end, .ctrl_e => {
            state.editor.moveLineEnd();
            state.completion.clear(allocator);
        },
        .ctrl_u => {
            try state.editor.deleteToStart(allocator);
            state.completion.clear(allocator);
        },
        .ctrl_k => {
            try state.editor.deleteToEnd(allocator);
            state.completion.clear(allocator);
        },
        .ctrl_w => {
            try state.editor.deletePreviousWord(allocator);
            state.completion.clear(allocator);
        },
        .ctrl_space => try state.completion.refresh(allocator, &state.editor, suggestions),
        else => return false,
    }

    state.viewport = ziggy.TextArea.followCursor(&state.editor, "> ", state.viewport);
    return true;
}

pub fn buildEditorPane(
    allocator: std.mem.Allocator,
    state: *const EditorWorkspaceState,
    title: []const u8,
    theme: ziggy.AgentTheme,
    viewport_height: usize,
) !*const ziggy.Node {
    return try ziggy.EditorPane.build(allocator, &state.editor, .{
        .title = title,
        .viewport = state.viewport,
        .theme = theme,
        .viewport_height = viewport_height,
        .border_style = theme.border_style,
    });
}

pub fn buildWorkspaceShell(
    allocator: std.mem.Allocator,
    size: ziggy.Size,
    header_title: []const u8,
    tabs: []const []const u8,
    active_tab: usize,
    sidebar_title: []const u8,
    sidebar_items: []const []const u8,
    sidebar_selected: usize,
    body: *const ziggy.Node,
    footer_left: []const u8,
    footer_right: []const u8,
    status_text: []const u8,
    hints: []const []const u8,
    theme: ziggy.AgentTheme,
    show_sidebar: bool,
) !*const ziggy.Node {
    const left_segments = [_]ziggy.StatusSegments.Segment{
        .{ .text = footer_left, .style = theme.selected_alt, .visible = footer_left.len > 0 },
    };
    const center_segments = [_]ziggy.StatusSegments.Segment{
        .{ .text = status_text, .style = theme.status_idle, .visible = status_text.len > 0 },
    };
    var right_segments = try allocator.alloc(ziggy.StatusSegments.Segment, hints.len + @intFromBool(footer_right.len > 0));
    defer allocator.free(right_segments);
    var right_index: usize = 0;
    if (footer_right.len > 0) {
        right_segments[right_index] = .{ .text = footer_right, .style = theme.status_idle };
        right_index += 1;
    }
    for (hints) |hint| {
        right_segments[right_index] = .{ .text = hint, .style = theme.status_idle };
        right_index += 1;
    }

    return try ziggy.WorkspaceShell.build(allocator, .{
        .size = size,
        .title = header_title,
        .subtitle = "editor workspace example",
        .right_text = "workspace shell",
        .tabs = tabs,
        .selected_tab = active_tab,
        .sidebar = if (show_sidebar) .{
            .title = sidebar_title,
            .items = sidebar_items,
            .selected = sidebar_selected,
            .footer = status_text,
        } else null,
        .body = body,
        .footer_segments = .{
            .left = &left_segments,
            .center = &center_segments,
            .right = right_segments[0..right_index],
            .style = theme.pane,
            .border_style = theme.border_style,
            .padding_left = 1,
            .padding_right = 1,
        },
        .theme = theme,
        .border_style = theme.border_style,
    });
}

test "workspace support handles multiline editor motion" {
    var state = try EditorWorkspaceState.init(std.testing.allocator, "one\ntwo");
    defer state.deinit(std.testing.allocator);

    try std.testing.expect(try handleEditorKey(&state, std.testing.allocator, .enter, &.{}, 4));
    try std.testing.expect(std.mem.indexOf(u8, state.editor.value, "\n\n") != null);
}
