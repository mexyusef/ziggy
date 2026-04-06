const std = @import("std");

pub const Easing = enum {
    linear,
    out_quad,
    in_out_sine,
};

pub const Timeline = struct {
    duration_ms: u64 = 1000,
    loop: bool = true,
    alternate: bool = false,
    easing: Easing = .linear,

    pub fn progress(self: Timeline, now_ms: u64) f64 {
        if (self.duration_ms == 0) return 1.0;
        if (!self.loop) {
            return @min(@as(f64, @floatFromInt(now_ms)) / @as(f64, @floatFromInt(self.duration_ms)), 1.0);
        }
        const cycle = now_ms / self.duration_ms;
        const remainder = now_ms % self.duration_ms;
        var t = @as(f64, @floatFromInt(remainder)) / @as(f64, @floatFromInt(self.duration_ms));
        if (self.alternate and (cycle % 2 == 1)) t = 1.0 - t;
        return t;
    }

    pub fn eased(self: Timeline, now_ms: u64) f64 {
        return applyEasing(self.easing, self.progress(now_ms));
    }

    pub fn valueAt(self: Timeline, now_ms: u64, min: usize, max: usize) usize {
        if (max <= min) return min;
        const range = max - min;
        const eased_value = self.eased(now_ms);
        return min + @as(usize, @intFromFloat(@round(eased_value * @as(f64, @floatFromInt(range)))));
    }
};

pub fn applyEasing(easing: Easing, t: f64) f64 {
    const clamped = std.math.clamp(t, 0.0, 1.0);
    return switch (easing) {
        .linear => clamped,
        .out_quad => clamped * (2.0 - clamped),
        .in_out_sine => -(std.math.cos(std.math.pi * clamped) - 1.0) / 2.0,
    };
}

test "timeline loops and alternates" {
    const tl = Timeline{ .duration_ms = 1000, .loop = true, .alternate = true };
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), tl.progress(250), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.75), tl.progress(1250), 0.0001);
}

test "timeline valueAt maps range" {
    const tl = Timeline{ .duration_ms = 1000, .loop = false, .easing = .out_quad };
    try std.testing.expectEqual(@as(usize, 10), tl.valueAt(0, 10, 90));
    try std.testing.expect(tl.valueAt(500, 10, 90) > 40);
    try std.testing.expectEqual(@as(usize, 90), tl.valueAt(1000, 10, 90));
}
