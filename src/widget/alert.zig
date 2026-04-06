const std = @import("std");
const notice_bar = @import("notice_bar.zig");
const box = @import("box.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");

pub const Level = notice_bar.Level;

pub const Options = struct {
    level: Level = .info,
    label: []const u8 = "INFO",
    message: []const u8,
    style: style_mod.Style = .{},
    text_style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .single,
};

pub fn build(allocator: std.mem.Allocator, options: Options) !*const node_mod.Node {
    const bar = try notice_bar.build(allocator, .{
        .level = options.level,
        .label = options.label,
        .message = options.message,
        .text_style = options.text_style,
    });
    return try box.buildWithOptions(allocator, null, bar, .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
}

test "alert builds boxed notice" {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const node = try build(fba.allocator(), .{ .message = "Something happened." });
    try std.testing.expect(node.* == .box);
}
