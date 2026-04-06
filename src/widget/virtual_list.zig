const std = @import("std");
const parser = @import("../terminal/parser.zig");
const scroll_container = @import("scroll_container.zig");
const rich_document = @import("rich_document.zig");
const rich_text = @import("../format/rich_text.zig");
const style_mod = @import("../style/style.zig");
const node_mod = @import("node.zig");

pub const State = struct {
    cursor: usize = 0,
    offset: usize = 0,
    viewport: usize = 8,
    focused: bool = true,
};

pub fn handleKey(state: *State, item_count: usize, key: parser.Key) void {
    if (!state.focused or item_count == 0) return;
    switch (key) {
        .up => {
            if (state.cursor > 0) state.cursor -= 1;
        },
        .down => {
            if (state.cursor + 1 < item_count) state.cursor += 1;
        },
        .page_up => state.cursor = state.cursor -| state.viewport,
        .page_down => state.cursor = @min(item_count - 1, state.cursor + state.viewport),
        .home => state.cursor = 0,
        .end => state.cursor = item_count - 1,
        else => {},
    }
    if (state.cursor < state.offset) state.offset = state.cursor;
    if (state.cursor >= state.offset + state.viewport) state.offset = state.cursor - state.viewport + 1;
}

pub const Options = struct {
    title: ?[]const u8 = "Virtual List",
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    viewport: usize = 8,
};

pub fn build(allocator: std.mem.Allocator, items: []const []const u8, state: State, options: Options) !*const node_mod.Node {
    const start = @min(state.offset, items.len);
    const end = @min(start + options.viewport, items.len);
    const lines = try allocator.alloc(rich_text.Line, end - start);
    var out: usize = 0;
    for (items[start..end], start..) |item, absolute_index| {
        const style = if (absolute_index == state.cursor) options.selected_style else options.style;
        const spans = try allocator.alloc(rich_text.Span, 1);
        spans[0] = .{ .text = try std.fmt.allocPrint(allocator, "{s}{s}", .{ if (absolute_index == state.cursor) "> " else "  ", item }), .style = style };
        lines[out] = .{ .spans = spans };
        out += 1;
    }
    const doc = try rich_document.build(allocator, lines, 0, options.style);
    return try scroll_container.build(allocator, doc, .{
        .title = options.title,
        .offset = state.offset,
        .viewport = options.viewport,
        .total = items.len,
        .style = options.style,
    });
}

test "virtual list advances cursor" {
    var state: State = .{};
    handleKey(&state, 20, .page_down);
    try std.testing.expectEqual(@as(usize, 8), state.cursor);
}
