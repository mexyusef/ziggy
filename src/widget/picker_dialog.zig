const std = @import("std");
const vstack = @import("vstack.zig");
const pane = @import("pane.zig");
const text = @import("text.zig");
const box = @import("box.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");
const focus_mod = @import("focus.zig");

pub const Options = struct {
    description: ?[]const u8 = null,
    selected: usize = 0,
    offset: usize = 0,
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    box_style: style_mod.Style = .{},
    description_style: style_mod.Style = .{ .dim = true },
    border_style: border_mod.BorderStyle = .double,
    focus: focus_mod.FocusState = .{},
};

pub fn build(
    allocator: std.mem.Allocator,
    title: []const u8,
    items: []const []const u8,
    options: Options,
) !*const node_mod.Node {
    const list_box = try pane.buildSelectableList(allocator, "Options", items, .{
        .selected = options.selected,
        .offset = options.offset,
        .focused = true,
        .style = options.style,
        .selected_style = options.selected_style,
        .box_style = options.box_style,
        .border_style = .single,
        .focus = options.focus,
    });
    if (options.description) |description| {
        const desc = try text.buildWithOptions(allocator, try allocator.dupe(u8, description), .{
            .style = options.description_style,
            .wrap = .wrap,
        });
        const body = try vstack.build(allocator, &.{ desc, list_box }, 1);
        return try box.buildWithOptions(allocator, title, body, .{
            .style = options.box_style,
            .border_style = options.border_style,
            .padding_left = 1,
            .padding_right = 1,
            .padding_top = 1,
            .padding_bottom = 1,
        });
    }
    return try box.buildWithOptions(allocator, title, list_box, .{
        .style = options.box_style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
}

test "picker dialog builds titled option list" {
    var buffer: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const items = [_][]const u8{ "alpha", "beta" };
    const node = try build(fba.allocator(), "Pick Item", &items, .{ .description = "Choose one item." });
    try std.testing.expect(node.* == .box);
}
