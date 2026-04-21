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

    var text_input = try ziggy.TextInput.State.init(allocator, "switch-model");
    text_input.prompt = "> ";
    text_input.placeholder = "Type a command";
    text_input.style = theme.pane;
    text_input.setSuggestions(&.{
        .{ .label = "/help", .value = "/help" },
        .{ .label = "/model", .value = "/model" },
        .{ .label = "/resume", .value = "/resume" },
    });

    const text_input_node = try ziggy.TextInput.State.buildNode(&text_input, allocator);

    const checkbox_node = try ziggy.Checkbox.build(allocator, .{
        .label = "Enable tool approvals",
        .checked = true,
        .focused = true,
    }, theme.pane);

    const radio_state: ziggy.RadioGroup.State = .{
        .items = &.{ "Gemini", "OpenAI-compatible", "Anthropic" },
        .selected = 0,
        .cursor = 1,
        .focused = true,
    };
    const radio_node = try ziggy.RadioGroup.build(allocator, radio_state, .{
        .title = "Provider",
        .style = theme.pane,
        .selected_style = theme.selected,
        .border_style = theme.border_style,
    });

    const slider_node = try ziggy.Slider.build(allocator, .{
        .value = 72,
        .min = 0,
        .max = 100,
        .step = 5,
        .focused = true,
    }, .{
        .title = "Context Usage",
        .label = "Used",
        .style = theme.pane,
        .fill_style = theme.selected_alt,
        .border_style = theme.border_style,
    });

    const paginator_node = try ziggy.Paginator.build(allocator, .{
        .page = 3,
        .total_pages = 12,
        .focused = true,
    }, theme.status_idle);

    const timer_node = try ziggy.Timer.build(allocator, "Retry Window", 42_000, theme.pane);

    const help_entries = try allocator.dupe(ziggy.Help.Entry, &[_]ziggy.Help.Entry{
        .{ .key = "Ctrl+P", .description = "Open quick switcher" },
        .{ .key = "/", .description = "Open command mode" },
        .{ .key = "Esc", .description = "Close active overlay" },
    });
    const help_node = try ziggy.Help.build(allocator, help_entries, .{
        .title = "Key Help",
        .style = theme.pane,
        .border_style = theme.border_style,
    });

    const confirm_node = try ziggy.Confirm.build(allocator, "Discard Changes", "Drop current edits and reload from disk?", .{
        .visible = true,
        .selected_yes = false,
    }, theme.pane);

    const fields = try allocator.dupe(ziggy.Form.Field, &[_]ziggy.Form.Field{
        .{ .label = "Model", .value = "gemini-2.5-flash", .focused = true, .help = "Active provider model" },
        .{ .label = "Workspace", .value = "claude-code-repos", .help = "Current project root" },
    });
    const form_node = try ziggy.Form.build(allocator, fields, .{
        .title = "Workspace Form",
        .style = theme.pane,
        .help_style = theme.status_idle,
        .border_style = theme.border_style,
    });

    const menu_items = try allocator.dupe(ziggy.ContextMenu.Item, &[_]ziggy.ContextMenu.Item{
        .{ .label = "Open Session", .shortcut = "Enter" },
        .{ .label = "Compact Context", .shortcut = "Ctrl+K" },
        .{ .label = "Delete Session", .shortcut = "Del", .enabled = false },
    });
    const context_node = try ziggy.ContextMenu.build(allocator, menu_items, .{
        .visible = true,
        .cursor = 1,
    }, .{
        .title = "Context Menu",
        .style = theme.pane,
        .selected_style = theme.selected,
        .disabled_style = theme.status_idle,
        .border_style = theme.border_style,
    });

    const dropdown_items = try allocator.dupe(ziggy.Dropdown.Item, &[_]ziggy.Dropdown.Item{
        .{ .label = "Compact" },
        .{ .label = "Balanced" },
        .{ .label = "Verbose" },
    });
    const dropdown_node = try ziggy.Dropdown.build(allocator, dropdown_items, .{
        .expanded = true,
        .cursor = 2,
        .selected = 1,
        .focused = true,
    }, .{
        .title = "Response Style",
        .placeholder = "Choose a style",
        .style = theme.pane,
        .selected_style = theme.selected_alt,
        .border_style = theme.border_style,
    });

    const virtual_items = try allocator.dupe([]const u8, &[_][]const u8{
        "session-2026-04-01",
        "session-2026-04-02",
        "session-2026-04-03",
        "session-2026-04-04",
        "session-2026-04-05",
        "session-2026-04-06",
        "session-2026-04-07",
        "session-2026-04-08",
        "session-2026-04-09",
    });
    const virtual_node = try ziggy.VirtualList.build(allocator, virtual_items, .{
        .cursor = 6,
        .offset = 2,
        .viewport = 5,
        .focused = true,
    }, .{
        .title = "Virtual List",
        .style = theme.pane,
        .selected_style = theme.selected,
        .viewport = 5,
    });

    const table_headers = try allocator.dupe([]const u8, &[_][]const u8{ "Tool", "Mode", "Status" });
    const row1 = try allocator.dupe([]const u8, &[_][]const u8{ "read_file", "allow", "ready" });
    const row2 = try allocator.dupe([]const u8, &[_][]const u8{ "shell", "ask", "pending" });
    const row3 = try allocator.dupe([]const u8, &[_][]const u8{ "write_file", "deny", "blocked" });
    const table_rows = try allocator.alloc([]const []const u8, 3);
    table_rows[0] = row1;
    table_rows[1] = row2;
    table_rows[2] = row3;
    const table_node = try ziggy.Table.build(allocator, table_headers, table_rows, .{
        .title = "Permission Matrix",
        .style = theme.pane,
        .border_style = theme.border_style,
    });

    const tree_items = try allocator.dupe(ziggy.Tree.Item, &[_]ziggy.Tree.Item{
        .{ .depth = 0, .label = "workspace", .expanded = true },
        .{ .depth = 1, .label = "src", .expanded = true },
        .{ .depth = 2, .label = "cli", .expanded = false },
        .{ .depth = 1, .label = "docs", .expanded = false },
    });
    const tree_node = try ziggy.Tree.build(allocator, tree_items, .{
        .title = "Project Tree",
        .style = theme.pane,
        .border_style = theme.border_style,
    });

    const left = try ziggy.VStack.build(allocator, &.{
        text_input_node,
        checkbox_node,
        radio_node,
        slider_node,
        paginator_node,
        timer_node,
    }, 1);

    const middle = try ziggy.VStack.build(allocator, &.{
        help_node,
        form_node,
        context_node,
        dropdown_node,
    }, 1);

    const right = try ziggy.VStack.build(allocator, &.{
        virtual_node,
        table_node,
        tree_node,
        confirm_node,
    }, 1);

    const body = try ziggy.HStack.buildWithWeights(allocator, &.{ left, middle, right }, 1, &.{ 1, 1, 1 });
    const header = try ziggy.HeaderBar.build(allocator, "ziggy Controls Demo", .{
        .subtitle = "zigzag-style primitives rendered together",
        .right_text = "static showcase",
        .style = theme.pane,
        .title_style = theme.pane_active,
        .subtitle_style = theme.status_idle,
        .right_style = theme.selected_alt,
        .border_style = theme.border_style,
    });
    const footer = try ziggy.FooterBar.build(allocator, "controls", "build + run from launcher", .{
        .center = "text_input checkbox radio slider paginator timer help confirm form context dropdown virtual_list table tree",
        .style = theme.pane,
        .left_style = theme.selected_alt,
        .center_style = theme.status_idle,
        .right_style = theme.status_idle,
        .border_style = theme.border_style,
    });

    return try ziggy.VStack.buildWithWeights(allocator, &.{ header, body, footer }, 1, &.{ 0, 1, 0 });
}
