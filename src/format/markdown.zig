const std = @import("std");
const wrap = @import("wrap.zig");

pub fn renderLines(allocator: std.mem.Allocator, markdown: []const u8, width: usize) ![]const []const u8 {
    var out = std.ArrayList([]const u8).empty;
    defer out.deinit(allocator);

    var lines = std.mem.splitScalar(u8, markdown, '\n');
    var paragraph = std.ArrayList(u8).empty;
    defer paragraph.deinit(allocator);
    var in_code = false;

    while (lines.next()) |raw_line| {
        const line = std.mem.trimRight(u8, raw_line, "\r");
        const trimmed = std.mem.trim(u8, line, " \t");

        if (std.mem.startsWith(u8, trimmed, "```")) {
            try flushParagraph(allocator, &out, &paragraph, width);
            in_code = !in_code;
            try out.append(allocator, try allocator.dupe(u8, if (in_code) "```" else "```"));
            continue;
        }

        if (in_code) {
            const wrapped = try wrap.wrapParagraphLines(allocator, line, width, "  ", "  ");
            defer wrap.freeLines(allocator, wrapped);
            try appendLines(allocator, &out, wrapped);
            continue;
        }

        if (trimmed.len == 0) {
            try flushParagraph(allocator, &out, &paragraph, width);
            try out.append(allocator, try allocator.dupe(u8, ""));
            continue;
        }

        if (headingLevel(trimmed)) |level| {
            try flushParagraph(allocator, &out, &paragraph, width);
            const content = std.mem.trimLeft(u8, trimmed[level + 1 ..], " \t");
            const prefix = switch (level) {
                1 => "# ",
                2 => "## ",
                3 => "### ",
                else => "#### ",
            };
            const wrapped = try wrap.wrapParagraphLines(allocator, content, width, prefix, "   ");
            defer wrap.freeLines(allocator, wrapped);
            try appendLines(allocator, &out, wrapped);
            continue;
        }

        if (bulletPrefix(trimmed)) |prefix_len| {
            try flushParagraph(allocator, &out, &paragraph, width);
            const content = std.mem.trimLeft(u8, trimmed[prefix_len..], " \t");
            const wrapped = try wrap.wrapParagraphLines(allocator, content, width, "* ", "  ");
            defer wrap.freeLines(allocator, wrapped);
            try appendLines(allocator, &out, wrapped);
            continue;
        }

        if (std.mem.startsWith(u8, trimmed, ">")) {
            try flushParagraph(allocator, &out, &paragraph, width);
            const content = std.mem.trimLeft(u8, trimmed[1..], " \t");
            const wrapped = try wrap.wrapParagraphLines(allocator, content, width, "> ", "> ");
            defer wrap.freeLines(allocator, wrapped);
            try appendLines(allocator, &out, wrapped);
            continue;
        }

        if (paragraph.items.len > 0) try paragraph.append(allocator, ' ');
        try paragraph.appendSlice(allocator, trimmed);
    }

    try flushParagraph(allocator, &out, &paragraph, width);

    if (out.items.len == 0) {
        try out.append(allocator, try allocator.dupe(u8, ""));
    }

    return try out.toOwnedSlice(allocator);
}

fn appendLines(allocator: std.mem.Allocator, out: *std.ArrayList([]const u8), lines: []const []const u8) !void {
    for (lines) |line| try out.append(allocator, try allocator.dupe(u8, line));
}

fn flushParagraph(
    allocator: std.mem.Allocator,
    out: *std.ArrayList([]const u8),
    paragraph: *std.ArrayList(u8),
    width: usize,
) !void {
    const trimmed = std.mem.trim(u8, paragraph.items, " \t");
    if (trimmed.len == 0) {
        try paragraph.resize(allocator, 0);
        return;
    }
    const wrapped = try wrap.wrapPlainLines(allocator, trimmed, width);
    defer wrap.freeLines(allocator, wrapped);
    try appendLines(allocator, out, wrapped);
    try paragraph.resize(allocator, 0);
}

fn headingLevel(line: []const u8) ?usize {
    var idx: usize = 0;
    while (idx < line.len and idx < 4 and line[idx] == '#') : (idx += 1) {}
    if (idx == 0 or idx >= line.len or line[idx] != ' ') return null;
    return idx;
}

fn bulletPrefix(line: []const u8) ?usize {
    if (line.len >= 2 and (line[0] == '-' or line[0] == '*' or line[0] == '+') and line[1] == ' ') return 2;

    var idx: usize = 0;
    while (idx < line.len and std.ascii.isDigit(line[idx])) : (idx += 1) {}
    if (idx > 0 and idx + 1 < line.len and line[idx] == '.' and line[idx + 1] == ' ') return idx + 2;
    return null;
}

test "renderLines formats basic markdown structures" {
    const lines = try renderLines(std.testing.allocator,
        "# Title\n\n- one\n- two\n\n> quote\n\nplain paragraph text here",
        20,
    );
    defer wrap.freeLines(std.testing.allocator, lines);

    try std.testing.expectEqualStrings("# Title", lines[0]);
    try std.testing.expectEqualStrings("* one", lines[2]);
    try std.testing.expectEqualStrings("> quote", lines[5]);
}
