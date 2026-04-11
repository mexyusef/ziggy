const std = @import("std");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");

pub fn build(
    allocator: std.mem.Allocator,
    left: []const u8,
    right: []const u8,
    style: style_mod.Style,
) !*const node_mod.Node {
    return buildWithOptions(allocator, .{
        .left = left,
        .right = right,
        .style = style,
    });
}

pub const Options = struct {
    left: []const u8,
    right: []const u8,
    center: ?[]const u8 = null,
    style: style_mod.Style = .{},
    left_style: ?style_mod.Style = null,
    center_style: ?style_mod.Style = null,
    right_style: ?style_mod.Style = null,
};

pub fn buildWithOptions(
    allocator: std.mem.Allocator,
    options: Options,
) !*const node_mod.Node {
    return try node_mod.allocNode(allocator, .{
        .status_bar = .{
            .left = options.left,
            .right = options.right,
            .center = options.center,
            .style = options.style,
            .left_style = options.left_style,
            .center_style = options.center_style,
            .right_style = options.right_style,
        },
    });
}
