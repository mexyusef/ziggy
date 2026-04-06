const std = @import("std");
const text = @import("text.zig");
const style_mod = @import("../style/style.zig");
const parser = @import("../terminal/parser.zig");
const node_mod = @import("node.zig");

pub const State = struct {
    page: usize = 1,
    total_pages: usize = 1,
    focused: bool = true,

    pub fn handleKey(self: *State, key: parser.Key) void {
        if (!self.focused) return;
        switch (key) {
            .left, .page_up => {
                if (self.page > 1) self.page -= 1;
            },
            .right, .page_down => {
                if (self.page < self.total_pages) self.page += 1;
            },
            .home => self.page = 1,
            .end => self.page = self.total_pages,
            else => {},
        }
    }
};

pub fn build(allocator: std.mem.Allocator, state: State, style: style_mod.Style) !*const node_mod.Node {
    return try text.buildWithOptions(allocator, try std.fmt.allocPrint(allocator, "Page {d}/{d}", .{ state.page, state.total_pages }), .{
        .style = style,
        .wrap = .truncate_end,
        .alignment = .center,
    });
}

test "paginator advances page" {
    var state: State = .{ .page = 1, .total_pages = 3 };
    state.handleKey(.right);
    try std.testing.expectEqual(@as(usize, 2), state.page);
}
