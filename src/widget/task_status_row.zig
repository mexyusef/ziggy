const std = @import("std");
const badge = @import("badge.zig");
const hstack = @import("hstack.zig");
const progress_bar = @import("progress_bar.zig");
const spinner_row = @import("spinner_row.zig");
const text = @import("text.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");

pub const Mode = union(enum) {
    idle: []const u8,
    running: []const u8,
    progress: struct {
        label: []const u8,
        current: usize,
        total: usize,
    },
};

pub const Options = struct {
    title: []const u8,
    mode: Mode,
    now_ms: u64 = 0,
    gap: u16 = 1,
    title_style: style_mod.Style = .{ .bold = true },
    meta_style: style_mod.Style = .{ .fg = .{ .ansi = 8 } },
};

pub fn build(allocator: std.mem.Allocator, options: Options) !*const node_mod.Node {
    const title_node = try badge.build(allocator, try allocator.dupe(u8, options.title), .{
        .style = options.title_style,
        .padding_left = 1,
        .padding_right = 1,
    });

    const detail_node = switch (options.mode) {
        .idle => |label| try text.buildWithOptions(allocator, try allocator.dupe(u8, label), .{
            .style = options.meta_style,
            .wrap = .truncate_end,
        }),
        .running => |label| try spinner_row.build(allocator, .{
            .label = label,
            .now_ms = options.now_ms,
            .text_style = options.meta_style,
        }),
        .progress => |progress| blk: {
            const label = try text.buildWithOptions(allocator, try allocator.dupe(u8, progress.label), .{
                .style = options.meta_style,
                .wrap = .truncate_end,
            });
            const bar = try progress_bar.build(allocator, .{
                .current = progress.current,
                .total = progress.total,
                .show_label = true,
            });
            break :blk try hstack.buildWithWeights(allocator, &.{ label, bar }, 1, &.{ 2, 3 });
        },
    };

    return try hstack.buildWithWeights(allocator, &.{ title_node, detail_node }, options.gap, &.{ 1, 4 });
}
