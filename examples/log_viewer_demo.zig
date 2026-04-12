const std = @import("std");
const ziggy = @import("ziggy");
const support = @import("support.zig");

pub fn main() !void {
    _ = ziggy.prepareConsole();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const theme = ziggy.defaultAgentTheme();

    var viewport: ziggy.Viewport = .{
        .viewport_width = 52,
        .viewport_height = 10,
        .content_height = 16,
    };
    viewport.stickTo(.bottom);
    viewport.setContent(52, 18);

    const log_text =
        \\[10:20:01] booting ziggy runtime
        \\[10:20:02] tty prepared
        \\[10:20:03] loaded workspace state
        \\[10:20:05] connected completion provider
        \\[10:20:08] restored pane tree
        \\[10:20:13] indexed 32 files
        \\[10:20:16] background diagnostics started
        \\[10:20:20] sticky scroll pinned to bottom
        \\[10:20:21] appended final lines
        \\[10:20:22] this demo mirrors a chat/log viewport
        \\[10:20:24] scroll away to break sticky mode
        \\[10:20:27] scroll back to re-pin
        \\[10:20:31] renderer diff stayed compact
        \\[10:20:34] focus restore support enabled
        \\[10:20:35] editor history available
        \\[10:20:36] ready
        \\[10:20:40] follow-up line one
        \\[10:20:41] follow-up line two
    ;
    const built = try ziggy.StaticLog.buildFromText(allocator, log_text, .{
        .offset = viewport.offset_line,
        .viewport_height = viewport.viewport_height,
        .follow_end = viewport.stickyYFollowsEnd(),
        .style = theme.pane,
    });
    defer ziggy.RichText.freeLines(allocator, built.lines);
    defer ziggy.RichDocument.deinitNode(allocator, built.node);

    const explainer = try ziggy.Card.build(allocator, "Log Viewport", .{
        .subtitle = "sticky bottom + viewport state",
        .body =
        \\This example snapshots the tail of a longer log using
        \\`Viewport.stickTo(.bottom)` and `StaticLog.buildFromText`.
        \\
        \\Use this pattern for chat transcripts, diagnostics panes,
        \\and streaming command output.
        ,
        .style = theme.pane,
        .border_style = theme.border_style,
    });

    const log_panel = try ziggy.Box.buildWithOptions(allocator, "Live Log", built.node, .{
        .style = theme.pane,
        .border_style = theme.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });

    const root = try ziggy.VStack.build(allocator, &.{ explainer, log_panel }, 1);
    try support.renderStatic(root, support.detectTerminalSize());
}
