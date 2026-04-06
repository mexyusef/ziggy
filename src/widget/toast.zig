const std = @import("std");
const alert = @import("alert.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");

pub const Level = alert.Level;

pub const Options = struct {
    level: Level = .info,
    label: []const u8 = "INFO",
    message: []const u8,
    style: style_mod.Style = .{},
    text_style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .round,
};

pub fn build(allocator: std.mem.Allocator, options: Options) !*const node_mod.Node {
    return try alert.build(allocator, .{
        .level = options.level,
        .label = options.label,
        .message = options.message,
        .style = options.style,
        .text_style = options.text_style,
        .border_style = options.border_style,
    });
}

test "toast builds alert-shaped surface" {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const node = try build(fba.allocator(), .{ .message = "Saved." });
    try std.testing.expect(node.* == .box);
}
