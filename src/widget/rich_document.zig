const std = @import("std");
const node_mod = @import("node.zig");
const rich_text = @import("../format/rich_text.zig");
const style_mod = @import("../style/style.zig");

pub fn build(
    allocator: std.mem.Allocator,
    lines: []const rich_text.Line,
    offset: usize,
    style: style_mod.Style,
) !*const node_mod.Node {
    const owned_lines = try cloneLines(allocator, lines);
    return try node_mod.allocNode(allocator, .{
        .rich_scroll = .{
            .lines = owned_lines,
            .offset = offset,
            .style = style,
        },
    });
}

pub fn deinitNode(allocator: std.mem.Allocator, node: *const node_mod.Node) void {
    if (node.* != .rich_scroll) return;
    rich_text.freeLines(allocator, node.rich_scroll.lines);
    allocator.destroy(@constCast(node));
}

fn cloneLines(
    allocator: std.mem.Allocator,
    lines: []const rich_text.Line,
) ![]const rich_text.Line {
    const out = try allocator.alloc(rich_text.Line, lines.len);
    for (lines, 0..) |line, line_index| {
        const spans = try allocator.alloc(rich_text.Span, line.spans.len);
        for (line.spans, 0..) |span, span_index| {
            spans[span_index] = .{
                .text = try allocator.dupe(u8, span.text),
                .style = span.style,
                .link_target = if (span.link_target) |target| try allocator.dupe(u8, target) else null,
            };
        }
        out[line_index] = .{ .spans = spans };
    }
    return out;
}

pub fn clampOffset(total_lines: usize, viewport_height: usize, offset: usize) usize {
    if (viewport_height == 0) return 0;
    return @min(offset, maxOffset(total_lines, viewport_height));
}

pub fn followOffset(total_lines: usize, viewport_height: usize) usize {
    return maxOffset(total_lines, viewport_height);
}

fn maxOffset(total_lines: usize, viewport_height: usize) usize {
    if (viewport_height == 0) return 0;
    return total_lines -| viewport_height;
}

test "followOffset moves to tail when content exceeds viewport" {
    try std.testing.expectEqual(@as(usize, 0), followOffset(3, 5));
    try std.testing.expectEqual(@as(usize, 4), followOffset(10, 6));
}
