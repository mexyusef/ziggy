const std = @import("std");
const box = @import("box.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");

pub const Options = struct {
    style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .single,
    padding_left: u16 = 1,
    padding_right: u16 = 1,
    padding_top: u16 = 1,
    padding_bottom: u16 = 1,
};

pub fn build(
    allocator: std.mem.Allocator,
    title: []const u8,
    child: ?*const node_mod.Node,
    options: Options,
) !*const node_mod.Node {
    return try box.buildWithOptions(allocator, title, child, .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = options.padding_left,
        .padding_right = options.padding_right,
        .padding_top = options.padding_top,
        .padding_bottom = options.padding_bottom,
    });
}

test "group box wraps child in titled box" {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const child = try node_mod.allocNode(fba.allocator(), .{ .text = .{ .text = "body" } });
    const node = try build(fba.allocator(), "Preferences", child, .{});
    try std.testing.expect(node.* == .box);
}
