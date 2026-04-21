const std = @import("std");
const builtin = @import("builtin");

pub const RenderProfile = struct {
    ansi_enabled: bool = false,
    unicode_safe: bool = true,
};

var global_profile = std.atomic.Value(u8).init(pack(.{}));

pub fn set(profile: RenderProfile) void {
    global_profile.store(pack(profile), .release);
}

pub fn get() RenderProfile {
    return unpack(global_profile.load(.acquire));
}

pub fn detect(allocator: std.mem.Allocator, ansi_enabled: bool) RenderProfile {
    return .{
        .ansi_enabled = ansi_enabled,
        .unicode_safe = detectUnicodeSafe(allocator),
    };
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

fn pack(profile: RenderProfile) u8 {
    return (@as(u8, @intFromBool(profile.ansi_enabled)) << 1) | @as(u8, @intFromBool(profile.unicode_safe));
}

fn unpack(bits: u8) RenderProfile {
    return .{
        .ansi_enabled = (bits & 0b10) != 0,
        .unicode_safe = (bits & 0b01) != 0,
    };
}

test "profile roundtrip preserves flags" {
    const profile: RenderProfile = .{ .ansi_enabled = true, .unicode_safe = false };
    try std.testing.expectEqual(profile.ansi_enabled, unpack(pack(profile)).ansi_enabled);
    try std.testing.expectEqual(profile.unicode_safe, unpack(pack(profile)).unicode_safe);
}
