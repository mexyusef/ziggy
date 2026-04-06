const std = @import("std");
const surface_mod = @import("surface.zig");

pub const Surface = struct {
    rect: surface_mod.Rect,
    z_index: i16 = 0,
    clip_to_parent: bool = true,
    children: std.ArrayList(Surface) = .empty,

    pub fn deinit(self: *Surface, allocator: std.mem.Allocator) void {
        for (self.children.items) |*child| child.deinit(allocator);
        self.children.deinit(allocator);
    }

    pub fn addChild(self: *Surface, allocator: std.mem.Allocator, child: Surface) !void {
        try self.children.append(allocator, child);
    }

    pub fn visibleRect(self: Surface, parent: ?surface_mod.Rect) ?surface_mod.Rect {
        if (!self.clip_to_parent or parent == null) return self.rect;
        return self.rect.intersect(parent.?);
    }
};

pub fn collectVisibleRects(
    allocator: std.mem.Allocator,
    root: Surface,
) ![]surface_mod.Rect {
    var rects = std.ArrayList(surface_mod.Rect).empty;
    defer rects.deinit(allocator);
    try walkVisible(&rects, allocator, root, null);
    return try rects.toOwnedSlice(allocator);
}

fn walkVisible(
    rects: *std.ArrayList(surface_mod.Rect),
    allocator: std.mem.Allocator,
    surface: Surface,
    parent: ?surface_mod.Rect,
) !void {
    const visible = surface.visibleRect(parent) orelse return;
    try rects.append(allocator, visible);
    for (surface.children.items) |child| {
        try walkVisible(rects, allocator, child, visible);
    }
}

test "surface visibleRect intersects with parent clip" {
    const surface = Surface{
        .rect = .{ .x = 5, .y = 5, .width = 10, .height = 10 },
    };
    const visible = surface.visibleRect(.{ .x = 8, .y = 8, .width = 4, .height = 4 }).?;
    try std.testing.expectEqual(@as(u16, 8), visible.x);
    try std.testing.expectEqual(@as(u16, 8), visible.y);
    try std.testing.expectEqual(@as(u16, 4), visible.width);
    try std.testing.expectEqual(@as(u16, 4), visible.height);
}

test "collectVisibleRects walks root and children" {
    var root = Surface{ .rect = .{ .x = 0, .y = 0, .width = 20, .height = 10 } };
    defer root.deinit(std.testing.allocator);
    try root.addChild(std.testing.allocator, .{ .rect = .{ .x = 2, .y = 2, .width = 5, .height = 5 } });
    const rects = try collectVisibleRects(std.testing.allocator, root);
    defer std.testing.allocator.free(rects);
    try std.testing.expectEqual(@as(usize, 2), rects.len);
    try std.testing.expectEqual(@as(u16, 2), rects[1].x);
}
