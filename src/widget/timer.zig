const std = @import("std");
const text = @import("text.zig");
const style_mod = @import("../style/style.zig");
const node_mod = @import("node.zig");

pub fn formatRemaining(allocator: std.mem.Allocator, remaining_ms: u64) ![]const u8 {
    const total_seconds = remaining_ms / 1000;
    const minutes = total_seconds / 60;
    const seconds = total_seconds % 60;
    return try std.fmt.allocPrint(allocator, "{d:0>2}:{d:0>2}", .{ minutes, seconds });
}

pub fn build(allocator: std.mem.Allocator, title: []const u8, remaining_ms: u64, style: style_mod.Style) !*const node_mod.Node {
    const remaining = try formatRemaining(allocator, remaining_ms);
    return try text.buildWithOptions(allocator, try std.fmt.allocPrint(allocator, "{s}: {s}", .{ title, remaining }), .{
        .style = style,
        .wrap = .truncate_end,
    });
}

test "timer formats mm:ss" {
    const rendered = try formatRemaining(std.testing.allocator, 125000);
    defer std.testing.allocator.free(rendered);
    try std.testing.expectEqualStrings("02:05", rendered);
}
