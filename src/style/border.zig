pub const BorderStyle = enum {
    single,
    double,
    round,
    bold,
    classic,

    pub fn chars(self: BorderStyle) BorderChars {
        return switch (self) {
            .single => .{ .top_left = "┌", .top_right = "┐", .bottom_left = "└", .bottom_right = "┘", .horizontal = "─", .vertical = "│" },
            .double => .{ .top_left = "╔", .top_right = "╗", .bottom_left = "╚", .bottom_right = "╝", .horizontal = "═", .vertical = "║" },
            .round => .{ .top_left = "╭", .top_right = "╮", .bottom_left = "╰", .bottom_right = "╯", .horizontal = "─", .vertical = "│" },
            .bold => .{ .top_left = "┏", .top_right = "┓", .bottom_left = "┗", .bottom_right = "┛", .horizontal = "━", .vertical = "┃" },
            .classic => .{ .top_left = "+", .top_right = "+", .bottom_left = "+", .bottom_right = "+", .horizontal = "-", .vertical = "|" },
        };
    }
};

pub const BorderChars = struct {
    top_left: []const u8,
    top_right: []const u8,
    bottom_left: []const u8,
    bottom_right: []const u8,
    horizontal: []const u8,
    vertical: []const u8,
};
