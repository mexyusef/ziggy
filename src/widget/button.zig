const std = @import("std");
const accelerator = @import("accelerator.zig");
const badge = @import("badge.zig");
const hstack = @import("hstack.zig");
const text = @import("text.zig");
const box = @import("box.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");

pub const Variant = enum {
    normal,
    primary,
    danger,
};

pub const State = struct {
    label: []const u8,
    detail: ?[]const u8 = null,
    accelerator: ?[]const u8 = null,
    disabled: bool = false,
    focused: bool = true,
    pressed: bool = false,
};

pub const Options = struct {
    style: style_mod.Style = .{},
    primary_style: style_mod.Style = .{ .bold = true },
    danger_style: style_mod.Style = .{ .bold = true, .fg = .{ .ansi = 1 } },
    muted_style: style_mod.Style = .{ .dim = true },
    border_style: border_mod.BorderStyle = .single,
    variant: Variant = .normal,
};

pub fn build(allocator: std.mem.Allocator, state: State, options: Options) !*const node_mod.Node {
    const base_style = if (state.disabled)
        options.muted_style
    else switch (options.variant) {
        .normal => options.style,
        .primary => options.primary_style,
        .danger => options.danger_style,
    };

    var content: std.ArrayList(*const node_mod.Node) = .empty;
    defer content.deinit(allocator);
    try content.append(allocator, try text.buildWithOptions(allocator, try allocator.dupe(u8, state.label), .{
        .style = base_style,
        .wrap = .truncate_end,
    }));
    if (state.detail) |detail| {
        try content.append(allocator, try badge.build(allocator, detail, .{
            .style = if (state.disabled) options.muted_style else options.style,
        }));
    }
    if (state.accelerator) |keys| {
        try content.append(allocator, try accelerator.build(allocator, keys, .{}));
    }

    const body = if (content.items.len == 1) content.items[0] else try hstack.build(allocator, content.items, 1);
    return try box.buildWithOptions(allocator, null, body, .{
        .style = base_style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
    });
}

test "button builds boxed content with accelerator" {
    var buffer: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const node = try build(fba.allocator(), .{ .label = "Open", .accelerator = "Ctrl+P" }, .{ .variant = .primary });
    try std.testing.expect(node.* == .box);
}
