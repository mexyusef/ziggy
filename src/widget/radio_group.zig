const std = @import("std");
const parser = @import("../terminal/parser.zig");
const box = @import("box.zig");
const text = @import("text.zig");
const vstack = @import("vstack.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");
const node_mod = @import("node.zig");

pub const State = struct {
    items: []const []const u8,
    selected: usize = 0,
    cursor: usize = 0,
    focused: bool = true,
};

pub fn handleKey(state: *State, key: parser.Key) void {
    if (!state.focused or state.items.len == 0) return;
    switch (key) {
        .up => {
            if (state.cursor > 0) state.cursor -= 1;
        },
        .down => {
            if (state.cursor + 1 < state.items.len) state.cursor += 1;
        },
        .enter, .tab => state.selected = state.cursor,
        .char => |c| {
            if (c == ' ') state.selected = state.cursor;
        },
        else => {},
    }
}

pub const Options = struct {
    title: ?[]const u8 = "Options",
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    border_style: border_mod.BorderStyle = .single,
};

pub fn build(allocator: std.mem.Allocator, state: State, options: Options) !*const node_mod.Node {
    const rows = try allocator.alloc(*const node_mod.Node, state.items.len);
    for (state.items, 0..) |item, index| {
        const radio = if (index == state.selected) "(*)" else "( )";
        const cursor = if (index == state.cursor and state.focused) "> " else "  ";
        rows[index] = try text.buildWithOptions(allocator, try std.fmt.allocPrint(allocator, "{s}{s} {s}", .{ cursor, radio, item }), .{
            .style = if (index == state.cursor) options.selected_style else options.style,
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

test "radio group selects current cursor" {
    var state: State = .{ .items = &.{ "a", "b" } };
    handleKey(&state, .down);
    handleKey(&state, .enter);
    try std.testing.expectEqual(@as(usize, 1), state.selected);
}
