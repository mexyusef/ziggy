const std = @import("std");
const text = @import("text.zig");
const box = @import("box.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");

pub const Options = struct {
    style: style_mod.Style = .{},
    text_style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .round,
};

pub fn build(
    allocator: std.mem.Allocator,
    message: []const u8,
    options: Options,
) !*const node_mod.Node {
    const body = try text.buildWithOptions(allocator, try allocator.dupe(u8, message), .{
        .style = options.text_style,
        .wrap = .wrap,
    });
    return try box.buildWithOptions(allocator, null, body, .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
}

test "tooltip builds padded text box" {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const node = try build(fba.allocator(), "Press Enter to continue.", .{});
    try std.testing.expect(node.* == .box);
}
