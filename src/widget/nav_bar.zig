const std = @import("std");
const hstack = @import("hstack.zig");
const tab_bar = @import("tab_bar.zig");
const text = @import("text.zig");
const box = @import("box.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");

pub const Options = struct {
    selected: usize = 0,
    right_text: ?[]const u8 = null,
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    right_style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .single,
    boxed: bool = true,
};

pub fn build(
    allocator: std.mem.Allocator,
    items: []const []const u8,
    options: Options,
) !*const node_mod.Node {
    const tabs = try tab_bar.build(allocator, items, .{
        .selected = options.selected,
        .style = options.style,
        .selected_style = options.selected_style,
        .alignment = .left,
    });
    const row = if (options.right_text) |right_text| blk: {
        const right = try text.buildWithOptions(allocator, try allocator.dupe(u8, right_text), .{
            .style = options.right_style,
            .wrap = .truncate_start,
            .alignment = .right,
        });
        break :blk try hstack.buildWithWeights(allocator, &.{ tabs, right }, 1, &.{ 3, 2 });
    } else tabs;

    if (!options.boxed) return row;
    return try box.buildWithOptions(allocator, null, row, .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
    });
}

test "nav bar builds tab shell" {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const items = [_][]const u8{ "Chat", "Tools", "Config" };
    const node = try build(fba.allocator(), &items, .{ .right_text = "demo" });
    try std.testing.expect(node.* == .box);
}
