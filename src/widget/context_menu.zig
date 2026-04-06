const std = @import("std");
const parser = @import("../terminal/parser.zig");
const box = @import("box.zig");
const text = @import("text.zig");
const vstack = @import("vstack.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");
const node_mod = @import("node.zig");

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
    }

    pub fn hide(self: *State) void {
        self.visible = false;
    }
};

pub fn handleKey(state: *State, items: []const Item, key: parser.Key) void {
    if (!state.visible or items.len == 0) return;
    switch (key) {
        .up => {
            if (state.cursor > 0) state.cursor -= 1;
        },
        .down => {
            if (state.cursor + 1 < items.len) state.cursor += 1;
        },
        .escape => state.visible = false,
        .enter => {
            if (items[state.cursor].enabled) {
                state.selected = state.cursor;
                state.visible = false;
            }
        },
        else => {},
    }
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
