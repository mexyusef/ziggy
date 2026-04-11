const std = @import("std");
const parser = @import("../terminal/parser.zig");

pub const MouseSummary = struct {
    click_count: u8 = 0,
    drag_started: bool = false,
    drag_active: bool = false,
    wheel_y: i8 = 0,
};

pub const HoverTracker = struct {
    hovered_id: ?[]const u8 = null,
    entered_at_ms: u64 = 0,

    pub fn update(self: *HoverTracker, id: ?[]const u8, now_ms: u64) bool {
        if (eqlOptional(self.hovered_id, id)) return false;
        self.hovered_id = id;
        self.entered_at_ms = now_ms;
        return true;
    }

    pub fn hoveredFor(self: *const HoverTracker, now_ms: u64) u64 {
        if (self.hovered_id == null or now_ms < self.entered_at_ms) return 0;
        return now_ms - self.entered_at_ms;
    }
};

pub const MouseTracker = struct {
    last_button: ?parser.MouseButton = null,
    last_press_at_ms: u64 = 0,
    click_count: u8 = 0,
    pressed: bool = false,
    press_x: u16 = 0,
    press_y: u16 = 0,

    pub fn observe(self: *MouseTracker, mouse: parser.Mouse, now_ms: u64) MouseSummary {
        var summary: MouseSummary = .{};

        switch (mouse.button) {
            .wheel_up => {
                summary.wheel_y = -1;
                return summary;
            },
            .wheel_down => {
                summary.wheel_y = 1;
                return summary;
            },
            else => {},
        }

        if (mouse.pressed) {
            if (self.last_button != null and self.last_button.? == mouse.button and now_ms - self.last_press_at_ms <= 350) {
                self.click_count +|= 1;
            } else {
                self.click_count = 1;
            }
            self.last_button = mouse.button;
            self.last_press_at_ms = now_ms;
            self.pressed = true;
            self.press_x = mouse.x;
            self.press_y = mouse.y;
            summary.click_count = self.click_count;
            return summary;
        }

        if (self.pressed and distanceExceeded(self.press_x, self.press_y, mouse.x, mouse.y)) {
            summary.drag_started = true;
            summary.drag_active = true;
        }
        self.pressed = false;
        return summary;
    }
};

fn distanceExceeded(x0: u16, y0: u16, x1: u16, y1: u16) bool {
    const dx = @as(i32, x1) - @as(i32, x0);
    const dy = @as(i32, y1) - @as(i32, y0);
    return @abs(dx) > 1 or @abs(dy) > 1;
}

fn eqlOptional(a: ?[]const u8, b: ?[]const u8) bool {
    if (a == null and b == null) return true;
    if (a == null or b == null) return false;
    return std.mem.eql(u8, a.?, b.?);
}

test "mouse tracker counts clicks and wheel movement" {
    var tracker: MouseTracker = .{};
    const first = tracker.observe(.{ .button = .left, .x = 4, .y = 2, .pressed = true }, 100);
    try std.testing.expectEqual(@as(u8, 1), first.click_count);
    const second = tracker.observe(.{ .button = .left, .x = 4, .y = 2, .pressed = true }, 200);
    try std.testing.expectEqual(@as(u8, 2), second.click_count);
    const wheel = tracker.observe(.{ .button = .wheel_down, .x = 0, .y = 0, .pressed = true }, 210);
    try std.testing.expectEqual(@as(i8, 1), wheel.wheel_y);
}

test "hover tracker records transitions" {
    var tracker: HoverTracker = .{};
    try std.testing.expect(tracker.update("editor", 10));
    try std.testing.expectEqual(@as(u64, 15), tracker.hoveredFor(25));
    try std.testing.expect(!tracker.update("editor", 30));
    try std.testing.expect(tracker.update("sidebar", 40));
}
