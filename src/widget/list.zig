const std = @import("std");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const focus_mod = @import("focus.zig");
const parser = @import("../terminal/parser.zig");
const interaction = @import("../interaction/widget.zig");

pub const Options = struct {
    selected: usize = 0,
    offset: usize = 0,
    marker: []const u8 = "> ",
    unselected_marker: []const u8 = "  ",
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    focus: focus_mod.FocusState = .{},
};

pub const State = struct {
    selection: interaction.SelectState = .{},
};

pub fn handleEvent(state: *State, items: []const []const u8, key: parser.Key) interaction.Response {
    return state.selection.handleListKey(items.len, key);
}

pub fn build(
    allocator: std.mem.Allocator,
    items: []const []const u8,
    options: Options,
) !*const node_mod.Node {
    const owned_items = try allocator.alloc([]const u8, items.len);
    @memcpy(owned_items, items);
    return try node_mod.allocNode(allocator, .{
        .list = .{
            .items = owned_items,
            .selected = options.selected,
            .offset = options.offset,
            .marker = options.marker,
            .unselected_marker = options.unselected_marker,
            .style = options.style,
            .selected_style = options.selected_style,
            .focus = options.focus,
        },
    });
}

pub fn buildState(
    allocator: std.mem.Allocator,
    items: []const []const u8,
    state: State,
    options: Options,
) !*const node_mod.Node {
    return build(allocator, items, .{
        .selected = state.selection.cursor,
        .offset = state.selection.offset,
        .marker = options.marker,
        .unselected_marker = options.unselected_marker,
        .style = options.style,
        .selected_style = options.selected_style,
        .focus = options.focus,
    });
}

test "list state moves and submits" {
    const items = [_][]const u8{ "a", "b", "c" };
    var state: State = .{};
    _ = handleEvent(&state, &items, .down);
    try std.testing.expectEqual(@as(usize, 1), state.selection.cursor);
    const response = handleEvent(&state, &items, .enter);
    try std.testing.expectEqual(interaction.Action.submitted, response.action);
    try std.testing.expectEqual(@as(?usize, 1), response.selected);
}

test "list build owns the item slice" {
    var labels = try std.testing.allocator.alloc([]const u8, 2);
    defer std.testing.allocator.free(labels);
    labels[0] = "one";
    labels[1] = "two";

    const node = try build(std.testing.allocator, labels, .{});
    defer std.testing.allocator.destroy(@constCast(node));
    defer std.testing.allocator.free(node.list.items);

    try std.testing.expect(node.* == .list);
    try std.testing.expect(@intFromPtr(node.list.items.ptr) != @intFromPtr(labels.ptr));
    labels[0] = "mutated";
    try std.testing.expectEqualStrings("one", node.list.items[0]);
}
