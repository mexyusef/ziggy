const std = @import("std");
const vstack = @import("vstack.zig");
const input = @import("input.zig");
const pane = @import("pane.zig");
const box = @import("box.zig");
const text = @import("text.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");
const focus_mod = @import("focus.zig");

pub const Options = struct {
    prompt: []const u8 = "> ",
    cursor: usize = 0,
    selected: usize = 0,
    offset: usize = 0,
    hint: ?[]const u8 = null,
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    box_style: style_mod.Style = .{},
    hint_style: style_mod.Style = .{ .dim = true },
    border_style: border_mod.BorderStyle = .double,
    focus: focus_mod.FocusState = .{},
};

pub fn build(
    allocator: std.mem.Allocator,
    title: []const u8,
    query: []const u8,
    items: []const []const u8,
    options: Options,
) !*const node_mod.Node {
    const query_input = try input.build(allocator, options.prompt, try allocator.dupe(u8, query), options.cursor, true, options.style);
    const list_box = try pane.buildSelectableList(allocator, "Results", items, .{
        .selected = options.selected,
        .offset = options.offset,
        .focused = true,
        .style = options.style,
        .selected_style = options.selected_style,
        .box_style = options.box_style,
        .border_style = .single,
        .focus = options.focus,
    });
    if (options.hint) |hint| {
        const hint_node = try text.buildWithOptions(allocator, try allocator.dupe(u8, hint), .{
            .style = options.hint_style,
            .wrap = .truncate_end,
        });
        const body = try vstack.build(allocator, &.{ query_input, list_box, hint_node }, 1);
        return try box.buildWithOptions(allocator, title, body, .{
            .style = options.box_style,
            .border_style = options.border_style,
            .padding_left = 1,
            .padding_right = 1,
            .padding_top = 1,
            .padding_bottom = 1,
        });
    }
    const body = try vstack.build(allocator, &.{ query_input, list_box }, 1);
    return try box.buildWithOptions(allocator, title, body, .{
        .style = options.box_style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
}

test "command dialog builds input and result list" {
    var buffer: [12288]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const items = [_][]const u8{ "/help", "/clear" };
    const node = try build(fba.allocator(), "Command Palette", "/", &items, .{ .hint = "Ctrl+P or /" });
    try std.testing.expect(node.* == .box);
}
