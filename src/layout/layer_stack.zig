const std = @import("std");
const node_mod = @import("../widget/node.zig");
const surface = @import("../widget/surface.zig");

pub const Layer = struct {
    node: *const node_mod.Node,
    rect: ?surface.Rect = null,
    z: i32 = 0,
};

pub const Stack = struct {
    allocator: std.mem.Allocator,
    layers: std.ArrayList(Layer) = .empty,

    pub fn init(allocator: std.mem.Allocator) Stack {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Stack) void {
        self.layers.deinit(self.allocator);
    }

    pub fn push(self: *Stack, layer: Layer) !void {
        try self.layers.append(self.allocator, layer);
    }

    pub fn clear(self: *Stack) void {
        self.layers.clearRetainingCapacity();
    }

    pub fn count(self: *const Stack) usize {
        return self.layers.items.len;
    }

    pub fn buildNode(self: *Stack, allocator: std.mem.Allocator) !*const node_mod.Node {
        if (self.layers.items.len == 0) return try node_mod.allocNode(allocator, .empty);
        std.mem.sort(Layer, self.layers.items, {}, struct {
            fn lessThan(_: void, a: Layer, b: Layer) bool {
                if (a.z == b.z) return @intFromPtr(a.node) < @intFromPtr(b.node);
                return a.z < b.z;
            }
        }.lessThan);
        var current = self.layers.items[0].node;
        var index: usize = 1;
        while (index < self.layers.items.len) : (index += 1) {
            current = try node_mod.allocNode(allocator, .{ .overlay = .{ .base = current, .overlay = self.layers.items[index].node } });
        }
        return current;
    }
};

test "layer stack builds overlay chain" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var stack = Stack.init(alloc);
    defer stack.deinit();
    const a = try node_mod.allocNode(alloc, .empty);
    const b = try node_mod.allocNode(alloc, .empty);
    try stack.push(.{ .node = a, .z = 0 });
    try stack.push(.{ .node = b, .z = 1 });
    const built = try stack.buildNode(alloc);
    try std.testing.expect(built.* == .overlay);
}

test "layer stack clear drops all layers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var stack = Stack.init(alloc);
    defer stack.deinit();
    try stack.push(.{ .node = try node_mod.allocNode(alloc, .empty) });
    try std.testing.expectEqual(@as(usize, 1), stack.count());
    stack.clear();
    try std.testing.expectEqual(@as(usize, 0), stack.count());
}
