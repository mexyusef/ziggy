const std = @import("std");
const box = @import("box.zig");
const text = @import("text.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");
const node_mod = @import("node.zig");

pub const Options = struct {
    title: ?[]const u8 = "Table",
    style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .single,
};

fn writeCell(writer: anytype, value: []const u8, width: usize) !void {
    try writer.writeAll(value);
    if (width > value.len) {
        for (0..width - value.len) |_| try writer.writeByte(' ');
    }
}

pub fn build(allocator: std.mem.Allocator, headers: []const []const u8, rows: []const []const []const u8, options: Options) !*const node_mod.Node {
    var widths = try allocator.alloc(usize, headers.len);
    @memset(widths, 0);
    for (headers, 0..) |header, index| widths[index] = header.len;
    for (rows) |row| {
        for (row, 0..) |cell, index| widths[index] = @max(widths[index], cell.len);
    }

    var builder = std.ArrayList(u8).empty;
    const writer = builder.writer(allocator);
    for (headers, 0..) |header, index| {
        try writeCell(writer, header, widths[index] + 2);
    }
    try writer.writeByte('\n');
    for (widths) |width| {
        for (0..width + 2) |_| try writer.writeByte('-');
    }
    for (rows) |row| {
        try writer.writeByte('\n');
        for (row, 0..) |cell, index| {
            try writeCell(writer, cell, widths[index] + 2);
        }
    }
    const body = try builder.toOwnedSlice(allocator);
    return try box.buildWithOptions(allocator, options.title, try text.buildWithOptions(allocator, body, .{ .style = options.style, .wrap = .none }), .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
}

test "table builds fixed-width rows" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const headers = [_][]const u8{ "Name", "Lang" };
    const row1 = [_][]const u8{ "ziggy", "Zig" };
    const rows = [_][]const []const u8{ &row1 };
    const node = try build(alloc, &headers, &rows, .{});
    try std.testing.expect(node.* == .box);
}
