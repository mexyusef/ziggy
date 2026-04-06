const std = @import("std");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");

pub const Options = struct {
    style: style_mod.Style = .{ .bold = true },
    padding_left: u16 = 1,
    padding_right: u16 = 1,
    alignment: node_mod.Node.HorizontalAlign = .left,
};

pub fn build(
    allocator: std.mem.Allocator,
    text: []const u8,
    options: Options,
) !*const node_mod.Node {
    return try node_mod.allocNode(allocator, .{
        .badge = .{
            .text = text,
            .style = options.style,
            .padding_left = options.padding_left,
            .padding_right = options.padding_right,
            .alignment = options.alignment,
        },
    });
}
