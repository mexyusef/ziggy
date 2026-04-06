const screen_mod = @import("../terminal/screen.zig");
const overlay_mod = @import("overlay.zig");

pub const TabStatusKind = enum {
    idle,
    busy,
    waiting,
};

pub const RootState = struct {
    size: screen_mod.Size,
    focused: bool = true,
    frame_index: u64 = 0,
    now_ms: u64 = 0,
    title: ?[]const u8 = null,
    tab_status: ?TabStatusKind = null,
    overlay_count: usize = 0,
    blocking_overlay: ?overlay_mod.Kind = null,
};

pub const RootOptions = struct {
    focused: bool = true,
    now_ms: u64 = 0,
    title: ?[]const u8 = null,
    tab_status: ?TabStatusKind = null,
    tick_interval_ms: ?u64 = null,
};
