const std = @import("std");
const node_mod = @import("node.zig");
const box = @import("box.zig");
const list = @import("list.zig");
const style_mod = @import("../style/style.zig");
const focus_mod = @import("focus.zig");
const border_mod = @import("../style/border.zig");

pub const SelectableListOptions = struct {
    selected: usize = 0,
    offset: usize = 0,
    focused: bool = false,
    marker: []const u8 = "> ",
    unselected_marker: []const u8 = "  ",
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    box_style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .single,
    title_align: node_mod.Node.HorizontalAlign = .left,
    focus: focus_mod.FocusState = .{},
};

pub fn buildSelectableList(
    allocator: std.mem.Allocator,
    title: []const u8,
    items: []const []const u8,
    options: SelectableListOptions,
) !*const node_mod.Node {
    const child = try list.build(allocator, items, .{
        .selected = options.selected,
        .offset = options.offset,
        .marker = options.marker,
        .unselected_marker = options.unselected_marker,
        .style = options.style,
        .selected_style = options.selected_style,
        .focus = options.focus,
    });
    return try box.buildWithOptions(allocator, title, child, .{
        .style = if (options.focused) options.box_style else options.style,
        .border_style = options.border_style,
        .title_align = options.title_align,
    });
}

pub fn hitTestSelectableList(
    rect: @import("surface.zig").Rect,
    item_count: usize,
    offset: usize,
    x: u16,
    y: u16,
) ?usize {
    const local = rect.localPoint(x, y) orelse return null;
    _ = local.x;
    if (local.y == 0 or local.y >= rect.height -| 1) return null;
    const visible_index = @as(usize, local.y - 1);
    const absolute = offset + visible_index;
    if (absolute >= item_count) return null;
    return absolute;
}

test "hitTestSelectableList maps body rows to absolute item index" {
    const rect: @import("surface.zig").Rect = .{ .x = 0, .y = 0, .width = 20, .height = 8 };
    try std.testing.expectEqual(@as(?usize, 3), hitTestSelectableList(rect, 10, 2, 1, 2));
    try std.testing.expectEqual(@as(?usize, null), hitTestSelectableList(rect, 2, 0, 1, 6));
}
