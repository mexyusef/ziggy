const std = @import("std");
const box = @import("box.zig");
const text = @import("text.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");
const node_mod = @import("node.zig");
const parser = @import("../terminal/parser.zig");
const interaction = @import("../interaction/widget.zig");
const surface_mod = @import("surface.zig");

pub const Item = struct {
    depth: usize,
    label: []const u8,
    expanded: bool = false,
};

pub const Options = struct {
    title: ?[]const u8 = "Tree",
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    border_style: border_mod.BorderStyle = .single,
};

pub const State = struct {
    selection: interaction.SelectState = .{},
};

pub fn build(allocator: std.mem.Allocator, items: []const Item, options: Options) !*const node_mod.Node {
    return buildState(allocator, items, .{}, options);
}

pub fn buildState(
    allocator: std.mem.Allocator,
    items: []const Item,
    state: State,
    options: Options,
) !*const node_mod.Node {
    var builder = std.ArrayList(u8).empty;
    const writer = builder.writer(allocator);
    for (items, 0..) |item, index| {
        if (index > 0) try writer.writeByte('\n');
        try writer.writeAll(if (index == state.selection.cursor and items.len > 0) "> " else "  ");
        for (0..item.depth) |_| try writer.writeAll("  ");
        try writer.print("{s} {s}", .{ if (item.expanded) "▼" else "▶", item.label });
    }
    const body = try builder.toOwnedSlice(allocator);
    return try box.buildWithOptions(allocator, options.title, try text.buildWithOptions(allocator, body, .{
        .style = if (items.len > 0 and state.selection.focused) options.selected_style else options.style,
        .wrap = .none,
    }), .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
}

pub fn handleEvent(state: *State, items: []Item, key: parser.Key) interaction.Response {
    switch (key) {
        .left => {
            if (items.len == 0) return .{};
            const index = state.selection.cursor;
            if (index < items.len and items[index].expanded) {
                items[index].expanded = false;
                return .{ .handled = true, .redraw = true, .action = .changed, .selected = index };
            }
            return .{};
        },
        .right => {
            if (items.len == 0) return .{};
            const index = state.selection.cursor;
            if (index < items.len and !items[index].expanded) {
                items[index].expanded = true;
                return .{ .handled = true, .redraw = true, .action = .changed, .selected = index };
            }
            return .{};
        },
        else => return state.selection.handleListKey(items.len, key),
    }
}

pub fn hitTestItem(rect: surface_mod.Rect, item_count: usize, x: u16, y: u16) ?usize {
    const local = rect.localPoint(x, y) orelse return null;
    if (local.y == 0 or local.y >= rect.height -| 1) return null;
    const item_index = @as(usize, local.y - 1);
    if (item_index >= item_count) return null;
    return item_index;
}

test "tree builds hierarchical labels" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const items = [_]Item{
        .{ .depth = 0, .label = "project", .expanded = true },
        .{ .depth = 1, .label = "src", .expanded = true },
    };
    const node = try build(alloc, &items, .{});
    try std.testing.expect(node.* == .box);
}

test "tree state expands and navigates" {
    var items = [_]Item{
        .{ .depth = 0, .label = "project", .expanded = false },
        .{ .depth = 1, .label = "src", .expanded = false },
    };
    var state: State = .{};
    const expand = handleEvent(&state, &items, .right);
    try std.testing.expectEqual(interaction.Action.changed, expand.action);
    try std.testing.expect(items[0].expanded);
    _ = handleEvent(&state, &items, .down);
    try std.testing.expectEqual(@as(usize, 1), state.selection.cursor);
}
