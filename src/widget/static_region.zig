const std = @import("std");
const rich_text = @import("../format/rich_text.zig");
const rich_document = @import("rich_document.zig");
const vstack = @import("vstack.zig");
const box = @import("box.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");

pub const State = struct {
    lines: []rich_text.Line = &.{},

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        rich_text.freeLines(allocator, self.lines);
        self.* = .{};
    }

    pub fn clear(self: *State, allocator: std.mem.Allocator) void {
        self.deinit(allocator);
    }

    pub fn appendPlainLine(self: *State, allocator: std.mem.Allocator, text: []const u8, style: style_mod.Style) !void {
        var out = std.ArrayList(rich_text.Line).empty;
        defer out.deinit(allocator);

        for (self.lines) |line| try out.append(allocator, try cloneLine(allocator, line));
        try out.append(allocator, try rich_text.plainLine(allocator, text, style));

        rich_text.freeLines(allocator, self.lines);
        self.lines = try out.toOwnedSlice(allocator);
    }
};

fn cloneLine(allocator: std.mem.Allocator, line: rich_text.Line) !rich_text.Line {
    const spans = try allocator.alloc(rich_text.Span, line.spans.len);
    for (line.spans, 0..) |span, index| {
        spans[index] = .{
            .text = try allocator.dupe(u8, span.text),
            .style = span.style,
            .link_target = if (span.link_target) |target| try allocator.dupe(u8, target) else null,
        };
    }
    return .{ .spans = spans };
}

pub const Options = struct {
    title: ?[]const u8 = "Static",
    style: style_mod.Style = .{},
    gap: u16 = 1,
};

pub fn build(
    allocator: std.mem.Allocator,
    state: *const State,
    live: *const node_mod.Node,
    options: Options,
) !*const node_mod.Node {
    if (state.lines.len == 0) return live;

    const static_doc = try rich_document.build(allocator, state.lines, rich_document.followOffset(state.lines.len, state.lines.len), options.style);
    const static_box = try box.buildWithOptions(allocator, options.title, static_doc, .{
        .style = options.style,
        .padding_left = 1,
        .padding_right = 1,
    });
    return try vstack.build(allocator, &.{ static_box, live }, options.gap);
}

test "static region wraps live node when lines exist" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var state: State = .{};
    defer state.deinit(std.testing.allocator);
    try state.appendPlainLine(std.testing.allocator, "done 1", .{});

    const live = try node_mod.allocNode(allocator, .{ .text = .{ .text = "live" } });

    const root = try build(allocator, &state, live, .{});
    try std.testing.expect(root.* == .vstack);
}
