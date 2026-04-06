const std = @import("std");
const hstack = @import("hstack.zig");
const spinner = @import("spinner.zig");
const text = @import("text.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");

pub const Options = struct {
    label: []const u8,
    now_ms: u64 = 0,
    interval_ms: u64 = 80,
    spinner_style: style_mod.Style = .{ .fg = .{ .ansi = 11 }, .bold = true },
    text_style: style_mod.Style = .{},
    gap: u16 = 1,
};

pub fn build(allocator: std.mem.Allocator, options: Options) !*const node_mod.Node {
    const spin = try spinner.build(allocator, .{
        .now_ms = options.now_ms,
        .interval_ms = options.interval_ms,
        .style = options.spinner_style,
    });
    const label = try text.buildWithOptions(allocator, try allocator.dupe(u8, options.label), .{
        .style = options.text_style,
        .wrap = .none,
        .alignment = .left,
    });
    return try hstack.build(allocator, &.{ spin, label }, options.gap);
}
