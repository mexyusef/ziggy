const std = @import("std");
const node_mod = @import("node.zig");
const hstack = @import("hstack.zig");
const divider = @import("divider.zig");
const text = @import("text.zig");
const style_mod = @import("../style/style.zig");

pub const Options = struct {
    label_style: style_mod.Style = .{ .bold = true },
    line_style: style_mod.Style = .{},
    gap: u16 = 1,
    alignment: node_mod.Node.HorizontalAlign = .center,
    glyph: ?[]const u8 = null,
};

pub fn build(
    allocator: std.mem.Allocator,
    label: []const u8,
    options: Options,
) !*const node_mod.Node {
    const left = try divider.build(allocator, .{
        .axis = .horizontal,
        .style = options.line_style,
        .glyph = options.glyph,
    });
    const center = try text.buildWithOptions(allocator, try allocator.dupe(u8, label), .{
        .style = options.label_style,
        .wrap = .truncate_end,
        .alignment = options.alignment,
    });
    const right = try divider.build(allocator, .{
        .axis = .horizontal,
        .style = options.line_style,
        .glyph = options.glyph,
    });
    return try hstack.buildWithWeights(allocator, &.{ left, center, right }, options.gap, &.{ 3, 0, 3 });
}

test "separator builds labeled divider row" {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const node = try build(fba.allocator(), "Section", .{});
    try std.testing.expect(node.* == .hstack);
}
