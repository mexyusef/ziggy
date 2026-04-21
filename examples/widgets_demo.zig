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

    const header = try ziggy.HeaderBar.build(allocator, "ziggy Widget Gallery", .{
        .subtitle = "header, menu, breadcrumb, nav, cards, alerts, toasts, tooltip",
        .right_text = "static demo",
        .style = theme.pane,
        .title_style = theme.pane_active,
        .subtitle_style = theme.status_idle,
        .right_style = theme.selected_alt,
        .border_style = theme.border_style,
    });

    const menu_items = try allocator.dupe([]const u8, &[_][]const u8{ "File", "Edit", "View", "Help" });
    const menu = try ziggy.MenuBar.build(allocator, menu_items, .{
        .selected = 2,
        .style = theme.pane,
        .selected_style = theme.selected_alt,
        .border_style = theme.border_style,
    });

    const breadcrumb_items = try allocator.dupe([]const u8, &[_][]const u8{ "workspace", "examples", "widgets_demo.zig" });
    const breadcrumb = try ziggy.Breadcrumb.build(allocator, breadcrumb_items, .{
        .style = theme.pane,
        .current_style = theme.selected,
    });

    const nav_items = try allocator.dupe([]const u8, &[_][]const u8{ "Overview", "Dialogs", "Notifications", "Editors" });
    const nav = try ziggy.NavBar.build(allocator, nav_items, .{
        .selected = 1,
        .style = theme.pane,
        .selected_style = theme.selected_alt,
        .right_text = "demo",
        .border_style = theme.border_style,
    });

    const alert = try ziggy.Alert.build(allocator, .{
        .level = .warning,
        .label = "WARNING",
        .message = "This gallery is a static snapshot of shared primitives.",
        .style = theme.pane,
        .text_style = theme.status_idle,
        .border_style = theme.border_style,
    });
    const toast = try ziggy.Toast.build(allocator, .{
        .level = .success,
        .label = "DONE",
        .message = "The richer UI primitive set is available for app shells.",
    });
    const tooltip = try ziggy.Tooltip.build(allocator, "Hover/help surfaces can share one tooltip widget.", .{});

    const left_card_summary = try ziggy.Card.build(allocator, "Notifications", .{
        .subtitle = "alert + toast + tooltip",
        .body = "Small notification surfaces for app shells and transient UX.",
        .style = theme.pane,
        .border_style = theme.border_style,
    });
    const left_card_body = try ziggy.VStack.build(allocator, &.{ left_card_summary, alert, toast, tooltip }, 1);
    const left_card = try ziggy.Box.buildWithOptions(allocator, "Notification Surfaces", left_card_body, .{
        .style = theme.pane,
        .border_style = theme.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });

    const commands = try allocator.dupe([]const u8, &[_][]const u8{ "Open Session", "Switch Model", "Compact Context", "Review Diff" });
    const command_dialog = try ziggy.CommandDialog.build(allocator, "Command Palette", "sw", commands, .{
        .selected = 1,
        .cursor = 2,
        .hint = "Ctrl+P opens, arrows move, Enter selects",
        .style = theme.pane,
        .selected_style = theme.selected,
        .box_style = theme.pane,
        .border_style = theme.border_style,
    });
    const picker_items = try allocator.dupe([]const u8, &[_][]const u8{ "Workspace A", "Workspace B", "Workspace C" });
    const picker = try ziggy.PickerDialog.build(allocator, "Quick Switcher", picker_items, .{
        .description = "Ctrl+P style picker surface.",
        .selected = 0,
        .style = theme.pane,
        .selected_style = theme.selected_alt,
        .box_style = theme.pane,
        .border_style = theme.border_style,
    });
    const right_card_summary = try ziggy.Card.build(allocator, "Dialogs", .{
        .subtitle = "command + picker",
        .body = "Command palette and Ctrl+P style picker surfaces are shared primitives.",
        .style = theme.pane,
        .border_style = theme.border_style,
    });
    const right_card_body = try ziggy.VStack.build(allocator, &.{ right_card_summary, command_dialog, picker }, 1);
    const right_card = try ziggy.Box.buildWithOptions(allocator, "Dialog Surfaces", right_card_body, .{
        .style = theme.pane,
        .border_style = theme.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });

    const body = try ziggy.HStack.buildWithWeights(allocator, &.{ left_card, right_card }, 1, &.{ 1, 1 });
    const footer = try ziggy.FooterBar.build(allocator, "widgets", "esc to close", .{
        .center = "ziggy gallery",
        .style = theme.pane,
        .left_style = theme.selected_alt,
        .center_style = theme.status_idle,
        .right_style = theme.status_idle,
        .border_style = theme.border_style,
    });
    return try ziggy.VStack.buildWithWeights(allocator, &.{ header, menu, breadcrumb, nav, body, footer }, 1, &.{ 0, 0, 0, 0, 1, 0 });
}
