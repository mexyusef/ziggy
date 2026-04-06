const std = @import("std");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");

pub fn build(
    allocator: std.mem.Allocator,
    lines: []const []const u8,
    offset: usize,
    style: style_mod.Style,
) !*const node_mod.Node {
    return try node_mod.allocNode(allocator, .{
        .scroll = .{
            .lines = lines,
            .offset = offset,
            .style = style,
        },
    });
}
