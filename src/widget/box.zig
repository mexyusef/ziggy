const std = @import("std");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");

pub fn build(
    allocator: std.mem.Allocator,
    title: ?[]const u8,
    child: ?*const node_mod.Node,
    style: style_mod.Style,
) !*const node_mod.Node {
    return buildWithOptions(allocator, title, child, .{ .style = style });
}

pub const Options = struct {
    style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .single,
    title_align: node_mod.Node.HorizontalAlign = .left,
    margin_top: u16 = 0,
    margin_bottom: u16 = 0,
    margin_left: u16 = 0,
    margin_right: u16 = 0,
    padding_top: u16 = 0,
    padding_bottom: u16 = 0,
    padding_left: u16 = 0,
    padding_right: u16 = 0,
};

pub fn buildWithOptions(
    allocator: std.mem.Allocator,
    title: ?[]const u8,
    child: ?*const node_mod.Node,
    options: Options,
) !*const node_mod.Node {
    return try node_mod.allocNode(allocator, .{
        .box = .{
            .title = title,
            .title_align = options.title_align,
            .style = options.style,
            .border_style = options.border_style,
            .margin_top = options.margin_top,
            .margin_bottom = options.margin_bottom,
            .margin_left = options.margin_left,
            .margin_right = options.margin_right,
            .padding_top = options.padding_top,
            .padding_bottom = options.padding_bottom,
            .padding_left = options.padding_left,
            .padding_right = options.padding_right,
            .child = child,
        },
    });
}
