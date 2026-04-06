const std = @import("std");

pub const Field = struct {
    key: []const u8,
    value: []const u8,
};

pub const Section = struct {
    title: []const u8,
    body: []const u8,
};

pub fn previewText(text: []const u8, limit: usize) []const u8 {
    const trimmed = std.mem.trim(u8, text, " \r\t\n");
    if (trimmed.len == 0) return "<empty>";
    const line = std.mem.sliceTo(trimmed, '\n');
    return line[0..@min(line.len, limit)];
}

pub fn buildFieldsBody(allocator: std.mem.Allocator, fields: []const Field) ![]u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    for (fields, 0..) |field, index| {
        try out.writer.print("{s}: {s}", .{ field.key, field.value });
        if (index + 1 < fields.len) try out.writer.writeByte('\n');
    }
    const body = try allocator.dupe(u8, out.written());
    out.deinit();
    return body;
}

pub fn buildSectionsBody(allocator: std.mem.Allocator, sections: []const Section) ![]u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    for (sections, 0..) |section, index| {
        try out.writer.print("{s}:\n{s}", .{ section.title, section.body });
        if (index + 1 < sections.len) try out.writer.writeAll("\n\n");
    }
    const body = try allocator.dupe(u8, out.written());
    out.deinit();
    return body;
}

test "preview text trims and truncates" {
    try std.testing.expectEqualStrings("hello", previewText("  hello\nworld", 12));
}

test "field and section body builders format blocks" {
    const fields = [_]Field{
        .{ .key = "provider", .value = "gemini" },
        .{ .key = "model", .value = "gemini-2.5-flash" },
    };
    const fields_body = try buildFieldsBody(std.testing.allocator, &fields);
    defer std.testing.allocator.free(fields_body);
    try std.testing.expect(std.mem.indexOf(u8, fields_body, "provider: gemini") != null);

    const sections = [_]Section{
        .{ .title = "summary", .body = "hello" },
        .{ .title = "keys", .body = "y/n" },
    };
    const sections_body = try buildSectionsBody(std.testing.allocator, &sections);
    defer std.testing.allocator.free(sections_body);
    try std.testing.expect(std.mem.indexOf(u8, sections_body, "summary:\nhello") != null);
    try std.testing.expect(std.mem.indexOf(u8, sections_body, "keys:\ny/n") != null);
}
