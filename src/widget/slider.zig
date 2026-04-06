const std = @import("std");
const parser = @import("../terminal/parser.zig");
const box = @import("box.zig");
const vstack = @import("vstack.zig");
const text = @import("text.zig");
const progress = @import("progress_bar.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");
const node_mod = @import("node.zig");

pub const State = struct {
    value: usize = 0,
    min: usize = 0,
    max: usize = 100,
    step: usize = 1,
    focused: bool = true,

    pub fn handleKey(self: *State, key: parser.Key) void {
        if (!self.focused) return;
        switch (key) {
            .left => self.value = if (self.value >= self.min + self.step) self.value - self.step else self.min,
            .right => self.value = @min(self.max, self.value + self.step),
            .home => self.value = self.min,
            .end => self.value = self.max,
            else => {},
        }
    }
};

pub const Options = struct {
    title: ?[]const u8 = "Slider",
    label: []const u8 = "Value",
    style: style_mod.Style = .{},
    fill_style: style_mod.Style = .{ .bold = true },
    border_style: border_mod.BorderStyle = .single,
};

pub fn build(allocator: std.mem.Allocator, state: State, options: Options) !*const node_mod.Node {
    const current = state.value - state.min;
    const total = @max(@as(usize, 1), state.max - state.min);
    const label = try text.buildWithOptions(allocator, try std.fmt.allocPrint(allocator, "{s}: {d}", .{ options.label, state.value }), .{
        .style = options.style,
        .wrap = .truncate_end,
    });
    const bar = try progress.build(allocator, .{
        .current = current,
        .total = total,
        .style = options.style,
        .fill_style = options.fill_style,
        .show_label = false,
    });
    return try box.buildWithOptions(allocator, options.title, try vstack.build(allocator, &.{ label, bar }, 1), .{
        .style = options.style,
        .border_style = options.border_style,
        .padding_left = 1,
        .padding_right = 1,
        .padding_top = 1,
        .padding_bottom = 1,
    });
}

test "slider moves right" {
    var state: State = .{};
    state.handleKey(.right);
    try std.testing.expectEqual(@as(usize, 1), state.value);
}
