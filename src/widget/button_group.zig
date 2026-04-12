const std = @import("std");
const parser = @import("../terminal/parser.zig");
const button = @import("button.zig");
const hstack = @import("hstack.zig");
const node_mod = @import("node.zig");

pub const Item = struct {
    label: []const u8,
    detail: ?[]const u8 = null,
    accelerator: ?[]const u8 = null,
    enabled: bool = true,
};

pub const State = struct {
    selected: usize = 0,
    focused: bool = true,

    pub fn handleKey(self: *State, items: []const Item, key: parser.Key) void {
        if (!self.focused or items.len == 0) return;
        switch (key) {
            .left => self.selected -|= 1,
            .right => self.selected = @min(self.selected + 1, items.len - 1),
            else => {},
        }
    }
};

pub fn build(allocator: std.mem.Allocator, items: []const Item, state: State) !*const node_mod.Node {
    const nodes = try allocator.alloc(*const node_mod.Node, items.len);
    for (items, 0..) |item, index| {
        nodes[index] = try button.build(allocator, .{
            .label = item.label,
            .detail = item.detail,
            .accelerator = item.accelerator,
            .disabled = !item.enabled,
            .focused = state.focused and index == state.selected,
            .pressed = false,
        }, .{ .variant = if (index == state.selected) .primary else .normal });
    }
    return try hstack.build(allocator, nodes, 1);
}

test "button group moves selection with arrows" {
    var state: State = .{};
    const items = [_]Item{ .{ .label = "A" }, .{ .label = "B" } };
    state.handleKey(&items, .right);
    try std.testing.expectEqual(@as(usize, 1), state.selected);
}
