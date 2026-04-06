const std = @import("std");
const wrap = @import("wrap.zig");
const rich_text = @import("rich_text.zig");
const style_mod = @import("../style/style.zig");

pub const Theme = struct {
    base: style_mod.Style = .{},
    heading: style_mod.Style = .{ .fg = .{ .ansi = 14 }, .bold = true },
    bullet: style_mod.Style = .{ .fg = .{ .ansi = 11 }, .bold = true },
    quote: style_mod.Style = .{ .fg = .{ .ansi = 6 }, .dim = true },
    code: style_mod.Style = .{ .fg = .{ .ansi = 10 }, .bg = .{ .ansi = 8 } },
    strong: style_mod.Style = .{ .bold = true },
    emphasis: style_mod.Style = .{ .underline = true },
    link: style_mod.Style = .{ .fg = .{ .ansi = 12 }, .underline = true },
    muted: style_mod.Style = .{ .fg = .{ .ansi = 8 }, .dim = true },
    accent: style_mod.Style = .{ .fg = .{ .ansi = 12 }, .bold = true },
    code_lineno: style_mod.Style = .{ .fg = .{ .ansi = 8 }, .dim = true },
};

pub fn renderLines(
    allocator: std.mem.Allocator,
    markdown: []const u8,
    width: usize,
    theme: Theme,
) ![]const rich_text.Line {
    var out = std.ArrayList(rich_text.Line).empty;
    defer out.deinit(allocator);

    var lines = std.mem.splitScalar(u8, markdown, '\n');
    var paragraph = std.ArrayList(u8).empty;
    defer paragraph.deinit(allocator);
    var in_code = false;
    var code_lang: []const u8 = "";
    var code_line_no: usize = 1;

    while (lines.next()) |raw_line| {
        const line = std.mem.trimRight(u8, raw_line, "\r");
        const trimmed = std.mem.trim(u8, line, " \t");

        if (std.mem.startsWith(u8, trimmed, "```")) {
            try flushParagraph(allocator, &out, &paragraph, width, theme);
            if (!in_code) {
                in_code = true;
                code_lang = std.mem.trim(u8, trimmed[3..], " \t");
                code_line_no = 1;
                try appendRuleLine(allocator, &out, width, "-", theme.muted);
                if (code_lang.len > 0) {
                    const header = try std.fmt.allocPrint(allocator, " code: {s} ", .{code_lang});
                    defer allocator.free(header);
                    try out.append(allocator, try rich_text.plainLine(allocator, header, theme.accent));
                }
            } else {
                in_code = false;
                code_lang = "";
                try appendRuleLine(allocator, &out, width, "-", theme.muted);
            }
            continue;
        }

        if (in_code) {
            const prefix = try std.fmt.allocPrint(allocator, "{d: >2}| ", .{code_line_no});
            defer allocator.free(prefix);
            const wrapped = try wrap.wrapParagraphLines(allocator, line, width, prefix, "   | ");
            defer wrap.freeLines(allocator, wrapped);
            try appendWrappedWithPrefix(allocator, &out, wrapped, prefix, "   | ", theme.code_lineno, theme.code, theme);
            code_line_no += 1;
            continue;
        }

        if (trimmed.len == 0) {
            try flushParagraph(allocator, &out, &paragraph, width, theme);
            try out.append(allocator, try rich_text.plainLine(allocator, "", theme.base));
            continue;
        }

        if (isHorizontalRule(trimmed)) {
            try flushParagraph(allocator, &out, &paragraph, width, theme);
            try appendRuleLine(allocator, &out, width, "-", theme.muted);
            continue;
        }

        if (headingLevel(trimmed)) |level| {
            try flushParagraph(allocator, &out, &paragraph, width, theme);
            const content = std.mem.trimLeft(u8, trimmed[level + 1 ..], " \t");
            const prefix = switch (level) {
                1 => "# ",
                2 => "## ",
                3 => "### ",
                else => "#### ",
            };
            const wrapped = try wrap.wrapParagraphLines(allocator, content, width, prefix, "   ");
            defer wrap.freeLines(allocator, wrapped);
            try appendWrappedWithPrefix(allocator, &out, wrapped, prefix, "   ", theme.heading, theme.heading, theme);
            continue;
        }

        if (bulletPrefix(trimmed)) |prefix_len| {
            try flushParagraph(allocator, &out, &paragraph, width, theme);
            const marker = trimmed[0..prefix_len];
            const content = std.mem.trimLeft(u8, trimmed[prefix_len..], " \t");
            const rest_prefix = try allocator.alloc(u8, marker.len);
            defer allocator.free(rest_prefix);
            @memset(rest_prefix, ' ');
            const wrapped = try wrap.wrapParagraphLines(allocator, content, width, marker, rest_prefix);
            defer wrap.freeLines(allocator, wrapped);
            try appendWrappedWithPrefix(allocator, &out, wrapped, marker, rest_prefix, theme.bullet, theme.base, theme);
            continue;
        }

        if (std.mem.startsWith(u8, trimmed, ">")) {
            try flushParagraph(allocator, &out, &paragraph, width, theme);
            const content = std.mem.trimLeft(u8, trimmed[1..], " \t");
            const wrapped = try wrap.wrapParagraphLines(allocator, content, width, "> ", "> ");
            defer wrap.freeLines(allocator, wrapped);
            try appendWrappedWithPrefix(allocator, &out, wrapped, "> ", "> ", theme.quote, theme.quote, theme);
            continue;
        }

        if (paragraph.items.len > 0) try paragraph.append(allocator, ' ');
        try paragraph.appendSlice(allocator, trimmed);
    }

    try flushParagraph(allocator, &out, &paragraph, width, theme);
    if (out.items.len == 0) try out.append(allocator, try rich_text.plainLine(allocator, "", theme.base));
    return try out.toOwnedSlice(allocator);
}

fn appendWrappedWithPrefix(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(rich_text.Line),
    wrapped: []const []const u8,
    first_prefix: []const u8,
    rest_prefix: []const u8,
    prefix_style: style_mod.Style,
    text_style: style_mod.Style,
    theme: Theme,
) !void {
    for (wrapped, 0..) |line, index| {
        const prefix = if (index == 0) first_prefix else rest_prefix;
        const text = if (std.mem.startsWith(u8, line, prefix)) line[prefix.len..] else line;
        try out.append(allocator, try styledInlineLine(allocator, prefix, prefix_style, text, text_style, theme));
    }
}

fn flushParagraph(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(rich_text.Line),
    paragraph: *std.ArrayList(u8),
    width: usize,
    theme: Theme,
) !void {
    const trimmed = std.mem.trim(u8, paragraph.items, " \t");
    if (trimmed.len == 0) {
        try paragraph.resize(allocator, 0);
        return;
    }

    const wrapped = try wrap.wrapPlainLines(allocator, trimmed, width);
    defer wrap.freeLines(allocator, wrapped);
    for (wrapped) |line| {
        try out.append(allocator, try styledInlineLine(allocator, "", theme.base, line, theme.base, theme));
    }
    try paragraph.resize(allocator, 0);
}

fn styledInlineLine(
    allocator: std.mem.Allocator,
    prefix: []const u8,
    prefix_style: style_mod.Style,
    text: []const u8,
    text_style: style_mod.Style,
    theme: Theme,
) !rich_text.Line {
    var spans = std.ArrayList(rich_text.Span).empty;
    defer spans.deinit(allocator);

    try spans.append(allocator, .{
        .text = try allocator.dupe(u8, prefix),
        .style = prefix_style,
    });

    try appendInlineStyledText(allocator, &spans, text, text_style, theme);
    return .{ .spans = try spans.toOwnedSlice(allocator) };
}

fn appendInlineStyledText(
    allocator: std.mem.Allocator,
    spans: *std.ArrayList(rich_text.Span),
    text: []const u8,
    base_style: style_mod.Style,
    theme: Theme,
) !void {
    if (looksLikeBareUrl(text)) {
        try spans.append(allocator, .{
            .text = try allocator.dupe(u8, text),
            .style = theme.link,
            .link_target = try allocator.dupe(u8, text),
        });
        return;
    }

    var index: usize = 0;
    var segment_start: usize = 0;
    var mode: enum { normal, code, strong, emphasis, link_label, link_url } = .normal;
    var link_label_start: usize = 0;
    var pending_link_label: ?[]u8 = null;
    defer if (pending_link_label) |label| allocator.free(label);

    while (index < text.len) {
        if (mode == .normal and index + 1 < text.len and text[index] == '*' and text[index + 1] == '*') {
            if (index > segment_start) try spans.append(allocator, .{ .text = try allocator.dupe(u8, text[segment_start..index]), .style = base_style });
            mode = .strong;
            index += 2;
            segment_start = index;
            continue;
        }
        if (mode == .strong and index + 1 < text.len and text[index] == '*' and text[index + 1] == '*') {
            try spans.append(allocator, .{ .text = try allocator.dupe(u8, text[segment_start..index]), .style = mergeStyles(base_style, theme.strong) });
            mode = .normal;
            index += 2;
            segment_start = index;
            continue;
        }
        if (mode == .normal and text[index] == '`') {
            if (index > segment_start) try spans.append(allocator, .{ .text = try allocator.dupe(u8, text[segment_start..index]), .style = base_style });
            mode = .code;
            index += 1;
            segment_start = index;
            continue;
        }
        if (mode == .code and text[index] == '`') {
            try spans.append(allocator, .{ .text = try allocator.dupe(u8, text[segment_start..index]), .style = theme.code });
            mode = .normal;
            index += 1;
            segment_start = index;
            continue;
        }
        if (mode == .normal and text[index] == '_') {
            if (index > segment_start) try spans.append(allocator, .{ .text = try allocator.dupe(u8, text[segment_start..index]), .style = base_style });
            mode = .emphasis;
            index += 1;
            segment_start = index;
            continue;
        }
        if (mode == .emphasis and text[index] == '_') {
            try spans.append(allocator, .{ .text = try allocator.dupe(u8, text[segment_start..index]), .style = mergeStyles(base_style, theme.emphasis) });
            mode = .normal;
            index += 1;
            segment_start = index;
            continue;
        }
        if (mode == .normal and text[index] == '[') {
            if (index > segment_start) try spans.append(allocator, .{ .text = try allocator.dupe(u8, text[segment_start..index]), .style = base_style });
            mode = .link_label;
            link_label_start = index + 1;
            index += 1;
            segment_start = index;
            continue;
        }
        if (mode == .link_label and text[index] == ']') {
            pending_link_label = try allocator.dupe(u8, text[link_label_start..index]);
            mode = .link_url;
            index += 1;
            segment_start = index;
            continue;
        }
        if (mode == .link_url and text[index] == '(') {
            index += 1;
            segment_start = index;
            continue;
        }
        if (mode == .link_url and text[index] == ')') {
            if (pending_link_label) |label| {
                const url = text[segment_start..index];
                const link_text = try std.fmt.allocPrint(allocator, "{s} ({s})", .{ label, url });
                defer allocator.free(link_text);
                try spans.append(allocator, .{
                    .text = try allocator.dupe(u8, link_text),
                    .style = theme.link,
                    .link_target = try allocator.dupe(u8, url),
                });
                allocator.free(label);
                pending_link_label = null;
            }
            mode = .normal;
            index += 1;
            segment_start = index;
            continue;
        }
        index += 1;
    }

    if (segment_start < text.len or text.len == 0) {
        const style = switch (mode) {
            .code => theme.code,
            .strong => mergeStyles(base_style, theme.strong),
            .emphasis => mergeStyles(base_style, theme.emphasis),
            else => base_style,
        };
        try spans.append(allocator, .{ .text = try allocator.dupe(u8, text[segment_start..]), .style = style });
    }
}

fn looksLikeBareUrl(text: []const u8) bool {
    return std.mem.startsWith(u8, text, "http://") or std.mem.startsWith(u8, text, "https://");
}

fn mergeStyles(base: style_mod.Style, overlay: style_mod.Style) style_mod.Style {
    return .{
        .fg = if (style_mod.Style.eql(.{ .fg = overlay.fg }, .{})) base.fg else overlay.fg,
        .bg = if (style_mod.Style.eql(.{ .bg = overlay.bg }, .{})) base.bg else overlay.bg,
        .bold = base.bold or overlay.bold,
        .dim = base.dim or overlay.dim,
        .underline = base.underline or overlay.underline,
    };
}

fn isHorizontalRule(line: []const u8) bool {
    if (line.len < 3) return false;
    const first = line[0];
    if (first != '-' and first != '*' and first != '_') return false;
    for (line) |byte| {
        if (byte != first) return false;
    }
    return true;
}

fn repeatedRule(allocator: std.mem.Allocator, width: usize, glyph: []const u8) ![]u8 {
    const repeat_count = @max(@min(width, 60), 8);
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);
    var index: usize = 0;
    while (index < repeat_count) : (index += 1) {
        try out.appendSlice(allocator, glyph);
    }
    return try out.toOwnedSlice(allocator);
}

fn appendRuleLine(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(rich_text.Line),
    width: usize,
    glyph: []const u8,
    style: style_mod.Style,
) !void {
    const rule = try repeatedRule(allocator, width, glyph);
    defer allocator.free(rule);
    try out.append(allocator, try rich_text.plainLine(allocator, rule, style));
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

test "renderLines returns styled heading and bullet lines" {
    const lines = try renderLines(std.testing.allocator, "# Title\n\n- one\nplain `code` text", 24, .{});
    defer rich_text.freeLines(std.testing.allocator, lines);

    try std.testing.expect(lines.len >= 3);
    try std.testing.expectEqualStrings("# ", lines[0].spans[0].text);
    try std.testing.expect(lines[0].spans[0].style.bold);
    try std.testing.expectEqualStrings("- ", lines[2].spans[0].text);
}

test "renderLines preserves numbered markers and code fences" {
    const markdown =
        \\1. first
        \\2. second
        \\
        \\```zig
        \\const x = 1;
        \\```
    ;
    const lines = try renderLines(std.testing.allocator, markdown, 32, .{});
    defer rich_text.freeLines(std.testing.allocator, lines);

    try std.testing.expectEqualStrings("1. ", lines[0].spans[0].text);
    try std.testing.expect(lines.len >= 6);
}

test "renderLines styles links and strong text" {
    const lines = try renderLines(std.testing.allocator, "a **bold** [site](https://x)", 40, .{});
    defer rich_text.freeLines(std.testing.allocator, lines);
    try std.testing.expect(lines[0].spans.len >= 3);
}

test "renderLines styles bare links" {
    const lines = try renderLines(std.testing.allocator, "https://example.com", 40, .{});
    defer rich_text.freeLines(std.testing.allocator, lines);
    try std.testing.expect(lines[0].spans.len >= 1);
    var found = false;
    for (lines[0].spans) |span| {
        if (span.style.underline) {
            found = true;
            break;
        }
    }
    try std.testing.expect(found);
}
