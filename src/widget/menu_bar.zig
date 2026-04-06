const std = @import("std");
const hstack = @import("hstack.zig");
const text = @import("text.zig");
const box = @import("box.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");

pub const Options = struct {
    selected: usize = 0,
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    border_style: border_mod.BorderStyle = .single,
    boxed: bool = true,
};

pub fn build(
    allocator: std.mem.Allocator,
    items: []const []const u8,
    options: Options,
) !*const node_mod.Node {
    const children = try allocator.alloc(*const node_mod.Node, items.len);
    for (items, 0..) |item, index| {
        children[index] = try text.buildWithOptions(allocator, try allocator.dupe(u8, item), .{
            .style = if (index == options.selected) options.selected_style else options.style,
            .wrap = .truncate_end,
        });
    }
    const row = try hstack.build(allocator, children, 2);
    if (!options.boxed) return row;
    return try box.buildWithOptions(allocator, null, row, .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
    });
}

test "menu bar builds boxed row" {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const items = [_][]const u8{ "File", "Edit", "View" };
    const node = try build(fba.allocator(), &items, .{ .selected = 1 });
    try std.testing.expect(node.* == .box);
}
