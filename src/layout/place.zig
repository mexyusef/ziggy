const surface = @import("../widget/surface.zig");

pub const Horizontal = enum { left, center, right };
pub const Vertical = enum { top, middle, bottom };
pub const AnchorPlacement = enum {
    below_start,
    below_end,
    above_start,
    above_end,
    right_top,
    left_top,
};

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

pub fn placeNearAnchor(
    container: surface.Rect,
    anchor: surface.Rect,
    width: u16,
    height: u16,
    placement: AnchorPlacement,
) surface.Rect {
    var x: i32 = @intCast(anchor.x);
    var y: i32 = @intCast(anchor.y);

    switch (placement) {
        .below_start => {
            x = @intCast(anchor.x);
            y = @intCast(anchor.y + anchor.height);
        },
        .below_end => {
            x = @as(i32, @intCast(anchor.x)) + @as(i32, @intCast(anchor.width)) - @as(i32, @intCast(width));
            y = @intCast(anchor.y + anchor.height);
        },
        .above_start => {
            x = @intCast(anchor.x);
            y = @as(i32, @intCast(anchor.y)) - @as(i32, @intCast(height));
        },
        .above_end => {
            x = @as(i32, @intCast(anchor.x)) + @as(i32, @intCast(anchor.width)) - @as(i32, @intCast(width));
            y = @as(i32, @intCast(anchor.y)) - @as(i32, @intCast(height));
        },
        .right_top => {
            x = @intCast(anchor.x + anchor.width);
            y = @intCast(anchor.y);
        },
        .left_top => {
            x = @as(i32, @intCast(anchor.x)) - @as(i32, @intCast(width));
            y = @intCast(anchor.y);
        },
    }

    const min_x: i32 = @intCast(container.x);
    const min_y: i32 = @intCast(container.y);
    const max_x = min_x + @as(i32, @intCast(container.width -| @min(width, container.width)));
    const max_y = min_y + @as(i32, @intCast(container.height -| @min(height, container.height)));

    return .{
        .x = @intCast(@max(min_x, @min(x, max_x))),
        .y = @intCast(@max(min_y, @min(y, max_y))),
        .width = @min(width, container.width),
        .height = @min(height, container.height),
    };
}

test "place within centers a rect" {
    const rect = placeWithin(.{ .x = 0, .y = 0, .width = 20, .height = 10 }, 6, 4, .center, .middle);
    try @import("std").testing.expectEqual(@as(i32, 7), rect.x);
    try @import("std").testing.expectEqual(@as(i32, 3), rect.y);
}

test "placeNearAnchor clamps inside container" {
    const rect = placeNearAnchor(
        .{ .x = 0, .y = 0, .width = 20, .height = 10 },
        .{ .x = 18, .y = 8, .width = 2, .height = 1 },
        6,
        3,
        .below_start,
    );
    try @import("std").testing.expectEqual(@as(i32, 14), rect.x);
    try @import("std").testing.expectEqual(@as(i32, 7), rect.y);
}
