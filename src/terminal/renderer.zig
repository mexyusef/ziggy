const std = @import("std");
const ansi = @import("ansi.zig");
const screen_mod = @import("screen.zig");
const style_mod = @import("../style/style.zig");

pub fn renderFull(writer: *std.Io.Writer, screen: *const screen_mod.Screen) !void {
    try ansi.writeClearScreen(writer);
    var current_style: style_mod.Style = .{};
    var style_valid = false;
    var current_link: ?[]const u8 = null;

    for (0..screen.size.height) |y| {
        for (0..screen.size.width) |x| {
            const cell = screen.getCell(.{
                .x = @intCast(x),
                .y = @intCast(y),
            });
            if (cell.continuation) continue;
            try ansi.writeMoveTo(writer, @intCast(x), @intCast(y));
            if (!style_valid or !style_mod.Style.eql(current_style, cell.style)) {
                try ansi.writeStyle(writer, cell.style);
                current_style = cell.style;
                style_valid = true;
            }
            const next_link = cell.linkTarget();
            if (!linkEql(current_link, next_link)) {
                if (current_link != null) try ansi.writeHyperlinkClose(writer);
                if (next_link) |target| try ansi.writeHyperlinkOpen(writer, target);
                current_link = next_link;
            }
            try writer.writeAll(cell.glyph_bytes[0..cell.glyph_len]);
        }
    }
    if (current_link != null) try ansi.writeHyperlinkClose(writer);
    try ansi.writeReset(writer);
}

pub fn renderDiffWithCapabilities(
    writer: *std.Io.Writer,
    previous: *const screen_mod.Screen,
    current: *const screen_mod.Screen,
    capabilities: @import("capabilities.zig").Capabilities,
) !void {
    if (capabilities.synchronized_output) try ansi.writeSyncOutputBegin(writer);
    defer if (capabilities.synchronized_output) ansi.writeSyncOutputEnd(writer) catch {};
    try renderDiff(writer, previous, current);
}

pub fn renderDiff(
    writer: *std.Io.Writer,
    previous: *const screen_mod.Screen,
    current: *const screen_mod.Screen,
) !void {
    if (previous.size.width != current.size.width or previous.size.height != current.size.height) {
        return renderFull(writer, current);
    }

    var current_style: style_mod.Style = .{};
    var style_valid = false;
    var current_link: ?[]const u8 = null;

    for (0..current.size.height) |y| {
        for (0..current.size.width) |x| {
            const point: screen_mod.Point = .{ .x = @intCast(x), .y = @intCast(y) };
            const old = previous.getCell(point);
            const new = current.getCell(point);
            if (screen_mod.Cell.eql(old, new)) continue;
            if (new.continuation) continue;

            try ansi.writeMoveTo(writer, point.x, point.y);
            if (!style_valid or !style_mod.Style.eql(current_style, new.style)) {
                try ansi.writeStyle(writer, new.style);
                current_style = new.style;
                style_valid = true;
            }
            const next_link = new.linkTarget();
            if (!linkEql(current_link, next_link)) {
                if (current_link != null) try ansi.writeHyperlinkClose(writer);
                if (next_link) |target| try ansi.writeHyperlinkOpen(writer, target);
                current_link = next_link;
            }
            try writer.writeAll(new.glyph_bytes[0..new.glyph_len]);
        }
    }
    if (current_link != null) try ansi.writeHyperlinkClose(writer);
    try ansi.writeReset(writer);
}

fn linkEql(a: ?[]const u8, b: ?[]const u8) bool {
    if (a == null and b == null) return true;
    if (a == null or b == null) return false;
    return std.mem.eql(u8, a.?, b.?);
}

test "renderDiff emits changed bytes only" {
    var prev = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 3, .height = 1 });
    defer prev.deinit();
    var curr = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 3, .height = 1 });
    defer curr.deinit();

    prev.writeText(.{ .x = 0, .y = 0 }, "abc", .{});
    curr.writeText(.{ .x = 0, .y = 0 }, "axc", .{});

    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    try renderDiff(&out.writer, &prev, &curr);
    try std.testing.expect(std.mem.indexOfScalar(u8, out.written(), 'x') != null);
}

test "renderDiffWithCapabilities wraps synchronized output" {
    var prev = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 1, .height = 1 });
    defer prev.deinit();
    var curr = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 1, .height = 1 });
    defer curr.deinit();
    curr.writeText(.{ .x = 0, .y = 0 }, "x", .{});

    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    try renderDiffWithCapabilities(&out.writer, &prev, &curr, .{ .synchronized_output = true });
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "\x1b[?2026h") != null);
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "\x1b[?2026l") != null);
}

test "renderFull skips continuation cells" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 3, .height = 1 });
    defer screen.deinit();
    screen.writeText(.{ .x = 0, .y = 0 }, "表x", .{});

    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    try renderFull(&out.writer, &screen);
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "表") != null);
}

test "renderFull emits hyperlink sequences" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 4, .height = 1 });
    defer screen.deinit();
    screen.writeLinkedText(.{ .x = 0, .y = 0 }, "go", .{}, "https://x");

    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    try renderFull(&out.writer, &screen);
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "\x1b]8;;https://x\x1b\\") != null);
}
