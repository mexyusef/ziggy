const std = @import("std");
const style_mod = @import("../style/style.zig");

pub const Span = struct {
    text: []const u8,
    style: style_mod.Style = .{},
    link_target: ?[]const u8 = null,
};

pub const Line = struct {
    spans: []Span,
};

pub fn plainLine(allocator: std.mem.Allocator, text: []const u8, style: style_mod.Style) !Line {
    const spans = try allocator.alloc(Span, 1);
    spans[0] = .{
        .text = try allocator.dupe(u8, text),
        .style = style,
    };
    return .{ .spans = spans };
}

pub fn prefixedLine(
    allocator: std.mem.Allocator,
    prefix: []const u8,
    prefix_style: style_mod.Style,
    text: []const u8,
    text_style: style_mod.Style,
) !Line {
    const span_count: usize = if (text.len == 0) 1 else 2;
    const spans = try allocator.alloc(Span, span_count);
    spans[0] = .{
        .text = try allocator.dupe(u8, prefix),
        .style = prefix_style,
    };
    if (span_count == 2) {
        spans[1] = .{
            .text = try allocator.dupe(u8, text),
            .style = text_style,
        };
    }
    return .{ .spans = spans };
}

pub fn freeLine(allocator: std.mem.Allocator, line: Line) void {
    for (line.spans) |span| {
        allocator.free(span.text);
        if (span.link_target) |target| allocator.free(target);
    }
    allocator.free(line.spans);
}

pub fn freeLines(allocator: std.mem.Allocator, lines: []const Line) void {
    for (lines) |line| freeLine(allocator, line);
    allocator.free(lines);
}

pub fn lineTextLength(line: Line) usize {
    var total: usize = 0;
    for (line.spans) |span| total += span.text.len;
    return total;
}

test "prefixedLine builds two spans" {
    const line = try prefixedLine(std.testing.allocator, "> ", .{ .bold = true }, "hello", .{});
    defer freeLine(std.testing.allocator, line);

    try std.testing.expectEqual(@as(usize, 2), line.spans.len);
    try std.testing.expectEqualStrings("> ", line.spans[0].text);
    try std.testing.expectEqualStrings("hello", line.spans[1].text);
}
