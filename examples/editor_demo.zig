const std = @import("std");
const ziggy = @import("ziggy");
const support = @import("support.zig");
const workspace_support = @import("editor_workspace_support.zig");

const Msg = ziggy.Event;
const Scope = enum {
    workspace,
    palette,
    completion,
};

const Action = enum {
    quit,
    open_palette,
    close_overlay,
    palette_next,
    palette_previous,
    palette_page_up,
    palette_page_down,
    palette_accept,
    completion_open,
    completion_accept,
    completion_next,
    completion_previous,
    completion_page_up,
    completion_page_down,
    focus_next_pane,
    focus_previous_pane,
    toggle_sidebar,
    toggle_problems,
};

const tabs = [_][]const u8{
    "main.zig",
    "build.zig",
    "src/editor_session.zig",
    "README.md",
};

const sidebar_items = [_][]const u8{
    "Explorer",
    "Search",
    "Symbols",
    "Diagnostics",
    "Buffers",
};

const footer_hints = [_][]const u8{
    "Ctrl+P Palette",
    "Ctrl+Space Complete",
    "Ctrl+N Next Pane",
    "Ctrl+R Prev Pane",
    "Ctrl+C Quit",
};

const palette_commands = [_]ziggy.PaletteController.Entry{
    .{ .label = "Open File", .detail = "open a workspace file into the focused pane" },
    .{ .label = "Switch Buffer", .detail = "change the active tab or open buffer" },
    .{ .label = "Toggle Sidebar", .detail = "show or hide the navigation sidebar" },
    .{ .label = "Format Document", .detail = "run a formatter against the current buffer" },
    .{ .label = "Show Diagnostics", .detail = "open the bottom diagnostics panel" },
    .{ .label = "Open Command Palette", .detail = "re-open the palette with command mode active" },
};

const completion_items = [_]ziggy.Completion.Item{
    .{ .label = "const", .value = "const ", .detail = "immutable binding" },
    .{ .label = "var", .value = "var ", .detail = "mutable binding" },
    .{ .label = "pub fn", .value = "pub fn ", .detail = "public function" },
    .{ .label = "try", .value = "try ", .detail = "error propagation" },
    .{ .label = "defer", .value = "defer ", .detail = "cleanup" },
};

const DemoSession = struct {
    active_tab: usize,
    sidebar_selected: usize,
    show_sidebar: bool,
    pane_tree: ziggy.PaneTree.Snapshot,
    panels: ziggy.PanelHost.Snapshot,
    palette: ziggy.PaletteController.State.Snapshot,
    editor: ziggy.EditorViewState.Snapshot,

    fn deinit(self: *DemoSession, allocator: std.mem.Allocator) void {
        self.pane_tree.deinit(allocator);
        self.panels.deinit(allocator);
        self.palette.deinit(allocator);
    }
};

const Model = struct {
    workspace: workspace_support.EditorWorkspaceState,
    pane_tree: ziggy.PaneTree.State,
    panel_host: ziggy.PanelHost.State,
    palette: ziggy.PaletteController.State,
    actions: ziggy.ActionRouter(Scope, Action),
    hover: ziggy.InteractionRuntime.HoverTracker = .{},
    mouse: ziggy.InteractionRuntime.MouseTracker = .{},

    pub fn init(self: *@This(), ctx: *ziggy.Context) ziggy.Command(Msg) {
        _ = self;
        ctx.requestRedraw();
        return .none;
    }

    pub fn update(self: *@This(), event: Msg, ctx: *ziggy.Context) ziggy.Command(Msg) {
        switch (event) {
            .key => |key| {
                if (self.handleActionKey(key, ctx)) |cmd| return cmd;
                if (self.palette.open) {
                    self.handlePaletteTextKey(ctx, key);
                } else if (workspace_support.handleEditorKey(&self.workspace, ctx.persistent_allocator, key, &completion_items, 14) catch false) {
                    self.workspace.status_text = "Editing";
                    ctx.requestRedraw();
                }
            },
            .mouse => |mouse| self.handleMouse(mouse, ctx),
            else => {},
        }
        return .none;
    }

    fn activeScopes(self: *const @This()) [3]Scope {
        return .{
            if (self.workspace.completion.popup.visible) .completion else .workspace,
            if (self.palette.open) .palette else .workspace,
            .workspace,
        };
    }

    fn handleActionKey(self: *@This(), key: ziggy.Key, ctx: *ziggy.Context) ?ziggy.Command(Msg) {
        var event: ziggy.InputRuntime.KeyEvent = .{ .key = key };
        const resolved = self.actions.handleKey(&event, &self.activeScopes()) orelse return null;
        switch (resolved.action) {
            .quit => return .quit,
            .open_palette => {
                self.palette.open = !self.palette.open;
                self.palette.selected = 0;
                self.palette.offset = 0;
                if (self.palette.open) {
                    self.palette.refresh(ctx.persistent_allocator, &palette_commands) catch {};
                    self.workspace.status_text = "Palette opened";
                }
                ctx.requestRedraw();
            },
            .close_overlay => {
                if (self.palette.open) {
                    self.palette.clear();
                    self.workspace.status_text = "Palette closed";
                } else {
                    self.workspace.completion.clear(ctx.persistent_allocator);
                }
                ctx.requestRedraw();
            },
            .palette_next => {
                self.palette.moveNext();
                ctx.requestRedraw();
            },
            .palette_previous => {
                self.palette.movePrevious();
                ctx.requestRedraw();
            },
            .palette_page_up => {
                self.palette.pageUp();
                ctx.requestRedraw();
            },
            .palette_page_down => {
                self.palette.pageDown();
                ctx.requestRedraw();
            },
            .palette_accept => self.acceptPalette(ctx),
            .completion_open => {
                self.workspace.completion.refresh(ctx.persistent_allocator, &self.workspace.editor, &completion_items) catch {};
                ctx.requestRedraw();
            },
            .completion_accept => {
                _ = self.workspace.completion.handleKey(ctx.persistent_allocator, &self.workspace.editor, .tab, &completion_items) catch false;
                self.workspace.status_text = "Completion accepted";
                ctx.requestRedraw();
            },
            .completion_next => {
                _ = self.workspace.completion.handleKey(ctx.persistent_allocator, &self.workspace.editor, .down, &completion_items) catch false;
                ctx.requestRedraw();
            },
            .completion_previous => {
                _ = self.workspace.completion.handleKey(ctx.persistent_allocator, &self.workspace.editor, .up, &completion_items) catch false;
                ctx.requestRedraw();
            },
            .completion_page_up => {
                _ = self.workspace.completion.handleKey(ctx.persistent_allocator, &self.workspace.editor, .page_up, &completion_items) catch false;
                ctx.requestRedraw();
            },
            .completion_page_down => {
                _ = self.workspace.completion.handleKey(ctx.persistent_allocator, &self.workspace.editor, .page_down, &completion_items) catch false;
                ctx.requestRedraw();
            },
            .focus_next_pane => {
                self.pane_tree.focusNext();
                self.workspace.status_text = "Focused next pane";
                ctx.requestRedraw();
            },
            .focus_previous_pane => {
                self.pane_tree.focusPrevious();
                self.workspace.status_text = "Focused previous pane";
                ctx.requestRedraw();
            },
            .toggle_sidebar => {
                self.workspace.show_sidebar = !self.workspace.show_sidebar;
                self.workspace.status_text = if (self.workspace.show_sidebar) "Sidebar shown" else "Sidebar hidden";
                ctx.requestRedraw();
            },
            .toggle_problems => {
                _ = self.panel_host.toggle("problems");
                self.workspace.status_text = "Toggled problems";
                ctx.requestRedraw();
            },
        }
        return .none;
    }

    fn handlePaletteTextKey(self: *@This(), ctx: *ziggy.Context, key: ziggy.Key) void {
        switch (key) {
            .backspace => {
                self.palette.query.backspace(ctx.persistent_allocator) catch {};
                self.palette.refresh(ctx.persistent_allocator, &palette_commands) catch {};
            },
            .char => |c| {
                self.palette.query.insertChar(ctx.persistent_allocator, c) catch {};
                self.palette.refresh(ctx.persistent_allocator, &palette_commands) catch {};
            },
            .left => self.palette.query.moveLeft(),
            .right => self.palette.query.moveRight(),
            .home, .ctrl_a => self.palette.query.moveHome(),
            .end, .ctrl_e => self.palette.query.moveEnd(),
            else => {},
        }
        ctx.requestRedraw();
    }

    fn acceptPalette(self: *@This(), ctx: *ziggy.Context) void {
        const current = self.palette.current(&palette_commands) orelse return;
        self.workspace.status_text = current.label;
        if (std.mem.eql(u8, current.label, "Toggle Sidebar")) {
            self.workspace.show_sidebar = !self.workspace.show_sidebar;
        } else if (std.mem.eql(u8, current.label, "Show Diagnostics")) {
            _ = self.panel_host.toggle("problems");
        }
        self.palette.clear();
        ctx.requestRedraw();
    }

    fn handleMouse(self: *@This(), mouse: ziggy.Mouse, ctx: *ziggy.Context) void {
        const summary = self.mouse.observe(mouse, ctx.now_ms);
        if (summary.wheel_y != 0) {
            if (self.palette.open) {
                if (summary.wheel_y > 0) self.palette.moveNext() else self.palette.movePrevious();
                ctx.requestRedraw();
                return;
            }
            if (self.workspace.completion.popup.visible) {
                _ = self.workspace.completion.handleKey(
                    ctx.persistent_allocator,
                    &self.workspace.editor,
                    if (summary.wheel_y > 0) .down else .up,
                    &completion_items,
                ) catch false;
                ctx.requestRedraw();
                return;
            }
        }

        if (!mouse.pressed) return;

        const hovered = if (mouse.x < 24)
            "sidebar"
        else if (mouse.x < 78)
            "editor"
        else if (mouse.y < 14)
            "symbols"
        else
            "preview";
        if (self.hover.update(hovered, ctx.now_ms)) {
            self.workspace.status_text = hovered;
        }

        if (mouse.button != .left) {
            ctx.requestRedraw();
            return;
        }

        if (mouse.x < 24) {
            self.workspace.show_sidebar = true;
            self.workspace.sidebar_selected = @min(@as(usize, if (mouse.y > 3) mouse.y - 3 else 0), sidebar_items.len - 1);
            self.workspace.status_text = sidebar_items[self.workspace.sidebar_selected];
        } else if (mouse.x < 78) {
            _ = self.pane_tree.focusPane(1);
            self.workspace.status_text = if (summary.click_count >= 2) "Editor pane activated" else "Editor pane focused";
        } else if (mouse.y < 14) {
            _ = self.pane_tree.focusPane(2);
            self.workspace.status_text = "Symbols pane focused";
        } else {
            _ = self.pane_tree.focusPane(3);
            self.workspace.status_text = "Preview pane focused";
        }
        ctx.requestRedraw();
    }

    pub fn viewNode(self: *@This(), ctx: *ziggy.Context) !*const ziggy.Node {
        const theme = ziggy.defaultAgentTheme();
        self.workspace.syncViewport(60, 14, "> ");

        const editor_pane = try workspace_support.buildEditorPane(
            ctx.allocator,
            &self.workspace,
            tabs[self.workspace.active_tab],
            theme,
            14,
        );

        const utility_panel = if (self.palette.open) blk: {
            const labels = try self.palette.labels(ctx.allocator, &palette_commands);
            defer ctx.allocator.free(labels);
            break :blk try ziggy.CommandDialog.build(ctx.allocator, "Command Palette", self.palette.query.value, labels, .{
                .selected = self.palette.selected,
                .offset = self.palette.offset,
                .cursor = self.palette.query.cursor,
                .hint = "Ctrl+P toggles, arrows move, Enter accepts",
                .style = theme.pane,
                .selected_style = theme.selected,
                .box_style = theme.pane,
                .border_style = theme.border_style,
            });
        } else if (self.workspace.completion.popup.visible) blk: {
            break :blk (try ziggy.AutocompletePopup.build(ctx.allocator, &self.workspace.completion.popup, .{
                .title = "Completions",
                .hint = "Tab accepts",
                .style = theme.pane,
                .selected_style = theme.selected_alt,
                .box_style = theme.pane,
                .border_style = theme.border_style,
            })) orelse try ziggy.Card.build(ctx.allocator, "Inspector", .{
                .subtitle = "fallback",
                .body = "completion popup hidden",
                .style = theme.pane,
                .border_style = theme.border_style,
            });
        } else blk: {
            const palette_detail = if (self.palette.current(&palette_commands)) |entry|
                entry.detail orelse "select a command to inspect it"
            else
                "open the palette to inspect a command";
            const detail_card = try ziggy.Card.build(ctx.allocator, "Palette Detail", .{
                .subtitle = "controller state",
                .body = palette_detail,
                .style = theme.pane,
                .border_style = theme.border_style,
            });
            const intro = try ziggy.Card.build(ctx.allocator, "Inspector", .{
                .subtitle = "ziged-shaped workspace",
                .body =
                \\This demo restores a saved workspace session through `ziggy` hooks.
                \\
                \\- pane tree snapshot restore
                \\- panel host snapshot restore
                \\- editor cursor and viewport restore
                \\- action-scoped key routing
                \\- command palette controller
                \\- completion controller
                ,
                .style = theme.pane,
                .border_style = theme.border_style,
            });
            break :blk try ziggy.VStack.build(ctx.allocator, &.{ intro, detail_card }, 1);
        };

        const symbol_panel = try ziggy.Card.build(ctx.allocator, "Symbols", .{
            .subtitle = "secondary pane",
            .body =
            \\pub fn main
            \\pub fn initSession
            \\pub fn restoreWorkspace
            \\pub fn renderChrome
            ,
            .style = theme.pane,
            .border_style = theme.border_style,
        });
        const preview_panel = try ziggy.Card.build(ctx.allocator, "Preview", .{
            .subtitle = "third pane",
            .body =
            \\Workspace:
            \\- project: ziged
            \\- branch: ziged-readiness-plan
            \\- focus pane: restored
            \\- overlays: palette/completion
            ,
            .style = theme.pane,
            .border_style = theme.border_style,
        });
        const pane_body = try self.pane_tree.build(ctx.allocator, ctx.size, &.{
            .{ .id = 1, .node = editor_pane },
            .{ .id = 2, .node = symbol_panel },
            .{ .id = 3, .node = preview_panel },
        });
        const problems_panel = try ziggy.Card.build(ctx.allocator, "Problems", .{
            .subtitle = "bottom dock",
            .body =
            \\0 errors
            \\0 warnings
            \\session restored from persistent UI hooks
            ,
            .style = theme.pane,
            .border_style = theme.border_style,
        });
        const terminal_panel = try ziggy.Card.build(ctx.allocator, "Terminal", .{
            .subtitle = "bottom dock",
            .body =
            \\> zig build test
            \\> zig build example-editor
            \\all green
            ,
            .style = theme.pane,
            .border_style = theme.border_style,
        });
        const body = try self.panel_host.build(ctx.allocator, ctx.size, pane_body, &.{
            .{ .id = "utility", .node = utility_panel },
            .{ .id = "problems", .node = problems_panel },
            .{ .id = "terminal", .node = terminal_panel },
        });
        return try workspace_support.buildWorkspaceShell(
            ctx.allocator,
            ctx.size,
            "ziged Workspace Demo",
            &tabs,
            self.workspace.active_tab,
            "Workspace",
            &sidebar_items,
            self.workspace.sidebar_selected,
            body,
            "ziged-workspace",
            "Ctrl+C quits",
            self.workspace.status_text,
            &footer_hints,
            theme,
            self.workspace.show_sidebar,
        );
    }
};

fn buildSavedSession(allocator: std.mem.Allocator) !DemoSession {
    var temp_tree = try ziggy.PaneTree.State.initSingle(allocator, 1);
    defer temp_tree.deinit();
    _ = try temp_tree.splitFocused(.horizontal, 2);
    _ = try temp_tree.splitFocused(.vertical, 3);
    _ = temp_tree.focusPane(1);

    var temp_panels: ziggy.PanelHost.State = .{};
    defer temp_panels.deinit(allocator);
    try temp_panels.add(allocator, "utility", .right, 30, true);
    try temp_panels.add(allocator, "problems", .bottom, 8, true);
    try temp_panels.add(allocator, "terminal", .bottom, 8, false);

    var temp_palette = try ziggy.PaletteController.State.init(allocator, "diag");
    defer temp_palette.deinit(allocator);
    try temp_palette.refresh(allocator, &palette_commands);
    temp_palette.selected = 4;

    return .{
        .active_tab = 2,
        .sidebar_selected = 2,
        .show_sidebar = true,
        .pane_tree = try temp_tree.snapshot(allocator),
        .panels = try temp_panels.snapshot(allocator),
        .palette = try temp_palette.snapshot(allocator),
        .editor = .{
            .cursor = 48,
            .selection_anchor = null,
            .viewport = .{
                .offset_line = 0,
                .offset_column = 0,
                .width = 60,
                .height = 14,
                .scroll_margin = 1,
            },
        },
    };
}

fn restoreSavedSession(model: *Model, allocator: std.mem.Allocator, session: *const DemoSession) !void {
    model.pane_tree.deinit();
    model.pane_tree = try ziggy.PaneTree.State.restore(allocator, session.pane_tree);
    try model.panel_host.restore(allocator, session.panels);
    try model.palette.restore(allocator, session.palette, &palette_commands);
    ziggy.EditorViewState.restore(&model.workspace.editor, session.editor);
    model.workspace.viewport = session.editor.viewport;
    model.workspace.active_tab = session.active_tab;
    model.workspace.sidebar_selected = session.sidebar_selected;
    model.workspace.show_sidebar = session.show_sidebar;
    model.workspace.status_text = "Session restored";
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const initial =
        \\const std = @import("std");
        \\
        \\pub fn main() !void {
        \\    std.debug.print("hello from ziggy editor demo\\n", .{});
        \\}
    ;

    var session = try buildSavedSession(allocator);
    defer session.deinit(allocator);

    var model: Model = .{
        .workspace = try workspace_support.EditorWorkspaceState.init(allocator, initial),
        .pane_tree = try ziggy.PaneTree.State.initSingle(allocator, 1),
        .panel_host = .{},
        .palette = try ziggy.PaletteController.State.init(allocator, ""),
        .actions = ziggy.ActionRouter(Scope, Action).init(allocator),
    };
    defer model.workspace.deinit(allocator);
    defer model.pane_tree.deinit();
    defer model.panel_host.deinit(allocator);
    defer model.palette.deinit(allocator);
    defer model.actions.deinit();
    try restoreSavedSession(&model, allocator, &session);
    try model.actions.bindGlobal(.ctrl_c, .quit);
    try model.actions.bindGlobal(.ctrl_p, .open_palette);
    try model.actions.bindGlobal(.escape, .close_overlay);
    try model.actions.bind(.palette, .down, .palette_next);
    try model.actions.bind(.palette, .up, .palette_previous);
    try model.actions.bind(.palette, .page_down, .palette_page_down);
    try model.actions.bind(.palette, .page_up, .palette_page_up);
    try model.actions.bind(.palette, .enter, .palette_accept);
    try model.actions.bind(.workspace, .ctrl_space, .completion_open);
    try model.actions.bind(.completion, .tab, .completion_accept);
    try model.actions.bind(.completion, .enter, .completion_accept);
    try model.actions.bind(.completion, .down, .completion_next);
    try model.actions.bind(.completion, .up, .completion_previous);
    try model.actions.bind(.completion, .page_down, .completion_page_down);
    try model.actions.bind(.completion, .page_up, .completion_page_up);
    try model.actions.bind(.workspace, .ctrl_n, .focus_next_pane);
    try model.actions.bind(.workspace, .ctrl_r, .focus_previous_pane);

    try support.runInteractiveProgram(Model, Msg, allocator, model, .{
        .title = "ziggy editor demo",
        .tick_interval_ms = 0,
    });
}
