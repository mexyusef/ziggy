const std = @import("std");
const builtin = @import("builtin");

const DWORD = std.os.windows.DWORD;
const HANDLE = std.os.windows.HANDLE;
const BOOL = std.os.windows.BOOL;

extern "kernel32" fn WriteConsoleW(
    hConsoleOutput: HANDLE,
    lpBuffer: [*]const u16,
    nNumberOfCharsToWrite: DWORD,
    lpNumberOfCharsWritten: *DWORD,
    lpReserved: ?*anyopaque,
) callconv(.winapi) BOOL;

pub fn writeStdout(allocator: std.mem.Allocator, bytes: []const u8) !void {
    return writeFile(allocator, std.fs.File.stdout(), bytes);
}

pub fn writeStderr(allocator: std.mem.Allocator, bytes: []const u8) !void {
    return writeFile(allocator, std.fs.File.stderr(), bytes);
}

pub fn writeFile(allocator: std.mem.Allocator, file: std.fs.File, bytes: []const u8) !void {
    if (builtin.os.tag == .windows and isConsole(file)) {
        return writeConsolePreservingAnsi(allocator, file, bytes);
    }
    try file.writeAll(bytes);
}

fn isConsole(file: std.fs.File) bool {
    if (builtin.os.tag != .windows) return false;

    var mode: DWORD = 0;
    return std.os.windows.kernel32.GetConsoleMode(file.handle, &mode) != 0;
}

fn writeConsolePreservingAnsi(allocator: std.mem.Allocator, file: std.fs.File, bytes: []const u8) !void {
    var cursor: usize = 0;
    while (cursor < bytes.len) {
        const esc_index = std.mem.indexOfScalarPos(u8, bytes, cursor, 0x1b);
        if (esc_index) |index| {
            if (index > cursor) {
                try writeConsoleUtf8(allocator, file, bytes[cursor..index]);
            }
            const end = ansiSequenceEnd(bytes, index) orelse bytes.len;
            try file.writeAll(bytes[index..end]);
            cursor = end;
        } else {
            try writeConsoleUtf8(allocator, file, bytes[cursor..]);
            break;
        }
    }
}

fn writeConsoleUtf8(allocator: std.mem.Allocator, file: std.fs.File, bytes: []const u8) !void {
    if (bytes.len == 0) return;

    const utf16 = try std.unicode.utf8ToUtf16LeAlloc(allocator, bytes);
    defer allocator.free(utf16);

    var written: DWORD = 0;
    if (WriteConsoleW(file.handle, utf16.ptr, @intCast(utf16.len), &written, null) == 0) {
        return error.WriteFailed;
    }
    if (written != utf16.len) {
        return error.WriteFailed;
    }
}

fn ansiSequenceEnd(bytes: []const u8, start: usize) ?usize {
    if (start + 1 >= bytes.len or bytes[start] != 0x1b) return null;

    return switch (bytes[start + 1]) {
        '[' => csiEnd(bytes, start + 2),
        ']' => oscEnd(bytes, start + 2),
        '(', ')', '*', '+', '-', '.', '#', ' ', '%', 'P', 'X', '^', '_' => simpleEscapeEnd(bytes, start + 1),
        else => @min(start + 2, bytes.len),
    };
}

fn csiEnd(bytes: []const u8, from: usize) ?usize {
    var index = from;
    while (index < bytes.len) : (index += 1) {
        const byte = bytes[index];
        if (byte >= 0x40 and byte <= 0x7e) return index + 1;
    }
    return null;
}

fn oscEnd(bytes: []const u8, from: usize) ?usize {
    var index = from;
    while (index < bytes.len) : (index += 1) {
        if (bytes[index] == 0x07) return index + 1;
        if (bytes[index] == '\\' and index > from and bytes[index - 1] == 0x1b) return index + 1;
    }
    return null;
}

fn simpleEscapeEnd(bytes: []const u8, from: usize) ?usize {
    if (from + 1 > bytes.len) return null;
    return @min(from + 2, bytes.len);
}

test "ansi sequence end detects csi and osc" {
    try std.testing.expectEqual(@as(?usize, 5), ansiSequenceEnd("\x1b[31mX", 0));
    try std.testing.expectEqual(@as(?usize, 7), ansiSequenceEnd("\x1b]0;hi\x07X", 0));
    try std.testing.expectEqual(@as(?usize, 8), ansiSequenceEnd("\x1b]8;;x\x1b\\Y", 0));
}
