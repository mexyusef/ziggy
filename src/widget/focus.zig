pub const FocusState = struct {
    active: bool = false,
    focus_id: ?[]const u8 = null,
};

pub const FocusTarget = struct {
    id: []const u8,
    active: bool = false,
};
