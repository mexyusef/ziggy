const std = @import("std");
const ziggy = @import("ziggy");
const support = @import("support.zig");

pub fn main() !void {
    _ = ziggy.prepareConsole();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const root = try buildRoot(allocator);
    try support.renderStatic(root, support.detectTerminalSize());
}

pub fn buildRoot(allocator: std.mem.Allocator) !*const ziggy.Node {
    const theme = ziggy.defaultAgentTheme();

    const header = try ziggy.HeaderBar.build(allocator, "ziggy Shell Demo", .{
        .subtitle = "header + sidebar + document + footer",
        .right_text = "Ctrl+P | Tab",
        .style = theme.pane,
        .title_style = theme.pane_active,
        .subtitle_style = theme.status_idle,
        .right_style = theme.selected_alt,
        .border_style = theme.border_style,
    });

    const nav_items = try allocator.dupe([]const u8, &[_][]const u8{ "Chat", "Tasks", "Tools", "Sessions" });
    const nav = try ziggy.NavBar.build(allocator, nav_items, .{
        .selected = 0,
        .style = theme.pane,
        .selected_style = theme.selected_alt,
        .right_text = "workspace demo",
        .border_style = theme.border_style,
    });

    const sidebar_items = try allocator.dupe([]const u8, &[_][]const u8{ "Chat", "Tools", "Sessions", "Config" });
    const sidebar = try ziggy.Sidebar.build(allocator, "Navigation", sidebar_items, .{
        .selected = 0,
        .focused = true,
        .style = theme.pane,
        .selected_style = theme.selected,
        .box_style = theme.pane,
        .footer = "Workspace: demo",
        .border_style = theme.border_style,
    });

    const transcript_md =
        \\# Welcome to ziggy
        \\
        \\This demo shows a reusable shell composition:
        \\
        \\- header bar
        \\- sidebar
        \\- rich document
        \\- footer bar
        \\
        \\```zig
        \\const ui = "rich";
        \\std.debug.print("{s}\n", .{ui});
        \\```
        \\
        \\## Notes
        \\
        \\The conversation view is wrapped in a shared scroll container.
        \\This is the primitive intended for long transcripts, code blocks,
        \\and other large documents that need a viewport and scrollbar.
        \\
        \\- header/footer are reusable widgets
        \\- sidebar is reusable
        \\- nav bar is reusable
        \\- alert/toast/tooltip are reusable
    ;
    const rich_lines = try ziggy.FormatRichMarkdown.renderLines(allocator, transcript_md, 56, .{});
    const doc_offset = ziggy.RichDocument.followOffset(rich_lines.len, 10);
    const doc = try ziggy.RichDocument.build(allocator, rich_lines, doc_offset, theme.pane);
    const conversation = try ziggy.ScrollContainer.build(allocator, doc, .{
        .title = "Conversation",
        .style = theme.pane,
        .scrollbar_style = theme.status_idle,
        .thumb_style = theme.selected_alt,
        .border_style = theme.border_style,
        .offset = doc_offset,
        .viewport = 10,
        .total = rich_lines.len,
    });

    const alert = try ziggy.Alert.build(allocator, .{
        .level = .info,
        .label = "INFO",
        .message = "Dialogs, sidebars, nav bars, and rich docs are now shared primitives.",
        .style = theme.pane,
        .text_style = theme.status_idle,
        .border_style = theme.border_style,
    });

    const center = try ziggy.VStack.buildWithWeights(allocator, &.{ nav, conversation, alert }, 1, &.{ 1, 8, 2 });
    const body = try ziggy.HStack.buildWithWeights(allocator, &.{ sidebar, center }, 1, &.{ 1, 4 });

    const footer = try ziggy.FooterBar.build(allocator, "focus: conversation", "esc to quit", .{
        .center = "demo ready",
        .style = theme.pane,
        .left_style = theme.selected_alt,
        .center_style = theme.status_idle,
        .right_style = theme.status_idle,
        .border_style = theme.border_style,
    });

    return try ziggy.VStack.buildWithWeights(allocator, &.{ header, body, footer }, 1, &.{ 0, 1, 0 });
}
