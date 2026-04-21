const std = @import("std");
const ziggy = @import("ziggy");
const support = @import("support.zig");

const Action = enum {
    open_palette,
    next_item,
    prev_item,
    close_palette,
};

pub fn main() !void {
    _ = ziggy.prepareConsole();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const root = try buildRoot(allocator);
    try support.renderStatic(root, support.detectTerminalSize());
}

pub fn buildRoot(allocator: std.mem.Allocator) !*const ziggy.Node {
    var router = ziggy.CommandRouter(Action).init(allocator);
    defer router.deinit();
    try router.bind(.ctrl_p, .open_palette);
    try router.bind(.down, .next_item);
    try router.bind(.up, .prev_item);
    try router.bind(.escape, .close_palette);

    var overlay_state = ziggy.Overlay.State.init(allocator);
    defer overlay_state.deinit();
    var overlay_manager = ziggy.OverlayManager.init(&overlay_state);
    try overlay_manager.openPalette("command", "Command Palette");

    var toast_manager = ziggy.ToastManager.init(allocator);
    defer toast_manager.deinit();
    try toast_manager.push("done", "DONE", "Command palette primitives are now available in ziggy.", .success, 0, 3000);

    const commands = try allocator.dupe([]const u8, &[_][]const u8{
        "Open Session",
        "Switch Model",
        "Review Diff",
        "Compact Context",
        "Doctor",
    });

    var down_event: ziggy.InputRuntime.KeyEvent = .{ .key = .down };
    const selected: usize = switch (router.handleKey(&down_event).?) {
        .next_item => 1,
        else => 0,
    };

    const dialog = try ziggy.CommandDialog.build(allocator, "Command Palette", "sw", commands, .{
        .selected = selected,
        .cursor = 2,
        .hint = "Ctrl+P opens, arrows move, Enter selects",
    });

    var editor = try ziggy.Editor.init(allocator, "sw");
    defer editor.deinit(allocator);
    const completion_items = [_]ziggy.Completion.Item{
        .{ .label = "Switch Model", .value = "Switch Model", .detail = "provider/model picker" },
        .{ .label = "Switch Workspace", .value = "Switch Workspace", .detail = "quick project switch" },
        .{ .label = "Sweep Session", .value = "Sweep Session", .detail = "compact current context" },
    };
    var completion_state: ziggy.Completion.State = .{};
    defer completion_state.deinit(allocator);
    try ziggy.Completion.update(allocator, &completion_state, &editor, &completion_items);
    completion_state.visible = true;
    completion_state.selected = 1;
    const popup = (try ziggy.AutocompletePopup.build(allocator, &completion_state, .{
        .title = "Autocomplete",
        .hint = "Tab/Enter accept",
    })) orelse unreachable;

    const tooltip = try ziggy.Tooltip.build(allocator, "This is an anchored-popup style surface candidate.", .{});
    const latest_toast = toast_manager.latest().?;
    const toast = try ziggy.Toast.build(allocator, .{
        .level = latest_toast.level,
        .label = latest_toast.label,
        .message = latest_toast.message,
    });
    return try ziggy.VStack.buildWithWeights(allocator, &.{ dialog, popup, tooltip, toast }, 1, &.{ 5, 2, 2, 2 });
}
