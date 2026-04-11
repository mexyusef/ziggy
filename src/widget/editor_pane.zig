const std = @import("std");
const theme_mod = @import("../style/theme.zig");
const border_mod = @import("../style/border.zig");
const editor_mod = @import("editor.zig");
const line_numbers = @import("line_numbers.zig");
const text_area = @import("text_area.zig");
const scrollbar = @import("scrollbar.zig");
const hstack = @import("hstack.zig");
const box = @import("box.zig");
const node_mod = @import("node.zig");

pub const Options = struct {
    title: []const u8,
    viewport: text_area.Viewport,
    theme: theme_mod.AgentTheme = theme_mod.defaultAgentTheme(),
    prompt: []const u8 = "> ",
    viewport_height: usize,
    focused: bool = true,
    placeholder: ?[]const u8 = "Type here...",
    show_scrollbar: bool = true,
    border_style: border_mod.BorderStyle = .single,
};

pub fn build(
    allocator: std.mem.Allocator,
    editor: *const editor_mod.Editor,
    options: Options,
) !*const node_mod.Node {
    const gutter = try line_numbers.build(allocator, .{
        .count = editor.lineCount(),
        .selected = editor.currentLine() + 1,
        .offset = options.viewport.offset_line,
        .viewport_height = options.viewport_height,
        .style = options.theme.status_idle,
        .selected_style = options.theme.selected_alt,
    });

    const editor_node = try text_area.buildEditorWithViewport(allocator, editor, options.viewport, .{
        .prompt = options.prompt,
        .focused = options.focused,
        .style = options.theme.input,
        .placeholder = options.placeholder,
    });

    if (!options.show_scrollbar) {
        const row = try hstack.buildWithWeights(allocator, &.{ gutter.node, editor_node }, 1, &.{ 1, 12 });
        return try wrapBox(allocator, options, row);
    }

    const scroller = try scrollbar.build(allocator, .{
        .axis = .vertical,
        .offset = options.viewport.offset_line,
        .viewport = options.viewport_height,
        .total = editor.lineCount(),
        .style = options.theme.status_idle,
        .thumb_style = options.theme.selected_alt,
    });
    const row = try hstack.buildWithWeights(allocator, &.{ gutter.node, editor_node, scroller }, 1, &.{ 1, 12, 1 });
    return try wrapBox(allocator, options, row);
}

fn wrapBox(allocator: std.mem.Allocator, options: Options, child: *const node_mod.Node) !*const node_mod.Node {
    return try box.buildWithOptions(allocator, options.title, child, .{
        .style = options.theme.pane,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
}

test "editor pane builds composite widget" {
    var buffer: [16384]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    var editor = try editor_mod.Editor.init(allocator, "one\ntwo");
    const node = try build(allocator, &editor, .{
        .title = "main.zig",
        .viewport = .{ .width = 40, .height = 10, .scroll_margin = 1 },
        .viewport_height = 10,
    });
    try std.testing.expect(node.* == .box);
}
