const std = @import("std");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");

pub const Options = struct {
    current: usize = 0,
    total: usize = 100,
    style: style_mod.Style = .{},
    fill_style: style_mod.Style = .{ .bold = true },
    empty_glyph: []const u8 = "░",
    full_glyph: []const u8 = "█",
    show_label: bool = true,
};

pub fn build(allocator: std.mem.Allocator, options: Options) !*const node_mod.Node {
    return try node_mod.allocNode(allocator, .{
        .progress_bar = .{
            .current = options.current,
            .total = options.total,
            .style = options.style,
            .fill_style = options.fill_style,
            .empty_glyph = options.empty_glyph,
            .full_glyph = options.full_glyph,
            .show_label = options.show_label,
        },
    });
}
