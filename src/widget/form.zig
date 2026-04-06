const std = @import("std");
const box = @import("box.zig");
const input = @import("input.zig");
const text = @import("text.zig");
const vstack = @import("vstack.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");
const node_mod = @import("node.zig");

pub const Field = struct {
    label: []const u8,
    value: []const u8,
    cursor: usize = 0,
    focused: bool = false,
    help: ?[]const u8 = null,
};

pub const Options = struct {
    title: ?[]const u8 = "Form",
    style: style_mod.Style = .{},
    help_style: style_mod.Style = .{ .dim = true },
    border_style: border_mod.BorderStyle = .single,
};

pub fn build(allocator: std.mem.Allocator, fields: []const Field, options: Options) !*const node_mod.Node {
    const children = try allocator.alloc(*const node_mod.Node, fields.len * 2);
    var out: usize = 0;
    for (fields) |field| {
        children[out] = try input.build(allocator, try std.fmt.allocPrint(allocator, "{s}: ", .{field.label}), try allocator.dupe(u8, field.value), field.cursor, field.focused, options.style);
        out += 1;
        children[out] = if (field.help) |help_text|
            try text.buildWithOptions(allocator, try allocator.dupe(u8, help_text), .{ .style = options.help_style, .wrap = .wrap })
        else
            try text.build(allocator, "", options.help_style);
        out += 1;
    }
    return try box.buildWithOptions(allocator, options.title, try vstack.build(allocator, children, 1), .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
}

test "form builds labeled fields" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const fields = [_]Field{ .{ .label = "Name", .value = "ziggy", .focused = true } };
    const node = try build(alloc, &fields, .{});
    try std.testing.expect(node.* == .box);
}
