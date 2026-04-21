const std = @import("std");
const layout_place = @import("../layout/place.zig");
const surface_mod = @import("../widget/surface.zig");
const overlay_mod = @import("../app/overlay.zig");

pub const InputLayer = enum {
    overlay,
    focused,
    global,
};

pub const PopupRequest = struct {
    width: u16,
    height: u16,
    preferred: []const layout_place.AnchorPlacement = &.{ .below_start, .above_start, .below_end, .above_end, .right_top, .left_top },
};

pub fn allowsLayer(overlays: *const overlay_mod.State, layer: InputLayer) bool {
    const top = overlays.top() orelse return true;
    if (!top.kind.blocksInput()) return true;
    return layer == .overlay;
}

pub fn resolvePopupRect(container: surface_mod.Rect, anchor: surface_mod.Rect, request: PopupRequest) surface_mod.Rect {
    for (request.preferred) |placement| {
        const rect = layout_place.placeNearAnchor(container, anchor, request.width, request.height, placement);
        if (fitsPlacement(container, anchor, rect, placement)) return rect;
    }
    return layout_place.placeNearAnchor(container, anchor, request.width, request.height, request.preferred[0]);
}

fn fitsPlacement(container: surface_mod.Rect, anchor: surface_mod.Rect, rect: surface_mod.Rect, placement: layout_place.AnchorPlacement) bool {
    _ = container;
    return switch (placement) {
        .below_start, .below_end => rect.y >= anchor.y + anchor.height,
        .above_start, .above_end => rect.y + rect.height <= anchor.y,
        .right_top => rect.x >= anchor.x + anchor.width,
        .left_top => rect.x + rect.width <= anchor.x,
    };
}

test "blocking overlay only allows overlay layer" {
    var overlays = overlay_mod.State.init(std.testing.allocator);
    defer overlays.deinit();
    try overlays.push("modal", "Modal", .modal, null);
    try std.testing.expect(allowsLayer(&overlays, .overlay));
    try std.testing.expect(!allowsLayer(&overlays, .focused));
    try std.testing.expect(!allowsLayer(&overlays, .global));
}

test "resolve popup rect falls back when below placement does not fit" {
    const rect = resolvePopupRect(
        .{ .x = 0, .y = 0, .width = 30, .height = 10 },
        .{ .x = 10, .y = 8, .width = 4, .height = 1 },
        .{
            .width = 8,
            .height = 3,
            .preferred = &.{ .below_start, .above_start },
        },
    );
    try std.testing.expectEqual(@as(u16, 10), rect.x);
    try std.testing.expectEqual(@as(u16, 5), rect.y);
}
