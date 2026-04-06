const std = @import("std");
const hstack = @import("hstack.zig");
const text = @import("text.zig");
const box = @import("box.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");

pub const Options = struct {
    center: ?[]const u8 = null,
    style: style_mod.Style = .{},
    left_style: style_mod.Style = .{},
    center_style: style_mod.Style = .{ .dim = true },
    right_style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .single,
    boxed: bool = true,
};

pub fn build(
    allocator: std.mem.Allocator,
    left: []const u8,
    right: []const u8,
    options: Options,
) !*const node_mod.Node {
    const left_node = try text.buildWithOptions(allocator, try allocator.dupe(u8, left), .{
        .style = options.left_style,
        .wrap = .truncate_end,
    });
    const center_node = try text.buildWithOptions(allocator, try allocator.dupe(u8, options.center orelse ""), .{
        .style = options.center_style,
        .wrap = .truncate_end,
        .alignment = .center,
    });
    const right_node = try text.buildWithOptions(allocator, try allocator.dupe(u8, right), .{
        .style = options.right_style,
        .wrap = .truncate_start,
        .alignment = .right,
    });
    const row = try hstack.buildWithWeights(allocator, &.{ left_node, center_node, right_node }, 1, &.{ 2, 1, 2 });
    if (!options.boxed) return row;
    return try box.buildWithOptions(allocator, null, row, .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
    });
}

test "footer bar builds three-part row" {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const node = try build(fba.allocator(), "left", "right", .{ .center = "mid" });
    try std.testing.expect(node.* == .box);
}
