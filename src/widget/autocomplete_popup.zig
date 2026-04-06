const std = @import("std");
const completion = @import("completion.zig");
const completion_menu = @import("completion_menu.zig");
const box = @import("box.zig");
const text = @import("text.zig");
const vstack = @import("vstack.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");
const focus_mod = @import("focus.zig");
const surface_mod = @import("surface.zig");

pub const Options = struct {
    title: []const u8 = "Autocomplete",
    anchor: ?surface_mod.Rect = null,
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    box_style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .single,
    hint: ?[]const u8 = null,
    hint_style: style_mod.Style = .{ .dim = true },
    focus: focus_mod.FocusState = .{},
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
    });
    const body = try vstack.build(allocator, &.{ menu, hint }, 1);
    return try box.buildWithOptions(allocator, null, body, .{
        .style = options.box_style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
    });
}

test "autocomplete popup hides when invisible" {
    var state: completion.State = .{};
    defer state.deinit(std.testing.allocator);
    try std.testing.expect((try build(std.testing.allocator, &state, .{})) == null);
}
