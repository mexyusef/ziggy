const std = @import("std");
const screen_mod = @import("../terminal/screen.zig");
const root_mod = @import("root.zig");
const input_mod = @import("input.zig");
const overlay_mod = @import("overlay.zig");

pub const Context = struct {
    allocator: std.mem.Allocator,
    persistent_allocator: std.mem.Allocator,
    size: screen_mod.Size,
    focused: bool = true,
    frame_index: u64 = 0,
    now_ms: u64 = 0,
    title: ?[]const u8 = null,
    tab_status: ?root_mod.TabStatusKind = null,
    input_dispatcher: ?*input_mod.Dispatcher = null,
    overlays: ?*overlay_mod.State = null,
    redraw_requested: bool = false,
    quit_requested: bool = false,

    pub fn requestRedraw(self: *Context) void {
        self.redraw_requested = true;
    }

    pub fn requestQuit(self: *Context) void {
        self.quit_requested = true;
    }

    pub fn openOverlay(self: *Context, id: []const u8, title: ?[]const u8, kind: overlay_mod.Kind) !void {
        if (self.overlays) |overlays| {
            try overlays.push(id, title, kind, null);
            self.requestRedraw();
        }
    }

    pub fn closeOverlay(self: *Context, id: []const u8) void {
        if (self.overlays) |overlays| {
            if (overlays.pop(id)) self.requestRedraw();
        }
    }
};
