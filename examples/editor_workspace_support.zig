const std = @import("std");
const ziggy = @import("ziggy");

pub const EditorWorkspaceState = struct {
    editor: ziggy.Editor,
    viewport: ziggy.TextArea.Viewport = .{ .scroll_margin = 1 },
    completion_state: ziggy.Completion.State = .{},
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
        self.completion_state.deinit(allocator);
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
            state.completion_state.visible = false;
        },
        .enter, .ctrl_j => {
            try state.editor.insertNewline(allocator);
            state.completion_state.visible = false;
        },
        .backspace => {
            try state.editor.backspace(allocator);
            state.completion_state.visible = false;
        },
        .delete, .ctrl_d => {
            try state.editor.deleteForward(allocator);
            state.completion_state.visible = false;
        },
        .left => {
            state.editor.moveLeft();
            state.completion_state.visible = false;
        },
        .right => {
            state.editor.moveRight();
            state.completion_state.visible = false;
        },
        .shift_left => {
            state.editor.selectLeft();
            state.completion_state.visible = false;
        },
        .shift_right => {
            state.editor.selectRight();
            state.completion_state.visible = false;
        },
        .up => {
            if (state.completion_state.visible) {
                state.completion_state.selectPrevious();
            } else {
                state.editor.moveUp();
            }
        },
        .down => {
            if (state.completion_state.visible) {
                state.completion_state.selectNext();
            } else {
                state.editor.moveDown();
            }
        },
        .page_up => {
            state.editor.pageUp(@max(visible_editor_height, 1));
            state.completion_state.visible = false;
        },
        .page_down => {
            state.editor.pageDown(@max(visible_editor_height, 1));
            state.completion_state.visible = false;
        },
        .word_left => {
            state.editor.moveWordLeft();
            state.completion_state.visible = false;
        },
        .word_right => {
            state.editor.moveWordRight();
            state.completion_state.visible = false;
        },
        .home, .ctrl_a => {
            state.editor.moveLineHome();
            state.completion_state.visible = false;
        },
        .end, .ctrl_e => {
            state.editor.moveLineEnd();
            state.completion_state.visible = false;
        },
        .ctrl_u => {
            try state.editor.deleteToStart(allocator);
            state.completion_state.visible = false;
        },
        .ctrl_k => {
            try state.editor.deleteToEnd(allocator);
            state.completion_state.visible = false;
        },
        .ctrl_w => {
            try state.editor.deletePreviousWord(allocator);
            state.completion_state.visible = false;
        },
        .ctrl_space => try ziggy.Completion.update(allocator, &state.completion_state, &state.editor, suggestions),
        .tab => {
            if (state.completion_state.visible) {
                _ = try state.completion_state.applyCurrent(allocator, &state.editor);
                state.completion_state.visible = false;
            } else {
                try state.editor.insertText(allocator, "    ");
            }
        },
        .escape => state.completion_state.visible = false,
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
    const line_numbers = try ziggy.LineNumbers.build(allocator, .{
        .count = state.editor.lineCount(),
        .selected = state.editor.currentLine() + 1,
        .offset = state.viewport.offset_line,
        .viewport_height = viewport_height,
        .style = theme.status_idle,
        .selected_style = theme.selected_alt,
    });

    const editor_node = try ziggy.TextArea.buildEditorWithViewport(allocator, &state.editor, state.viewport, .{
        .prompt = "> ",
        .focused = true,
        .style = theme.input,
        .placeholder = "Type here...",
    });

    const scrollbar = try ziggy.Scrollbar.build(allocator, .{
        .axis = .vertical,
        .offset = state.viewport.offset_line,
        .viewport = viewport_height,
        .total = state.editor.lineCount(),
        .style = theme.status_idle,
        .thumb_style = theme.selected_alt,
    });

    const row = try ziggy.HStack.buildWithWeights(allocator, &.{ line_numbers.node, editor_node, scrollbar }, 1, &.{ 1, 12, 1 });
    return try ziggy.Box.buildWithOptions(allocator, title, row, .{
        .style = theme.pane,
        .border_style = theme.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
}

pub fn buildWorkspaceShell(
    allocator: std.mem.Allocator,
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
    const header = try ziggy.HeaderBar.build(allocator, header_title, .{
        .subtitle = "editor workspace example",
        .right_text = "workspace shell",
        .tabs = tabs,
        .selected_tab = active_tab,
        .style = theme.pane,
        .title_style = theme.pane_active,
        .subtitle_style = theme.status_idle,
        .right_style = theme.selected_alt,
        .tab_style = theme.pane,
        .tab_selected_style = theme.selected,
        .border_style = theme.border_style,
    });

    const shell_body = if (show_sidebar) blk: {
        const sidebar = try ziggy.Sidebar.build(allocator, sidebar_title, sidebar_items, .{
            .selected = sidebar_selected,
            .focused = true,
            .style = theme.pane,
            .selected_style = theme.selected,
            .box_style = theme.pane,
            .footer = status_text,
            .footer_style = theme.status_idle,
            .border_style = theme.border_style,
        });
        break :blk try ziggy.HStack.buildWithWeights(allocator, &.{ sidebar, body }, 1, &.{ 1, 5 });
    } else body;

    const footer = try ziggy.FooterBar.build(allocator, footer_left, footer_right, .{
        .center = status_text,
        .hints = hints,
        .style = theme.pane,
        .left_style = theme.selected_alt,
        .center_style = theme.status_idle,
        .right_style = theme.status_idle,
        .hint_style = theme.status_idle,
        .border_style = theme.border_style,
    });

    return try ziggy.VStack.buildWithWeights(allocator, &.{ header, shell_body, footer }, 1, &.{ 0, 1, 0 });
}

test "workspace support handles multiline editor motion" {
    var state = try EditorWorkspaceState.init(std.testing.allocator, "one\ntwo");
    defer state.deinit(std.testing.allocator);

    try std.testing.expect(try handleEditorKey(&state, std.testing.allocator, .enter, &.{}, 4));
    try std.testing.expect(std.mem.indexOf(u8, state.editor.value, "\n\n") != null);
}
