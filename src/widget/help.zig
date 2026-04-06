const std = @import("std");
const box = @import("box.zig");
const text = @import("text.zig");
const vstack = @import("vstack.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");
const node_mod = @import("node.zig");

pub const Entry = struct {
    key: []const u8,
    description: []const u8,
};

pub const Options = struct {
    title: ?[]const u8 = "Help",
    style: style_mod.Style = .{},
    border_style: border_mod.BorderStyle = .single,
};

pub fn build(allocator: std.mem.Allocator, entries: []const Entry, options: Options) !*const node_mod.Node {
    const rows = try allocator.alloc(*const node_mod.Node, entries.len);
    for (entries, 0..) |entry, index| {
        rows[index] = try text.buildWithOptions(allocator, try std.fmt.allocPrint(allocator, "{s:<16} {s}", .{ entry.key, entry.description }), .{
            .style = options.style,
            .wrap = .truncate_end,
        });
    }
    return try box.buildWithOptions(allocator, options.title, try vstack.build(allocator, rows, 0), .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
}

test "help builds entry list" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const entries = [_]Entry{ .{ .key = "Ctrl+P", .description = "Open palette" } };
    const node = try build(alloc, &entries, .{});
    try std.testing.expect(node.* == .box);
}
