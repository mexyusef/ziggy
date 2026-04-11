const std = @import("std");
const ziggy = @import("ziggy");
const support = @import("support.zig");
const workspace_support = @import("editor_workspace_support.zig");

const Msg = ziggy.Event;

const tabs = [_][]const u8{
    "main.zig",
    "build.zig",
    "README.md",
};

const sidebar_items = [_][]const u8{
    "Explorer",
    "Search",
    "Symbols",
    "Diagnostics",
};

const footer_hints = [_][]const u8{
    "Ctrl+P Palette",
    "Ctrl+Space Complete",
    "Tab Accept/Indent",
    "Ctrl+C Quit",
};

const palette_commands = [_][]const u8{
    "Open File",
    "Switch Buffer",
    "Toggle Sidebar",
    "Format Document",
    "Show Diagnostics",
    "Open Command Palette",
};

const completion_items = [_]ziggy.Completion.Item{
    .{ .label = "const", .value = "const ", .detail = "immutable binding" },
    .{ .label = "var", .value = "var ", .detail = "mutable binding" },
    .{ .label = "pub fn", .value = "pub fn ", .detail = "public function" },
    .{ .label = "try", .value = "try ", .detail = "error propagation" },
    .{ .label = "defer", .value = "defer ", .detail = "cleanup" },
};

const Model = struct {
    workspace: workspace_support.EditorWorkspaceState,
    palette_open: bool = false,
    palette_selected: usize = 0,
    palette_query: ziggy.Editor,

    pub fn init(self: *@This(), ctx: *ziggy.Context) ziggy.Command(Msg) {
        _ = self;
        ctx.requestRedraw();
        return .none;
    }

    pub fn update(self: *@This(), event: Msg, ctx: *ziggy.Context) ziggy.Command(Msg) {
        switch (event) {
            .key => |key| switch (key) {
                .ctrl_c => return .quit,
                .ctrl_p => {
                    self.palette_open = !self.palette_open;
                    self.palette_selected = 0;
                    ctx.requestRedraw();
                },
                .escape => {
                    if (self.palette_open) {
                        self.palette_open = false;
                        self.workspace.status_text = "Palette closed";
                        ctx.requestRedraw();
                    }
                },
                else => {
                    if (self.palette_open) {
                        self.handlePaletteKey(ctx, key);
                    } else {
                        if (workspace_support.handleEditorKey(&self.workspace, ctx.persistent_allocator, key, &completion_items, 14) catch false) {
                            self.workspace.status_text = "Editing";
                            ctx.requestRedraw();
                        }
                    }
                },
            },
            else => {},
        }
        return .none;
    }

    fn handlePaletteKey(self: *@This(), ctx: *ziggy.Context, key: ziggy.Key) void {
        switch (key) {
            .up => {
                if (self.palette_selected > 0) self.palette_selected -= 1;
            },
            .down => {
                if (self.palette_selected + 1 < palette_commands.len) self.palette_selected += 1;
            },
            .backspace => {
                self.palette_query.backspace(ctx.persistent_allocator) catch {};
            },
            .char => |c| {
                self.palette_query.insertChar(ctx.persistent_allocator, c) catch {};
            },
            .left => self.palette_query.moveLeft(),
            .right => self.palette_query.moveRight(),
            .home, .ctrl_a => self.palette_query.moveHome(),
            .end, .ctrl_e => self.palette_query.moveEnd(),
            .enter => {
                self.workspace.status_text = palette_commands[self.palette_selected];
                if (std.mem.eql(u8, palette_commands[self.palette_selected], "Toggle Sidebar")) {
                    self.workspace.show_sidebar = !self.workspace.show_sidebar;
                }
                self.palette_open = false;
            },
            else => {},
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

        const side_panel = if (self.palette_open) blk: {
            break :blk try ziggy.CommandDialog.build(ctx.allocator, "Command Palette", self.palette_query.value, &palette_commands, .{
                .selected = self.palette_selected,
                .cursor = self.palette_query.cursor,
                .hint = "Ctrl+P toggles, arrows move, Enter accepts",
                .style = theme.pane,
                .selected_style = theme.selected,
                .box_style = theme.pane,
                .border_style = theme.border_style,
            });
        } else if (self.workspace.completion_state.visible) blk: {
            break :blk (try ziggy.AutocompletePopup.build(ctx.allocator, &self.workspace.completion_state, .{
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
            break :blk try ziggy.Card.build(ctx.allocator, "Inspector", .{
                .subtitle = "workspace state",
                .body =
                \\This editor demo is built from reusable `ziggy` primitives.
                \\
                \\- line numbers
                \\- text area viewport
                \\- scrollbar
                \\- tabs in header chrome
                \\- footer key hints
                \\- command palette side panel
                \\- completion surface
                ,
                .style = theme.pane,
                .border_style = theme.border_style,
            });
        };

        const body = try ziggy.HStack.buildWithWeights(ctx.allocator, &.{ editor_pane, side_panel }, 1, &.{ 5, 2 });
        return try workspace_support.buildWorkspaceShell(
            ctx.allocator,
            "ziggy Editor Demo",
            &tabs,
            self.workspace.active_tab,
            "Workspace",
            &sidebar_items,
            self.workspace.sidebar_selected,
            body,
            "editor-demo",
            "Ctrl+C quits",
            self.workspace.status_text,
            &footer_hints,
            theme,
            self.workspace.show_sidebar,
        );
    }
};

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

    var model: Model = .{
        .workspace = try workspace_support.EditorWorkspaceState.init(allocator, initial),
        .palette_query = try ziggy.Editor.init(allocator, ""),
    };
    defer model.workspace.deinit(allocator);
    defer model.palette_query.deinit(allocator);

    try support.runInteractiveProgram(Model, Msg, allocator, model, .{
        .title = "ziggy editor demo",
        .tick_interval_ms = 0,
    });
}
