const std = @import("std");

pub fn uppercase(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    var out = try allocator.alloc(u8, text.len);
    for (text, 0..) |byte, index| out[index] = std.ascii.toUpper(byte);
    return out;
}

pub fn lowercase(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    var out = try allocator.alloc(u8, text.len);
    for (text, 0..) |byte, index| out[index] = std.ascii.toLower(byte);
    return out;
}

pub fn hangingIndent(allocator: std.mem.Allocator, text: []const u8, indent: u16) ![]u8 {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);

    const prefix = try allocator.alloc(u8, indent);
    defer allocator.free(prefix);
    @memset(prefix, ' ');

    var parts = std.mem.splitScalar(u8, text, '\n');
    var first = true;
    while (parts.next()) |line| {
        if (!first) {
            try out.appendSlice(allocator, "\n");
            try out.appendSlice(allocator, prefix);
        }
        try out.appendSlice(allocator, line);
        first = false;
    }

    return try out.toOwnedSlice(allocator);
}

test "hangingIndent indents all but first line" {
    const text = try hangingIndent(std.testing.allocator, "a\nb\nc", 2);
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings("a\n  b\n  c", text);
}
