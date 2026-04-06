const std = @import("std");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const surface_mod = @import("surface.zig");

pub const Options = struct {
    axis: node_mod.Node.ScrollbarAxis = .vertical,
    offset: usize = 0,
    viewport: usize = 0,
    total: usize = 0,
    style: style_mod.Style = .{},
    thumb_style: style_mod.Style = .{ .bold = true },
    track_glyph: []const u8 = "│",
    thumb_glyph: []const u8 = "█",
};

pub fn build(allocator: std.mem.Allocator, options: Options) !*const node_mod.Node {
    return try node_mod.allocNode(allocator, .{
        .scrollbar = .{
            .axis = options.axis,
            .offset = options.offset,
            .viewport = options.viewport,
            .total = options.total,
            .style = options.style,
            .thumb_style = options.thumb_style,
            .track_glyph = options.track_glyph,
            .thumb_glyph = options.thumb_glyph,
        },
    });
}

pub const VerticalHit = enum {
    page_up,
    page_down,
};

pub fn hitTestVerticalTrack(
    rect: surface_mod.Rect,
    offset: usize,
    viewport: usize,
    total: usize,
    x: u16,
    y: u16,
) ?VerticalHit {
    if (!rect.contains(x, y) or rect.width == 0 or rect.height == 0) return null;
    if (total <= viewport or viewport == 0) return null;

    const local = rect.localPoint(x, y) orelse return null;
    const track_len = @as(usize, rect.height);
    const thumb_len = @max((viewport * track_len) / total, 1);
    const max_offset = total - viewport;
    const thumb_start = if (max_offset == 0)
        0
    else
        (@min(offset, max_offset) * (track_len - thumb_len)) / max_offset;
    const row = @as(usize, local.y);

    if (row < thumb_start) return .page_up;
    if (row >= thumb_start + thumb_len) return .page_down;
    return null;
}

test "hitTestVerticalTrack maps clicks outside thumb to paging" {
    const rect: surface_mod.Rect = .{ .x = 10, .y = 5, .width = 1, .height = 10 };
    try std.testing.expectEqual(@as(?VerticalHit, .page_up), hitTestVerticalTrack(rect, 4, 4, 20, 10, 5));
    try std.testing.expectEqual(@as(?VerticalHit, .page_down), hitTestVerticalTrack(rect, 4, 4, 20, 10, 14));
}
