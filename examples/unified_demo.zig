const std = @import("std");
const ziggy = @import("ziggy");
const support = @import("support.zig");
const widgets_demo = @import("widgets_demo.zig");
const shell_demo = @import("shell_demo.zig");
const controls_demo = @import("controls_demo.zig");
const dialog_demo = @import("dialog_demo.zig");
const full_demo = @import("full_demo.zig");
const render_to_string_demo = @import("render_to_string_demo.zig");

const Msg = ziggy.Event;

const ExampleKind = enum {
    widgets,
    shell,
    controls,
    dialog,
    full,
    interactive,
    editor,
    log_viewer,
    text_buffer,
    render_to_string,
};

const ExampleEntry = struct {
    kind: ExampleKind,
    label: []const u8,
    exe_name: []const u8,
    summary: []const u8,
};

const entries = [_]ExampleEntry{
    .{ .kind = .widgets, .label = "widgets_demo", .exe_name = "ziggy-widgets-demo.exe", .summary = "Gallery of panels, alerts, toasts, cards, tabs, and chrome." },
    .{ .kind = .shell, .label = "shell_demo", .exe_name = "ziggy-shell-demo.exe", .summary = "Workspace shell framing with sidebar, document pane, and footer." },
    .{ .kind = .controls, .label = "controls_demo", .exe_name = "ziggy-controls-demo.exe", .summary = "Inputs, selectors, forms, tree, table, and status controls." },
    .{ .kind = .dialog, .label = "dialog_demo", .exe_name = "ziggy-dialog-demo.exe", .summary = "Command dialog, picker, tooltip, autocomplete, and toast surfaces." },
    .{ .kind = .full, .label = "full_demo", .exe_name = "ziggy-full-demo.exe", .summary = "Composite shell demo with transcript, dialogs, and workspace framing." },
    .{ .kind = .interactive, .label = "interactive_demo", .exe_name = "ziggy-interactive-demo.exe", .summary = "Dedicated keystroke and input handling demo." },
    .{ .kind = .editor, .label = "editor_demo", .exe_name = "ziggy-editor-demo.exe", .summary = "Editor workspace with transcript, palette, and completion support." },
    .{ .kind = .log_viewer, .label = "log_viewer_demo", .exe_name = "ziggy-log-viewer-demo.exe", .summary = "Scrollable log viewer and static region behavior demo." },
    .{ .kind = .text_buffer, .label = "text_buffer_demo", .exe_name = "ziggy-text-buffer-demo.exe", .summary = "Text buffer editing and history behavior demo." },
    .{ .kind = .render_to_string, .label = "render_to_string_demo", .exe_name = "ziggy-render-to-string-demo.exe", .summary = "Themed ANSI snapshot demo for non-interactive rendering." },
};

const entry_labels = [_][]const u8{
    entries[0].label,
    entries[1].label,
    entries[2].label,
    entries[3].label,
    entries[4].label,
    entries[5].label,
    entries[6].label,
    entries[7].label,
    entries[8].label,
    entries[9].label,
};

const Shared = struct {
    launch_requested: ?ExampleKind = null,
    should_exit: bool = false,
};

const Model = struct {
    shared: *Shared,
    menu_state: ziggy.List.State = .{ .selection = .{ .focused = true, .viewport = 12 } },
    notice: []const u8 = "Enter launches selected demo. j/k and arrows move. PgUp/PgDn/Home/End jump. Esc quits.",

    pub fn init(self: *@This(), ctx: *ziggy.Context) ziggy.Command(Msg) {
        _ = self;
        ctx.requestRedraw();
        return .none;
    }

    pub fn update(self: *@This(), event: Msg, ctx: *ziggy.Context) ziggy.Command(Msg) {
        switch (event) {
            .key => |key| switch (key) {
                .ctrl_c, .escape => {
                    self.shared.should_exit = true;
                    return .quit;
                },
                .enter => {
                    self.shared.launch_requested = entries[self.menu_state.selection.cursor].kind;
                    return .quit;
                },
                .up, .down, .page_up, .page_down, .home, .end => self.handleListKey(key, ctx),
                .char => |c| switch (c) {
                    'k', 'K' => self.handleListKey(.up, ctx),
                    'j', 'J' => self.handleListKey(.down, ctx),
                    'g' => self.handleListKey(.home, ctx),
                    'G' => self.handleListKey(.end, ctx),
                    else => {},
                },
                else => {},
            },
            else => {},
        }
        return .none;
    }

    fn handleListKey(self: *@This(), key: ziggy.Key, ctx: *ziggy.Context) void {
        const response = ziggy.List.handleEvent(&self.menu_state, &entry_labels, key);
        if (response.redraw) ctx.requestRedraw();
    }

    pub fn viewNode(self: *@This(), ctx: *ziggy.Context) !*const ziggy.Node {
        const theme = ziggy.defaultAgentTheme();
        const selected = entries[self.menu_state.selection.cursor];

        const header = try ziggy.HeaderBar.build(ctx.allocator, "ziggy Example Launcher", .{
            .subtitle = "Enter launches the real demo executable. Preview is a static snapshot when available.",
            .right_text = "example-all",
            .style = theme.pane,
            .title_style = theme.pane_active,
            .subtitle_style = theme.status_idle,
            .right_style = theme.selected_alt,
            .border_style = theme.border_style,
        });

        const menu_list = try ziggy.List.buildState(ctx.allocator, &entry_labels, self.menu_state, .{
            .style = theme.pane,
            .selected_style = theme.selected,
            .focus = .{ .active = true, .focus_id = "examples" },
        });
        const menu = try ziggy.Box.buildWithOptions(ctx.allocator, "Examples", menu_list, .{
            .style = theme.pane,
            .border_style = theme.border_style,
            .padding_top = 1,
            .padding_bottom = 1,
            .padding_left = 1,
            .padding_right = 1,
        });

        const summary = try ziggy.Text.buildWithOptions(ctx.allocator, try std.fmt.allocPrint(ctx.allocator, "{s}\n\nbinary: {s}\n\ncommand:\n.\\zig-out\\bin\\{s}", .{
            selected.summary,
            selected.exe_name,
            selected.exe_name,
        }), .{
            .style = theme.status_idle,
            .wrap = .wrap,
        });
        const summary_box = try ziggy.Box.buildWithOptions(ctx.allocator, "Selected", summary, .{
            .style = theme.pane,
            .border_style = theme.border_style,
            .padding_top = 1,
            .padding_bottom = 1,
            .padding_left = 1,
            .padding_right = 1,
        });

        const preview = try previewPanel(ctx.allocator, selected.kind, theme);
        const right = try ziggy.VStack.buildWithWeights(ctx.allocator, &.{ summary_box, preview }, 1, &.{ 0, 1 });
        const body = try ziggy.HStack.buildWithWeights(ctx.allocator, &.{ menu, right }, 1, &.{ 2, 3 });

        const footer = try ziggy.FooterBar.build(ctx.allocator, "launch", "Esc quits", .{
            .center = self.notice,
            .style = theme.pane,
            .left_style = theme.selected_alt,
            .center_style = theme.status_idle,
            .right_style = theme.status_idle,
            .border_style = theme.border_style,
        });

        return try ziggy.VStack.buildWithWeights(ctx.allocator, &.{ header, body, footer }, 1, &.{ 0, 1, 0 });
    }
};

pub fn main() !void {
    while (true) {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        var shared: Shared = .{};
        const model = Model{ .shared = &shared };
        try support.runInteractiveProgram(Model, Msg, arena.allocator(), model, .{
            .title = "ziggy example launcher",
            .tick_interval_ms = 0,
        });

        if (shared.launch_requested) |kind| {
            try runExampleBinary(kind);
            continue;
        }
        break;
    }
}

fn previewPanel(
    allocator: std.mem.Allocator,
    kind: ExampleKind,
    theme: ziggy.AgentTheme,
) !*const ziggy.Node {
    const root = buildPreviewRoot(allocator, kind) catch null;
    if (root) |node| {
        const saved_profile = ziggy.getRenderProfile();
        defer ziggy.setRenderProfile(saved_profile);
        ziggy.setRenderProfile(.{
            .ansi_enabled = saved_profile.ansi_enabled,
            .unicode_safe = false,
        });

        const snapshot = try ziggy.renderToString(allocator, node, .{
            .width = 58,
            .height = 14,
            .ansi_styles = false,
            .trim_trailing_spaces = true,
        });
        const text = try ziggy.Text.buildWithOptions(allocator, snapshot, .{
            .style = theme.status_idle,
            .wrap = .none,
        });
        return try ziggy.Box.buildWithOptions(allocator, "Preview", text, .{
            .style = theme.pane,
            .border_style = theme.border_style,
            .padding_top = 1,
            .padding_bottom = 1,
            .padding_left = 1,
            .padding_right = 1,
        });
    }

    const fallback = try ziggy.Text.buildWithOptions(allocator,
        "No embedded snapshot for this example.\nPress Enter to launch the real executable.", .{
        .style = theme.status_idle,
        .wrap = .wrap,
    });
    return try ziggy.Box.buildWithOptions(allocator, "Preview", fallback, .{
        .style = theme.pane,
        .border_style = theme.border_style,
        .padding_top = 1,
        .padding_bottom = 1,
        .padding_left = 1,
        .padding_right = 1,
    });
}

fn buildPreviewRoot(allocator: std.mem.Allocator, kind: ExampleKind) !*const ziggy.Node {
    return switch (kind) {
        .widgets => try widgets_demo.buildRoot(allocator),
        .shell => try shell_demo.buildRoot(allocator),
        .controls => try controls_demo.buildRoot(allocator),
        .dialog => try dialog_demo.buildRoot(allocator),
        .full => try full_demo.buildRoot(allocator),
        .render_to_string => try render_to_string_demo.buildRoot(allocator),
        else => error.NoEmbeddedPreview,
    };
}

fn runExampleBinary(kind: ExampleKind) !void {
    const exe_name = for (entries) |entry| {
        if (entry.kind == kind) break entry.exe_name;
    } else return error.UnknownExample;

    const self_dir = try std.fs.selfExeDirPathAlloc(std.heap.page_allocator);
    defer std.heap.page_allocator.free(self_dir);

    const full_path = try std.fs.path.join(std.heap.page_allocator, &.{ self_dir, exe_name });
    defer std.heap.page_allocator.free(full_path);

    support.clearPendingConsoleInput();
    var child = std.process.Child.init(&.{ full_path }, std.heap.page_allocator);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    const result = try child.wait();
    const message = switch (result) {
        .Exited => |code| try std.fmt.allocPrint(std.heap.page_allocator, "\n[{s}] exited with code {}. Press any key to continue...", .{ exe_name, code }),
        .Signal => |sig| try std.fmt.allocPrint(std.heap.page_allocator, "\n[{s}] terminated by signal {}. Press any key to continue...", .{ exe_name, sig }),
        .Stopped => |sig| try std.fmt.allocPrint(std.heap.page_allocator, "\n[{s}] stopped by signal {}. Press any key to continue...", .{ exe_name, sig }),
        .Unknown => |code| try std.fmt.allocPrint(std.heap.page_allocator, "\n[{s}] ended with status {}. Press any key to continue...", .{ exe_name, code }),
    };
    defer std.heap.page_allocator.free(message);
    try support.waitForAnyKey(message);
}
