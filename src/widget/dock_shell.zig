const std = @import("std");
const dock_layout = @import("dock_layout.zig");
const hstack = @import("hstack.zig");
const vstack = @import("vstack.zig");
const node_mod = @import("node.zig");

pub const Slot = struct {
    node: *const node_mod.Node,
    width: u16,
};

pub const RightColumn = struct {
    top: *const node_mod.Node,
    bottom: ?*const node_mod.Node = null,
    width: u16,
};

pub const Options = struct {
    layout: dock_layout.Layout,
    center: *const node_mod.Node,
    sidebar: ?Slot = null,
    right: ?RightColumn = null,
    bottom: ?*const node_mod.Node = null,
};

pub fn build(allocator: std.mem.Allocator, options: Options) !*const node_mod.Node {
    var main_children: std.ArrayList(*const node_mod.Node) = .empty;
    defer main_children.deinit(allocator);
    var main_weights: std.ArrayList(u16) = .empty;
    defer main_weights.deinit(allocator);

    if (options.sidebar) |sidebar| {
        try main_children.append(allocator, sidebar.node);
        try main_weights.append(allocator, @max(sidebar.width, 1));
    }

    try main_children.append(allocator, options.center);
    try main_weights.append(allocator, @max(options.layout.center_width, 1));

    if (options.right) |right| {
        const right_node = if (right.bottom) |bottom|
            try vstack.buildWithWeights(
                allocator,
                &.{ right.top, bottom },
                1,
                &.{ @max(options.layout.rightTopRect().?.height, 1), @max(options.layout.rightBottomRect().?.height, 1) },
            )
        else
            right.top;
        try main_children.append(allocator, right_node);
        try main_weights.append(allocator, @max(right.width, 1));
    }

    const main_row = try hstack.buildWithWeights(allocator, main_children.items, 1, main_weights.items);
    if (options.bottom) |bottom| {
        return try vstack.buildWithWeights(
            allocator,
            &.{ main_row, bottom },
            1,
            &.{ @max(options.layout.mainRowHeight(), 1), @max(options.layout.bottom_height, 1) },
        );
    }
    return main_row;
}

test "dock shell builds sidebar right and bottom regions" {
    var buffer: [16384]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const text = try node_mod.allocNode(allocator, .{ .text = .{ .text = "x" } });
    const layout = dock_layout.compute(true, true, .{ .width = 100, .height = 30 });
    const shell = try build(allocator, .{
        .layout = layout,
        .center = text,
        .sidebar = .{ .node = text, .width = layout.sidebar_width },
        .right = .{ .top = text, .bottom = text, .width = layout.right_width },
        .bottom = text,
    });
    try std.testing.expect(shell.* == .vstack);
}
