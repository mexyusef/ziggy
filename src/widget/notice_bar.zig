const std = @import("std");
const badge = @import("badge.zig");
const hstack = @import("hstack.zig");
const text = @import("text.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");

pub const Level = enum {
    info,
    success,
    warning,
    err,
};

pub const Options = struct {
    level: Level = .info,
    label: []const u8 = "INFO",
    message: []const u8,
    badge_style: ?style_mod.Style = null,
    text_style: style_mod.Style = .{},
};

pub fn build(allocator: std.mem.Allocator, options: Options) !*const node_mod.Node {
    const resolved_badge_style = options.badge_style orelse switch (options.level) {
        .info => style_mod.Style{ .fg = .{ .ansi = 15 }, .bg = .{ .ansi = 6 }, .bold = true },
        .success => style_mod.Style{ .fg = .{ .ansi = 15 }, .bg = .{ .ansi = 2 }, .bold = true },
        .warning => style_mod.Style{ .fg = .{ .ansi = 0 }, .bg = .{ .ansi = 11 }, .bold = true },
        .err => style_mod.Style{ .fg = .{ .ansi = 15 }, .bg = .{ .ansi = 1 }, .bold = true },
    };
    const badge_node = try badge.build(allocator, options.label, .{
        .style = resolved_badge_style,
    });
    const text_node = try text.buildWithOptions(allocator, try allocator.dupe(u8, options.message), .{
        .style = options.text_style,
        .wrap = .truncate_end,
    });
    return try hstack.buildWithWeights(allocator, &.{ badge_node, text_node }, 1, &.{ 1, 6 });
}
