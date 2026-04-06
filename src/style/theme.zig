const style_mod = @import("style.zig");
const border_mod = @import("border.zig");

pub const AgentTheme = struct {
    pane: style_mod.Style = .{ .fg = .{ .ansi = 8 } },
    pane_active: style_mod.Style = .{ .fg = .{ .ansi = 7 }, .bold = true },
    selected: style_mod.Style = .{ .fg = .{ .ansi = 15 }, .bg = .{ .ansi = 8 }, .bold = true },
    selected_alt: style_mod.Style = .{ .fg = .{ .ansi = 4 }, .bold = true },
    input: style_mod.Style = .{ .fg = .{ .ansi = 15 }, .bg = .{ .ansi = 0 } },
    input_active: style_mod.Style = .{ .fg = .{ .ansi = 15 }, .bg = .{ .ansi = 8 } },
    status_idle: style_mod.Style = .{ .fg = .{ .ansi = 8 } },
    status_running: style_mod.Style = .{ .fg = .{ .ansi = 208 }, .bold = true },
    status_error: style_mod.Style = .{ .fg = .{ .ansi = 1 }, .bold = true },
    border_style: border_mod.BorderStyle = .round,
    modal_border_style: border_mod.BorderStyle = .double,
};

pub fn defaultAgentTheme() AgentTheme {
    return .{};
}
