const std = @import("std");
const hstack = @import("hstack.zig");
const vstack = @import("vstack.zig");
const text = @import("text.zig");
const key_hints = @import("key_hints.zig");
const box = @import("box.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");

pub const Options = struct {
    center: ?[]const u8 = null,
    hints: ?[]const []const u8 = null,
    style: style_mod.Style = .{},
    left_style: style_mod.Style = .{},
    center_style: style_mod.Style = .{ .dim = true },
    right_style: style_mod.Style = .{},
    hint_style: style_mod.Style = .{ .dim = true },
    border_style: border_mod.BorderStyle = .single,
    boxed: bool = true,
};

pub fn build(
    allocator: std.mem.Allocator,
    left: []const u8,
    right: []const u8,
    options: Options,
) !*const node_mod.Node {
    const left_node = try text.buildWithOptions(allocator, try allocator.dupe(u8, left), .{
        .style = options.left_style,
        .wrap = .truncate_end,
    });
    const center_node = try text.buildWithOptions(allocator, try allocator.dupe(u8, options.center orelse ""), .{
        .style = options.center_style,
        .wrap = .truncate_end,
        .alignment = .center,
    });
    const right_node = try text.buildWithOptions(allocator, try allocator.dupe(u8, right), .{
        .style = options.right_style,
        .wrap = .truncate_start,
        .alignment = .right,
    });
    const row = try hstack.buildWithWeights(allocator, &.{ left_node, center_node, right_node }, 1, &.{ 2, 1, 2 });
    const content = if (options.hints) |hints|
        try vstack.build(allocator, &.{
            row,
            try key_hints.build(allocator, hints, .{
                .style = options.hint_style,
            }),
        }, 1)
    else
        row;

    if (!options.boxed) return content;
    return try box.buildWithOptions(allocator, null, content, .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
    });
}

test "footer bar builds three-part row" {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const node = try build(fba.allocator(), "left", "right", .{ .center = "mid" });
    try std.testing.expect(node.* == .box);
}

test "footer bar can include key hints" {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const hints = [_][]const u8{ "Ctrl+P Palette", "Esc Back" };
    const node = try build(fba.allocator(), "left", "right", .{ .hints = &hints });
    try std.testing.expect(node.* == .box);
}
