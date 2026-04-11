const std = @import("std");
const screen_mod = @import("../terminal/screen.zig");
const hstack = @import("hstack.zig");
const vstack = @import("vstack.zig");
const node_mod = @import("node.zig");

pub const Region = enum {
    left,
    right,
    bottom,
};

pub const PanelNode = struct {
    id: []const u8,
    node: *const node_mod.Node,
};

pub const EntrySnapshot = struct {
    id: []const u8,
    region: Region,
    size: u16,
    visible: bool = true,
};

pub const Snapshot = struct {
    entries: []EntrySnapshot,

    pub fn deinit(self: *Snapshot, allocator: std.mem.Allocator) void {
        for (self.entries) |entry| allocator.free(entry.id);
        allocator.free(self.entries);
        self.entries = &.{};
    }
};

pub const State = struct {
    entries: std.ArrayListUnmanaged(Entry) = .{},

    const Entry = struct {
        id: []const u8,
        region: Region,
        size: u16,
        visible: bool = true,
    };

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        for (self.entries.items) |entry| allocator.free(entry.id);
        self.entries.deinit(allocator);
    }

    pub fn add(self: *State, allocator: std.mem.Allocator, id: []const u8, region: Region, size: u16, visible: bool) !void {
        if (self.findEntry(id)) |entry| {
            entry.region = region;
            entry.size = size;
            entry.visible = visible;
            return;
        }
        try self.entries.append(allocator, .{
            .id = try allocator.dupe(u8, id),
            .region = region,
            .size = size,
            .visible = visible,
        });
    }

    pub fn show(self: *State, id: []const u8) bool {
        const entry = self.findEntry(id) orelse return false;
        entry.visible = true;
        return true;
    }

    pub fn hide(self: *State, id: []const u8) bool {
        const entry = self.findEntry(id) orelse return false;
        entry.visible = false;
        return true;
    }

    pub fn toggle(self: *State, id: []const u8) bool {
        const entry = self.findEntry(id) orelse return false;
        entry.visible = !entry.visible;
        return entry.visible;
    }

    pub fn showExclusive(self: *State, region: Region, id: []const u8) bool {
        var found = false;
        for (self.entries.items) |*entry| {
            if (entry.region != region) continue;
            entry.visible = std.mem.eql(u8, entry.id, id);
            if (entry.visible) found = true;
        }
        return found;
    }

    pub fn setSize(self: *State, id: []const u8, size: u16) bool {
        const entry = self.findEntry(id) orelse return false;
        entry.size = size;
        return true;
    }

    pub fn visibleCount(self: *const State, region: ?Region) usize {
        var count: usize = 0;
        for (self.entries.items) |entry| {
            if (!entry.visible) continue;
            if (region != null and entry.region != region.?) continue;
            count += 1;
        }
        return count;
    }

    pub fn build(
        self: *const State,
        allocator: std.mem.Allocator,
        size: screen_mod.Size,
        center: *const node_mod.Node,
        panels: []const PanelNode,
    ) !*const node_mod.Node {
        const side_layout = try self.buildHorizontalLayout(allocator, size, center, panels);
        return try self.buildBottomLayout(allocator, size, side_layout, panels);
    }

    pub fn snapshot(self: *const State, allocator: std.mem.Allocator) !Snapshot {
        const out = try allocator.alloc(EntrySnapshot, self.entries.items.len);
        for (self.entries.items, 0..) |entry, index| {
            out[index] = .{
                .id = try allocator.dupe(u8, entry.id),
                .region = entry.region,
                .size = entry.size,
                .visible = entry.visible,
            };
        }
        return .{ .entries = out };
    }

    pub fn restore(self: *State, allocator: std.mem.Allocator, saved: Snapshot) !void {
        self.deinit(allocator);
        self.* = .{};
        for (saved.entries) |entry| {
            try self.add(allocator, entry.id, entry.region, entry.size, entry.visible);
        }
    }

    fn buildHorizontalLayout(
        self: *const State,
        allocator: std.mem.Allocator,
        size: screen_mod.Size,
        center: *const node_mod.Node,
        panels: []const PanelNode,
    ) !*const node_mod.Node {
        const left = try self.buildRegionStack(allocator, .left, panels);
        const right = try self.buildRegionStack(allocator, .right, panels);
        if (left == null and right == null) return center;

        var children: std.ArrayList(*const node_mod.Node) = .empty;
        defer children.deinit(allocator);
        var weights: std.ArrayList(u16) = .empty;
        defer weights.deinit(allocator);

        const left_width = regionSize(self, .left);
        const right_width = regionSize(self, .right);
        const center_width = @max(size.width -| left_width -| right_width, 1);

        if (left) |node| {
            try children.append(allocator, node);
            try weights.append(allocator, @max(left_width, 1));
        }
        try children.append(allocator, center);
        try weights.append(allocator, center_width);
        if (right) |node| {
            try children.append(allocator, node);
            try weights.append(allocator, @max(right_width, 1));
        }

        return try hstack.buildWithWeights(allocator, children.items, 1, weights.items);
    }

    fn buildBottomLayout(
        self: *const State,
        allocator: std.mem.Allocator,
        size: screen_mod.Size,
        upper: *const node_mod.Node,
        panels: []const PanelNode,
    ) !*const node_mod.Node {
        const bottom = try self.buildRegionStack(allocator, .bottom, panels);
        if (bottom == null) return upper;
        const bottom_height = regionSize(self, .bottom);
        const upper_height = @max(size.height -| bottom_height, 1);
        const weights = [_]u16{ upper_height, @max(bottom_height, 1) };
        return try vstack.buildWithWeights(allocator, &.{ upper, bottom.? }, 1, &weights);
    }

    fn buildRegionStack(
        self: *const State,
        allocator: std.mem.Allocator,
        region: Region,
        panels: []const PanelNode,
    ) !?*const node_mod.Node {
        var nodes: std.ArrayList(*const node_mod.Node) = .empty;
        defer nodes.deinit(allocator);

        for (self.entries.items) |entry| {
            if (!entry.visible or entry.region != region) continue;
            const node = lookupPanelNode(panels, entry.id) orelse continue;
            try nodes.append(allocator, node);
        }

        if (nodes.items.len == 0) return null;
        if (nodes.items.len == 1) return nodes.items[0];

        return switch (region) {
            .left, .right => try vstack.build(allocator, nodes.items, 1),
            .bottom => try hstack.build(allocator, nodes.items, 1),
        };
    }

    fn findEntry(self: *State, id: []const u8) ?*Entry {
        for (self.entries.items) |*entry| {
            if (std.mem.eql(u8, entry.id, id)) return entry;
        }
        return null;
    }
};

fn lookupPanelNode(panels: []const PanelNode, id: []const u8) ?*const node_mod.Node {
    for (panels) |panel| {
        if (std.mem.eql(u8, panel.id, id)) return panel.node;
    }
    return null;
}

fn regionSize(state: *const State, region: Region) u16 {
    var max_size: u16 = 0;
    for (state.entries.items) |entry| {
        if (!entry.visible or entry.region != region) continue;
        max_size = @max(max_size, entry.size);
    }
    return max_size;
}

test "panel host supports visibility and exclusivity" {
    var state: State = .{};
    defer state.deinit(std.testing.allocator);

    try state.add(std.testing.allocator, "left-a", .left, 18, true);
    try state.add(std.testing.allocator, "left-b", .left, 14, false);
    try state.add(std.testing.allocator, "bottom", .bottom, 8, true);
    try std.testing.expectEqual(@as(usize, 2), state.visibleCount(null));
    try std.testing.expect(state.showExclusive(.left, "left-b"));
    try std.testing.expectEqual(@as(usize, 1), state.visibleCount(.left));
    try std.testing.expect(state.hide("bottom"));
    try std.testing.expectEqual(@as(usize, 0), state.visibleCount(.bottom));
}

test "panel host snapshot roundtrip preserves entries" {
    var state: State = .{};
    defer state.deinit(std.testing.allocator);
    try state.add(std.testing.allocator, "utility", .right, 24, true);
    try state.add(std.testing.allocator, "problems", .bottom, 8, false);

    var snapshot = try state.snapshot(std.testing.allocator);
    defer snapshot.deinit(std.testing.allocator);

    var restored: State = .{};
    defer restored.deinit(std.testing.allocator);
    try restored.restore(std.testing.allocator, snapshot);
    try std.testing.expectEqual(@as(usize, 1), restored.visibleCount(.right));
    try std.testing.expectEqual(@as(usize, 0), restored.visibleCount(.bottom));
}
