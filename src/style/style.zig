const color_mod = @import("color.zig");

pub const Style = struct {
    fg: color_mod.Color = .default,
    bg: color_mod.Color = .default,
    bold: bool = false,
    dim: bool = false,
    underline: bool = false,

    pub fn eql(a: Style, b: Style) bool {
        return a.bold == b.bold and
            a.dim == b.dim and
            a.underline == b.underline and
            colorEql(a.fg, b.fg) and
            colorEql(a.bg, b.bg);
    }
};

fn colorEql(a: color_mod.Color, b: color_mod.Color) bool {
    if (@intFromEnum(a) != @intFromEnum(b)) return false;
    return switch (a) {
        .default => true,
        .ansi => |idx| idx == b.ansi,
        .rgb => |rgb| rgb.r == b.rgb.r and rgb.g == b.rgb.g and rgb.b == b.rgb.b,
    };
}
