const std = @import("std");
const node_mod = @import("node.zig");
const pane = @import("pane.zig");
const completion = @import("completion.zig");
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

    return try pane.buildSelectableList(allocator, options.title, labels, .{
        .selected = state.selected,
        .focused = true,
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
