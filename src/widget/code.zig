const std = @import("std");
const rich_text = @import("../format/rich_text.zig");
const style_mod = @import("../style/style.zig");
const rich_document = @import("rich_document.zig");
const node_mod = @import("node.zig");

pub const Theme = struct {
    line_number: style_mod.Style = .{ .fg = .{ .ansi = 8 } },
    language: style_mod.Style = .{ .fg = .{ .ansi = 14 }, .bold = true },
    code: style_mod.Style = .{ .fg = .{ .ansi = 15 }, .bg = .{ .ansi = 8 } },
};

pub const Options = struct {
    code: []const u8,
    language: ?[]const u8 = null,
    offset: usize = 0,
    viewport_height: usize = 0,
    follow_end: bool = false,
    theme: Theme = .{},
};

pub fn renderLines(allocator: std.mem.Allocator, options: Options) ![]const rich_text.Line {
    var out = std.ArrayList(rich_text.Line).empty;
    defer out.deinit(allocator);

    if (options.language) |language| {
        const header = try std.fmt.allocPrint(allocator, "code [{s}]", .{language});
        defer allocator.free(header);
        try out.append(allocator, try rich_text.plainLine(allocator, header, options.theme.language));
        try out.append(allocator, try rich_text.plainLine(allocator, "", options.theme.code));
    }

    var counter = std.mem.splitScalar(u8, options.code, '\n');
    var count: usize = 0;
    while (counter.next()) |_| count += 1;
    const width = std.fmt.count("{d}", .{@max(count, 1)});

    var lines = std.mem.splitScalar(u8, options.code, '\n');
    var line_no: usize = 1;
    while (lines.next()) |line| : (line_no += 1) {
        const num = try std.fmt.allocPrint(allocator, "{d: >[1]} ", .{ line_no, width });
        defer allocator.free(num);
        const spans = try allocator.alloc(rich_text.Span, 2);
        spans[0] = .{ .text = try allocator.dupe(u8, num), .style = options.theme.line_number };
        spans[1] = .{ .text = try allocator.dupe(u8, line), .style = options.theme.code };
        try out.append(allocator, .{ .spans = spans });
    }

    if (count == 0) {
        try out.append(allocator, try rich_text.plainLine(allocator, "1 ", options.theme.line_number));
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
        .node = try rich_document.build(allocator, lines, resolved_offset, options.theme.code),
        .lines = lines,
    };
}

test "renderLines includes language header and numbers" {
    const lines = try renderLines(std.testing.allocator, .{
        .code = "const x = 1;\nreturn x;",
        .language = "zig",
    });
    defer rich_text.freeLines(std.testing.allocator, lines);
    try std.testing.expectEqualStrings("code [zig]", lines[0].spans[0].text);
    try std.testing.expectEqualStrings("1 ", lines[2].spans[0].text);
}
