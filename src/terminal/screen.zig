const std = @import("std");
const style_mod = @import("../style/style.zig");
const profile = @import("profile.zig");

pub const Size = struct {
    width: u16,
    height: u16,
};

pub const Point = struct {
    x: u16,
    y: u16,
};

pub const Cell = struct {
    byte: u8 = ' ',
    glyph_len: u8 = 1,
    glyph_bytes: [4]u8 = .{ ' ', 0, 0, 0 },
    display_width: u8 = 1,
    continuation: bool = false,
    link_len: u8 = 0,
    link_bytes: [96]u8 = .{0} ** 96,
    style: style_mod.Style = .{},

    pub fn eql(a: Cell, b: Cell) bool {
        return a.byte == b.byte and
            a.glyph_len == b.glyph_len and
            a.display_width == b.display_width and
            a.continuation == b.continuation and
            a.link_len == b.link_len and
            std.mem.eql(u8, a.link_bytes[0..a.link_len], b.link_bytes[0..b.link_len]) and
            std.mem.eql(u8, a.glyph_bytes[0..a.glyph_len], b.glyph_bytes[0..b.glyph_len]) and
            style_mod.Style.eql(a.style, b.style);
    }

    pub fn linkTarget(self: *const Cell) ?[]const u8 {
        if (self.link_len == 0) return null;
        return self.link_bytes[0..self.link_len];
    }

};

pub const Screen = struct {
    allocator: std.mem.Allocator,
    size: Size,
    cells: []Cell,

    pub fn init(allocator: std.mem.Allocator, size: Size) !Screen {
        const cells = try allocator.alloc(Cell, @as(usize, size.width) * @as(usize, size.height));
        var screen = Screen{
            .allocator = allocator,
            .size = size,
            .cells = cells,
        };
        screen.clear();
        return screen;
    }

    pub fn deinit(self: *Screen) void {
        self.allocator.free(self.cells);
    }

    pub fn clear(self: *Screen) void {
        @memset(self.cells, .{});
    }

    pub fn resize(self: *Screen, size: Size) !void {
        self.allocator.free(self.cells);
        self.size = size;
        self.cells = try self.allocator.alloc(Cell, @as(usize, size.width) * @as(usize, size.height));
        self.clear();
    }

    pub fn setCell(self: *Screen, point: Point, byte: u8, style: style_mod.Style) void {
        if (point.x >= self.size.width or point.y >= self.size.height) return;
        self.cells[indexOf(self.size, point)] = .{
            .byte = byte,
            .glyph_len = 1,
            .glyph_bytes = .{ byte, 0, 0, 0 },
            .display_width = 1,
            .continuation = false,
            .link_len = 0,
            .style = style,
        };
    }

    pub fn setGlyph(self: *Screen, point: Point, glyph: []const u8, style: style_mod.Style) void {
        self.setGlyphWithLink(point, glyph, style, null);
    }

    pub fn setGlyphWithLink(self: *Screen, point: Point, glyph: []const u8, style: style_mod.Style, link_target: ?[]const u8) void {
        const safe_glyph = glyphForTerminal(glyph);
        if (point.x >= self.size.width or point.y >= self.size.height or safe_glyph.len == 0 or safe_glyph.len > 4) return;
        const width = glyphDisplayWidth(safe_glyph);
        var glyph_bytes: [4]u8 = .{ 0, 0, 0, 0 };
        for (safe_glyph, 0..) |byte, index| glyph_bytes[index] = byte;
        var link_bytes: [96]u8 = .{0} ** 96;
        const link_len: u8 = if (link_target) |target|
            @intCast(@min(target.len, link_bytes.len))
        else
            0;
        if (link_target) |target| {
            @memcpy(link_bytes[0..link_len], target[0..link_len]);
        }
        self.cells[indexOf(self.size, point)] = .{
            .byte = safe_glyph[0],
            .glyph_len = @intCast(safe_glyph.len),
            .glyph_bytes = glyph_bytes,
            .display_width = width,
            .continuation = false,
            .link_len = link_len,
            .link_bytes = link_bytes,
            .style = style,
        };
        if (width > 1 and point.x + 1 < self.size.width) {
            self.cells[indexOf(self.size, .{ .x = point.x + 1, .y = point.y })] = .{
                .byte = ' ',
                .glyph_len = 1,
                .glyph_bytes = .{ ' ', 0, 0, 0 },
                .display_width = 0,
                .continuation = true,
                .link_len = link_len,
                .link_bytes = link_bytes,
                .style = style,
            };
        }
    }

    pub fn writeText(self: *Screen, point: Point, text: []const u8, style: style_mod.Style) void {
        self.writeLinkedText(point, text, style, null);
    }

    pub fn writeLinkedText(self: *Screen, point: Point, text: []const u8, style: style_mod.Style, link_target: ?[]const u8) void {
        var x = point.x;
        var utf8 = std.unicode.Utf8View.init(text) catch {
            for (text) |c| {
                if (x >= self.size.width) break;
                self.setCell(.{ .x = x, .y = point.y }, c, style);
                x += 1;
            }
            return;
        };
        var iter = utf8.iterator();
        while (iter.nextCodepoint()) |codepoint| {
            if (x >= self.size.width) break;
            var buf: [4]u8 = undefined;
            const glyph_len = std.unicode.utf8Encode(codepoint, &buf) catch break;
            const width = codepointWidth(codepoint);
            if (glyph_len == 1)
                self.setGlyphWithLink(.{ .x = x, .y = point.y }, buf[0..1], style, link_target)
            else
                self.setGlyphWithLink(.{ .x = x, .y = point.y }, buf[0..glyph_len], style, link_target);
            x += width;
        }
    }

    pub fn getCell(self: *const Screen, point: Point) Cell {
        return self.cells[indexOf(self.size, point)];
    }

    pub fn copyFrom(self: *Screen, other: *const Screen) void {
        if (self.cells.len != other.cells.len) return;
        @memcpy(self.cells, other.cells);
        self.size = other.size;
    }

    fn indexOf(size: Size, point: Point) usize {
        return @as(usize, point.y) * @as(usize, size.width) + @as(usize, point.x);
    }
};

fn glyphDisplayWidth(glyph: []const u8) u8 {
    var iter = std.unicode.Utf8View.init(glyph) catch return 1;
    var it = iter.iterator();
    const cp = it.nextCodepoint() orelse return 1;
    return codepointWidth(cp);
}

fn glyphForTerminal(glyph: []const u8) []const u8 {
    const active = profile.get();
    if (!needsUnicodeFallback(glyph)) return glyph;
    if (isIconGlyph(glyph)) {
        if (active.iconEnabled()) return glyph;
        return asciiFallbackGlyph(glyph);
    }
    if (active.unicodeEnabled()) return glyph;
    return asciiFallbackGlyph(glyph);
}

fn needsUnicodeFallback(glyph: []const u8) bool {
    if (glyph.len == 0) return false;
    if (std.unicode.Utf8View.init(glyph)) |view| {
        var iter = view.iterator();
        while (iter.nextCodepoint()) |cp| {
            if (cp > 0x7f) return true;
        }
    } else |_| {
        return true;
    }
    return false;
}

fn isIconGlyph(glyph: []const u8) bool {
    if (glyph.len == 0) return false;
    if (std.unicode.Utf8View.init(glyph)) |view| {
        var iter = view.iterator();
        const cp = iter.nextCodepoint() orelse return false;
        if (iter.nextCodepoint() != null) return false;
        return switch (cp) {
            '┌', '┐', '└', '┘', '╔', '╗', '╚', '╝', '╭', '╮', '╰', '╯', '┏', '┓', '┗', '┛',
            '─', '═', '━',
            '│', '║', '┃',
            '█', '░',
            '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏',
            => true,
            else => false,
        };
    } else |_| {
        return false;
    }
}

fn asciiFallbackGlyph(glyph: []const u8) []const u8 {
    if (glyph.len == 0) return glyph;
    if (std.unicode.Utf8View.init(glyph)) |view| {
        var iter = view.iterator();
        const cp = iter.nextCodepoint() orelse return "?";
        if (iter.nextCodepoint() != null) return "?";
        return switch (cp) {
            '┌', '┐', '└', '┘', '╔', '╗', '╚', '╝', '╭', '╮', '╰', '╯', '┏', '┓', '┗', '┛' => "+",
            '─', '═', '━' => "-",
            '│', '║', '┃' => "|",
            '▶' => ">",
            '▼' => "v",
            '█' => "#",
            '░' => "-",
            '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' => "*",
            else => if (cp <= 0x7f) glyph else "?",
        };
    } else |_| {
        return "?";
    }
}

fn codepointWidth(codepoint: u21) u8 {
    if ((codepoint >= 0x1100 and codepoint <= 0x115F) or
        (codepoint >= 0x2329 and codepoint <= 0x232A) or
        (codepoint >= 0x2E80 and codepoint <= 0xA4CF) or
        (codepoint >= 0xAC00 and codepoint <= 0xD7A3) or
        (codepoint >= 0xF900 and codepoint <= 0xFAFF) or
        (codepoint >= 0xFE10 and codepoint <= 0xFE19) or
        (codepoint >= 0xFE30 and codepoint <= 0xFE6F) or
        (codepoint >= 0xFF00 and codepoint <= 0xFF60) or
        (codepoint >= 0xFFE0 and codepoint <= 0xFFE6))
    {
        return 2;
    }
    return 1;
}

test "screen writeText writes bytes" {
    var screen = try Screen.init(std.testing.allocator, .{ .width = 10, .height = 2 });
    defer screen.deinit();

    screen.writeText(.{ .x = 1, .y = 0 }, "abc", .{});
    try std.testing.expectEqual(@as(u8, 'a'), screen.getCell(.{ .x = 1, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, 'c'), screen.getCell(.{ .x = 3, .y = 0 }).byte);
}

test "screen stores utf8 glyphs" {
    var screen = try Screen.init(std.testing.allocator, .{ .width = 4, .height = 1 });
    defer screen.deinit();

    screen.writeText(.{ .x = 0, .y = 0 }, "╭x", .{});
    const glyph = screen.getCell(.{ .x = 0, .y = 0 });
    try std.testing.expectEqualStrings("╭", glyph.glyph_bytes[0..glyph.glyph_len]);
    try std.testing.expectEqual(@as(u8, 'x'), screen.getCell(.{ .x = 1, .y = 0 }).byte);
}

test "screen marks wide glyph continuation" {
    var screen = try Screen.init(std.testing.allocator, .{ .width = 4, .height = 1 });
    defer screen.deinit();

    screen.writeText(.{ .x = 0, .y = 0 }, "表x", .{});
    const wide = screen.getCell(.{ .x = 0, .y = 0 });
    const cont = screen.getCell(.{ .x = 1, .y = 0 });
    try std.testing.expectEqual(@as(u8, 2), wide.display_width);
    try std.testing.expect(cont.continuation);
    try std.testing.expectEqual(@as(u8, 'x'), screen.getCell(.{ .x = 2, .y = 0 }).byte);
}

test "screen stores link metadata" {
    var screen = try Screen.init(std.testing.allocator, .{ .width = 8, .height = 1 });
    defer screen.deinit();

    screen.writeLinkedText(.{ .x = 0, .y = 0 }, "hi", .{}, "https://x");
    const cell = screen.getCell(.{ .x = 0, .y = 0 });
    try std.testing.expectEqualStrings("https://x", cell.linkTarget().?);
}

test "screen falls back to ascii glyphs when unicode is unsafe" {
    const saved = profile.get();
    defer profile.set(saved);
    profile.set(.{ .ansi_enabled = false, .unicode_safe = false, .icon_safe = false });

    var screen = try Screen.init(std.testing.allocator, .{ .width = 4, .height = 1 });
    defer screen.deinit();

    screen.setGlyph(.{ .x = 0, .y = 0 }, "┌", .{});
    screen.setGlyph(.{ .x = 1, .y = 0 }, "█", .{});
    screen.setGlyph(.{ .x = 2, .y = 0 }, "⠋", .{});
    screen.setGlyph(.{ .x = 3, .y = 0 }, "é", .{});

    try std.testing.expectEqualStrings("+", screen.getCell(.{ .x = 0, .y = 0 }).glyph_bytes[0..screen.getCell(.{ .x = 0, .y = 0 }).glyph_len]);
    try std.testing.expectEqualStrings("#", screen.getCell(.{ .x = 1, .y = 0 }).glyph_bytes[0..screen.getCell(.{ .x = 1, .y = 0 }).glyph_len]);
    try std.testing.expectEqualStrings("*", screen.getCell(.{ .x = 2, .y = 0 }).glyph_bytes[0..screen.getCell(.{ .x = 2, .y = 0 }).glyph_len]);
    try std.testing.expectEqualStrings("?", screen.getCell(.{ .x = 3, .y = 0 }).glyph_bytes[0..screen.getCell(.{ .x = 3, .y = 0 }).glyph_len]);
}

test "screen honors unicode render mode separately from icon mode" {
    const saved = profile.get();
    defer profile.set(saved);
    profile.set(.{
        .ansi_enabled = false,
        .unicode_safe = false,
        .icon_safe = false,
        .render_mode = .unicode_force,
        .icon_mode = .ascii,
    });

    var screen = try Screen.init(std.testing.allocator, .{ .width = 3, .height = 1 });
    defer screen.deinit();

    screen.setGlyph(.{ .x = 0, .y = 0 }, "é", .{});
    screen.setGlyph(.{ .x = 1, .y = 0 }, "┌", .{});

    try std.testing.expectEqualStrings("é", screen.getCell(.{ .x = 0, .y = 0 }).glyph_bytes[0..screen.getCell(.{ .x = 0, .y = 0 }).glyph_len]);
    try std.testing.expectEqualStrings("+", screen.getCell(.{ .x = 1, .y = 0 }).glyph_bytes[0..screen.getCell(.{ .x = 1, .y = 0 }).glyph_len]);
}

test "screen honors forced unicode icon mode" {
    const saved = profile.get();
    defer profile.set(saved);
    profile.set(.{
        .ansi_enabled = false,
        .unicode_safe = false,
        .icon_safe = false,
        .render_mode = .unicode_force,
        .icon_mode = .unicode,
    });

    var screen = try Screen.init(std.testing.allocator, .{ .width = 2, .height = 1 });
    defer screen.deinit();

    screen.setGlyph(.{ .x = 0, .y = 0 }, "┌", .{});
    try std.testing.expectEqualStrings("┌", screen.getCell(.{ .x = 0, .y = 0 }).glyph_bytes[0..screen.getCell(.{ .x = 0, .y = 0 }).glyph_len]);
}
