const std = @import("std");
const viewport = @import("../widget/viewport.zig");

test "sticky bottom follows appended content until user scrolls away" {
    var state: viewport.State = .{
        .viewport_height = 4,
        .content_height = 8,
    };
    state.stickTo(.bottom);
    try std.testing.expectEqual(@as(usize, 4), state.offset_line);

    state.setContent(0, 10);
    try std.testing.expectEqual(@as(usize, 6), state.offset_line);

    state.scrollLines(-1);
    try std.testing.expectEqual(viewport.StickyEdge.none, state.sticky_y);

    state.setContent(0, 12);
    try std.testing.expectEqual(@as(usize, 5), state.offset_line);
}
