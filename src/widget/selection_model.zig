const std = @import("std");

pub const Direction = enum {
    previous,
    next,
};

pub fn clampIndex(index: usize, count: usize) usize {
    if (count == 0) return 0;
    return @min(index, count - 1);
}

pub fn ensureOptionalIndex(index: ?usize, count: usize) ?usize {
    if (count == 0) return null;
    return if (index) |value| clampIndex(value, count) else null;
}

pub fn move(cursor: *usize, count: usize, direction: Direction, wrap: bool) void {
    if (count == 0) {
        cursor.* = 0;
        return;
    }
    switch (direction) {
        .previous => {
            if (cursor.* == 0) {
                if (wrap) cursor.* = count - 1;
            } else {
                cursor.* -= 1;
            }
        },
        .next => {
            if (cursor.* + 1 >= count) {
                if (wrap) cursor.* = 0;
            } else {
                cursor.* += 1;
            }
        },
    }
}

pub fn moveEnabled(
    comptime Item: type,
    cursor: *usize,
    items: []const Item,
    direction: Direction,
    wrap: bool,
) void {
    if (items.len == 0) {
        cursor.* = 0;
        return;
    }

    cursor.* = clampIndex(cursor.*, items.len);
    var attempts: usize = 0;
    while (attempts < items.len) : (attempts += 1) {
        move(cursor, items.len, direction, wrap);
        if (!@hasField(Item, "enabled") or items[cursor.*].enabled) return;
    }

    if (@hasField(Item, "enabled") and !items[cursor.*].enabled) {
        var index: usize = 0;
        while (index < items.len) : (index += 1) {
            if (items[index].enabled) {
                cursor.* = index;
                return;
            }
        }
    }
}

pub fn firstEnabled(comptime Item: type, items: []const Item) ?usize {
    if (!@hasField(Item, "enabled")) return if (items.len == 0) null else 0;
    for (items, 0..) |item, index| {
        if (item.enabled) return index;
    }
    return null;
}

pub fn activateEnabled(comptime Item: type, selected: *?usize, cursor: usize, items: []const Item) bool {
    if (items.len == 0 or cursor >= items.len) return false;
    if (@hasField(Item, "enabled") and !items[cursor].enabled) return false;
    selected.* = cursor;
    return true;
}

pub fn windowOffset(selected: usize, count: usize, viewport: usize, current_offset: usize) usize {
    if (count == 0 or viewport == 0 or count <= viewport) return 0;

    var offset = @min(current_offset, count - viewport);
    if (selected < offset) return selected;
    if (selected >= offset + viewport) offset = selected + 1 - viewport;
    return @min(offset, count - viewport);
}

test "moveEnabled skips disabled items" {
    const Item = struct {
        enabled: bool,
    };

    const items = [_]Item{
        .{ .enabled = true },
        .{ .enabled = false },
        .{ .enabled = true },
    };

    var cursor: usize = 0;
    moveEnabled(Item, &cursor, &items, .next, false);
    try std.testing.expectEqual(@as(usize, 2), cursor);
}

test "windowOffset keeps selection visible" {
    try std.testing.expectEqual(@as(usize, 0), windowOffset(0, 10, 4, 0));
    try std.testing.expectEqual(@as(usize, 2), windowOffset(5, 10, 4, 0));
    try std.testing.expectEqual(@as(usize, 6), windowOffset(9, 10, 4, 0));
}
