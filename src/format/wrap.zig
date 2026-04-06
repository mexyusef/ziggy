const std = @import("std");

pub fn wrapParagraphLines(
    allocator: std.mem.Allocator,
    text: []const u8,
    width: usize,
    first_prefix: []const u8,
    rest_prefix: []const u8,
) ![]const []const u8 {
    var out = std.ArrayList([]const u8).empty;
    defer out.deinit(allocator);

    const usable_width = @max(width, first_prefix.len + 1);
    var line = std.ArrayList(u8).empty;
    defer line.deinit(allocator);

    try line.appendSlice(allocator, first_prefix);
    var current_len: usize = first_prefix.len;
    var use_rest_prefix = false;

    var words = std.mem.tokenizeAny(u8, text, " \t\r\n");
    while (words.next()) |word| {
        const prefix = if (use_rest_prefix) rest_prefix else first_prefix;
        const prefix_len = if (use_rest_prefix) rest_prefix.len else first_prefix.len;

        if (current_len == prefix_len) {
            if (prefix_len > line.items.len) {
                try line.resize(allocator, 0);
                try line.appendSlice(allocator, prefix);
            }
            const take = @min(word.len, usable_width -| prefix_len);
            try line.appendSlice(allocator, word[0..take]);
            current_len = prefix_len + take;
            use_rest_prefix = true;
            continue;
        }

        const needed = 1 + word.len;
        if (current_len + needed <= usable_width) {
            try line.append(allocator, ' ');
            try line.appendSlice(allocator, word);
            current_len += needed;
            continue;
        }

        try out.append(allocator, try allocator.dupe(u8, line.items));
        try line.resize(allocator, 0);
        try line.appendSlice(allocator, rest_prefix);
        const take = @min(word.len, usable_width -| rest_prefix.len);
        try line.appendSlice(allocator, word[0..take]);
        current_len = rest_prefix.len + take;
        use_rest_prefix = true;
    }

    if (line.items.len > 0) {
        try out.append(allocator, try allocator.dupe(u8, line.items));
    }

    if (out.items.len == 0) {
        try out.append(allocator, try allocator.dupe(u8, first_prefix));
    }

    return try out.toOwnedSlice(allocator);
}

pub fn wrapPlainLines(allocator: std.mem.Allocator, text: []const u8, width: usize) ![]const []const u8 {
    return wrapParagraphLines(allocator, text, width, "", "");
}

pub fn freeLines(allocator: std.mem.Allocator, lines: []const []const u8) void {
    for (lines) |line| allocator.free(line);
    allocator.free(lines);
}

test "wrapParagraphLines wraps with prefixes" {
    const lines = try wrapParagraphLines(std.testing.allocator, "alpha beta gamma delta", 10, "- ", "  ");
    defer freeLines(std.testing.allocator, lines);

    try std.testing.expectEqual(@as(usize, 4), lines.len);
    try std.testing.expectEqualStrings("- alpha", lines[0]);
    try std.testing.expectEqualStrings("  beta", lines[1]);
    try std.testing.expectEqualStrings("  gamma", lines[2]);
    try std.testing.expectEqualStrings("  delta", lines[3]);
}
