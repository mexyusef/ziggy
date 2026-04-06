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
    enabled: bool = true,
};

pub const State = struct {
    expanded: bool = false,
    cursor: usize = 0,
    selected: ?usize = null,
    focused: bool = true,
};

pub fn handleKey(state: *State, items: []const Item, key: parser.Key) void {
    if (!state.focused or items.len == 0) return;
    if (!state.expanded) {
        switch (key) {
            .enter, .down, .tab => state.expanded = true,
            else => {},
        }
        return;
    }
    switch (key) {
        .up => {
            if (state.cursor > 0) state.cursor -= 1;
        },
        .down => {
            if (state.cursor + 1 < items.len) state.cursor += 1;
        },
        .escape => state.expanded = false,
        .enter, .tab => {
            if (items[state.cursor].enabled) state.selected = state.cursor;
            state.expanded = false;
        },
        else => {},
    }
}

pub const Options = struct {
    title: ?[]const u8 = "Dropdown",
    placeholder: []const u8 = "Select...",
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    disabled_style: style_mod.Style = .{ .dim = true },
    border_style: border_mod.BorderStyle = .single,
};

pub fn build(allocator: std.mem.Allocator, items: []const Item, state: State, options: Options) !*const node_mod.Node {
    const trigger_text = if (state.selected) |index| items[index].label else options.placeholder;
    const trigger = try text.buildWithOptions(allocator, try std.fmt.allocPrint(allocator, "{s} {s}", .{ trigger_text, if (state.expanded) "▲" else "▼" }), .{
        .style = options.style,
        .wrap = .truncate_end,
    });
    if (!state.expanded) {
        return try box.buildWithOptions(allocator, options.title, trigger, .{
            .style = options.style,
            .border_style = options.border_style,
            .padding_left = 1,
            .padding_right = 1,
            .padding_top = 1,
            .padding_bottom = 1,
        });
    }
    const rows = try allocator.alloc(*const node_mod.Node, items.len + 1);
    rows[0] = trigger;
    for (items, 0..) |item, index| {
        const prefix = if (index == state.cursor) "> " else "  ";
        rows[index + 1] = try text.buildWithOptions(allocator, try std.fmt.allocPrint(allocator, "{s}{s}", .{ prefix, item.label }), .{
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

test "dropdown chooses item" {
    const items = [_]Item{ .{ .label = "A" }, .{ .label = "B" } };
    var state: State = .{};
    handleKey(&state, &items, .enter);
    handleKey(&state, &items, .down);
    handleKey(&state, &items, .enter);
    try std.testing.expectEqual(@as(?usize, 1), state.selected);
}
