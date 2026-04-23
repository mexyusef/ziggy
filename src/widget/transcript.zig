const std = @import("std");
const rich_markdown = @import("../format/rich_markdown.zig");
const rich_text = @import("../format/rich_text.zig");
const rich_document = @import("rich_document.zig");
const style_mod = @import("../style/style.zig");
const node_mod = @import("node.zig");
const surface_mod = @import("surface.zig");

pub const Entry = struct {
    title: []const u8,
    body: []const u8,
    selected: bool = false,
    badge: ?[]const u8 = null,
    meta: ?[]const u8 = null,
    title_style: style_mod.Style = .{},
    selected_title_style: style_mod.Style = .{ .bold = true },
    badge_style: style_mod.Style = .{ .bold = true },
    meta_style: style_mod.Style = .{ .dim = true },
    separator_style: style_mod.Style = .{ .dim = true },
    body_theme: rich_markdown.Theme = .{},
};

pub const Rendered = struct {
    lines: []const rich_text.Line,
    selected_line: usize,
    entry_starts: []const usize,

    pub fn deinit(self: *Rendered, allocator: std.mem.Allocator) void {
        rich_text.freeLines(allocator, self.lines);
        allocator.free(self.entry_starts);
    }
};

pub fn renderLines(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    width: usize,
) !Rendered {
    var out = std.ArrayList(rich_text.Line).empty;
    defer out.deinit(allocator);
    var entry_starts = std.ArrayList(usize).empty;
    defer entry_starts.deinit(allocator);

    var selected_line: usize = 0;
    for (entries, 0..) |entry, index| {
        if (index > 0) {
            try out.append(allocator, try separatorLine(allocator, width, entry.separator_style));
            try out.append(allocator, try rich_text.plainLine(allocator, "", entry.body_theme.base));
        }
        try entry_starts.append(allocator, out.items.len);
        if (entry.selected) selected_line = out.items.len;

        const header_prefix = if (entry.selected) "> " else "  ";
        const header_style = if (entry.selected) entry.selected_title_style else entry.title_style;
        try out.append(allocator, try headerLine(allocator, header_prefix, header_style, entry));

        const body_lines = try rich_markdown.renderLines(allocator, entry.body, @max(width -| 2, 10), entry.body_theme);
        defer rich_text.freeLines(allocator, body_lines);
        for (body_lines) |line| {
            try out.append(allocator, try indentLine(allocator, line, "  ", entry.body_theme.base));
        }
    }

    if (out.items.len == 0) try out.append(allocator, try rich_text.plainLine(allocator, "No entries.", .{}));
    return .{
        .lines = try out.toOwnedSlice(allocator),
        .selected_line = selected_line,
        .entry_starts = try entry_starts.toOwnedSlice(allocator),
    };
}

pub fn build(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    offset: usize,
    width: usize,
    default_style: style_mod.Style,
) !*const node_mod.Node {
    const rendered = try renderLines(allocator, entries, width);
    return try rich_document.build(allocator, rendered.lines, offset, default_style);
}

pub fn followOffset(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    width: usize,
    viewport_height: usize,
) !usize {
    const rendered = try renderLines(allocator, entries, width);
    defer {
        var owned = rendered;
        owned.deinit(allocator);
    }
    return rich_document.followOffset(rendered.lines.len, viewport_height);
}

pub fn entryIndexAtLine(entry_starts: []const usize, line_index: usize) usize {
    var selected: usize = 0;
    for (entry_starts, 0..) |start, index| {
        if (start <= line_index) selected = index else break;
    }
    return selected;
}

pub fn hitTestEntry(
    rect: surface_mod.Rect,
    entry_starts: []const usize,
    offset: usize,
    x: u16,
    y: u16,
) ?usize {
    const local = rect.localPoint(x, y) orelse return null;
    const line_index = offset + @as(usize, local.y);
    return entryIndexAtLine(entry_starts, line_index);
}

fn indentLine(
    allocator: std.mem.Allocator,
    line: rich_text.Line,
    indent: []const u8,
    indent_style: style_mod.Style,
) !rich_text.Line {
    const spans = try allocator.alloc(rich_text.Span, line.spans.len + 1);
    spans[0] = .{
        .text = try allocator.dupe(u8, indent),
        .style = indent_style,
    };
    for (line.spans, 0..) |span, index| {
        spans[index + 1] = .{
            .text = try allocator.dupe(u8, span.text),
            .style = span.style,
        };
    }
    return .{ .spans = spans };
}

fn headerLine(
    allocator: std.mem.Allocator,
    prefix: []const u8,
    header_style: style_mod.Style,
    entry: Entry,
) !rich_text.Line {
    var span_count: usize = 2;
    if (entry.badge != null) span_count += 1;
    if (entry.meta != null) span_count += 1;

    const spans = try allocator.alloc(rich_text.Span, span_count);
    spans[0] = .{
        .text = try allocator.dupe(u8, prefix),
        .style = header_style,
    };

    var index: usize = 1;
    if (entry.badge) |badge| {
        const badge_text = try std.fmt.allocPrint(allocator, "[{s}] ", .{badge});
        spans[index] = .{
            .text = badge_text,
            .style = entry.badge_style,
        };
        index += 1;
    }

    spans[index] = .{
        .text = try allocator.dupe(u8, entry.title),
        .style = header_style,
    };
    index += 1;

    if (entry.meta) |meta| {
        const meta_text = try std.fmt.allocPrint(allocator, "  {s}", .{meta});
        spans[index] = .{
            .text = meta_text,
            .style = entry.meta_style,
        };
    }

    return .{ .spans = spans };
}

fn separatorLine(
    allocator: std.mem.Allocator,
    width: usize,
    style: style_mod.Style,
) !rich_text.Line {
    const separator_width = @max(@min(width, 48), 12);
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);
    var index: usize = 0;
    while (index < separator_width) : (index += 1) {
        try buf.appendSlice(allocator, "─");
    }
    const text = try buf.toOwnedSlice(allocator);
    defer allocator.free(text);
    return try rich_text.plainLine(allocator, text, style);
}

test "renderLines marks selected entry" {
    const entries = [_]Entry{
        .{ .title = "[user] hi", .body = "hello" },
        .{ .title = "[assistant] reply", .body = "# heading", .selected = true, .badge = "ASSIST", .meta = "msg 2" },
    };
    const rendered = try renderLines(std.testing.allocator, &entries, 40);
    defer {
        var owned = rendered;
        owned.deinit(std.testing.allocator);
    }
    try std.testing.expect(rendered.lines.len >= 5);
    try std.testing.expectEqual(@as(usize, 2), rendered.entry_starts.len);
    try std.testing.expectEqualStrings("> ", rendered.lines[rendered.selected_line].spans[0].text);
    try std.testing.expectEqualStrings("[ASSIST] ", rendered.lines[rendered.selected_line].spans[1].text);
    try std.testing.expectEqual(@as(usize, 1), entryIndexAtLine(rendered.entry_starts, rendered.selected_line));
    const rect: surface_mod.Rect = .{ .x = 0, .y = 0, .width = 40, .height = 10 };
    try std.testing.expectEqual(@as(?usize, 1), hitTestEntry(rect, rendered.entry_starts, 0, 0, @intCast(rendered.selected_line)));
}
