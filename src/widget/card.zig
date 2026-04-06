const std = @import("std");
const vstack = @import("vstack.zig");
const text = @import("text.zig");
const box = @import("box.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");

pub const Options = struct {
    subtitle: ?[]const u8 = null,
    body: []const u8 = "",
    style: style_mod.Style = .{},
    title_style: style_mod.Style = .{ .bold = true },
    subtitle_style: style_mod.Style = .{ .dim = true },
    body_style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .single,
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
    const body_node = try text.buildWithOptions(allocator, try allocator.dupe(u8, options.body), .{
        .style = options.body_style,
        .wrap = .wrap,
    });
    const content = if (options.subtitle) |subtitle| blk: {
        const subtitle_node = try text.buildWithOptions(allocator, try allocator.dupe(u8, subtitle), .{
            .style = options.subtitle_style,
            .wrap = .truncate_end,
        });
        break :blk try vstack.build(allocator, &.{ title_node, subtitle_node, body_node }, 1);
    } else try vstack.build(allocator, &.{ title_node, body_node }, 1);

    return try box.buildWithOptions(allocator, null, content, .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
}

test "card builds boxed content" {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const node = try build(fba.allocator(), "Agent", .{ .subtitle = "runtime", .body = "A reusable card primitive." });
    try std.testing.expect(node.* == .box);
}
