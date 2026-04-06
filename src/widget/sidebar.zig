const std = @import("std");
const vstack = @import("vstack.zig");
const text = @import("text.zig");
const pane = @import("pane.zig");
const box = @import("box.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");
const focus_mod = @import("focus.zig");

pub const Options = struct {
    selected: usize = 0,
    offset: usize = 0,
    focused: bool = false,
    footer: ?[]const u8 = null,
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    box_style: style_mod.Style = .{},
    footer_style: style_mod.Style = .{ .dim = true },
    border_style: border_mod.BorderStyle = .single,
    focus: focus_mod.FocusState = .{},
};

pub fn build(
    allocator: std.mem.Allocator,
    title: []const u8,
    items: []const []const u8,
    options: Options,
) !*const node_mod.Node {
    const list_box = try pane.buildSelectableList(allocator, title, items, .{
        .selected = options.selected,
        .offset = options.offset,
        .focused = options.focused,
        .style = options.style,
        .selected_style = options.selected_style,
        .box_style = options.box_style,
        .border_style = options.border_style,
        .focus = options.focus,
    });
    if (options.footer == null) return list_box;
    const footer = try text.buildWithOptions(allocator, try allocator.dupe(u8, options.footer.?), .{
        .style = options.footer_style,
        .wrap = .truncate_end,
    });
    const body = try vstack.build(allocator, &.{ list_box, footer }, 1);
    return try box.buildWithOptions(allocator, null, body, .{
        .style = options.box_style,
        .border_style = options.border_style,
    });
}

test "sidebar builds list shell" {
    var buffer: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const items = [_][]const u8{ "Home", "Agents", "Tools" };
    const node = try build(fba.allocator(), "Menu", &items, .{ .footer = "project scope" });
    try std.testing.expect(node.* == .box);
}
