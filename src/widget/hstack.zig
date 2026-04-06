const std = @import("std");
const node_mod = @import("node.zig");

pub fn build(
    allocator: std.mem.Allocator,
    children: []const *const node_mod.Node,
    gap: u16,
) !*const node_mod.Node {
    return buildWithWeights(allocator, children, gap, null);
}

pub fn buildWithWeights(
    allocator: std.mem.Allocator,
    children: []const *const node_mod.Node,
    gap: u16,
    weights: ?[]const u16,
) !*const node_mod.Node {
    const owned = try allocator.alloc(*const node_mod.Node, children.len);
    @memcpy(owned, children);
    const owned_weights = if (weights) |provided| blk: {
        if (provided.len != children.len) return error.InvalidWeights;
        const copy = try allocator.alloc(u16, provided.len);
        @memcpy(copy, provided);
        break :blk copy;
    } else null;
    return try node_mod.allocNode(allocator, .{
        .hstack = .{
            .children = owned,
            .gap = gap,
            .weights = owned_weights,
        },
    });
}
