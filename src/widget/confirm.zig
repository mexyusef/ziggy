const std = @import("std");
const parser = @import("../terminal/parser.zig");
const modal = @import("modal.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");

pub const Result = enum {
    none,
    confirmed,
    cancelled,
};

pub const State = struct {
    visible: bool = false,
    selected_yes: bool = true,
    result: Result = .none,

    pub fn show(self: *State) void {
        self.visible = true;
        self.result = .none;
    }

    pub fn hide(self: *State) void {
        self.visible = false;
    }

    pub fn handleKey(self: *State, key: parser.Key) void {
        if (!self.visible) return;
        switch (key) {
            .left => self.selected_yes = true,
            .right => self.selected_yes = false,
            .escape => {
                self.result = .cancelled;
                self.visible = false;
            },
            .enter => {
                self.result = if (self.selected_yes) .confirmed else .cancelled;
                self.visible = false;
            },
            .char => |c| switch (c) {
                'y', 'Y' => {
                    self.result = .confirmed;
                    self.visible = false;
                },
                'n', 'N' => {
                    self.result = .cancelled;
                    self.visible = false;
                },
                else => {},
            },
            else => {},
        }
    }
};

pub fn build(allocator: std.mem.Allocator, title: []const u8, message: []const u8, state: State, style: style_mod.Style) !*const node_mod.Node {
    const prompt = if (state.selected_yes) "[Yes]  No" else " Yes  [No]";
    const body = try std.fmt.allocPrint(allocator, "{s}\n\n{s}", .{ message, prompt });
    return try modal.buildWithOptions(allocator, title, body, .{
        .style = style,
        .border_style = border_mod.BorderStyle.double,
    });
}

test "confirm selects no on right" {
    var state: State = .{ .visible = true };
    state.handleKey(.right);
    state.handleKey(.enter);
    try std.testing.expectEqual(Result.cancelled, state.result);
}
