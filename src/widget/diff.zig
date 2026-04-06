const std = @import("std");
const rich_text = @import("../format/rich_text.zig");
const style_mod = @import("../style/style.zig");
const rich_document = @import("rich_document.zig");
const node_mod = @import("node.zig");

pub const Theme = struct {
    context: style_mod.Style = .{ .fg = .{ .ansi = 7 } },
    add: style_mod.Style = .{ .fg = .{ .ansi = 10 }, .bold = true },
    remove: style_mod.Style = .{ .fg = .{ .ansi = 9 }, .bold = true },
    header: style_mod.Style = .{ .fg = .{ .ansi = 14 }, .bold = true },
};

pub const Options = struct {
    diff: []const u8,
    offset: usize = 0,
    viewport_height: usize = 0,
    follow_end: bool = false,
    theme: Theme = .{},
};

pub fn renderLines(allocator: std.mem.Allocator, options: Options) ![]const rich_text.Line {
    var out = std.ArrayList(rich_text.Line).empty;
    defer out.deinit(allocator);

    var parts = std.mem.splitScalar(u8, options.diff, '\n');
    while (parts.next()) |part| {
        const style = if (std.mem.startsWith(u8, part, "@@"))
            options.theme.header
        else if (std.mem.startsWith(u8, part, "+"))
            options.theme.add
        else if (std.mem.startsWith(u8, part, "-"))
            options.theme.remove
        else
            options.theme.context;
        try out.append(allocator, try rich_text.plainLine(allocator, part, style));
    }

    if (out.items.len == 0) {
        try out.append(allocator, try rich_text.plainLine(allocator, "", options.theme.context));
    }

    return try out.toOwnedSlice(allocator);
}

pub fn build(allocator: std.mem.Allocator, options: Options) !struct {
    node: *const node_mod.Node,
    lines: []const rich_text.Line,
} {
    const lines = try renderLines(allocator, options);
    const resolved_offset = if (options.follow_end)
        rich_document.followOffset(lines.len, options.viewport_height)
    else
        rich_document.clampOffset(lines.len, options.viewport_height, options.offset);
    return .{
        .node = try rich_document.build(allocator, lines, resolved_offset, options.theme.context),
        .lines = lines,
    };
}

test "renderLines styles diff hunks" {
    const lines = try renderLines(std.testing.allocator, .{ .diff = "@@ x @@\n-old\n+new" });
    defer rich_text.freeLines(std.testing.allocator, lines);
    try std.testing.expect(lines[0].spans[0].style.bold);
    try std.testing.expect(lines[1].spans[0].style.bold);
    try std.testing.expect(lines[2].spans[0].style.bold);
}
