const std = @import("std");
const text = @import("text.zig");
const style_mod = @import("../style/style.zig");
const parser = @import("../terminal/parser.zig");
const node_mod = @import("node.zig");

pub const State = struct {
    label: []const u8,
    checked: bool = false,
    focused: bool = true,

    pub fn handleKey(self: *State, key: parser.Key) void {
        if (!self.focused) return;
        switch (key) {
            .enter, .tab => self.checked = !self.checked,
            .char => |c| {
                if (c == ' ') self.checked = !self.checked;
            },
            else => {},
        }
    }
};

pub fn build(allocator: std.mem.Allocator, state: State, style: style_mod.Style) !*const node_mod.Node {
    const marker = if (state.checked) "[x]" else "[ ]";
    return try text.buildWithOptions(allocator, try std.fmt.allocPrint(allocator, "{s} {s}", .{ marker, state.label }), .{
        .style = style,
        .wrap = .truncate_end,
    });
}

test "checkbox toggles on space" {
    var state: State = .{ .label = "check" };
    state.handleKey(.{ .char = ' ' });
    try std.testing.expect(state.checked);
}
