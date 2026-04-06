const std = @import("std");
const box = @import("box.zig");
const text = @import("text.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");
const node_mod = @import("node.zig");

pub const Item = struct {
    depth: usize,
    label: []const u8,
    expanded: bool = false,
};

pub const Options = struct {
    title: ?[]const u8 = "Tree",
    style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .single,
};

pub fn build(allocator: std.mem.Allocator, items: []const Item, options: Options) !*const node_mod.Node {
    var builder = std.ArrayList(u8).empty;
    const writer = builder.writer(allocator);
    for (items, 0..) |item, index| {
        if (index > 0) try writer.writeByte('\n');
        for (0..item.depth) |_| try writer.writeAll("  ");
        try writer.print("{s} {s}", .{ if (item.expanded) "▼" else "▶", item.label });
    }
    const body = try builder.toOwnedSlice(allocator);
    return try box.buildWithOptions(allocator, options.title, try text.buildWithOptions(allocator, body, .{ .style = options.style, .wrap = .none }), .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
}

test "tree builds hierarchical labels" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const items = [_]Item{
        .{ .depth = 0, .label = "project", .expanded = true },
        .{ .depth = 1, .label = "src", .expanded = true },
    };
    const node = try build(alloc, &items, .{});
    try std.testing.expect(node.* == .box);
}
