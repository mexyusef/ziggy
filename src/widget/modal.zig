const std = @import("std");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");

pub const Options = struct {
    style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .double,
    padding: u16 = 1,
};

pub fn build(
    allocator: std.mem.Allocator,
    title: []const u8,
    body: []const u8,
    style: style_mod.Style,
) !*const node_mod.Node {
    return buildWithOptions(allocator, title, body, .{ .style = style });
}

pub fn buildWithOptions(
    allocator: std.mem.Allocator,
    title: []const u8,
    body: []const u8,
    options: Options,
) !*const node_mod.Node {
    return try node_mod.allocNode(allocator, .{
        .modal = .{
            .title = title,
            .body = body,
            .child = null,
            .style = options.style,
            .border_style = options.border_style,
        },
    });
}

pub fn buildNode(
    allocator: std.mem.Allocator,
    title: []const u8,
    child: *const node_mod.Node,
    style: style_mod.Style,
) !*const node_mod.Node {
    return buildNodeWithOptions(allocator, title, child, .{ .style = style });
}

pub fn buildNodeWithOptions(
    allocator: std.mem.Allocator,
    title: []const u8,
    child: *const node_mod.Node,
    options: Options,
) !*const node_mod.Node {
    return try node_mod.allocNode(allocator, .{
        .modal = .{
            .title = title,
            .body = null,
            .child = child,
            .style = options.style,
            .border_style = options.border_style,
        },
    });
}
