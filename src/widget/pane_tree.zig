const std = @import("std");
const screen_mod = @import("../terminal/screen.zig");
const hstack = @import("hstack.zig");
const vstack = @import("vstack.zig");
const node_mod = @import("node.zig");
const parser = @import("../terminal/parser.zig");
const interaction = @import("../interaction/widget.zig");

pub const PaneId = u32;

pub const Axis = enum {
    horizontal,
    vertical,
};

pub const Pane = struct {
    id: PaneId,
    node: *const node_mod.Node,
};

pub const SnapshotNode = union(enum) {
    leaf: PaneId,
    split: struct {
        axis: Axis,
        ratio_percent: u8,
        first: usize,
        second: usize,
    },
};

pub const Snapshot = struct {
    nodes: []SnapshotNode,
    root_index: usize,
    focused: PaneId,
    next_id: PaneId,

    pub fn deinit(self: *Snapshot, allocator: std.mem.Allocator) void {
        allocator.free(self.nodes);
        self.* = .{
            .nodes = &.{},
            .root_index = 0,
            .focused = 0,
            .next_id = 0,
        };
    }
};

pub const State = struct {
    allocator: std.mem.Allocator,
    root: *TreeNode,
    focused: PaneId,
    next_id: PaneId,

    const TreeNode = union(enum) {
        leaf: PaneId,
        split: Split,
    };

    const Split = struct {
        axis: Axis,
        ratio_percent: u8,
        first: *TreeNode,
        second: *TreeNode,
    };

    pub fn initSingle(allocator: std.mem.Allocator, first_pane_id: PaneId) !State {
        const root = try allocator.create(TreeNode);
        root.* = .{ .leaf = first_pane_id };
        return .{
            .allocator = allocator,
            .root = root,
            .focused = first_pane_id,
            .next_id = first_pane_id + 1,
        };
    }

    pub fn deinit(self: *State) void {
        self.destroyNode(self.root);
    }

    pub fn allocPaneId(self: *State) PaneId {
        const pane_id = self.next_id;
        self.next_id += 1;
        return pane_id;
    }

    pub fn splitFocused(self: *State, axis: Axis, new_pane_id: ?PaneId) !PaneId {
        const pane_id = new_pane_id orelse self.allocPaneId();
        const target = self.findLeafNode(self.root, self.focused) orelse return error.PaneNotFound;
        const previous = target.leaf;

        const first = try self.allocator.create(TreeNode);
        errdefer self.allocator.destroy(first);
        first.* = .{ .leaf = previous };

        const second = try self.allocator.create(TreeNode);
        errdefer self.allocator.destroy(second);
        second.* = .{ .leaf = pane_id };

        target.* = .{
            .split = .{
                .axis = axis,
                .ratio_percent = 50,
                .first = first,
                .second = second,
            },
        };
        self.focused = pane_id;
        return pane_id;
    }

    pub fn focusPane(self: *State, pane_id: PaneId) bool {
        if (self.findLeafNode(self.root, pane_id) == null) return false;
        self.focused = pane_id;
        return true;
    }

    pub fn focusNext(self: *State) void {
        var ids: std.ArrayList(PaneId) = .empty;
        defer ids.deinit(self.allocator);
        self.collectLeafIds(self.root, &ids) catch return;
        if (ids.items.len == 0) return;
        const current = self.indexOf(ids.items, self.focused) orelse 0;
        self.focused = ids.items[(current + 1) % ids.items.len];
    }

    pub fn focusPrevious(self: *State) void {
        var ids: std.ArrayList(PaneId) = .empty;
        defer ids.deinit(self.allocator);
        self.collectLeafIds(self.root, &ids) catch return;
        if (ids.items.len == 0) return;
        const current = self.indexOf(ids.items, self.focused) orelse 0;
        self.focused = ids.items[(current + ids.items.len - 1) % ids.items.len];
    }

    pub fn handleEvent(self: *State, key: parser.Key) interaction.Response {
        switch (key) {
            .tab, .right, .down => {
                self.focusNext();
                return .{ .handled = true, .redraw = true, .action = .moved };
            },
            .back_tab, .left, .up => {
                self.focusPrevious();
                return .{ .handled = true, .redraw = true, .action = .moved };
            },
            .char => |c| switch (c) {
                'v', 'V' => {
                    _ = self.splitFocused(.vertical, null) catch return .{};
                    return .{ .handled = true, .redraw = true, .action = .changed };
                },
                's', 'S' => {
                    _ = self.splitFocused(.horizontal, null) catch return .{};
                    return .{ .handled = true, .redraw = true, .action = .changed };
                },
                'w', 'W' => {
                    if (self.closePane(self.focused)) return .{ .handled = true, .redraw = true, .action = .changed };
                    return .{};
                },
                else => return .{},
            },
            else => return .{},
        }
    }

    pub fn replacePane(self: *State, target_pane_id: PaneId, replacement_pane_id: PaneId) bool {
        const target = self.findLeafNode(self.root, target_pane_id) orelse return false;
        target.* = .{ .leaf = replacement_pane_id };
        if (self.focused == target_pane_id) self.focused = replacement_pane_id;
        if (replacement_pane_id >= self.next_id) self.next_id = replacement_pane_id + 1;
        return true;
    }

    pub fn swapPanes(self: *State, first_pane_id: PaneId, second_pane_id: PaneId) bool {
        const first = self.findLeafNode(self.root, first_pane_id) orelse return false;
        const second = self.findLeafNode(self.root, second_pane_id) orelse return false;
        first.* = .{ .leaf = second_pane_id };
        second.* = .{ .leaf = first_pane_id };
        if (self.focused == first_pane_id) {
            self.focused = second_pane_id;
        } else if (self.focused == second_pane_id) {
            self.focused = first_pane_id;
        }
        return true;
    }

    pub fn closePane(self: *State, pane_id: PaneId) bool {
        if (self.root.* == .leaf) return false;
        const result = self.closeIn(&self.root, pane_id);
        if (result) self.focusAfterClose();
        return result;
    }

    pub fn leafCount(self: *const State) usize {
        return self.countLeaves(self.root);
    }

    pub fn build(
        self: *const State,
        allocator: std.mem.Allocator,
        size: screen_mod.Size,
        panes: []const Pane,
    ) !*const node_mod.Node {
        return self.buildNode(allocator, size, self.root, panes);
    }

    pub fn snapshot(self: *const State, allocator: std.mem.Allocator) !Snapshot {
        var nodes: std.ArrayList(SnapshotNode) = .empty;
        defer nodes.deinit(allocator);
        const root_index = try self.snapshotNode(allocator, self.root, &nodes);
        return .{
            .nodes = try nodes.toOwnedSlice(allocator),
            .root_index = root_index,
            .focused = self.focused,
            .next_id = self.next_id,
        };
    }

    pub fn restore(allocator: std.mem.Allocator, saved: Snapshot) !State {
        if (saved.nodes.len == 0) return error.InvalidSnapshot;
        return .{
            .allocator = allocator,
            .root = try restoreNode(allocator, saved, saved.root_index),
            .focused = saved.focused,
            .next_id = saved.next_id,
        };
    }

    fn buildNode(
        self: *const State,
        allocator: std.mem.Allocator,
        size: screen_mod.Size,
        tree_node: *const TreeNode,
        panes: []const Pane,
    ) !*const node_mod.Node {
        return switch (tree_node.*) {
            .leaf => |pane_id| self.lookupPaneNode(panes, pane_id) orelse error.MissingPaneNode,
            .split => |split| blk: {
                const first_size, const second_size = splitChildSizes(size, split.axis, split.ratio_percent);
                const first = try self.buildNode(allocator, first_size, split.first, panes);
                const second = try self.buildNode(allocator, second_size, split.second, panes);
                const weights = switch (split.axis) {
                    .horizontal => [_]u16{
                        @max(@as(u16, @intCast(first_size.width)), 1),
                        @max(@as(u16, @intCast(second_size.width)), 1),
                    },
                    .vertical => [_]u16{
                        @max(@as(u16, @intCast(first_size.height)), 1),
                        @max(@as(u16, @intCast(second_size.height)), 1),
                    },
                };
                break :blk switch (split.axis) {
                    .horizontal => try hstack.buildWithWeights(allocator, &.{ first, second }, 1, &weights),
                    .vertical => try vstack.buildWithWeights(allocator, &.{ first, second }, 1, &weights),
                };
            },
        };
    }

    fn snapshotNode(
        self: *const State,
        allocator: std.mem.Allocator,
        tree_node: *const TreeNode,
        nodes: *std.ArrayList(SnapshotNode),
    ) !usize {
        return switch (tree_node.*) {
            .leaf => |pane_id| blk: {
                const index = nodes.items.len;
                try nodes.append(allocator, .{ .leaf = pane_id });
                break :blk index;
            },
            .split => |split| blk: {
                const first = try self.snapshotNode(allocator, split.first, nodes);
                const second = try self.snapshotNode(allocator, split.second, nodes);
                const index = nodes.items.len;
                try nodes.append(allocator, .{
                    .split = .{
                        .axis = split.axis,
                        .ratio_percent = split.ratio_percent,
                        .first = first,
                        .second = second,
                    },
                });
                break :blk index;
            },
        };
    }

    fn destroyNode(self: *State, tree_node: *TreeNode) void {
        switch (tree_node.*) {
            .leaf => {},
            .split => |split| {
                self.destroyNode(split.first);
                self.destroyNode(split.second);
            },
        }
        self.allocator.destroy(tree_node);
    }

    fn findLeafNode(_: *const State, tree_node: *TreeNode, pane_id: PaneId) ?*TreeNode {
        return switch (tree_node.*) {
            .leaf => |leaf_id| if (leaf_id == pane_id) tree_node else null,
            .split => |split| findLeafNode(undefined, split.first, pane_id) orelse findLeafNode(undefined, split.second, pane_id),
        };
    }

    fn closeIn(self: *State, tree_node_ptr: **TreeNode, pane_id: PaneId) bool {
        const tree_node = tree_node_ptr.*;
        switch (tree_node.*) {
            .leaf => return false,
            .split => |*split| {
                if (split.first.* == .leaf and split.first.leaf == pane_id) {
                    self.destroyNode(split.first);
                    const sibling = split.second;
                    tree_node_ptr.* = sibling;
                    self.allocator.destroy(tree_node);
                    return true;
                }
                if (split.second.* == .leaf and split.second.leaf == pane_id) {
                    self.destroyNode(split.second);
                    const sibling = split.first;
                    tree_node_ptr.* = sibling;
                    self.allocator.destroy(tree_node);
                    return true;
                }
                return self.closeIn(&split.first, pane_id) or self.closeIn(&split.second, pane_id);
            },
        }
    }

    fn focusAfterClose(self: *State) void {
        if (self.findLeafNode(self.root, self.focused) != null) return;
        var ids: std.ArrayList(PaneId) = .empty;
        defer ids.deinit(self.allocator);
        self.collectLeafIds(self.root, &ids) catch return;
        if (ids.items.len > 0) self.focused = ids.items[0];
    }

    fn countLeaves(_: *const State, tree_node: *const TreeNode) usize {
        return switch (tree_node.*) {
            .leaf => 1,
            .split => |split| countLeaves(undefined, split.first) + countLeaves(undefined, split.second),
        };
    }

    fn collectLeafIds(self: *const State, tree_node: *const TreeNode, ids: *std.ArrayList(PaneId)) !void {
        switch (tree_node.*) {
            .leaf => |pane_id| try ids.append(self.allocator, pane_id),
            .split => |split| {
                try self.collectLeafIds(split.first, ids);
                try self.collectLeafIds(split.second, ids);
            },
        }
    }

    fn lookupPaneNode(_: *const State, panes: []const Pane, pane_id: PaneId) ?*const node_mod.Node {
        for (panes) |pane| {
            if (pane.id == pane_id) return pane.node;
        }
        return null;
    }

    fn indexOf(_: *const State, ids: []const PaneId, pane_id: PaneId) ?usize {
        for (ids, 0..) |id, index| {
            if (id == pane_id) return index;
        }
        return null;
    }
};

fn restoreNode(allocator: std.mem.Allocator, saved: Snapshot, index: usize) !*State.TreeNode {
    if (index >= saved.nodes.len) return error.InvalidSnapshot;
    const node = try allocator.create(State.TreeNode);
    errdefer allocator.destroy(node);
    node.* = switch (saved.nodes[index]) {
        .leaf => |pane_id| .{ .leaf = pane_id },
        .split => |split| .{
            .split = .{
                .axis = split.axis,
                .ratio_percent = split.ratio_percent,
                .first = try restoreNode(allocator, saved, split.first),
                .second = try restoreNode(allocator, saved, split.second),
            },
        },
    };
    return node;
}

fn splitChildSizes(size: screen_mod.Size, axis: Axis, ratio_percent: u8) struct { screen_mod.Size, screen_mod.Size } {
    return switch (axis) {
        .horizontal => blk: {
            const gap: u16 = if (size.width > 0) 1 else 0;
            const usable_width = size.width -| gap;
            const first_width: u16 = @max(@as(u16, @intCast((@as(u32, usable_width) * ratio_percent) / 100)), 1);
            const second_width: u16 = @max(usable_width -| first_width, 1);
            break :blk .{
                .{ .width = first_width, .height = size.height },
                .{ .width = second_width, .height = size.height },
            };
        },
        .vertical => blk: {
            const gap: u16 = if (size.height > 0) 1 else 0;
            const usable_height = size.height -| gap;
            const first_height: u16 = @max(@as(u16, @intCast((@as(u32, usable_height) * ratio_percent) / 100)), 1);
            const second_height: u16 = @max(usable_height -| first_height, 1);
            break :blk .{
                .{ .width = size.width, .height = first_height },
                .{ .width = size.width, .height = second_height },
            };
        },
    };
}

test "pane tree supports split swap close and focus" {
    var state = try State.initSingle(std.testing.allocator, 1);
    defer state.deinit();

    const second = try state.splitFocused(.horizontal, null);
    try std.testing.expectEqual(@as(PaneId, 2), second);
    try std.testing.expectEqual(@as(usize, 2), state.leafCount());
    try std.testing.expect(state.focusPane(1));
    state.focusNext();
    try std.testing.expectEqual(@as(PaneId, 2), state.focused);
    try std.testing.expect(state.swapPanes(1, 2));
    try std.testing.expect(state.replacePane(1, 9));
    try std.testing.expect(state.focusPane(9));
    try std.testing.expect(state.closePane(2));
    try std.testing.expectEqual(@as(usize, 1), state.leafCount());
    try std.testing.expectEqual(@as(PaneId, 9), state.focused);
}

test "pane tree snapshot roundtrip preserves structure" {
    var state = try State.initSingle(std.testing.allocator, 1);
    defer state.deinit();
    _ = try state.splitFocused(.horizontal, 2);
    _ = try state.splitFocused(.vertical, 3);

    var snapshot = try state.snapshot(std.testing.allocator);
    defer snapshot.deinit(std.testing.allocator);

    var restored = try State.restore(std.testing.allocator, snapshot);
    defer restored.deinit();
    try std.testing.expectEqual(@as(usize, 3), restored.leafCount());
    try std.testing.expectEqual(state.focused, restored.focused);
}

test "pane tree handleEvent cycles and splits" {
    var state = try State.initSingle(std.testing.allocator, 1);
    defer state.deinit();
    const split = state.handleEvent(.{ .char = 'v' });
    try std.testing.expectEqual(interaction.Action.changed, split.action);
    try std.testing.expectEqual(@as(usize, 2), state.leafCount());
    const moved = state.handleEvent(.tab);
    try std.testing.expectEqual(interaction.Action.moved, moved.action);
}
