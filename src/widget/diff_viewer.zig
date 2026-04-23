const std = @import("std");
const diff = @import("diff.zig");
const text = @import("text.zig");
const box = @import("box.zig");
const vstack = @import("vstack.zig");
const style_mod = @import("../style/style.zig");
const node_mod = @import("node.zig");

pub const Theme = struct {
    frame_style: style_mod.Style = .{},
    summary_style: style_mod.Style = .{ .dim = true },
    diff_theme: diff.Theme = .{},
};

pub const Options = struct {
    title: ?[]const u8 = "Diff",
    diff_text: []const u8,
    summary: ?[]const u8 = null,
    offset: usize = 0,
    viewport_height: usize = 0,
    follow_end: bool = false,
    theme: Theme = .{},
};

pub fn build(allocator: std.mem.Allocator, options: Options) !*const node_mod.Node {
    const stats = summarizeDiff(options.diff_text);
    const summary_text = if (options.summary) |provided|
        try allocator.dupe(u8, provided)
    else
        try std.fmt.allocPrint(allocator, "hunks {d}  +{d}  -{d}", .{ stats.hunks, stats.added, stats.removed });

    const summary_node = try text.buildWithOptions(allocator, summary_text, .{
        .style = options.theme.summary_style,
        .wrap = .none,
    });
    const diff_view = try diff.build(allocator, .{
        .diff = options.diff_text,
        .offset = options.offset,
        .viewport_height = options.viewport_height,
        .follow_end = options.follow_end,
        .theme = options.theme.diff_theme,
    });
    const stack = try vstack.build(allocator, &.{ summary_node, diff_view.node }, 1);
    return try box.buildWithOptions(allocator, options.title, stack, .{
        .style = options.theme.frame_style,
        .padding_top = 0,
        .padding_bottom = 0,
        .padding_left = 0,
        .padding_right = 0,
    });
}

pub const Stats = struct {
    hunks: usize = 0,
    added: usize = 0,
    removed: usize = 0,
};

pub fn summarizeDiff(diff_text: []const u8) Stats {
    var stats: Stats = .{};
    var lines = std.mem.splitScalar(u8, diff_text, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "@@")) {
            stats.hunks += 1;
        } else if (std.mem.startsWith(u8, line, "+") and !std.mem.startsWith(u8, line, "+++")) {
            stats.added += 1;
        } else if (std.mem.startsWith(u8, line, "-") and !std.mem.startsWith(u8, line, "---")) {
            stats.removed += 1;
        }
    }
    return stats;
}

test "diff viewer summarizes diff stats" {
    const stats = summarizeDiff("@@ x @@\n-old\n+new\n+next");
    try std.testing.expectEqual(@as(usize, 1), stats.hunks);
    try std.testing.expectEqual(@as(usize, 2), stats.added);
    try std.testing.expectEqual(@as(usize, 1), stats.removed);
}
