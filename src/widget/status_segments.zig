const std = @import("std");
const hstack = @import("hstack.zig");
const text = @import("text.zig");
const box = @import("box.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");

pub const Segment = struct {
    text: []const u8,
    style: style_mod.Style = .{},
    visible: bool = true,
};

pub const Layout = struct {
    left: []const Segment = &.{},
    center: []const Segment = &.{},
    right: []const Segment = &.{},
    separator: []const u8 = "  ",
    style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .single,
    padding_left: u16 = 1,
    padding_right: u16 = 1,
};

pub fn buildBar(allocator: std.mem.Allocator, layout: Layout) !*const node_mod.Node {
    const left = try buildGroup(allocator, layout.left, layout.separator);
    const center = try buildGroup(allocator, layout.center, layout.separator);
    const right = try buildGroup(allocator, layout.right, layout.separator);
    const row = try hstack.buildWithWeights(allocator, &.{ left, center, right }, 1, &.{ 2, 1, 2 });
    return try box.buildWithOptions(allocator, null, row, .{
        .style = layout.style,
        .border_style = layout.border_style,
        .padding_left = layout.padding_left,
        .padding_right = layout.padding_right,
    });
}

pub fn buildGroup(
    allocator: std.mem.Allocator,
    segments: []const Segment,
    separator: []const u8,
) !*const node_mod.Node {
    var nodes: std.ArrayList(*const node_mod.Node) = .empty;
    defer nodes.deinit(allocator);

    var first = true;
    for (segments) |segment| {
        if (!segment.visible or segment.text.len == 0) continue;
        if (!first and separator.len > 0) {
            try nodes.append(allocator, try text.buildWithOptions(allocator, try allocator.dupe(u8, separator), .{
                .style = .{ .dim = true },
                .wrap = .truncate_end,
            }));
        }
        try nodes.append(allocator, try text.buildWithOptions(allocator, try allocator.dupe(u8, segment.text), .{
            .style = segment.style,
            .wrap = .truncate_end,
        }));
        first = false;
    }

    if (nodes.items.len == 0) return try node_mod.allocNode(allocator, .empty);
    if (nodes.items.len == 1) return nodes.items[0];
    return try hstack.build(allocator, nodes.items, 0);
}

test "status segments build bar" {
    var buffer: [12288]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const node = try buildBar(fba.allocator(), .{
        .left = &.{.{ .text = "mode: normal" }},
        .center = &.{.{ .text = "line 10" }},
        .right = &.{ .{ .text = "utf-8" }, .{ .text = "lf" } },
    });
    try std.testing.expect(node.* == .box);
}
