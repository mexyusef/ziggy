const std = @import("std");

pub const Rect = struct {
    x: u16,
    y: u16,
    width: u16,
    height: u16,

    pub fn contains(self: Rect, x: u16, y: u16) bool {
        return x >= self.x and y >= self.y and x < self.x + self.width and y < self.y + self.height;
    }

    pub fn localPoint(self: Rect, x: u16, y: u16) ?struct { x: u16, y: u16 } {
        if (!self.contains(x, y)) return null;
        return .{ .x = x - self.x, .y = y - self.y };
    }

    pub fn intersect(self: Rect, other: Rect) ?Rect {
        const x0 = @max(self.x, other.x);
        const y0 = @max(self.y, other.y);
        const x1 = @min(self.x + self.width, other.x + other.width);
        const y1 = @min(self.y + self.height, other.y + other.height);
        if (x1 <= x0 or y1 <= y0) return null;
        return .{
            .x = x0,
            .y = y0,
            .width = x1 - x0,
            .height = y1 - y0,
        };
    }
};

test "rect contains and localPoint" {
    const rect = Rect{ .x = 10, .y = 5, .width = 20, .height = 4 };
    try std.testing.expect(rect.contains(10, 5));
    try std.testing.expect(!rect.contains(30, 8));
    const local = rect.localPoint(12, 7).?;
    try std.testing.expectEqual(@as(u16, 2), local.x);
    try std.testing.expectEqual(@as(u16, 2), local.y);
}
