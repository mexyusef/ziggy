const std = @import("std");
const ziggy = @import("ziggy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    _ = ziggy.prepareConsole();
    const active = ziggy.getRenderProfile();

    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);
    const writer = buffer.writer(allocator);

    try writer.print("ziggy glyph probe\n", .{});
    try writer.print("ansi_enabled={any}\n", .{active.ansi_enabled});
    try writer.print("encoding_safe={any}\n", .{active.encoding_safe});
    try writer.print("unicode_safe={any}\n", .{active.unicode_safe});
    try writer.print("icon_safe={any}\n", .{active.icon_safe});
    try writer.print("render_mode={s}\n", .{@tagName(active.render_mode)});
    try writer.print("icon_mode={s}\n", .{@tagName(active.icon_mode)});
    try writer.print("unicode_enabled={any}\n", .{active.unicodeEnabled()});
    try writer.print("icon_enabled={any}\n", .{active.iconEnabled()});
    try writer.writeAll("\n");
    try writer.writeAll("text: Cafe élan | 日本語 | λ | →\n");
    try writer.writeAll("borders: ┌─┐ │ │ └─┘\n");
    try writer.writeAll("blocks: █░█░\n");
    try writer.writeAll("spinner: ⠋⠙⠹⠸⠼\n");
    try writer.writeAll("icons: ✓ ⚠ ✗\n");
    try writer.writeAll("\n");
    try writer.writeAll("override with ZIGGY_RENDER_MODE=ascii|unicode|unicode_force and ZIGGY_ICON_MODE=ascii|unicode|nerd_font\n");

    try ziggy.writeStdout(allocator, buffer.items);
}
