const std = @import("std");

pub const StickyEdge = enum {
    none,
    top,
    bottom,
    left,
    right,
};

pub const State = struct {
    offset_line: usize = 0,
    offset_column: usize = 0,
    viewport_width: usize = 0,
    viewport_height: usize = 0,
    content_width: usize = 0,
    content_height: usize = 0,
    follow_end: bool = false,
    scroll_margin: usize = 1,
    sticky_y: StickyEdge = .none,
    sticky_x: StickyEdge = .none,

    pub fn clamp(self: *State) void {
        self.offset_line = @min(self.offset_line, maxOffset(self.content_height, self.viewport_height));
        self.offset_column = @min(self.offset_column, maxOffset(self.content_width, self.viewport_width));
    }

    pub fn setViewport(self: *State, width: usize, height: usize) void {
        self.viewport_width = width;
        self.viewport_height = height;
        self.clamp();
    }

    pub fn setContent(self: *State, width: usize, height: usize) void {
        self.content_width = width;
        self.content_height = height;
        if (self.follow_end or self.sticky_y == .bottom) {
            self.offset_line = maxOffset(height, self.viewport_height);
        }
        if (self.sticky_y == .top) self.offset_line = 0;
        if (self.sticky_x == .left) self.offset_column = 0;
        if (self.sticky_x == .right) self.offset_column = maxOffset(width, self.viewport_width);
        self.clamp();
    }

    pub fn pageDown(self: *State) void {
        if (self.viewport_height == 0) return;
        self.offset_line = @min(self.offset_line + self.viewport_height, maxOffset(self.content_height, self.viewport_height));
    }

    pub fn pageUp(self: *State) void {
        if (self.viewport_height == 0) return;
        self.offset_line -|= self.viewport_height;
    }

    pub fn scrollLines(self: *State, delta: isize) void {
        if (delta != 0) {
            if (delta < 0 and self.sticky_y == .bottom) {
                self.sticky_y = .none;
                self.follow_end = false;
            }
            if (delta > 0 and self.sticky_y == .top) self.sticky_y = .none;
        }
        if (delta >= 0) {
            self.offset_line = @min(self.offset_line + @as(usize, @intCast(delta)), maxOffset(self.content_height, self.viewport_height));
        } else {
            self.offset_line -|= @as(usize, @intCast(-delta));
        }
    }

    pub fn scrollColumns(self: *State, delta: isize) void {
        if (delta != 0) {
            if (delta < 0 and self.sticky_x == .right) self.sticky_x = .none;
            if (delta > 0 and self.sticky_x == .left) self.sticky_x = .none;
        }
        if (delta >= 0) {
            self.offset_column = @min(self.offset_column + @as(usize, @intCast(delta)), maxOffset(self.content_width, self.viewport_width));
        } else {
            self.offset_column -|= @as(usize, @intCast(-delta));
        }
    }

    pub fn revealLine(self: *State, line: usize) void {
        if (self.viewport_height == 0) return;
        const margin = @min(self.scroll_margin, self.viewport_height -| 1);
        const top_limit = self.offset_line + margin;
        const bottom_limit = self.offset_line + self.viewport_height -| 1 -| margin;

        if (line < top_limit) {
            self.offset_line = line -| margin;
        } else if (line > bottom_limit) {
            self.offset_line = line -| (self.viewport_height -| 1 -| margin);
        }
        self.clamp();
    }

    pub fn revealPoint(self: *State, line: usize, column: usize) void {
        self.revealLine(line);
        if (self.viewport_width == 0) return;
        const margin = @min(self.scroll_margin, self.viewport_width -| 1);
        const left_limit = self.offset_column + margin;
        const right_limit = self.offset_column + self.viewport_width -| 1 -| margin;
        if (column < left_limit) {
            self.offset_column = column -| margin;
        } else if (column > right_limit) {
            self.offset_column = column -| (self.viewport_width -| 1 -| margin);
        }
        self.clamp();
    }

    pub fn followBottom(self: *State) void {
        self.follow_end = true;
        self.offset_line = maxOffset(self.content_height, self.viewport_height);
    }

    pub fn stopFollow(self: *State) void {
        self.follow_end = false;
    }

    pub fn stickTo(self: *State, edge: StickyEdge) void {
        switch (edge) {
            .none => {
                self.sticky_x = .none;
                self.sticky_y = .none;
                self.follow_end = false;
            },
            .top, .bottom => {
                self.sticky_y = edge;
                self.follow_end = edge == .bottom;
                self.offset_line = if (edge == .bottom) maxOffset(self.content_height, self.viewport_height) else 0;
            },
            .left, .right => {
                self.sticky_x = edge;
                self.offset_column = if (edge == .right) maxOffset(self.content_width, self.viewport_width) else 0;
            },
        }
        self.clamp();
    }

    pub fn stickyYFollowsEnd(self: *const State) bool {
        return self.follow_end or self.sticky_y == .bottom;
    }
};

fn maxOffset(total: usize, viewport: usize) usize {
    if (viewport == 0) return 0;
    return total -| viewport;
}

test "viewport reveals distant line with margin" {
    var state: State = .{
        .viewport_height = 10,
        .content_height = 50,
        .scroll_margin = 1,
    };
    state.revealLine(30);
    try std.testing.expectEqual(@as(usize, 22), state.offset_line);
}

test "viewport followBottom tracks end" {
    var state: State = .{
        .viewport_height = 5,
        .content_height = 20,
    };
    state.followBottom();
    try std.testing.expectEqual(@as(usize, 15), state.offset_line);
    state.setContent(0, 22);
    try std.testing.expectEqual(@as(usize, 17), state.offset_line);
}
