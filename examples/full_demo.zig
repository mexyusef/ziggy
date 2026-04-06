const std = @import("std");
const ziggy = @import("ziggy");
const support = @import("support.zig");

pub fn main() !void {
    _ = ziggy.prepareConsole();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const theme = ziggy.defaultAgentTheme();

    const header = try ziggy.HeaderBar.build(allocator, "ziggy Full Demo", .{
        .subtitle = "shell + nav + sidebar + transcript + dialogs + footer",
        .right_text = "full demo",
        .style = theme.pane,
        .title_style = theme.pane_active,
        .subtitle_style = theme.status_idle,
        .right_style = theme.selected_alt,
        .border_style = theme.border_style,
    });

    const menu_items = [_][]const u8{ "Workspace", "Models", "Tasks", "Help" };
    const menu = try ziggy.MenuBar.build(allocator, &menu_items, .{
        .selected = 1,
        .style = theme.pane,
        .selected_style = theme.selected_alt,
        .border_style = theme.border_style,
    });

    const breadcrumb_items = [_][]const u8{ "workspace", "src", "main.zig" };
    const breadcrumb = try ziggy.Breadcrumb.build(allocator, &breadcrumb_items, .{
        .style = theme.pane,
        .current_style = theme.selected,
    });

    const sidebar_items = [_][]const u8{ "Conversation", "Sessions", "Tools", "Config" };
    const sidebar = try ziggy.Sidebar.build(allocator, "Workspace", &sidebar_items, .{
        .selected = 0,
        .focused = true,
        .style = theme.pane,
        .selected_style = theme.selected,
        .box_style = theme.pane,
        .footer = "Ctrl+P for palette",
        .border_style = theme.border_style,
    });

    const transcript_md =
        \\# Conversation
        \\
        \\**User:** Can you show a rich `ziggy` demo?
        \\
        \\**Assistant:** Yes. This full demo combines:
        \\
        \\- `HeaderBar`
        \\- `MenuBar`
        \\- `Breadcrumb`
        \\- `Sidebar`
        \\- `CommandDialog`
        \\- `PickerDialog`
        \\- `RichDocument`
        \\- `FooterBar`
        \\
        \\```zig
        \\const theme = ziggy.defaultAgentTheme();
        \\const root = try ziggy.VStack.buildWithWeights(...);
        \\```
        \\
        \\## Notes
        \\
        \\This is the kind of shell `cirebronx` can keep consuming directly.
    ;
    const rich_lines = try ziggy.FormatRichMarkdown.renderLines(allocator, transcript_md, 70, .{});
    const doc = try ziggy.RichDocument.build(allocator, rich_lines, 0, theme.pane);
    const transcript = try ziggy.ScrollContainer.build(allocator, doc, .{
        .title = "Transcript",
        .style = theme.pane,
        .scrollbar_style = theme.status_idle,
        .thumb_style = theme.selected_alt,
        .border_style = theme.border_style,
        .offset = 0,
        .viewport = 18,
        .total = rich_lines.len,
    });

    const commands = [_][]const u8{ "Open Session", "Switch Model", "Compact Context", "Review Diff" };
    const command_dialog = try ziggy.CommandDialog.build(allocator, "Palette", "sw", &commands, .{
        .selected = 1,
        .cursor = 2,
        .hint = "Ctrl+P style dialog",
        .style = theme.pane,
        .selected_style = theme.selected,
        .box_style = theme.pane,
        .border_style = theme.border_style,
    });
    const picker_items = [_][]const u8{ "gemini-2.5-flash", "gpt-5", "claude-sonnet" };
    const picker = try ziggy.PickerDialog.build(allocator, "Models", &picker_items, .{
        .description = "Quick switcher / picker example",
        .selected = 0,
        .style = theme.pane,
        .selected_style = theme.selected_alt,
        .box_style = theme.pane,
        .border_style = theme.border_style,
    });
    const dialogs_summary = try ziggy.Card.build(allocator, "Dialogs", .{
        .subtitle = "palette + picker",
        .body = "A full app can combine a command palette with a quick-switch picker in the same shell.",
        .style = theme.pane,
        .border_style = theme.border_style,
    });
    const dialogs = try ziggy.VStack.buildWithWeights(allocator, &.{ dialogs_summary, command_dialog, picker }, 1, &.{ 0, 1, 1 });
    const dialogs_card = try ziggy.Box.buildWithOptions(allocator, "Dialogs", dialogs, .{
        .style = theme.pane,
        .border_style = theme.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });

    const main_panel = try ziggy.HStack.buildWithWeights(allocator, &.{ transcript, dialogs_card }, 1, &.{ 3, 2 });
    const body = try ziggy.HStack.buildWithWeights(allocator, &.{ sidebar, main_panel }, 1, &.{ 1, 5 });

    const footer = try ziggy.FooterBar.build(allocator, "full-demo", "esc to leave demo", .{
        .center = "rich primitives plan completed to runnable-demo level",
        .style = theme.pane,
        .left_style = theme.selected_alt,
        .center_style = theme.status_idle,
        .right_style = theme.status_idle,
        .border_style = theme.border_style,
    });

    const root = try ziggy.VStack.buildWithWeights(allocator, &.{ header, menu, breadcrumb, body, footer }, 1, &.{ 0, 0, 0, 1, 0 });
    try support.renderStatic(root, support.detectTerminalSize());
}
