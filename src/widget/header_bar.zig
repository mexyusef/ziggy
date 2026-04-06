const std = @import("std");
const hstack = @import("hstack.zig");
const vstack = @import("vstack.zig");
const text = @import("text.zig");
const box = @import("box.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");

pub const Options = struct {
    subtitle: ?[]const u8 = null,
    right_text: ?[]const u8 = null,
    style: style_mod.Style = .{},
    title_style: style_mod.Style = .{ .bold = true },
    subtitle_style: style_mod.Style = .{ .dim = true },
    right_style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .single,
    boxed: bool = true,
};

pub fn build(
    allocator: std.mem.Allocator,
    title: []const u8,
    options: Options,
) !*const node_mod.Node {
    const title_node = try text.buildWithOptions(allocator, try allocator.dupe(u8, title), .{
        .style = options.title_style,
        .wrap = .truncate_end,
    });
    const left = if (options.subtitle) |subtitle| blk: {
        const subtitle_node = try text.buildWithOptions(allocator, try allocator.dupe(u8, subtitle), .{
            .style = options.subtitle_style,
            .wrap = .truncate_end,
        });
        break :blk try vstack.build(allocator, &.{ title_node, subtitle_node }, 0);
    } else title_node;

    const row = if (options.right_text) |right_text| blk: {
        const right = try text.buildWithOptions(allocator, try allocator.dupe(u8, right_text), .{
            .style = options.right_style,
            .wrap = .truncate_end,
            .alignment = .right,
        });
        break :blk try hstack.buildWithWeights(allocator, &.{ left, right }, 1, &.{ 3, 2 });
    } else left;

    if (!options.boxed) return row;
    return try box.buildWithOptions(allocator, null, row, .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
    });
}

test "header bar builds boxed shell" {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const node = try build(fba.allocator(), "ziggy", .{ .subtitle = "runtime" });
    try std.testing.expect(node.* == .box);
}
