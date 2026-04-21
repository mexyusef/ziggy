const std = @import("std");
const box = @import("box.zig");
const text = @import("text.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");
const node_mod = @import("node.zig");
const parser = @import("../terminal/parser.zig");
const interaction = @import("../interaction/widget.zig");
const surface_mod = @import("surface.zig");

pub const Options = struct {
    title: ?[]const u8 = "Table",
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    border_style: border_mod.BorderStyle = .single,
};

pub const State = struct {
    selection: interaction.SelectState = .{},
};

fn writeCell(writer: anytype, value: []const u8, width: usize) !void {
    try writer.writeAll(value);
    if (width > value.len) {
        for (0..width - value.len) |_| try writer.writeByte(' ');
    }
}

pub fn build(allocator: std.mem.Allocator, headers: []const []const u8, rows: []const []const []const u8, options: Options) !*const node_mod.Node {
    return buildState(allocator, headers, rows, .{}, options);
}

pub fn buildState(
    allocator: std.mem.Allocator,
    headers: []const []const u8,
    rows: []const []const []const u8,
    state: State,
    options: Options,
) !*const node_mod.Node {
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
    for (rows, 0..) |row, row_index| {
        try writer.writeByte('\n');
        if (row_index == state.selection.cursor and rows.len > 0) {
            try writer.writeAll("> ");
        } else {
            try writer.writeAll("  ");
        }
        for (row, 0..) |cell, index| {
            try writeCell(writer, cell, widths[index] + 2);
        }
    }
    const body = try builder.toOwnedSlice(allocator);
    return try box.buildWithOptions(allocator, options.title, try text.buildWithOptions(allocator, body, .{
        .style = if (rows.len > 0 and state.selection.focused) options.selected_style else options.style,
        .wrap = .none,
    }), .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
}

pub fn handleEvent(state: *State, rows: usize, key: parser.Key) interaction.Response {
    return state.selection.handleListKey(rows, key);
}

pub fn hitTestRow(rect: surface_mod.Rect, row_count: usize, x: u16, y: u16) ?usize {
    const local = rect.localPoint(x, y) orelse return null;
    if (local.y < 2 or local.y >= rect.height -| 1) return null;
    const row_index = @as(usize, local.y - 2);
    if (row_index >= row_count) return null;
    return row_index;
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

test "table state navigates and submits rows" {
    const row1 = [_][]const u8{ "one" };
    const row2 = [_][]const u8{ "two" };
    const rows = [_][]const []const u8{ &row1, &row2 };
    var state: State = .{};
    _ = handleEvent(&state, rows.len, .down);
    try std.testing.expectEqual(@as(usize, 1), state.selection.cursor);
    const response = handleEvent(&state, rows.len, .enter);
    try std.testing.expectEqual(interaction.Action.submitted, response.action);
    try std.testing.expectEqual(@as(?usize, 1), response.selected);
}

test "table row hit testing maps body rows" {
    const rect: surface_mod.Rect = .{ .x = 0, .y = 0, .width = 30, .height = 8 };
    try std.testing.expectEqual(@as(?usize, 0), hitTestRow(rect, 3, 1, 2));
    try std.testing.expectEqual(@as(?usize, 2), hitTestRow(rect, 3, 1, 4));
}
