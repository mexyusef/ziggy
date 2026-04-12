const std = @import("std");
const hstack = @import("hstack.zig");
const text = @import("text.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");

pub const Options = struct {
    style: style_mod.Style = .{ .dim = true },
    key_style: style_mod.Style = .{ .bold = true },
    separator_style: style_mod.Style = .{ .dim = true },
};

pub fn build(allocator: std.mem.Allocator, combo: []const u8, options: Options) !*const node_mod.Node {
    var parts = std.mem.splitScalar(u8, combo, '+');
    var nodes: std.ArrayList(*const node_mod.Node) = .empty;
    defer nodes.deinit(allocator);

    var first = true;
    while (parts.next()) |part| {
        if (!first) {
            try nodes.append(allocator, try text.buildWithOptions(allocator, try allocator.dupe(u8, "+"), .{
                .style = options.separator_style,
            }));
        }
        first = false;
        try nodes.append(allocator, try text.buildWithOptions(allocator, try allocator.dupe(u8, part), .{
            .style = options.key_style,
        }));
    }

    if (nodes.items.len == 0) {
        return try text.buildWithOptions(allocator, try allocator.dupe(u8, ""), .{ .style = options.style });
    }
    return try hstack.build(allocator, nodes.items, 0);
}

test "accelerator splits key combo into tokens" {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const node = try build(fba.allocator(), "Ctrl+P", .{});
    try std.testing.expect(node.* == .hstack);
}
