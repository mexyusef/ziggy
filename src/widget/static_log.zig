const std = @import("std");
const rich_text = @import("../format/rich_text.zig");
const rich_document = @import("rich_document.zig");
const style_mod = @import("../style/style.zig");
const node_mod = @import("node.zig");

pub const Options = struct {
    offset: usize = 0,
    viewport_height: usize = 0,
    follow_end: bool = true,
    style: style_mod.Style = .{},
};

pub fn build(
    allocator: std.mem.Allocator,
    lines: []const rich_text.Line,
    options: Options,
) !*const node_mod.Node {
    const resolved_offset = if (options.follow_end)
        rich_document.followOffset(lines.len, options.viewport_height)
    else
        rich_document.clampOffset(lines.len, options.viewport_height, options.offset);
    return try rich_document.build(allocator, lines, resolved_offset, options.style);
}

pub fn buildFromText(
    allocator: std.mem.Allocator,
    text: []const u8,
    options: Options,
) !struct {
    node: *const node_mod.Node,
    lines: []const rich_text.Line,
} {
    var out = std.ArrayList(rich_text.Line).empty;
    defer out.deinit(allocator);

    var parts = std.mem.splitScalar(u8, text, '\n');
    while (parts.next()) |part| {
        try out.append(allocator, try rich_text.plainLine(allocator, part, options.style));
    }
    if (out.items.len == 0) {
        try out.append(allocator, try rich_text.plainLine(allocator, "", options.style));
    }

    const lines = try out.toOwnedSlice(allocator);
    return .{
        .node = try build(allocator, lines, options),
        .lines = lines,
    };
}

test "buildFromText follows end by default" {
    const built = try buildFromText(std.testing.allocator, "a\nb\nc\nd", .{ .viewport_height = 2 });
    defer rich_document.deinitNode(std.testing.allocator, built.node);
    defer rich_text.freeLines(std.testing.allocator, built.lines);
    try std.testing.expect(built.node.* == .rich_scroll);
    try std.testing.expectEqual(@as(usize, 2), built.node.rich_scroll.offset);
}
