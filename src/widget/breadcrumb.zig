const std = @import("std");
const hstack = @import("hstack.zig");
const text = @import("text.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");

pub const Options = struct {
    style: style_mod.Style = .{},
    current_style: style_mod.Style = .{ .bold = true },
    separator: []const u8 = " / ",
};

pub fn build(
    allocator: std.mem.Allocator,
    items: []const []const u8,
    options: Options,
) !*const node_mod.Node {
    if (items.len == 0) return try text.build(allocator, "", options.style);

    const child_count: usize = items.len * 2 - 1;
    const children = try allocator.alloc(*const node_mod.Node, child_count);
    var out_index: usize = 0;
    for (items, 0..) |item, index| {
        children[out_index] = try text.buildWithOptions(allocator, try allocator.dupe(u8, item), .{
            .style = if (index + 1 == items.len) options.current_style else options.style,
            .wrap = .truncate_end,
        });
        out_index += 1;
        if (index + 1 < items.len) {
            children[out_index] = try text.buildWithOptions(allocator, try allocator.dupe(u8, options.separator), .{
                .style = options.style,
                .wrap = .truncate_end,
            });
            out_index += 1;
        }
    }
    return try hstack.build(allocator, children, 0);
}

test "breadcrumb builds path row" {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const items = [_][]const u8{ "workspace", "src", "widget" };
    const node = try build(fba.allocator(), &items, .{});
    try std.testing.expect(node.* == .hstack);
}
