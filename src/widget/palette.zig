const std = @import("std");
const completion = @import("completion.zig");
const completion_menu = @import("completion_menu.zig");
const node_mod = @import("node.zig");
const text = @import("text.zig");
const box = @import("box.zig");
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
    detail_title: []const u8 = "Details",
    detail_style: style_mod.Style = .{},
    detail_box_style: style_mod.Style = .{},
    max_visible_items: usize = 7,
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
        .max_visible_items = options.max_visible_items,
    })) orelse return null;

    const current = state.current();
    const detail_text = if (current) |match| match.item.detail orelse match.item.value else "";
    const detail_and_hint = if (options.hint) |hint|
        try std.fmt.allocPrint(allocator, "{s}\n\n{s}", .{ detail_text, hint })
    else
        try allocator.dupe(u8, detail_text);
    const detail_body = try text.buildWithOptions(allocator, detail_and_hint, .{
        .style = options.detail_style,
        .wrap = .word,
        .alignment = .left,
    });
    const detail_box = try box.buildWithOptions(allocator, options.detail_title, detail_body, .{
        .style = options.detail_box_style,
        .border_style = .single,
    });
    return try vstack.buildWithWeights(allocator, &.{ menu, detail_box }, 1, &.{ 6, 2 });
}

test "palette hides when completion is hidden" {
    var state: completion.State = .{};
    defer state.deinit(std.testing.allocator);
    try std.testing.expect((try build(std.testing.allocator, &state, .{})) == null);
}

test "palette builds detail pane from selected item detail" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var state: completion.State = .{
        .matches = try allocator.alloc(completion.Match, 2),
        .selected = 1,
        .visible = true,
    };
    state.matches[0] = .{ .item = .{ .label = "/help", .value = "/help", .detail = "help detail" } };
    state.matches[1] = .{ .item = .{ .label = "/status", .value = "/status", .detail = "status detail" } };

    const node = (try build(allocator, &state, .{ .hint = "Enter applies" })).?;
    try std.testing.expect(node.* == .vstack);
    try std.testing.expectEqual(@as(usize, 2), node.vstack.children.len);
}
