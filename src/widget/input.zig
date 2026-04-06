const std = @import("std");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");

pub fn build(
    allocator: std.mem.Allocator,
    prompt: []const u8,
    value: []const u8,
    cursor: usize,
    focused: bool,
    style: style_mod.Style,
) !*const node_mod.Node {
    return try node_mod.allocNode(allocator, .{
        .input = .{
            .prompt = prompt,
            .value = value,
            .cursor = cursor,
            .focused = focused,
            .style = style,
        },
    });
}
