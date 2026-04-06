const std = @import("std");
const style_mod = @import("../style/style.zig");
const rich_text = @import("../format/rich_text.zig");
const rich_document = @import("rich_document.zig");
const node_mod = @import("node.zig");

pub const Options = struct {
    start: usize = 1,
    count: usize,
    selected: ?usize = null,
    offset: usize = 0,
    viewport_height: usize = 0,
    follow_end: bool = false,
    style: style_mod.Style = .{ .fg = .{ .ansi = 8 } },
    selected_style: style_mod.Style = .{ .fg = .{ .ansi = 11 }, .bold = true },
};

pub fn renderLines(allocator: std.mem.Allocator, options: Options) ![]const rich_text.Line {
    var out = std.ArrayList(rich_text.Line).empty;
    defer out.deinit(allocator);

    const end = options.start + options.count;
    const width = std.fmt.count("{d}", .{end -| 1});

    var index: usize = 0;
    while (index < options.count) : (index += 1) {
        const line_no = options.start + index;
        const text = try std.fmt.allocPrint(allocator, "{d: >[1]}", .{ line_no, width });
        defer allocator.free(text);
        try out.append(allocator, try rich_text.plainLine(
            allocator,
            text,
            if (options.selected != null and options.selected.? == line_no) options.selected_style else options.style,
        ));
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
        .node = try rich_document.build(allocator, lines, resolved_offset, options.style),
        .lines = lines,
    };
}

test "renderLines pads line numbers" {
    const lines = try renderLines(std.testing.allocator, .{ .count = 12 });
    defer rich_text.freeLines(std.testing.allocator, lines);
    try std.testing.expectEqualStrings(" 1", lines[0].spans[0].text);
    try std.testing.expectEqualStrings("12", lines[11].spans[0].text);
}
