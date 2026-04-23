const std = @import("std");
const parser = @import("../terminal/parser.zig");
const box = @import("box.zig");
const text = @import("text.zig");
const vstack = @import("vstack.zig");
const selection_model = @import("selection_model.zig");
const style_mod = @import("../style/style.zig");
const border_mod = @import("../style/border.zig");
const node_mod = @import("node.zig");
const interaction = @import("../interaction/widget.zig");

pub const Item = struct {
    label: []const u8,
    enabled: bool = true,
};

pub const State = struct {
    expanded: bool = false,
    cursor: usize = 0,
    offset: usize = 0,
    selected: ?usize = null,
    focused: bool = true,
};

pub fn handleEvent(state: *State, items: []const Item, key: parser.Key) interaction.Response {
    if (!state.focused or items.len == 0) return .{};
    var select: interaction.SelectState = .{
        .open = state.expanded,
        .cursor = state.cursor,
        .selected = state.selected,
        .focused = state.focused,
    };
    defer {
        state.expanded = select.open;
        state.cursor = select.cursor;
        state.selected = select.selected;
        state.offset = selection_model.windowOffset(state.cursor, items.len, 5, state.offset);
    }
    select.normalize(items.len);
    if (!select.open) {
        switch (key) {
            .enter, .down, .tab => {
                const response = select.openMenu(items.len);
                if (selection_model.firstEnabled(Item, items)) |index| {
                    select.cursor = if (state.selected) |selected| selection_model.clampIndex(selected, items.len) else index;
                }
                return response;
            },
            else => return .{},
        }
    }
    switch (key) {
        .up => return select.moveEnabled(Item, items, .previous),
        .down => return select.moveEnabled(Item, items, .next),
        .escape => return select.closeMenu(),
        .enter, .tab => {
            const response = select.activateEnabled(Item, items);
            if (response.action == .submitted) select.open = false;
            return response;
        },
        else => return .{},
    }
}

pub fn handleKey(state: *State, items: []const Item, key: parser.Key) void {
    _ = handleEvent(state, items, key);
}

pub const Options = struct {
    title: ?[]const u8 = "Dropdown",
    placeholder: []const u8 = "Select...",
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
    disabled_style: style_mod.Style = .{ .dim = true },
    border_style: border_mod.BorderStyle = .single,
    max_visible_items: usize = 5,
};

pub fn build(allocator: std.mem.Allocator, items: []const Item, state: State, options: Options) !*const node_mod.Node {
    const trigger_text = if (state.selected) |index| items[index].label else options.placeholder;
    const trigger = try text.buildWithOptions(allocator, try std.fmt.allocPrint(allocator, "{s} {s}", .{ trigger_text, if (state.expanded) "▲" else "▼" }), .{
        .style = options.style,
        .wrap = .truncate_end,
    });
    if (!state.expanded) {
        return try box.buildWithOptions(allocator, options.title, trigger, .{
            .style = options.style,
            .border_style = options.border_style,
            .padding_left = 1,
            .padding_right = 1,
            .padding_top = 1,
            .padding_bottom = 1,
        });
    }
    const visible_items = @min(options.max_visible_items, items.len);
    const offset = selection_model.windowOffset(state.cursor, items.len, visible_items, state.offset);
    const rows = try allocator.alloc(*const node_mod.Node, visible_items + 1);
    rows[0] = trigger;
    for (items[offset .. offset + visible_items], 0..) |item, visible_index| {
        const index = offset + visible_index;
        const prefix = if (index == state.cursor) "> " else "  ";
        rows[visible_index + 1] = try text.buildWithOptions(allocator, try std.fmt.allocPrint(allocator, "{s}{s}", .{ prefix, item.label }), .{
            .style = if (!item.enabled) options.disabled_style else if (index == state.cursor) options.selected_style else options.style,
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

test "dropdown chooses item" {
    const items = [_]Item{ .{ .label = "A" }, .{ .label = "B" } };
    var state: State = .{};
    handleKey(&state, &items, .enter);
    handleKey(&state, &items, .down);
    handleKey(&state, &items, .enter);
    try std.testing.expectEqual(@as(?usize, 1), state.selected);
}

test "dropdown skips disabled options" {
    const items = [_]Item{ .{ .label = "A" }, .{ .label = "B", .enabled = false }, .{ .label = "C" } };
    var state: State = .{};
    handleKey(&state, &items, .enter);
    handleKey(&state, &items, .down);
    try std.testing.expectEqual(@as(usize, 2), state.cursor);
}

test "dropdown event response reports submit" {
    const items = [_]Item{ .{ .label = "A" }, .{ .label = "B" } };
    var state: State = .{};
    _ = handleEvent(&state, &items, .enter);
    _ = handleEvent(&state, &items, .down);
    const response = handleEvent(&state, &items, .enter);
    try std.testing.expectEqual(interaction.Action.submitted, response.action);
    try std.testing.expectEqual(@as(?usize, 1), response.selected);
}

test "dropdown keeps cursor window visible" {
    const items = [_]Item{
        .{ .label = "A" },
        .{ .label = "B" },
        .{ .label = "C" },
        .{ .label = "D" },
        .{ .label = "E" },
        .{ .label = "F" },
    };
    var state: State = .{};
    _ = handleEvent(&state, &items, .enter);
    _ = handleEvent(&state, &items, .down);
    _ = handleEvent(&state, &items, .down);
    _ = handleEvent(&state, &items, .down);
    _ = handleEvent(&state, &items, .down);
    _ = handleEvent(&state, &items, .down);
    try std.testing.expectEqual(@as(usize, 5), state.cursor);
    try std.testing.expect(state.offset > 0);
}
