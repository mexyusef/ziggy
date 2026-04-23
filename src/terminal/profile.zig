const std = @import("std");
const builtin = @import("builtin");

pub const RenderMode = enum(u2) {
    auto,
    ascii,
    unicode,
    unicode_force,
};

pub const IconMode = enum(u2) {
    auto,
    ascii,
    unicode,
    nerd_font,
};

pub const RenderProfile = struct {
    ansi_enabled: bool = false,
    encoding_safe: bool = true,
    unicode_safe: bool = true,
    icon_safe: bool = true,
    render_mode: RenderMode = .auto,
    icon_mode: IconMode = .auto,

    pub fn unicodeEnabled(self: RenderProfile) bool {
        return switch (self.render_mode) {
            .auto => self.unicode_safe,
            .ascii => false,
            .unicode, .unicode_force => true,
        };
    }

    pub fn iconEnabled(self: RenderProfile) bool {
        return switch (self.icon_mode) {
            .auto => self.icon_safe and self.unicodeEnabled(),
            .ascii => false,
            .unicode, .nerd_font => self.unicodeEnabled(),
        };
    }
};

var global_profile = std.atomic.Value(u32).init(pack(.{}));

pub fn set(profile: RenderProfile) void {
    global_profile.store(pack(profile), .release);
}

pub fn get() RenderProfile {
    return unpack(global_profile.load(.acquire));
}

pub fn detect(allocator: std.mem.Allocator, ansi_enabled: bool) RenderProfile {
    return applyEnvOverrides(allocator, .{
        .ansi_enabled = ansi_enabled,
        .encoding_safe = detectEncodingSafe(),
        .unicode_safe = detectUnicodeSafe(allocator),
        .icon_safe = detectIconSafe(allocator),
    });
}

fn detectEncodingSafe() bool {
    return true;
}

fn detectUnicodeSafe(allocator: std.mem.Allocator) bool {
    if (builtin.os.tag != .windows) return true;

    if (hasEnv(allocator, "WT_SESSION")) return true;
    if (hasEnvValue(allocator, "TERM_PROGRAM", "vscode")) return true;
    if (hasEnvValue(allocator, "TERM_PROGRAM", "WezTerm")) return true;
    if (hasEnvValue(allocator, "TERM_PROGRAM", "Hyper")) return true;
    if (hasEnvValue(allocator, "ConEmuANSI", "ON")) return true;
    if (hasEnv(allocator, "MSYSTEM")) return true;
    if (envContains(allocator, "TERM", "xterm")) return true;
    if (envContains(allocator, "TERM", "kitty")) return true;
    if (envContains(allocator, "TERM", "wezterm")) return true;
    if (envContains(allocator, "TERM", "ghostty")) return true;

    // Be conservative on plain cmd.exe / conhost. Lossy ASCII fallback is
    // preferable to emitting mojibake.
    return false;
}

fn detectIconSafe(allocator: std.mem.Allocator) bool {
    if (builtin.os.tag != .windows) return true;

    if (hasEnv(allocator, "WT_SESSION")) return true;
    if (hasEnvValue(allocator, "TERM_PROGRAM", "vscode")) return true;
    if (hasEnvValue(allocator, "TERM_PROGRAM", "WezTerm")) return true;
    if (hasEnvValue(allocator, "TERM_PROGRAM", "Hyper")) return true;
    if (hasEnvValue(allocator, "ConEmuANSI", "ON")) return true;
    if (hasEnv(allocator, "MSYSTEM")) return true;
    if (envContains(allocator, "TERM", "xterm")) return true;
    if (envContains(allocator, "TERM", "kitty")) return true;
    if (envContains(allocator, "TERM", "wezterm")) return true;
    if (envContains(allocator, "TERM", "ghostty")) return true;

    return false;
}

fn hasEnv(allocator: std.mem.Allocator, key: []const u8) bool {
    return std.process.hasEnvVar(allocator, key) catch false;
}

fn hasEnvValue(allocator: std.mem.Allocator, key: []const u8, expected: []const u8) bool {
    const value = std.process.getEnvVarOwned(allocator, key) catch return false;
    defer allocator.free(value);
    return std.ascii.eqlIgnoreCase(value, expected);
}

fn envContains(allocator: std.mem.Allocator, key: []const u8, needle: []const u8) bool {
    const value = std.process.getEnvVarOwned(allocator, key) catch return false;
    defer allocator.free(value);
    const lowered = std.ascii.allocLowerString(allocator, value) catch return false;
    defer allocator.free(lowered);
    return std.mem.indexOf(u8, lowered, needle) != null;
}

fn applyEnvOverrides(allocator: std.mem.Allocator, detected: RenderProfile) RenderProfile {
    var next = detected;
    if (std.process.getEnvVarOwned(allocator, "ZIGGY_RENDER_MODE")) |value| {
        defer allocator.free(value);
        if (parseRenderMode(value)) |mode| next.render_mode = mode;
    } else |_| {}
    if (std.process.getEnvVarOwned(allocator, "ZIGGY_ICON_MODE")) |value| {
        defer allocator.free(value);
        if (parseIconMode(value)) |mode| next.icon_mode = mode;
    } else |_| {}
    return next;
}

fn parseRenderMode(raw: []const u8) ?RenderMode {
    if (std.ascii.eqlIgnoreCase(raw, "auto")) return .auto;
    if (std.ascii.eqlIgnoreCase(raw, "ascii")) return .ascii;
    if (std.ascii.eqlIgnoreCase(raw, "unicode")) return .unicode;
    if (std.ascii.eqlIgnoreCase(raw, "unicode_force")) return .unicode_force;
    if (std.ascii.eqlIgnoreCase(raw, "unicode-force")) return .unicode_force;
    return null;
}

fn parseIconMode(raw: []const u8) ?IconMode {
    if (std.ascii.eqlIgnoreCase(raw, "auto")) return .auto;
    if (std.ascii.eqlIgnoreCase(raw, "ascii")) return .ascii;
    if (std.ascii.eqlIgnoreCase(raw, "unicode")) return .unicode;
    if (std.ascii.eqlIgnoreCase(raw, "nerd_font")) return .nerd_font;
    if (std.ascii.eqlIgnoreCase(raw, "nerd-font")) return .nerd_font;
    return null;
}

fn pack(profile: RenderProfile) u32 {
    return (@as(u32, @intFromBool(profile.ansi_enabled)) << 0) |
        (@as(u32, @intFromBool(profile.encoding_safe)) << 1) |
        (@as(u32, @intFromBool(profile.unicode_safe)) << 2) |
        (@as(u32, @intFromBool(profile.icon_safe)) << 3) |
        (@as(u32, @intFromEnum(profile.render_mode)) << 4) |
        (@as(u32, @intFromEnum(profile.icon_mode)) << 6);
}

fn unpack(bits: u32) RenderProfile {
    return .{
        .ansi_enabled = (bits & (@as(u32, 1) << 0)) != 0,
        .encoding_safe = (bits & (@as(u32, 1) << 1)) != 0,
        .unicode_safe = (bits & (@as(u32, 1) << 2)) != 0,
        .icon_safe = (bits & (@as(u32, 1) << 3)) != 0,
        .render_mode = @enumFromInt((bits >> 4) & 0b11),
        .icon_mode = @enumFromInt((bits >> 6) & 0b11),
    };
}

test "profile roundtrip preserves flags" {
    const profile: RenderProfile = .{
        .ansi_enabled = true,
        .encoding_safe = true,
        .unicode_safe = false,
        .icon_safe = false,
        .render_mode = .unicode_force,
        .icon_mode = .nerd_font,
    };
    try std.testing.expectEqual(profile.ansi_enabled, unpack(pack(profile)).ansi_enabled);
    try std.testing.expectEqual(profile.encoding_safe, unpack(pack(profile)).encoding_safe);
    try std.testing.expectEqual(profile.unicode_safe, unpack(pack(profile)).unicode_safe);
    try std.testing.expectEqual(profile.icon_safe, unpack(pack(profile)).icon_safe);
    try std.testing.expectEqual(profile.render_mode, unpack(pack(profile)).render_mode);
    try std.testing.expectEqual(profile.icon_mode, unpack(pack(profile)).icon_mode);
}

test "profile render mode controls unicode enablement" {
    try std.testing.expect((RenderProfile{ .unicode_safe = true, .render_mode = .auto }).unicodeEnabled());
    try std.testing.expect(!(RenderProfile{ .unicode_safe = true, .render_mode = .ascii }).unicodeEnabled());
    try std.testing.expect((RenderProfile{ .unicode_safe = false, .render_mode = .unicode }).unicodeEnabled());
    try std.testing.expect((RenderProfile{ .unicode_safe = false, .render_mode = .unicode_force }).unicodeEnabled());
}

test "profile icon mode stays separate from unicode mode" {
    try std.testing.expect(!(RenderProfile{ .unicode_safe = true, .icon_safe = false, .icon_mode = .auto }).iconEnabled());
    try std.testing.expect(!(RenderProfile{ .unicode_safe = true, .icon_safe = true, .render_mode = .ascii, .icon_mode = .auto }).iconEnabled());
    try std.testing.expect((RenderProfile{ .unicode_safe = false, .render_mode = .unicode_force, .icon_safe = false, .icon_mode = .unicode }).iconEnabled());
}

test "profile parses render mode values" {
    try std.testing.expectEqual(@as(?RenderMode, .auto), parseRenderMode("auto"));
    try std.testing.expectEqual(@as(?RenderMode, .ascii), parseRenderMode("ASCII"));
    try std.testing.expectEqual(@as(?RenderMode, .unicode), parseRenderMode("unicode"));
    try std.testing.expectEqual(@as(?RenderMode, .unicode_force), parseRenderMode("unicode-force"));
    try std.testing.expectEqual(@as(?RenderMode, null), parseRenderMode("bogus"));
}

test "profile parses icon mode values" {
    try std.testing.expectEqual(@as(?IconMode, .auto), parseIconMode("auto"));
    try std.testing.expectEqual(@as(?IconMode, .ascii), parseIconMode("ascii"));
    try std.testing.expectEqual(@as(?IconMode, .unicode), parseIconMode("unicode"));
    try std.testing.expectEqual(@as(?IconMode, .nerd_font), parseIconMode("nerd_font"));
    try std.testing.expectEqual(@as(?IconMode, null), parseIconMode("bogus"));
}
