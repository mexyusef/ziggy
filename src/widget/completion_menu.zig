const std = @import("std");
const node_mod = @import("node.zig");
const pane = @import("pane.zig");
const completion = @import("completion.zig");
const selection_model = @import("selection_model.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");
const focus_mod = @import("focus.zig");

pub const Options = struct {
    title: []const u8 = "Completions",
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    box_style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .single,
    focus: focus_mod.FocusState = .{},
    max_visible_items: usize = 8,
};

pub fn build(
    allocator: std.mem.Allocator,
    state: *const completion.State,
    options: Options,
) !?*const node_mod.Node {
    if (!state.visible or state.matches.len == 0) return null;

    var labels = try allocator.alloc([]const u8, state.matches.len);
    for (state.matches, 0..) |match, index| {
        labels[index] = match.item.label;
    }

    const viewport = @max(@min(options.max_visible_items, state.matches.len), 1);
    const offset = selection_model.windowOffset(state.selected, state.matches.len, viewport, 0);

    return try pane.buildSelectableList(allocator, options.title, labels, .{
        .selected = state.selected,
        .offset = offset,
        .focused = options.focus.active,
        .style = options.style,
        .selected_style = options.selected_style,
        .box_style = options.box_style,
        .border_style = options.border_style,
        .focus = options.focus,
    });
}

test "completion menu hides when state is hidden" {
    var state: completion.State = .{};
    defer state.deinit(std.testing.allocator);
    try std.testing.expect((try build(std.testing.allocator, &state, .{})) == null);
}

test "completion menu builds with viewport offset" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var state: completion.State = .{
        .matches = try allocator.alloc(completion.Match, 10),
        .selected = 7,
        .visible = true,
    };

    for (state.matches) |*match| {
        match.* = .{ .item = .{ .label = "item", .value = "item" } };
    }

    const node = (try build(allocator, &state, .{ .max_visible_items = 4 })).?;
    try std.testing.expect(node.* == .box);
}
