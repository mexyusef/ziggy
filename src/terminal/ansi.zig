const std = @import("std");
const style_mod = @import("../style/style.zig");
const color_mod = @import("../style/color.zig");

pub fn writeReset(writer: *std.Io.Writer) !void {
    try writer.writeAll("\x1b[0m");
}

pub fn writeEnableBracketedPaste(writer: *std.Io.Writer) !void {
    try writer.writeAll("\x1b[?2004h");
}

pub fn writeDisableBracketedPaste(writer: *std.Io.Writer) !void {
    try writer.writeAll("\x1b[?2004l");
}

pub fn writeEnableMouse(writer: *std.Io.Writer) !void {
    try writer.writeAll("\x1b[?1000h\x1b[?1006h");
}

pub fn writeDisableMouse(writer: *std.Io.Writer) !void {
    try writer.writeAll("\x1b[?1006l\x1b[?1000l");
}

pub fn writeSyncOutputBegin(writer: *std.Io.Writer) !void {
    try writer.writeAll("\x1b[?2026h");
}

pub fn writeSyncOutputEnd(writer: *std.Io.Writer) !void {
    try writer.writeAll("\x1b[?2026l");
}

pub fn writeEnterAlternateScreen(writer: *std.Io.Writer) !void {
    try writer.writeAll("\x1b[?1049h");
}

pub fn writeLeaveAlternateScreen(writer: *std.Io.Writer) !void {
    try writer.writeAll("\x1b[?1049l");
}

pub fn writeSetTitle(writer: *std.Io.Writer, title: []const u8) !void {
    try writer.print("\x1b]0;{s}\x1b\\", .{title});
}

pub fn writeClearTitle(writer: *std.Io.Writer) !void {
    try writer.writeAll("\x1b]0;\x1b\\");
}

pub fn writeTabStatus(writer: *std.Io.Writer, kind: @import("../app/root.zig").TabStatusKind) !void {
    const payload = switch (kind) {
        .idle => "indicator=#00d75f;status=Idle;statusColor=#888888",
        .busy => "indicator=#ff9500;status=Working;statusColor=#ff9500",
        .waiting => "indicator=#5f87ff;status=Waiting;statusColor=#5f87ff",
    };
    try writer.print("\x1b]21337;{s}\x1b\\", .{payload});
}

pub fn writeClearTabStatus(writer: *std.Io.Writer) !void {
    try writer.writeAll("\x1b]21337;indicator=;status=;statusColor=\x1b\\");
}

test "ansi emits title and tab status sequences" {
    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();

    try writeSetTitle(&out.writer, "ziggy");
    try writeTabStatus(&out.writer, .busy);
    try writeClearTabStatus(&out.writer);

    const written = out.written();
    try std.testing.expect(std.mem.indexOf(u8, written, "\x1b]0;ziggy\x1b\\") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "\x1b]21337;indicator=#ff9500;status=Working;statusColor=#ff9500\x1b\\") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "\x1b]21337;indicator=;status=;statusColor=\x1b\\") != null);
}

pub fn writeHyperlinkOpen(writer: *std.Io.Writer, target: []const u8) !void {
    try writer.print("\x1b]8;;{s}\x1b\\", .{target});
}

pub fn writeHyperlinkClose(writer: *std.Io.Writer) !void {
    try writer.writeAll("\x1b]8;;\x1b\\");
}

pub fn writeClearScreen(writer: *std.Io.Writer) !void {
    try writer.writeAll("\x1b[2J\x1b[H");
}

pub fn writeMoveTo(writer: *std.Io.Writer, x: u16, y: u16) !void {
    try writer.print("\x1b[{d};{d}H", .{ y + 1, x + 1 });
}

pub fn writeStyle(writer: *std.Io.Writer, style: style_mod.Style) !void {
    try writer.writeAll("\x1b[0");
    if (style.bold) try writer.writeAll(";1");
    if (style.dim) try writer.writeAll(";2");
    if (style.underline) try writer.writeAll(";4");
    try writeColor(writer, style.fg, true);
    try writeColor(writer, style.bg, false);
    try writer.writeByte('m');
}

fn writeColor(writer: *std.Io.Writer, color: color_mod.Color, fg: bool) !void {
    const base_true: u8 = if (fg) 38 else 48;
    switch (color) {
        .default => {},
        .ansi => |idx| {
            if (idx < 8) {
                try writer.print(";{d}", .{(if (fg) @as(u8, 30) else @as(u8, 40)) + idx});
            } else if (idx < 16) {
                try writer.print(";{d}", .{(if (fg) @as(u8, 90) else @as(u8, 100)) + (idx - 8)});
            } else {
                try writer.print(";{d};5;{d}", .{ base_true, idx });
            }
        },
        .rgb => |rgb| {
            try writer.print(";{d};2;{d};{d};{d}", .{ base_true, rgb.r, rgb.g, rgb.b });
        },
    }
}
