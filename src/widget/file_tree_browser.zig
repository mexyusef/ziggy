const std = @import("std");
const tree = @import("tree.zig");
const style_mod = @import("../style/style.zig");
const surface_mod = @import("surface.zig");
const parser = @import("../terminal/parser.zig");
const interaction = @import("../interaction/widget.zig");
const node_mod = @import("node.zig");

pub const Entry = struct {
    path: []const u8,
    label: []const u8,
    depth: usize,
    is_dir: bool = false,
    expanded: bool = false,
};

pub const Options = struct {
    title: ?[]const u8 = "Files",
    style: style_mod.Style = .{},
    selected_style: style_mod.Style = .{ .bold = true },
};

pub const State = struct {
    tree_state: tree.State = .{},
};

pub fn buildState(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    state: State,
    options: Options,
) !*const node_mod.Node {
    const items = try allocator.alloc(tree.Item, entries.len);
    defer allocator.free(items);
    for (entries, 0..) |entry, index| {
        items[index] = .{
            .depth = entry.depth,
            .label = entry.label,
            .expanded = entry.expanded,
        };
    }
    return try tree.buildState(allocator, items, state.tree_state, .{
        .title = options.title,
        .style = options.style,
        .selected_style = options.selected_style,
    });
}

pub fn handleEvent(state: *State, entries: []Entry, key: parser.Key) interaction.Response {
    switch (key) {
        .left => {
            if (entries.len == 0) return .{};
            const index = state.tree_state.selection.cursor;
            if (index < entries.len and entries[index].is_dir and entries[index].expanded) {
                entries[index].expanded = false;
                return .{ .handled = true, .redraw = true, .action = .changed, .selected = index };
            }
            return .{};
        },
        .right => {
            if (entries.len == 0) return .{};
            const index = state.tree_state.selection.cursor;
            if (index < entries.len and entries[index].is_dir and !entries[index].expanded) {
                entries[index].expanded = true;
                return .{ .handled = true, .redraw = true, .action = .changed, .selected = index };
            }
            return .{};
        },
        else => return state.tree_state.selection.handleListKey(entries.len, key),
    }
}

pub fn hitTestItem(rect: surface_mod.Rect, item_count: usize, x: u16, y: u16) ?usize {
    return tree.hitTestItem(rect, item_count, x, y);
}

pub fn fromPaths(allocator: std.mem.Allocator, paths: []const []const u8) ![]Entry {
    const entries = try allocator.alloc(Entry, paths.len);
    for (paths, 0..) |path, index| {
        const is_dir = std.mem.endsWith(u8, path, "/") or std.mem.endsWith(u8, path, "\\");
        const trimmed = std.mem.trimRight(u8, path, "/\\");
        const label = labelFromPath(trimmed);
        entries[index] = .{
            .path = path,
            .label = label,
            .depth = pathDepth(trimmed),
            .is_dir = is_dir,
            .expanded = false,
        };
    }
    return entries;
}

fn labelFromPath(path: []const u8) []const u8 {
    const slash = std.mem.lastIndexOfAny(u8, path, "/\\") orelse return path;
    return path[slash + 1 ..];
}

fn pathDepth(path: []const u8) usize {
    var depth: usize = 0;
    for (path) |byte| {
        if (byte == '/' or byte == '\\') depth += 1;
    }
    return depth;
}

test "file tree browser maps paths into entries" {
    const paths = [_][]const u8{
        "src/",
        "src/app.zig",
        "src/widget/",
        "src/widget/tree.zig",
    };
    const entries = try fromPaths(std.testing.allocator, &paths);
    defer std.testing.allocator.free(entries);
    try std.testing.expect(entries[0].is_dir);
    try std.testing.expectEqualStrings("app.zig", entries[1].label);
    try std.testing.expectEqual(@as(usize, 2), entries[3].depth);
}
