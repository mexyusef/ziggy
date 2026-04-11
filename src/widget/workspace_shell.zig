const std = @import("std");
const screen_mod = @import("../terminal/screen.zig");
const theme_mod = @import("../style/theme.zig");
const border_mod = @import("../style/border.zig");
const focus_mod = @import("focus.zig");
const header_bar = @import("header_bar.zig");
const footer_bar = @import("footer_bar.zig");
const status_segments = @import("status_segments.zig");
const sidebar = @import("sidebar.zig");
const hstack = @import("hstack.zig");
const vstack = @import("vstack.zig");
const node_mod = @import("node.zig");

pub const SidebarOptions = struct {
    title: []const u8,
    items: []const []const u8,
    selected: usize = 0,
    offset: usize = 0,
    footer: ?[]const u8 = null,
    width: u16 = 24,
    focused: bool = true,
    focus: focus_mod.FocusState = .{},
};

pub const Options = struct {
    size: screen_mod.Size,
    title: []const u8,
    body: *const node_mod.Node,
    subtitle: ?[]const u8 = null,
    right_text: ?[]const u8 = null,
    tabs: ?[]const []const u8 = null,
    selected_tab: usize = 0,
    sidebar: ?SidebarOptions = null,
    footer_left: []const u8 = "",
    footer_center: ?[]const u8 = null,
    footer_right: []const u8 = "",
    hints: ?[]const []const u8 = null,
    footer_segments: ?status_segments.Layout = null,
    theme: theme_mod.AgentTheme = theme_mod.defaultAgentTheme(),
    border_style: border_mod.BorderStyle = .single,
};

pub fn build(allocator: std.mem.Allocator, options: Options) !*const node_mod.Node {
    const header = try header_bar.build(allocator, options.title, .{
        .subtitle = options.subtitle,
        .right_text = options.right_text,
        .tabs = options.tabs,
        .selected_tab = options.selected_tab,
        .style = options.theme.pane,
        .title_style = options.theme.pane_active,
        .subtitle_style = options.theme.status_idle,
        .right_style = options.theme.selected_alt,
        .tab_style = options.theme.pane,
        .tab_selected_style = options.theme.selected,
        .border_style = options.border_style,
    });

    const shell_body = if (options.sidebar) |sidebar_options| blk: {
        const sidebar_node = try sidebar.build(allocator, sidebar_options.title, sidebar_options.items, .{
            .selected = sidebar_options.selected,
            .offset = sidebar_options.offset,
            .focused = sidebar_options.focused,
            .footer = sidebar_options.footer,
            .style = options.theme.pane,
            .selected_style = options.theme.selected,
            .box_style = options.theme.pane,
            .footer_style = options.theme.status_idle,
            .border_style = options.border_style,
            .focus = sidebar_options.focus,
        });
        const sidebar_width = @max(sidebar_options.width, 1);
        const center_width = @max(options.size.width -| sidebar_width, 1);
        const weights = [_]u16{ sidebar_width, center_width };
        break :blk try hstack.buildWithWeights(allocator, &.{ sidebar_node, options.body }, 1, &weights);
    } else options.body;

    const footer = if (options.footer_segments) |segments| blk: {
        break :blk try status_segments.buildBar(allocator, segments);
    } else try footer_bar.build(allocator, options.footer_left, options.footer_right, .{
        .center = options.footer_center,
        .hints = options.hints,
        .style = options.theme.pane,
        .left_style = options.theme.selected_alt,
        .center_style = options.theme.status_idle,
        .right_style = options.theme.status_idle,
        .hint_style = options.theme.status_idle,
        .border_style = options.border_style,
    });

    const header_height = estimateHeaderHeight(options);
    const footer_height = estimateFooterHeight(options);
    const gap_total: u16 = 2;
    const body_height = @max(options.size.height -| header_height -| footer_height -| gap_total, 1);

    return try vstack.buildWithWeights(
        allocator,
        &.{ header, shell_body, footer },
        1,
        &.{ header_height, body_height, footer_height },
    );
}

fn estimateHeaderHeight(options: Options) u16 {
    var height: u16 = 3;
    if (options.subtitle != null) height += 1;
    if (options.tabs != null) height += 2;
    return height;
}

fn estimateFooterHeight(options: Options) u16 {
    if (options.footer_segments != null) return 3;
    if (options.hints != null and options.hints.?.len > 0) return 5;
    return 3;
}

test "workspace shell builds with sidebar" {
    var buffer: [16384]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const body = try node_mod.allocNode(fba.allocator(), .{ .text = .{ .text = "body" } });
    const items = [_][]const u8{ "Explorer", "Search" };
    const node = try build(fba.allocator(), .{
        .size = .{ .width = 100, .height = 30 },
        .title = "Workspace",
        .body = body,
        .sidebar = .{
            .title = "Sidebar",
            .items = &items,
        },
    });
    try std.testing.expect(node.* == .vstack);
}
