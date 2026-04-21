const std = @import("std");
const ziggy = @import("ziggy");

pub fn main() !void {
    _ = ziggy.prepareConsole();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const root = try buildRoot(allocator);
    const output = try ziggy.renderToString(allocator, root, .{
        .width = 56,
        .height = 11,
        .ansi_styles = true,
        .trim_trailing_spaces = false,
        .include_final_newline = true,
    });
    defer allocator.free(output);

    try ziggy.writeStdout(allocator, output);
}

pub fn buildRoot(allocator: std.mem.Allocator) !*const ziggy.Node {

    const badge = try ziggy.Badge.build(allocator, "LIVE", .{
        .style = .{
            .fg = .{ .ansi = 15 },
            .bg = .{ .rgb = .{ .r = 15, .g = 118, .b = 110 } },
            .bold = true,
        },
    });
    const spinner = try ziggy.Spinner.build(allocator, .{
        .now_ms = 320,
        .style = .{
            .fg = .{ .rgb = .{ .r = 255, .g = 200, .b = 87 } },
            .bold = true,
        },
    });
    const progress = try ziggy.ProgressBar.build(allocator, .{
        .current = 68,
        .total = 100,
        .style = .{ .fg = .{ .ansi = 8 } },
        .fill_style = .{
            .fg = .{ .rgb = .{ .r = 122, .g = 162, .b = 247 } },
            .bold = true,
        },
    });
    const right_column = try ziggy.VStack.build(allocator, &.{ badge, spinner, progress }, 1);
    const right_panel = try ziggy.Box.buildWithOptions(allocator, "Pipeline", right_column, .{
        .style = .{
            .fg = .{ .ansi = 15 },
            .bg = .{ .rgb = .{ .r = 30, .g = 41, .b = 59 } },
        },
        .padding_top = 1,
        .padding_bottom = 1,
        .padding_left = 1,
        .padding_right = 1,
    });
    const left_panel = try ziggy.Card.build(allocator, "Agent Workspace", .{
        .subtitle = "renderToString demo",
        .body =
            \\- themed panels
            \\- spinner + progress
            \\- ANSI snapshot rendering
        ,
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
    const root = try ziggy.HStack.build(allocator, &.{ left_panel, right_panel }, 2);
    return root;
}
