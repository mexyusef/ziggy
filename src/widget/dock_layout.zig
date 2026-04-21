const std = @import("std");
const screen_mod = @import("../terminal/screen.zig");
const surface_mod = @import("surface.zig");

pub const Layout = struct {
    header_height: u16,
    body_height: u16,
    footer_height: u16,
    center_width: u16,
    center_height: u16,
    editor_width: usize,
    editor_height: usize,
    sidebar_width: u16,
    right_width: u16,
    main_height: u16,
    bottom_height: u16,
    outline_boundary_x: u16,
    preview_boundary_y: u16,
    right_panel_x: u16,
    bottom_panel_y: u16,

    pub fn hasSidebar(self: Layout) bool {
        return self.sidebar_width > 0;
    }

    pub fn hasRight(self: Layout) bool {
        return self.right_width > 0;
    }

    pub fn hasBottom(self: Layout) bool {
        return self.bottom_height > 0;
    }

    pub fn mainRowHeight(self: Layout) u16 {
        return if (self.hasBottom()) self.main_height else self.body_height;
    }

    pub fn sidebarRect(self: Layout) ?surface_mod.Rect {
        if (!self.hasSidebar()) return null;
        return .{
            .x = 0,
            .y = self.header_height,
            .width = self.sidebar_width,
            .height = self.mainRowHeight(),
        };
    }

    pub fn centerRect(self: Layout) surface_mod.Rect {
        return .{
            .x = if (self.hasSidebar()) self.sidebar_width + 1 else 0,
            .y = self.header_height,
            .width = self.center_width,
            .height = self.mainRowHeight(),
        };
    }

    pub fn rightRect(self: Layout) ?surface_mod.Rect {
        if (!self.hasRight()) return null;
        return .{
            .x = self.right_panel_x,
            .y = self.header_height,
            .width = self.right_width,
            .height = self.mainRowHeight(),
        };
    }

    pub fn rightTopRect(self: Layout) ?surface_mod.Rect {
        const rect = self.rightRect() orelse return null;
        return .{
            .x = rect.x,
            .y = rect.y,
            .width = rect.width,
            .height = @max(rect.height / 2, 1),
        };
    }

    pub fn rightBottomRect(self: Layout) ?surface_mod.Rect {
        const rect = self.rightRect() orelse return null;
        const top_height = @max(rect.height / 2, 1);
        const bottom_y = rect.y + top_height + 1;
        const bottom_height = rect.height -| top_height -| 1;
        if (bottom_height == 0) return null;
        return .{
            .x = rect.x,
            .y = bottom_y,
            .width = rect.width,
            .height = bottom_height,
        };
    }

    pub fn bottomRect(self: Layout) ?surface_mod.Rect {
        if (!self.hasBottom()) return null;
        return .{
            .x = 0,
            .y = self.bottom_panel_y,
            .width = self.sidebar_width + self.center_width + self.right_width + @as(u16, if (self.hasSidebar()) 2 else 1),
            .height = self.bottom_height,
        };
    }

    pub fn insetRect(_: Layout, rect: surface_mod.Rect, inset_x: u16, inset_y: u16) ?surface_mod.Rect {
        if (rect.width <= inset_x * 2 or rect.height <= inset_y * 2) return null;
        return .{
            .x = rect.x + inset_x,
            .y = rect.y + inset_y,
            .width = rect.width - inset_x * 2,
            .height = rect.height - inset_y * 2,
        };
    }
};

pub fn compute(show_sidebar: bool, show_bottom: bool, size: screen_mod.Size) Layout {
    return computeWithPanels(show_sidebar, true, show_bottom, size);
}

pub fn computeWithPanels(show_sidebar: bool, show_right: bool, show_bottom: bool, size: screen_mod.Size) Layout {
    const header_height: u16 = 5;
    const footer_height: u16 = 3;
    const body_height = @max(size.height -| header_height -| footer_height -| 2, 1);
    const bottom_height: u16 = if (show_bottom) @min(@max(size.height / 6, 4), 7) else 0;
    const main_height = if (show_bottom) @max(body_height -| bottom_height -| 1, 1) else body_height;

    const sidebar_width: u16 = if (show_sidebar) 22 else 0;
    const right_width: u16 = if (show_right) @min(@max(size.width / 4, 26), 36) else 0;
    const shell_gap: u16 = if (show_sidebar and show_right) 2 else if (show_sidebar or show_right) 1 else 0;
    const center_width = @max(size.width -| sidebar_width -| right_width -| shell_gap, 24);
    const center_height = @max(main_height, 8);

    return .{
        .header_height = header_height,
        .body_height = body_height,
        .footer_height = footer_height,
        .center_width = center_width,
        .center_height = center_height,
        .editor_width = @max(@as(usize, center_width / 2), 24),
        .editor_height = @max(@as(usize, center_height / 2), 10),
        .sidebar_width = sidebar_width,
        .right_width = right_width,
        .main_height = main_height,
        .bottom_height = bottom_height,
        .outline_boundary_x = sidebar_width + center_width,
        .preview_boundary_y = header_height + (center_height / 2),
        .right_panel_x = sidebar_width + center_width + 1,
        .bottom_panel_y = header_height + main_height + 1,
    };
}

test "dock layout computes shell rects" {
    const layout = computeWithPanels(true, true, true, .{ .width = 120, .height = 40 });
    try std.testing.expect(layout.hasSidebar());
    try std.testing.expect(layout.hasRight());
    try std.testing.expect(layout.hasBottom());
    try std.testing.expectEqual(@as(u16, 22), layout.sidebarRect().?.width);
    try std.testing.expect(layout.rightTopRect().?.height > 0);
    try std.testing.expect(layout.bottomRect().?.height > 0);
}

test "dock layout omits bottom rect when hidden" {
    const layout = computeWithPanels(false, false, false, .{ .width = 80, .height = 24 });
    try std.testing.expect(layout.bottomRect() == null);
    try std.testing.expect(layout.sidebarRect() == null);
}

test "dock layout omits right rect when hidden" {
    const layout = computeWithPanels(true, false, false, .{ .width = 100, .height = 30 });
    try std.testing.expect(layout.rightRect() == null);
    try std.testing.expect(layout.center_width >= 24);
}
