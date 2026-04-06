const std = @import("std");
const completion = @import("completion.zig");
const completion_menu = @import("completion_menu.zig");
const node_mod = @import("node.zig");
const text = @import("text.zig");
const vstack = @import("vstack.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");
const focus_mod = @import("focus.zig");

pub const Options = struct {
    title: []const u8 = "Palette",
    hint: ?[]const u8 = null,
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    box_style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .double,
    focus: focus_mod.FocusState = .{},
    hint_style: style_mod.Style = .{ .fg = .{ .ansi = 8 }, .dim = true },
};

pub fn build(
    allocator: std.mem.Allocator,
    state: *const completion.State,
    options: Options,
) !?*const node_mod.Node {
    const menu = (try completion_menu.build(allocator, state, .{
        .title = options.title,
        .style = options.style,
        .selected_style = options.selected_style,
        .box_style = options.box_style,
        .border_style = options.border_style,
        .focus = options.focus,
    })) orelse return null;

    if (options.hint == null) return menu;

    const hint = try text.buildWithOptions(allocator, try allocator.dupe(u8, options.hint.?), .{
        .style = options.hint_style,
        .wrap = .truncate_end,
        .alignment = .left,
    });
    return try vstack.build(allocator, &.{ menu, hint }, 1);
}

test "palette hides when completion is hidden" {
    var state: completion.State = .{};
    defer state.deinit(std.testing.allocator);
    try std.testing.expect((try build(std.testing.allocator, &state, .{})) == null);
}
