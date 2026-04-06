const std = @import("std");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");

pub const Options = struct {
    axis: node_mod.Node.SplitAxis = .horizontal,
    style: style_mod.Style = .{},
    glyph: ?[]const u8 = null,
};

pub fn build(allocator: std.mem.Allocator, options: Options) !*const node_mod.Node {
    return try node_mod.allocNode(allocator, .{
        .divider = .{
            .axis = options.axis,
            .style = options.style,
            .glyph = options.glyph,
        },
    });
}
