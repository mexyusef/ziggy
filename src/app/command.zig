pub const Tag = enum {
    none,
    quit,
    redraw,
    set_tick_interval_ms,
    clear_tick_interval,
    set_title,
    clear_title,
    set_tab_status,
    clear_tab_status,
};

pub fn Command(comptime Msg: type) type {
    _ = Msg;
    return union(Tag) {
        none,
        quit,
        redraw,
        set_tick_interval_ms: u64,
        clear_tick_interval,
        set_title: []const u8,
        clear_title,
        set_tab_status: @import("root.zig").TabStatusKind,
        clear_tab_status,
    };
}
