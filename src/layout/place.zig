const surface = @import("../widget/surface.zig");

pub const Horizontal = enum { left, center, right };
pub const Vertical = enum { top, middle, bottom };

pub fn placeWithin(container: surface.Rect, width: u16, height: u16, horizontal: Horizontal, vertical: Vertical) surface.Rect {
    const x = switch (horizontal) {
        .left => container.x,
        .center => container.x + @as(i32, @intCast(@max(@as(i32, 0), @divTrunc(@as(i32, container.width) - @as(i32, width), 2)))),
        .right => container.x + @as(i32, @intCast(@max(@as(i32, 0), @as(i32, container.width) - @as(i32, width)))),
    };
    const y = switch (vertical) {
        .top => container.y,
        .middle => container.y + @as(i32, @intCast(@max(@as(i32, 0), @divTrunc(@as(i32, container.height) - @as(i32, height), 2)))),
        .bottom => container.y + @as(i32, @intCast(@max(@as(i32, 0), @as(i32, container.height) - @as(i32, height)))),
    };
    return .{
        .x = @intCast(x),
        .y = @intCast(y),
        .width = @min(width, container.width),
        .height = @min(height, container.height),
    };
}

test "place within centers a rect" {
    const rect = placeWithin(.{ .x = 0, .y = 0, .width = 20, .height = 10 }, 6, 4, .center, .middle);
    try @import("std").testing.expectEqual(@as(i32, 7), rect.x);
    try @import("std").testing.expectEqual(@as(i32, 3), rect.y);
}
