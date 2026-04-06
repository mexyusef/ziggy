const std = @import("std");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");

pub const Options = struct {
    selected: usize = 0,
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    separator: []const u8 = "  ",
    alignment: node_mod.Node.HorizontalAlign = .left,
};

pub fn build(
    allocator: std.mem.Allocator,
    items: []const []const u8,
    options: Options,
) !*const node_mod.Node {
    const owned = try allocator.alloc([]const u8, items.len);
    @memcpy(owned, items);
    return try node_mod.allocNode(allocator, .{
        .tab_bar = .{
            .items = owned,
            .selected = options.selected,
            .style = options.style,
            .selected_style = options.selected_style,
            .separator = options.separator,
            .alignment = options.alignment,
        },
    });
}
