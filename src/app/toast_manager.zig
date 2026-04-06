const std = @import("std");
const widget_toast = @import("../widget/toast.zig");

pub const ToastEntry = struct {
    id: []u8,
    label: []u8,
    message: []u8,
    level: widget_toast.Level,
    expires_at_ms: u64,

    fn deinit(self: *ToastEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.label);
        allocator.free(self.message);
    }
};

pub const Manager = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(ToastEntry) = .empty,

    pub fn init(allocator: std.mem.Allocator) Manager {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Manager) void {
        for (self.entries.items) |*entry| entry.deinit(self.allocator);
        self.entries.deinit(self.allocator);
    }

    pub fn push(
        self: *Manager,
        id: []const u8,
        label: []const u8,
        message: []const u8,
        level: widget_toast.Level,
        now_ms: u64,
        ttl_ms: u64,
    ) !void {
        try self.entries.append(self.allocator, .{
            .id = try self.allocator.dupe(u8, id),
            .label = try self.allocator.dupe(u8, label),
            .message = try self.allocator.dupe(u8, message),
            .level = level,
            .expires_at_ms = now_ms + ttl_ms,
        });
    }

    pub fn sweep(self: *Manager, now_ms: u64) void {
        var index: usize = 0;
        while (index < self.entries.items.len) {
            if (self.entries.items[index].expires_at_ms <= now_ms) {
                var removed = self.entries.orderedRemove(index);
                removed.deinit(self.allocator);
            } else {
                index += 1;
            }
        }
    }

    pub fn latest(self: *const Manager) ?ToastEntry {
        if (self.entries.items.len == 0) return null;
        return self.entries.items[self.entries.items.len - 1];
    }
};

test "toast manager expires entries" {
    var manager = Manager.init(std.testing.allocator);
    defer manager.deinit();
    try manager.push("saved", "DONE", "Saved.", .success, 100, 50);
    try std.testing.expect(manager.latest() != null);
    manager.sweep(151);
    try std.testing.expect(manager.latest() == null);
}
