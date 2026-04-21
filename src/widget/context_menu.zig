const std = @import("std");
const parser = @import("../terminal/parser.zig");
const box = @import("box.zig");
const text = @import("text.zig");
const vstack = @import("vstack.zig");
const selection_model = @import("selection_model.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");
const node_mod = @import("node.zig");
const interaction = @import("../interaction/widget.zig");

pub const Item = struct {
    label: []const u8,
    shortcut: ?[]const u8 = null,
    enabled: bool = true,
};

pub const State = struct {
    visible: bool = false,
    cursor: usize = 0,
    selected: ?usize = null,

    pub fn show(self: *State) void {
        self.visible = true;
        self.selected = null;
        self.cursor = 0;
    }

    pub fn hide(self: *State) void {
        self.visible = false;
    }
};

pub fn handleEvent(state: *State, items: []const Item, key: parser.Key) interaction.Response {
    if (!state.visible or items.len == 0) return .{};
    var select: interaction.SelectState = .{
        .open = state.visible,
        .cursor = state.cursor,
        .selected = state.selected,
    };
    defer {
        state.visible = select.open;
        state.cursor = select.cursor;
        state.selected = select.selected;
    }
    select.normalize(items.len);
    switch (key) {
        .up => return select.moveEnabled(Item, items, .previous),
        .down => return select.moveEnabled(Item, items, .next),
        .escape => return select.closeMenu(),
        .enter => {
            const response = select.activateEnabled(Item, items);
            if (response.action == .submitted) select.open = false;
            return response;
        },
        else => return .{},
    }
}

pub fn handleKey(state: *State, items: []const Item, key: parser.Key) void {
    _ = handleEvent(state, items, key);
}

pub const Options = struct {
    title: ?[]const u8 = "Menu",
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    disabled_style: style_mod.Style = .{ .dim = true },
    border_style: border_mod.BorderStyle = .single,
};

pub fn build(allocator: std.mem.Allocator, items: []const Item, state: State, options: Options) !*const node_mod.Node {
    const rows = try allocator.alloc(*const node_mod.Node, items.len);
    for (items, 0..) |item, index| {
        const prefix = if (index == state.cursor) "> " else "  ";
        const line = if (item.shortcut) |shortcut|
            try std.fmt.allocPrint(allocator, "{s}{s:<24} {s}", .{ prefix, item.label, shortcut })
        else
            try std.fmt.allocPrint(allocator, "{s}{s}", .{ prefix, item.label });
        rows[index] = try text.buildWithOptions(allocator, line, .{
            .style = if (!item.enabled) options.disabled_style else if (index == state.cursor) options.selected_style else options.style,
            .wrap = .truncate_end,
        });
    }
    return try box.buildWithOptions(allocator, options.title, try vstack.build(allocator, rows, 0), .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
}

test "context menu selects current item" {
    const items = [_]Item{ .{ .label = "Open" }, .{ .label = "Delete" } };
    var state: State = .{ .visible = true };
    handleKey(&state, &items, .down);
    handleKey(&state, &items, .enter);
    try std.testing.expectEqual(@as(?usize, 1), state.selected);
}

test "context menu skips disabled items" {
    const items = [_]Item{ .{ .label = "Open", .enabled = true }, .{ .label = "Delete", .enabled = false }, .{ .label = "Rename", .enabled = true } };
    var state: State = .{ .visible = true };
    handleKey(&state, &items, .down);
    try std.testing.expectEqual(@as(usize, 2), state.cursor);
}

test "context menu event closes on submit" {
    const items = [_]Item{ .{ .label = "Open" }, .{ .label = "Delete" } };
    var state: State = .{ .visible = true };
    _ = handleEvent(&state, &items, .down);
    const response = handleEvent(&state, &items, .enter);
    try std.testing.expectEqual(interaction.Action.submitted, response.action);
    try std.testing.expect(!state.visible);
}
