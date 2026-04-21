const std = @import("std");
const ansi = @import("terminal/ansi.zig");
const screen_mod = @import("terminal/screen.zig");
const node_mod = @import("widget/node.zig");
const rect_mod = @import("widget/surface.zig");
const widget_render = @import("widget/render.zig");
const style_mod = @import("style/style.zig");

pub const RenderToStringOptions = struct {
    width: u16 = 80,
    height: u16 = 24,
    ansi_styles: bool = false,
    trim_trailing_spaces: bool = true,
    include_final_newline: bool = false,
};

pub fn renderNodeToString(
    allocator: std.mem.Allocator,
    node: *const node_mod.Node,
    options: RenderToStringOptions,
) ![]u8 {
    var screen = try screen_mod.Screen.init(allocator, .{
        .width = options.width,
        .height = options.height,
    });
    defer screen.deinit();

    widget_render.renderNode(&screen, .{
        .x = 0,
        .y = 0,
        .width = options.width,
        .height = options.height,
    }, node);

    return renderScreenToString(allocator, &screen, options);
}

pub fn renderScreenToString(
    allocator: std.mem.Allocator,
    screen: *const screen_mod.Screen,
    options: RenderToStringOptions,
) ![]u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();

    for (0..screen.size.height) |row_index| {
        const y: u16 = @intCast(row_index);
        const end_x = lineEnd(screen, y, options.trim_trailing_spaces);
        var current_style: style_mod.Style = .{};
        var style_valid = false;
        var current_link: ?[]const u8 = null;

        for (0..end_x) |col_index| {
            const x: u16 = @intCast(col_index);
            const cell = screen.getCell(.{ .x = x, .y = y });
            if (cell.continuation) continue;

            if (options.ansi_styles) {
                if (!style_valid or !style_mod.Style.eql(current_style, cell.style)) {
                    try ansi.writeStyle(&out.writer, cell.style);
                    current_style = cell.style;
                    style_valid = true;
                }

                const next_link = cell.linkTarget();
                if (!linkEql(current_link, next_link)) {
                    if (current_link != null) try ansi.writeHyperlinkClose(&out.writer);
                    if (next_link) |target| try ansi.writeHyperlinkOpen(&out.writer, target);
                    current_link = next_link;
                }
            }

            try out.writer.writeAll(cell.glyph_bytes[0..cell.glyph_len]);
        }

        if (options.ansi_styles) {
            if (current_link != null) try ansi.writeHyperlinkClose(&out.writer);
            if (style_valid) try ansi.writeReset(&out.writer);
        }

        if (row_index + 1 < screen.size.height or options.include_final_newline) {
            try out.writer.writeByte('\n');
        }
    }

    return allocator.dupe(u8, out.written());
}

fn lineEnd(screen: *const screen_mod.Screen, y: u16, trim_trailing_spaces: bool) usize {
    if (!trim_trailing_spaces) return screen.size.width;

    var x: usize = screen.size.width;
    while (x > 0) {
        x -= 1;
        const cell = screen.getCell(.{ .x = @intCast(x), .y = y });
        if (cell.continuation) continue;
        if (cell.glyph_len != 1 or cell.glyph_bytes[0] != ' ') return x + 1;
    }
    return 0;
}

fn linkEql(a: ?[]const u8, b: ?[]const u8) bool {
    if (a == null and b == null) return true;
    if (a == null or b == null) return false;
    return std.mem.eql(u8, a.?, b.?);
}

test "renderNodeToString renders plain text frame" {
    const text = @import("widget/text.zig");

    const root = try text.build(std.testing.allocator, "hi", .{});
    defer std.testing.allocator.destroy(root);

    const output = try renderNodeToString(std.testing.allocator, root, .{
        .width = 4,
        .height = 2,
    });
    defer std.testing.allocator.free(output);

    try std.testing.expectEqualStrings("hi\n", output);
}

test "renderNodeToString renders ansi themed box scene" {
    const box = @import("widget/box.zig");
    const badge = @import("widget/badge.zig");
    const card = @import("widget/card.zig");
    const hstack = @import("widget/hstack.zig");
    const progress_bar = @import("widget/progress_bar.zig");
    const spinner = @import("widget/spinner.zig");
    const vstack = @import("widget/vstack.zig");

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const status = try badge.build(allocator, "RUNNING", .{
        .style = .{
            .fg = .{ .ansi = 15 },
            .bg = .{ .rgb = .{ .r = 15, .g = 118, .b = 110 } },
            .bold = true,
        },
    });
    const load = try spinner.build(allocator, .{
        .now_ms = 240,
        .style = .{
            .fg = .{ .rgb = .{ .r = 255, .g = 200, .b = 87 } },
            .bold = true,
        },
    });
    const progress = try progress_bar.build(allocator, .{
        .current = 72,
        .total = 100,
        .style = .{ .fg = .{ .ansi = 8 } },
        .fill_style = .{
            .fg = .{ .rgb = .{ .r = 122, .g = 162, .b = 247 } },
            .bold = true,
        },
    });
    const left = try card.build(allocator, "Planner", .{
        .subtitle = "agent runtime",
        .body = "Queueing tasks\nStreaming tools",
        .style = .{
            .fg = .{ .ansi = 15 },
            .bg = .{ .rgb = .{ .r = 26, .g = 27, .b = 38 } },
        },
        .title_style = .{
            .fg = .{ .rgb = .{ .r = 122, .g = 162, .b = 247 } },
            .bold = true,
        },
        .subtitle_style = .{
            .fg = .{ .rgb = .{ .r = 125, .g = 207, .b = 255 } },
            .dim = true,
        },
        .body_style = .{ .fg = .{ .ansi = 15 } },
    });
    const right_body = try vstack.build(allocator, &.{ status, load, progress }, 1);
    const right = try box.buildWithOptions(allocator, "Pipeline", right_body, .{
        .style = .{
            .fg = .{ .ansi = 15 },
            .bg = .{ .rgb = .{ .r = 30, .g = 41, .b = 59 } },
        },
        .padding_top = 1,
        .padding_bottom = 1,
        .padding_left = 1,
        .padding_right = 1,
    });
    const root = try hstack.build(allocator, &.{ left, right }, 2);

    const output = try renderNodeToString(std.testing.allocator, root, .{
        .width = 48,
        .height = 10,
        .ansi_styles = true,
        .trim_trailing_spaces = false,
    });
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\x1b[0;97;48;2;26;27;38m") != null or std.mem.indexOf(u8, output, "\x1b[0;48;2;26;27;38m") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\x1b[0;97;48;2;30;41;59m") != null or std.mem.indexOf(u8, output, "\x1b[0;48;2;30;41;59m") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Planner") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Pipeline") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "RUNNING") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\x1b[0m") != null);
}
