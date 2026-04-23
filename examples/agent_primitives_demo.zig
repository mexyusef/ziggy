const std = @import("std");
const ziggy = @import("ziggy");

pub fn main() !void {
    _ = ziggy.prepareConsole();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const root = try buildRoot(allocator);
    const output = try ziggy.renderToString(allocator, root, .{
        .width = 100,
        .height = 28,
        .ansi_styles = true,
        .trim_trailing_spaces = false,
        .include_final_newline = true,
    });
    defer allocator.free(output);

    try ziggy.writeStdout(allocator, output);
}

fn buildRoot(allocator: std.mem.Allocator) !*const ziggy.Node {
    const messages = [_]ziggy.AgentTranscript.Message{
        .{ .role = .system, .body = "Session started\n\n- repo: cirebronx\n- mode: plan+build" },
        .{ .role = .user, .body = "Search the repo for terminal rendering issues.", .meta = "prompt" },
        .{ .role = .assistant, .body = "Scanning `src/cli/tui.zig` and current `ziggy` profile handling.", .selected = true, .meta = "step 2/4" },
        .{ .role = .tool, .body = "rg -n \"unicode_safe|WriteConsoleW|cmd.exe\" src", .meta = "shell" },
    };
    const transcript_panel = try ziggy.AgentTranscript.build(allocator, &messages, .{
        .title = "Agent Transcript",
        .width = 46,
        .viewport_height = 16,
    });

    const diff_panel = try ziggy.DiffViewer.build(allocator, .{
        .title = "Patch Preview",
        .diff_text =
            \\@@ -14,6 +14,10 @@
            \\-    unicode_safe: bool = true,
            \\+    encoding_safe: bool = true,
            \\+    unicode_safe: bool = true,
            \\+    icon_safe: bool = true,
            \\+    render_mode: RenderMode = .auto,
            \\+    icon_mode: IconMode = .auto,
        ,
        .viewport_height = 12,
    });

    const paths = [_][]const u8{
        "src/",
        "src/cli/",
        "src/cli/tui.zig",
        "src/cli/tui_layout.zig",
        "src/terminal/",
        "src/terminal/profile.zig",
        "docs/",
        "docs/rendering-notes.md",
    };
    const tree_entries = try ziggy.FileTreeBrowser.fromPaths(allocator, &paths);
    const files_panel = try ziggy.FileTreeBrowser.buildState(allocator, tree_entries, .{}, .{
        .title = "Repo Tree",
    });

    const right = try ziggy.VStack.buildWithWeights(allocator, &.{ diff_panel, files_panel }, 1, &.{ 2, 1 });
    return try ziggy.HStack.buildWithWeights(allocator, &.{ transcript_panel.node, right }, 2, &.{ 3, 2 });
}
