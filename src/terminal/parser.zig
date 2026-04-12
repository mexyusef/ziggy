const std = @import("std");

pub const Key = union(enum) {
    char: u8,
    enter,
    tab,
    back_tab,
    backspace,
    delete,
    ctrl_a,
    ctrl_b,
    ctrl_f,
    ctrl_g,
    ctrl_h,
    ctrl_d,
    ctrl_e,
    ctrl_j,
    ctrl_k,
    ctrl_l,
    ctrl_n,
    ctrl_o,
    ctrl_p,
    ctrl_q,
    ctrl_r,
    ctrl_s,
    ctrl_space,
    ctrl_t,
    ctrl_u,
    ctrl_v,
    ctrl_w,
    ctrl_x,
    ctrl_y,
    ctrl_z,
    home,
    end,
    page_up,
    page_down,
    word_left,
    word_right,
    shift_left,
    shift_right,
    up,
    down,
    left,
    right,
    escape,
    ctrl_c,
    unknown: u8,
};

pub const Event = union(enum) {
    key: Key,
    mouse: Mouse,
    focus: bool,
    resize: struct {
        width: u16,
        height: u16,
    },
    paste: []const u8,
};

pub const Mouse = struct {
    button: MouseButton,
    x: u16,
    y: u16,
    pressed: bool = true,
};

pub const MouseButton = enum {
    left,
    middle,
    right,
    wheel_up,
    wheel_down,
    other,
};

const ParseResult = struct {
    event: Event,
    consumed: usize,
};

pub fn parseOne(bytes: []const u8) ?ParseResult {
    if (bytes.len == 0) return null;
    if (bytes[0] == 1) return .{ .event = .{ .key = .ctrl_a }, .consumed = 1 };
    if (bytes[0] == 2) return .{ .event = .{ .key = .ctrl_b }, .consumed = 1 };
    if (bytes[0] == 3) return .{ .event = .{ .key = .ctrl_c }, .consumed = 1 };
    if (bytes[0] == 4) return .{ .event = .{ .key = .ctrl_d }, .consumed = 1 };
    if (bytes[0] == 5) return .{ .event = .{ .key = .ctrl_e }, .consumed = 1 };
    if (bytes[0] == 6) return .{ .event = .{ .key = .ctrl_f }, .consumed = 1 };
    if (bytes[0] == 7) return .{ .event = .{ .key = .ctrl_g }, .consumed = 1 };
    if (bytes[0] == 8) return .{ .event = .{ .key = .ctrl_h }, .consumed = 1 };
    if (bytes[0] == 10) return .{ .event = .{ .key = .ctrl_j }, .consumed = 1 };
    if (bytes[0] == 11) return .{ .event = .{ .key = .ctrl_k }, .consumed = 1 };
    if (bytes[0] == 12) return .{ .event = .{ .key = .ctrl_l }, .consumed = 1 };
    if (bytes[0] == 14) return .{ .event = .{ .key = .ctrl_n }, .consumed = 1 };
    if (bytes[0] == 15) return .{ .event = .{ .key = .ctrl_o }, .consumed = 1 };
    if (bytes[0] == 16) return .{ .event = .{ .key = .ctrl_p }, .consumed = 1 };
    if (bytes[0] == 17) return .{ .event = .{ .key = .ctrl_q }, .consumed = 1 };
    if (bytes[0] == 18) return .{ .event = .{ .key = .ctrl_r }, .consumed = 1 };
    if (bytes[0] == 19) return .{ .event = .{ .key = .ctrl_s }, .consumed = 1 };
    if (bytes[0] == 0) return .{ .event = .{ .key = .ctrl_space }, .consumed = 1 };
    if (bytes[0] == '\t') return .{ .event = .{ .key = .tab }, .consumed = 1 };
    if (bytes[0] == 20) return .{ .event = .{ .key = .ctrl_t }, .consumed = 1 };
    if (bytes[0] == 21) return .{ .event = .{ .key = .ctrl_u }, .consumed = 1 };
    if (bytes[0] == 22) return .{ .event = .{ .key = .ctrl_v }, .consumed = 1 };
    if (bytes[0] == 23) return .{ .event = .{ .key = .ctrl_w }, .consumed = 1 };
    if (bytes[0] == 24) return .{ .event = .{ .key = .ctrl_x }, .consumed = 1 };
    if (bytes[0] == 25) return .{ .event = .{ .key = .ctrl_y }, .consumed = 1 };
    if (bytes[0] == 26) return .{ .event = .{ .key = .ctrl_z }, .consumed = 1 };
    if (bytes[0] == '\r' or bytes[0] == '\n') return .{ .event = .{ .key = .enter }, .consumed = 1 };
    if (bytes[0] == 127 or bytes[0] == 8) return .{ .event = .{ .key = .backspace }, .consumed = 1 };
    if (bytes[0] == 0x1b) {
        if (bytes.len >= 2 and bytes[1] != '[') {
            return switch (bytes[1]) {
                'b', 'B' => .{ .event = .{ .key = .word_left }, .consumed = 2 },
                'f', 'F' => .{ .event = .{ .key = .word_right }, .consumed = 2 },
                else => .{ .event = .{ .key = .escape }, .consumed = 1 },
            };
        }
        if (bytes.len >= 3 and bytes[1] == '[') {
            if (bytes.len >= 6 and bytes[2] == '1' and bytes[3] == ';' and bytes[4] == '5') {
                return switch (bytes[5]) {
                    'C' => .{ .event = .{ .key = .word_right }, .consumed = 6 },
                    'D' => .{ .event = .{ .key = .word_left }, .consumed = 6 },
                    else => .{ .event = .{ .key = .escape }, .consumed = 1 },
                };
            }
            if (bytes.len >= 6 and bytes[2] == '1' and bytes[3] == ';' and bytes[4] == '2') {
                return switch (bytes[5]) {
                    'C' => .{ .event = .{ .key = .shift_right }, .consumed = 6 },
                    'D' => .{ .event = .{ .key = .shift_left }, .consumed = 6 },
                    else => .{ .event = .{ .key = .escape }, .consumed = 1 },
                };
            }
            if (bytes[2] == '<') {
                return parseMouse(bytes);
            }
            return switch (bytes[2]) {
                'A' => .{ .event = .{ .key = .up }, .consumed = 3 },
                'B' => .{ .event = .{ .key = .down }, .consumed = 3 },
                'C' => .{ .event = .{ .key = .right }, .consumed = 3 },
                'D' => .{ .event = .{ .key = .left }, .consumed = 3 },
                'I' => .{ .event = .{ .focus = true }, .consumed = 3 },
                'O' => .{ .event = .{ .focus = false }, .consumed = 3 },
                'Z' => .{ .event = .{ .key = .back_tab }, .consumed = 3 },
                'H' => .{ .event = .{ .key = .home }, .consumed = 3 },
                'F' => .{ .event = .{ .key = .end }, .consumed = 3 },
                '5' => if (bytes.len >= 4 and bytes[3] == '~')
                    .{ .event = .{ .key = .page_up }, .consumed = 4 }
                else
                    .{ .event = .{ .key = .escape }, .consumed = 1 },
                '6' => if (bytes.len >= 4 and bytes[3] == '~')
                    .{ .event = .{ .key = .page_down }, .consumed = 4 }
                else
                    .{ .event = .{ .key = .escape }, .consumed = 1 },
                '3' => if (bytes.len >= 4 and bytes[3] == '~')
                    .{ .event = .{ .key = .delete }, .consumed = 4 }
                else
                    .{ .event = .{ .key = .escape }, .consumed = 1 },
                else => .{ .event = .{ .key = .escape }, .consumed = 1 },
            };
        }
        return .{ .event = .{ .key = .escape }, .consumed = 1 };
    }
    if (std.ascii.isPrint(bytes[0]) or bytes[0] == ' ') {
        return .{ .event = .{ .key = .{ .char = bytes[0] } }, .consumed = 1 };
    }
    return .{ .event = .{ .key = .{ .unknown = bytes[0] } }, .consumed = 1 };
}

fn parseMouse(bytes: []const u8) ?ParseResult {
    if (bytes.len < 6 or bytes[0] != 0x1b or bytes[1] != '[' or bytes[2] != '<') return null;
    var index: usize = 3;
    const button = parseNumber(bytes, &index) orelse return null;
    if (index >= bytes.len or bytes[index] != ';') return null;
    index += 1;
    const x = parseNumber(bytes, &index) orelse return null;
    if (index >= bytes.len or bytes[index] != ';') return null;
    index += 1;
    const y = parseNumber(bytes, &index) orelse return null;
    if (index >= bytes.len) return null;
    const suffix = bytes[index];
    if (suffix != 'M' and suffix != 'm') return null;
    index += 1;

    return .{
        .event = .{
            .mouse = .{
                .button = decodeMouseButton(button),
                .x = @intCast(x -| 1),
                .y = @intCast(y -| 1),
                .pressed = suffix == 'M',
            },
        },
        .consumed = index,
    };
}

fn parseNumber(bytes: []const u8, index: *usize) ?usize {
    const start = index.*;
    while (index.* < bytes.len and std.ascii.isDigit(bytes[index.*])) : (index.* += 1) {}
    if (index.* == start) return null;
    return std.fmt.parseUnsigned(usize, bytes[start..index.*], 10) catch null;
}

fn decodeMouseButton(code: usize) MouseButton {
    const base = code & 0b1100011;
    return switch (base) {
        0 => .left,
        1 => .middle,
        2 => .right,
        64 => .wheel_up,
        65 => .wheel_down,
        else => .other,
    };
}

pub fn parseBracketedPaste(allocator: std.mem.Allocator, bytes: []const u8) !?struct { event: Event, consumed: usize } {
    const start = "\x1b[200~";
    const end = "\x1b[201~";
    if (!std.mem.startsWith(u8, bytes, start)) return null;
    const body = bytes[start.len..];
    const end_index = std.mem.indexOf(u8, body, end) orelse return null;
    return .{
        .event = .{ .paste = try allocator.dupe(u8, body[0..end_index]) },
        .consumed = start.len + end_index + end.len,
    };
}

test "parser reads arrow key" {
    const parsed = parseOne("\x1b[A").?;
    try std.testing.expectEqual(@as(usize, 3), parsed.consumed);
    try std.testing.expect(parsed.event == .key);
    try std.testing.expect(parsed.event.key == .up);
}

test "parser reads terminal focus events" {
    const gained = parseOne("\x1b[I").?;
    try std.testing.expect(gained.event == .focus);
    try std.testing.expect(gained.event.focus);

    const lost = parseOne("\x1b[O").?;
    try std.testing.expect(lost.event == .focus);
    try std.testing.expect(!lost.event.focus);
}

test "parser reads ctrl+d" {
    const parsed = parseOne(&[_]u8{4}).?;
    try std.testing.expectEqual(@as(usize, 1), parsed.consumed);
    try std.testing.expect(parsed.event == .key);
    try std.testing.expect(parsed.event.key == .ctrl_d);
}

test "parser reads home end and page keys" {
    const home = parseOne("\x1b[H").?;
    try std.testing.expect(home.event == .key);
    try std.testing.expect(home.event.key == .home);

    const end = parseOne("\x1b[F").?;
    try std.testing.expect(end.event == .key);
    try std.testing.expect(end.event.key == .end);

    const page_up = parseOne("\x1b[5~").?;
    try std.testing.expectEqual(@as(usize, 4), page_up.consumed);
    try std.testing.expect(page_up.event == .key);
    try std.testing.expect(page_up.event.key == .page_up);

    const page_down = parseOne("\x1b[6~").?;
    try std.testing.expectEqual(@as(usize, 4), page_down.consumed);
    try std.testing.expect(page_down.event == .key);
    try std.testing.expect(page_down.event.key == .page_down);

    const delete = parseOne("\x1b[3~").?;
    try std.testing.expectEqual(@as(usize, 4), delete.consumed);
    try std.testing.expect(delete.event == .key);
    try std.testing.expect(delete.event.key == .delete);

    const back_tab = parseOne("\x1b[Z").?;
    try std.testing.expectEqual(@as(usize, 3), back_tab.consumed);
    try std.testing.expect(back_tab.event == .key);
    try std.testing.expect(back_tab.event.key == .back_tab);
}

test "parser reads editor control keys" {
    const ctrl_a = parseOne(&[_]u8{1}).?;
    try std.testing.expect(ctrl_a.event == .key);
    try std.testing.expect(ctrl_a.event.key == .ctrl_a);

    const ctrl_b = parseOne(&[_]u8{2}).?;
    try std.testing.expect(ctrl_b.event == .key);
    try std.testing.expect(ctrl_b.event.key == .ctrl_b);

    const ctrl_e = parseOne(&[_]u8{5}).?;
    try std.testing.expect(ctrl_e.event == .key);
    try std.testing.expect(ctrl_e.event.key == .ctrl_e);

    const ctrl_f = parseOne(&[_]u8{6}).?;
    try std.testing.expect(ctrl_f.event == .key);
    try std.testing.expect(ctrl_f.event.key == .ctrl_f);

    const ctrl_g = parseOne(&[_]u8{7}).?;
    try std.testing.expect(ctrl_g.event == .key);
    try std.testing.expect(ctrl_g.event.key == .ctrl_g);

    const ctrl_j = parseOne(&[_]u8{10}).?;
    try std.testing.expect(ctrl_j.event == .key);
    try std.testing.expect(ctrl_j.event.key == .ctrl_j);

    const ctrl_k = parseOne(&[_]u8{11}).?;
    try std.testing.expect(ctrl_k.event == .key);
    try std.testing.expect(ctrl_k.event.key == .ctrl_k);

    const ctrl_l = parseOne(&[_]u8{12}).?;
    try std.testing.expect(ctrl_l.event == .key);
    try std.testing.expect(ctrl_l.event.key == .ctrl_l);

    const ctrl_n = parseOne(&[_]u8{14}).?;
    try std.testing.expect(ctrl_n.event == .key);
    try std.testing.expect(ctrl_n.event.key == .ctrl_n);

    const ctrl_o = parseOne(&[_]u8{15}).?;
    try std.testing.expect(ctrl_o.event == .key);
    try std.testing.expect(ctrl_o.event.key == .ctrl_o);

    const ctrl_p = parseOne(&[_]u8{16}).?;
    try std.testing.expect(ctrl_p.event == .key);
    try std.testing.expect(ctrl_p.event.key == .ctrl_p);

    const ctrl_s = parseOne(&[_]u8{19}).?;
    try std.testing.expect(ctrl_s.event == .key);
    try std.testing.expect(ctrl_s.event.key == .ctrl_s);

    const ctrl_t = parseOne(&[_]u8{20}).?;
    try std.testing.expect(ctrl_t.event == .key);
    try std.testing.expect(ctrl_t.event.key == .ctrl_t);

    const ctrl_u = parseOne(&[_]u8{21}).?;
    try std.testing.expect(ctrl_u.event == .key);
    try std.testing.expect(ctrl_u.event.key == .ctrl_u);

    const ctrl_v = parseOne(&[_]u8{22}).?;
    try std.testing.expect(ctrl_v.event == .key);
    try std.testing.expect(ctrl_v.event.key == .ctrl_v);

    const ctrl_r = parseOne(&[_]u8{18}).?;
    try std.testing.expect(ctrl_r.event == .key);
    try std.testing.expect(ctrl_r.event.key == .ctrl_r);

    const ctrl_w = parseOne(&[_]u8{23}).?;
    try std.testing.expect(ctrl_w.event == .key);
    try std.testing.expect(ctrl_w.event.key == .ctrl_w);

    const ctrl_space = parseOne(&[_]u8{0}).?;
    try std.testing.expect(ctrl_space.event == .key);
    try std.testing.expect(ctrl_space.event.key == .ctrl_space);

    const ctrl_y = parseOne(&[_]u8{25}).?;
    try std.testing.expect(ctrl_y.event == .key);
    try std.testing.expect(ctrl_y.event.key == .ctrl_y);

    const ctrl_z = parseOne(&[_]u8{26}).?;
    try std.testing.expect(ctrl_z.event == .key);
    try std.testing.expect(ctrl_z.event.key == .ctrl_z);
}

test "parser reads word movement keys" {
    const alt_b = parseOne("\x1bb").?;
    try std.testing.expect(alt_b.event == .key);
    try std.testing.expect(alt_b.event.key == .word_left);

    const alt_f = parseOne("\x1bf").?;
    try std.testing.expect(alt_f.event == .key);
    try std.testing.expect(alt_f.event.key == .word_right);

    const ctrl_left = parseOne("\x1b[1;5D").?;
    try std.testing.expectEqual(@as(usize, 6), ctrl_left.consumed);
    try std.testing.expect(ctrl_left.event == .key);
    try std.testing.expect(ctrl_left.event.key == .word_left);

    const ctrl_right = parseOne("\x1b[1;5C").?;
    try std.testing.expectEqual(@as(usize, 6), ctrl_right.consumed);
    try std.testing.expect(ctrl_right.event == .key);
    try std.testing.expect(ctrl_right.event.key == .word_right);
}

test "parser reads shift arrows and mouse" {
    const shift_left = parseOne("\x1b[1;2D").?;
    try std.testing.expect(shift_left.event == .key);
    try std.testing.expect(shift_left.event.key == .shift_left);

    const shift_right = parseOne("\x1b[1;2C").?;
    try std.testing.expect(shift_right.event == .key);
    try std.testing.expect(shift_right.event.key == .shift_right);

    const mouse = parseOne("\x1b[<0;12;4M").?;
    try std.testing.expect(mouse.event == .mouse);
    try std.testing.expect(mouse.event.mouse.button == .left);
    try std.testing.expectEqual(@as(u16, 11), mouse.event.mouse.x);
    try std.testing.expectEqual(@as(u16, 3), mouse.event.mouse.y);
    try std.testing.expect(mouse.event.mouse.pressed);
}

test "parser reads bracketed paste" {
    const parsed = (try parseBracketedPaste(std.testing.allocator, "\x1b[200~hello\nworld\x1b[201~")).?;
    defer if (parsed.event == .paste) std.testing.allocator.free(parsed.event.paste);
    try std.testing.expectEqual(@as(usize, 23), parsed.consumed);
    try std.testing.expect(parsed.event == .paste);
    try std.testing.expectEqualStrings("hello\nworld", parsed.event.paste);
}
