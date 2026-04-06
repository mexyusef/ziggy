const std = @import("std");
const hstack = @import("hstack.zig");
const box = @import("box.zig");
const scrollbar = @import("scrollbar.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");

pub const Options = struct {
    title: ?[]const u8 = null,
    offset: usize = 0,
    viewport: usize = 0,
    total: usize = 0,
    style: style_mod.Style = .{},
    scrollbar_style: style_mod.Style = .{},
    thumb_style: style_mod.Style = .{ .bold = true },
    border_style: border_mod.BorderStyle = .single,
    show_box: bool = true,
};

pub fn build(
    allocator: std.mem.Allocator,
    child: *const node_mod.Node,
    options: Options,
) !*const node_mod.Node {
    const bar = try scrollbar.build(allocator, .{
        .axis = .vertical,
        .offset = options.offset,
        .viewport = options.viewport,
        .total = options.total,
        .style = options.scrollbar_style,
        .thumb_style = options.thumb_style,
    });
    const body = try hstack.buildWithWeights(allocator, &.{ child, bar }, 1, &.{ 12, 0 });
    if (!options.show_box) return body;
    return try box.buildWithOptions(allocator, options.title, body, .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
}

test "scroll container builds boxed content with scrollbar" {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const child = try node_mod.allocNode(fba.allocator(), .{ .text = .{ .text = "body" } });
    const node = try build(fba.allocator(), child, .{
        .title = "Scroll",
        .viewport = 10,
        .total = 20,
    });
    try std.testing.expect(node.* == .box);
}
