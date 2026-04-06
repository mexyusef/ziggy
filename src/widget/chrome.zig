const std = @import("std");
const node_mod = @import("node.zig");
const split = @import("split.zig");
const modal = @import("modal.zig");
const theme_mod = @import("../style/theme.zig");

pub const AgentShellOptions = struct {
    top_ratio_percent: u8 = 72,
    left_ratio_percent: u8 = 68,
    bottom_ratio_percent: u8 = 65,
};

pub fn buildAgentShell(
    allocator: std.mem.Allocator,
    left: *const node_mod.Node,
    right: *const node_mod.Node,
    input: *const node_mod.Node,
    status: *const node_mod.Node,
    options: AgentShellOptions,
) !*const node_mod.Node {
    const top = try split.build(allocator, left, right, options.left_ratio_percent, .horizontal);
    const bottom = try split.build(allocator, input, status, options.bottom_ratio_percent, .vertical);
    return try split.build(allocator, top, bottom, options.top_ratio_percent, .vertical);
}

pub fn buildOverlayModal(
    allocator: std.mem.Allocator,
    base: *const node_mod.Node,
    title: []const u8,
    body: []const u8,
) !*const node_mod.Node {
    return buildOverlayModalThemed(allocator, base, title, body, theme_mod.defaultAgentTheme());
}

pub fn buildOverlayModalThemed(
    allocator: std.mem.Allocator,
    base: *const node_mod.Node,
    title: []const u8,
    body: []const u8,
    theme: theme_mod.AgentTheme,
) !*const node_mod.Node {
    const overlay = try modal.buildWithOptions(allocator, title, body, .{
        .style = .{
            .fg = .{ .ansi = 15 },
            .bg = .{ .ansi = 4 },
            .bold = true,
        },
        .border_style = theme.modal_border_style,
    });
    return try node_mod.allocNode(allocator, .{
        .overlay = .{ .base = base, .overlay = overlay },
    });
}

test "agent shell builds nested split layout" {
    const left = try node_mod.allocNode(std.testing.allocator, .{ .text = .{ .text = "L" } });
    const right = try node_mod.allocNode(std.testing.allocator, .{ .text = .{ .text = "R" } });
    const input = try node_mod.allocNode(std.testing.allocator, .{ .text = .{ .text = "I" } });
    const status = try node_mod.allocNode(std.testing.allocator, .{ .text = .{ .text = "S" } });

    const root = try buildAgentShell(std.testing.allocator, left, right, input, status, .{});
    defer destroyOwnedNode(std.testing.allocator, root);
    try std.testing.expect(root.* == .split);
}

fn destroyOwnedNode(allocator: std.mem.Allocator, node: *const node_mod.Node) void {
    switch (node.*) {
        .split => |data| {
            destroyOwnedNode(allocator, data.left);
            destroyOwnedNode(allocator, data.right);
        },
        .overlay => |data| {
            destroyOwnedNode(allocator, data.base);
            destroyOwnedNode(allocator, data.overlay);
        },
        .box => |data| {
            if (data.child) |child| destroyOwnedNode(allocator, child);
        },
        else => {},
    }
    allocator.destroy(node);
}
