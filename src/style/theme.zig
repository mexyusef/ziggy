const std = @import("std");
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

pub fn bubbleAgentTheme() AgentTheme {
    return .{
        .pane = .{
            .fg = .{ .rgb = .{ .r = 181, .g = 189, .b = 214 } },
            .bg = .{ .rgb = .{ .r = 18, .g = 22, .b = 33 } },
        },
        .pane_active = .{
            .fg = .{ .rgb = .{ .r = 242, .g = 245, .b = 255 } },
            .bg = .{ .rgb = .{ .r = 16, .g = 85, .b = 128 } },
            .bold = true,
        },
        .selected = .{
            .fg = .{ .rgb = .{ .r = 248, .g = 250, .b = 252 } },
            .bg = .{ .rgb = .{ .r = 52, .g = 211, .b = 153 } },
            .bold = true,
        },
        .selected_alt = .{
            .fg = .{ .rgb = .{ .r = 240, .g = 249, .b = 255 } },
            .bg = .{ .rgb = .{ .r = 14, .g = 116, .b = 144 } },
            .bold = true,
        },
        .input = .{
            .fg = .{ .rgb = .{ .r = 239, .g = 244, .b = 255 } },
            .bg = .{ .rgb = .{ .r = 39, .g = 46, .b = 66 } },
        },
        .input_active = .{
            .fg = .{ .rgb = .{ .r = 250, .g = 252, .b = 255 } },
            .bg = .{ .rgb = .{ .r = 56, .g = 86, .b = 122 } },
            .bold = true,
        },
        .status_idle = .{
            .fg = .{ .rgb = .{ .r = 148, .g = 163, .b = 184 } },
        },
        .status_running = .{
            .fg = .{ .rgb = .{ .r = 251, .g = 191, .b = 36 } },
            .bold = true,
        },
        .status_error = .{
            .fg = .{ .rgb = .{ .r = 248, .g = 113, .b = 113 } },
            .bold = true,
        },
        .border_style = .round,
        .modal_border_style = .double,
    };
}

pub fn midnightAgentTheme() AgentTheme {
    return .{
        .pane = .{
            .fg = .{ .rgb = .{ .r = 205, .g = 213, .b = 235 } },
            .bg = .{ .rgb = .{ .r = 11, .g = 14, .b = 22 } },
        },
        .pane_active = .{
            .fg = .{ .rgb = .{ .r = 244, .g = 247, .b = 255 } },
            .bg = .{ .rgb = .{ .r = 31, .g = 58, .b = 147 } },
            .bold = true,
        },
        .selected = .{
            .fg = .{ .rgb = .{ .r = 255, .g = 250, .b = 240 } },
            .bg = .{ .rgb = .{ .r = 217, .g = 119, .b = 6 } },
            .bold = true,
        },
        .selected_alt = .{
            .fg = .{ .rgb = .{ .r = 254, .g = 240, .b = 138 } },
            .bg = .{ .rgb = .{ .r = 120, .g = 53, .b = 15 } },
            .bold = true,
        },
        .input = .{
            .fg = .{ .rgb = .{ .r = 239, .g = 244, .b = 255 } },
            .bg = .{ .rgb = .{ .r = 28, .g = 36, .b = 61 } },
        },
        .input_active = .{
            .fg = .{ .rgb = .{ .r = 255, .g = 251, .b = 235 } },
            .bg = .{ .rgb = .{ .r = 67, .g = 56, .b = 202 } },
            .bold = true,
        },
        .status_idle = .{ .fg = .{ .rgb = .{ .r = 148, .g = 163, .b = 184 } } },
        .status_running = .{ .fg = .{ .rgb = .{ .r = 250, .g = 204, .b = 21 } }, .bold = true },
        .status_error = .{ .fg = .{ .rgb = .{ .r = 248, .g = 113, .b = 113 } }, .bold = true },
        .border_style = .round,
        .modal_border_style = .double,
    };
}

pub fn forestAgentTheme() AgentTheme {
    return .{
        .pane = .{
            .fg = .{ .rgb = .{ .r = 217, .g = 246, .b = 233 } },
            .bg = .{ .rgb = .{ .r = 13, .g = 31, .b = 24 } },
        },
        .pane_active = .{
            .fg = .{ .rgb = .{ .r = 240, .g = 253, .b = 244 } },
            .bg = .{ .rgb = .{ .r = 22, .g = 101, .b = 52 } },
            .bold = true,
        },
        .selected = .{
            .fg = .{ .rgb = .{ .r = 7, .g = 43, .b = 32 } },
            .bg = .{ .rgb = .{ .r = 110, .g = 231, .b = 183 } },
            .bold = true,
        },
        .selected_alt = .{
            .fg = .{ .rgb = .{ .r = 236, .g = 253, .b = 245 } },
            .bg = .{ .rgb = .{ .r = 6, .g = 95, .b = 70 } },
            .bold = true,
        },
        .input = .{
            .fg = .{ .rgb = .{ .r = 236, .g = 253, .b = 245 } },
            .bg = .{ .rgb = .{ .r = 27, .g = 67, .b = 50 } },
        },
        .input_active = .{
            .fg = .{ .rgb = .{ .r = 236, .g = 253, .b = 245 } },
            .bg = .{ .rgb = .{ .r = 4, .g = 120, .b = 87 } },
            .bold = true,
        },
        .status_idle = .{ .fg = .{ .rgb = .{ .r = 134, .g = 239, .b = 172 } } },
        .status_running = .{ .fg = .{ .rgb = .{ .r = 250, .g = 204, .b = 21 } }, .bold = true },
        .status_error = .{ .fg = .{ .rgb = .{ .r = 252, .g = 165, .b = 165 } }, .bold = true },
        .border_style = .round,
        .modal_border_style = .double,
    };
}

pub fn emberAgentTheme() AgentTheme {
    return .{
        .pane = .{
            .fg = .{ .rgb = .{ .r = 254, .g = 242, .b = 229 } },
            .bg = .{ .rgb = .{ .r = 34, .g = 20, .b = 16 } },
        },
        .pane_active = .{
            .fg = .{ .rgb = .{ .r = 255, .g = 247, .b = 237 } },
            .bg = .{ .rgb = .{ .r = 154, .g = 52, .b = 18 } },
            .bold = true,
        },
        .selected = .{
            .fg = .{ .rgb = .{ .r = 67, .g = 20, .b = 7 } },
            .bg = .{ .rgb = .{ .r = 251, .g = 191, .b = 36 } },
            .bold = true,
        },
        .selected_alt = .{
            .fg = .{ .rgb = .{ .r = 255, .g = 237, .b = 213 } },
            .bg = .{ .rgb = .{ .r = 194, .g = 65, .b = 12 } },
            .bold = true,
        },
        .input = .{
            .fg = .{ .rgb = .{ .r = 255, .g = 237, .b = 213 } },
            .bg = .{ .rgb = .{ .r = 67, .g = 32, .b = 17 } },
        },
        .input_active = .{
            .fg = .{ .rgb = .{ .r = 255, .g = 247, .b = 237 } },
            .bg = .{ .rgb = .{ .r = 180, .g = 83, .b = 9 } },
            .bold = true,
        },
        .status_idle = .{ .fg = .{ .rgb = .{ .r = 253, .g = 186, .b = 116 } } },
        .status_running = .{ .fg = .{ .rgb = .{ .r = 253, .g = 224, .b = 71 } }, .bold = true },
        .status_error = .{ .fg = .{ .rgb = .{ .r = 252, .g = 165, .b = 165 } }, .bold = true },
        .border_style = .round,
        .modal_border_style = .double,
    };
}

pub fn themeByName(name: []const u8) AgentTheme {
    if (std.mem.eql(u8, name, "midnight")) return midnightAgentTheme();
    if (std.mem.eql(u8, name, "forest")) return forestAgentTheme();
    if (std.mem.eql(u8, name, "ember")) return emberAgentTheme();
    return bubbleAgentTheme();
}
