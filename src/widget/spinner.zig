const std = @import("std");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");

pub const Options = struct {
    now_ms: u64 = 0,
    interval_ms: u64 = 80,
    frames: []const []const u8 = &default_frames,
    style: style_mod.Style = .{ .fg = .{ .ansi = 11 }, .bold = true },
};

const default_frames = [_][]const u8{
    "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏",
};

pub fn frameIndex(options: Options) usize {
    if (options.frames.len == 0 or options.interval_ms == 0) return 0;
    return @intCast((options.now_ms / options.interval_ms) % options.frames.len);
}

pub fn currentFrame(options: Options) []const u8 {
    if (options.frames.len == 0) return "";
    return options.frames[frameIndex(options)];
}

pub fn build(allocator: std.mem.Allocator, options: Options) !*const node_mod.Node {
    return try node_mod.allocNode(allocator, .{
        .text = .{
            .text = try allocator.dupe(u8, currentFrame(options)),
            .style = options.style,
            .wrap = .none,
            .alignment = .left,
        },
    });
}

test "spinner frame advances with time" {
    const options = Options{ .now_ms = 160, .interval_ms = 80 };
    try std.testing.expectEqual(@as(usize, 2), frameIndex(options));
}
