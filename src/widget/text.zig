const std = @import("std");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");

pub fn build(allocator: std.mem.Allocator, text: []const u8, style: style_mod.Style) !*const node_mod.Node {
    return buildWithOptions(allocator, text, .{ .style = style });
}

pub const Options = struct {
    style: style_mod.Style = .{},
    wrap: node_mod.Node.WrapMode = .wrap,
    alignment: node_mod.Node.HorizontalAlign = .left,
};

pub fn buildWithOptions(allocator: std.mem.Allocator, text: []const u8, options: Options) !*const node_mod.Node {
    return try node_mod.allocNode(allocator, .{
        .text = .{ .text = text, .style = options.style, .wrap = options.wrap, .alignment = options.alignment },
    });
}
