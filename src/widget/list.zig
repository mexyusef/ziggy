const std = @import("std");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const focus_mod = @import("focus.zig");

pub const Options = struct {
    selected: usize = 0,
    offset: usize = 0,
    marker: []const u8 = "> ",
    unselected_marker: []const u8 = "  ",
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    focus: focus_mod.FocusState = .{},
};

pub fn build(
    allocator: std.mem.Allocator,
    items: []const []const u8,
    options: Options,
) !*const node_mod.Node {
    return try node_mod.allocNode(allocator, .{
        .list = .{
            .items = items,
            .selected = options.selected,
            .offset = options.offset,
            .marker = options.marker,
            .unselected_marker = options.unselected_marker,
            .style = options.style,
            .selected_style = options.selected_style,
            .focus = options.focus,
        },
    });
}
