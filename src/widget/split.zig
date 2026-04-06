const std = @import("std");
const node_mod = @import("node.zig");

pub fn build(
    allocator: std.mem.Allocator,
    left: *const node_mod.Node,
    right: *const node_mod.Node,
    ratio_percent: u8,
    axis: node_mod.Node.SplitAxis,
) !*const node_mod.Node {
    return try node_mod.allocNode(allocator, .{
        .split = .{
            .left = left,
            .right = right,
            .ratio_percent = ratio_percent,
            .axis = axis,
        },
    });
}
