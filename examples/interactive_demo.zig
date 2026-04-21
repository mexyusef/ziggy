const std = @import("std");
const ziggy = @import("ziggy");
const support = @import("support.zig");

const commands = [_][]const u8{
    "Open Session",
    "Switch Model",
    "Review Diff",
    "Compact Context",
    "Doctor",
    "Toggle Sidebar",
};

const Msg = ziggy.Event;

const Model = struct {
    palette: ziggy.CommandDialog.State,
    palette_open: bool = true,
    notice: []const u8 = "Ctrl+P opens palette. j/k or arrows move. Enter accepts. Esc quits.",

    pub fn init(self: *@This(), ctx: *ziggy.Context) ziggy.Command(Msg) {
        _ = self;
        ctx.requestRedraw();
        return .none;
    }

    pub fn update(self: *@This(), event: Msg, ctx: *ziggy.Context) ziggy.Command(Msg) {
        switch (event) {
            .key => |key| switch (key) {
                .ctrl_c, .escape => return .quit,
                .ctrl_p => {
                    self.palette_open = true;
                    ctx.requestRedraw();
                },
                .up, .down, .page_up, .page_down, .home, .end => {
                    if (self.palette_open) {
                        _ = self.palette.handleEvent(ctx.persistent_allocator, &commands, key) catch .{};
                        ctx.requestRedraw();
                    }
                },
                .enter => {
                    if (self.palette_open) {
                        const response = self.palette.handleEvent(ctx.persistent_allocator, &commands, .enter) catch return .none;
                        if (response.action == .submitted) {
                            if (response.selected) |selected| {
                                self.notice = commands[selected];
                                self.palette_open = false;
                                ctx.requestRedraw();
                            }
                        }
                    }
                },
                .backspace => {
                    _ = self.palette.query.handleEvent(ctx.persistent_allocator, .backspace) catch .{};
                    self.palette_open = true;
                    ctx.requestRedraw();
                },
                .char => |c| {
                    switch (c) {
                        'j', 'J' => {
                            if (self.palette_open) {
                                _ = self.palette.handleEvent(ctx.persistent_allocator, &commands, .down) catch .{};
                            } else {
                                _ = self.palette.query.handleEvent(ctx.persistent_allocator, .{ .char = c }) catch .{};
                                self.palette_open = true;
                            }
                        },
                        'k', 'K' => {
                            if (self.palette_open) {
                                _ = self.palette.handleEvent(ctx.persistent_allocator, &commands, .up) catch .{};
                            } else {
                                _ = self.palette.query.handleEvent(ctx.persistent_allocator, .{ .char = c }) catch .{};
                                self.palette_open = true;
                            }
                        },
                        else => {
                            _ = self.palette.query.handleEvent(ctx.persistent_allocator, .{ .char = c }) catch .{};
                            self.palette_open = true;
                        },
                    }
                    ctx.requestRedraw();
                },
                else => {},
            },
            else => {},
        }
        return .none;
    }

    pub fn viewNode(self: *@This(), ctx: *ziggy.Context) !*const ziggy.Node {
        const theme = ziggy.defaultAgentTheme();
        const header = try ziggy.HeaderBar.build(ctx.allocator, "ziggy Interactive Demo", .{
            .subtitle = "real keystrokes through ziggy.Program",
            .right_text = "Ctrl+C/Esc quit",
            .style = theme.pane,
            .title_style = theme.pane_active,
            .subtitle_style = theme.status_idle,
            .right_style = theme.selected_alt,
            .border_style = theme.border_style,
        });

        const query_input = try ziggy.Input.build(
            ctx.allocator,
            "> ",
            try ctx.allocator.dupe(u8, self.palette.query.editor.value),
            self.palette.query.editor.cursor,
            true,
            theme.pane,
        );
        const input_box = try ziggy.Box.buildWithOptions(ctx.allocator, "Input", query_input, .{
            .style = theme.pane,
            .border_style = theme.border_style,
            .padding_left = 1,
            .padding_right = 1,
        });

        const body = if (self.palette_open) blk: {
            break :blk try ziggy.CommandDialog.build(ctx.allocator, "Command Palette", self.palette.query.editor.value, &commands, .{
                .selected = self.palette.results.cursor,
                .cursor = self.palette.query.editor.cursor,
                .hint = "Type to edit query. j/k and arrows move. Enter selects.",
                .style = theme.pane,
                .selected_style = theme.selected,
                .box_style = theme.pane,
                .border_style = theme.border_style,
            });
        } else blk: {
            const alert = try ziggy.Alert.build(ctx.allocator, .{
                .level = .success,
                .label = "SELECTED",
                .message = self.notice,
                .style = theme.pane,
                .text_style = theme.status_idle,
                .border_style = theme.border_style,
            });
            break :blk alert;
        };

        const footer = try ziggy.FooterBar.build(ctx.allocator, "interactive", "Esc quits", .{
            .center = self.notice,
            .style = theme.pane,
            .left_style = theme.selected_alt,
            .center_style = theme.status_idle,
            .right_style = theme.status_idle,
            .border_style = theme.border_style,
        });

        return try ziggy.VStack.buildWithWeights(ctx.allocator, &.{ header, body, input_box, footer }, 1, &.{ 0, 1, 0, 0 });
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var palette = try ziggy.CommandDialog.State.init(allocator, "");
    defer palette.deinit(allocator);
    const model: Model = .{ .palette = palette };
    try support.runInteractiveProgram(Model, Msg, allocator, model, .{
        .title = "ziggy interactive demo",
        .tick_interval_ms = 0,
    });
}
