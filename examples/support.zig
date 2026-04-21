const std = @import("std");
const ziggy = @import("ziggy");

const DWORD = std.os.windows.DWORD;
const HANDLE = std.os.windows.HANDLE;
const SHORT = std.os.windows.SHORT;
const BOOL = std.os.windows.BOOL;
const WAIT_OBJECT_0: DWORD = 0;
const WAIT_TIMEOUT: DWORD = 258;

const COORD = extern struct {
    X: SHORT,
    Y: SHORT,
};

const SMALL_RECT = extern struct {
    Left: SHORT,
    Top: SHORT,
    Right: SHORT,
    Bottom: SHORT,
};

const CONSOLE_SCREEN_BUFFER_INFO = extern struct {
    dwSize: COORD,
    dwCursorPosition: COORD,
    wAttributes: u16,
    srWindow: SMALL_RECT,
    dwMaximumWindowSize: COORD,
};

extern "kernel32" fn GetConsoleScreenBufferInfo(
    hConsoleOutput: HANDLE,
    lpConsoleScreenBufferInfo: *CONSOLE_SCREEN_BUFFER_INFO,
) callconv(.winapi) BOOL;
extern "kernel32" fn WaitForSingleObject(
    hHandle: HANDLE,
    dwMilliseconds: DWORD,
) callconv(.winapi) DWORD;
extern "kernel32" fn FlushConsoleInputBuffer(
    hConsoleInput: HANDLE,
) callconv(.winapi) BOOL;
extern "kernel32" fn ReadConsoleInputW(
    hConsoleInput: HANDLE,
    lpBuffer: [*]INPUT_RECORD,
    nLength: DWORD,
    lpNumberOfEventsRead: *DWORD,
) callconv(.winapi) BOOL;

const KEY_EVENT_RECORD = extern struct {
    bKeyDown: BOOL,
    wRepeatCount: u16,
    wVirtualKeyCode: u16,
    wVirtualScanCode: u16,
    UnicodeChar: u16,
    dwControlKeyState: DWORD,
};

const INPUT_RECORD = extern struct {
    EventType: u16,
    _padding: u16,
    Event: extern union {
        KeyEvent: KEY_EVENT_RECORD,
        _raw: [16]u8,
    },
};

const KEY_EVENT: u16 = 0x0001;

pub fn restoreConsoleAfterFailure() void {
    ziggy.forceRestoreConsole();
    var buffer: [256]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&buffer);
    const stderr = &stderr_writer.interface;
    _ = stderr.writeAll("\x1b[?2026l\x1b[?2004l\x1b[?1006l\x1b[?1000l\x1b[?1049l\x1b[0m\r\n") catch {};
    _ = stderr.flush() catch {};
}

pub fn panicHandler(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    restoreConsoleAfterFailure();
    std.debug.panic("{s}", .{message});
}

pub fn detectTerminalSize() ziggy.Size {
    if (@import("builtin").os.tag == .windows) {
        if (queryConsoleSize(std.fs.File.stdout().handle)) |size| {
            return size;
        }
        if (std.fs.cwd().openFile("CONOUT$", .{ .mode = .read_write })) |conout| {
            defer conout.close();
            if (queryConsoleSize(conout.handle)) |size| {
                return size;
            }
        } else |_| {}
        if (queryConsoleSize(std.fs.File.stderr().handle)) |size| {
            return size;
        }
    }
    return .{ .width = 100, .height = 30 };
}

fn queryConsoleSize(handle: HANDLE) ?ziggy.Size {
    var info: CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (GetConsoleScreenBufferInfo(handle, &info) == 0) return null;
    const width = @as(u16, @intCast(@max(@as(i32, 1), @as(i32, info.srWindow.Right) - @as(i32, info.srWindow.Left) + 1)));
    const height = @as(u16, @intCast(@max(@as(i32, 1), @as(i32, info.srWindow.Bottom) - @as(i32, info.srWindow.Top) + 1)));
    return .{ .width = width, .height = height };
}

pub fn dumpScreen(writer: anytype, screen: *const ziggy.Screen) !void {
    var y: u16 = 0;
    while (y < screen.size.height) : (y += 1) {
        var x: u16 = 0;
        while (x < screen.size.width) {
            const cell = screen.getCell(.{ .x = x, .y = y });
            if (cell.continuation) {
                x += 1;
                continue;
            }
            try writer.writeAll(cell.glyph_bytes[0..cell.glyph_len]);
            x += @max(@as(u16, 1), cell.display_width);
        }
        try writer.writeByte('\n');
    }
}

pub fn renderStatic(root: *const ziggy.Node, size: ziggy.Size) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var screen = try ziggy.Screen.init(allocator, size);
    defer screen.deinit();
    ziggy.renderNode(&screen, .{ .x = 0, .y = 0, .width = screen.size.width, .height = screen.size.height }, root);

    var buffer: [8192]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    const stdout = &stdout_writer.interface;
    const output = try ziggy.renderScreenToString(allocator, &screen, .{
        .width = size.width,
        .height = size.height,
        .ansi_styles = ziggy.getRenderProfile().ansi_enabled,
        .trim_trailing_spaces = true,
        .include_final_newline = true,
    });
    defer allocator.free(output);
    try stdout.writeAll(output);
    try stdout.flush();
}

pub fn readEvent(allocator: std.mem.Allocator, stdin_file: std.fs.File) !?ziggy.Event {
    var buffer: [512]u8 = undefined;
    const read_len = try stdin_file.read(&buffer);
    if (read_len == 0) return null;
    const bytes = buffer[0..read_len];
    if (try ziggy.parseBracketedPaste(allocator, bytes)) |parsed| return parsed.event;
    if (ziggy.parseOne(bytes)) |parsed| return parsed.event;
    return null;
}

pub fn runInteractiveProgram(
    comptime Model: type,
    comptime Msg: type,
    allocator: std.mem.Allocator,
    model: Model,
    options: ziggy.RootOptions,
) !void {
    _ = ziggy.prepareConsole();

    const stdin_file = std.fs.File.stdin();
    const stdout_file = std.fs.File.stdout();
    var stdin_buffer: [4096]u8 = undefined;
    var stdout_buffer: [4096]u8 = undefined;
    var stdin_reader = stdin_file.reader(&stdin_buffer);
    var stdout_writer = stdout_file.writer(&stdout_buffer);
    const size = detectTerminalSize();
    const tty = ziggy.Tty.withCapabilities(
        &stdin_reader.interface,
        &stdout_writer.interface,
        size,
        .{
            .alternate_screen = true,
            .bracketed_paste = true,
            .mouse = true,
            .synchronized_output = true,
            .terminal_title = true,
        },
    );

    var program = try ziggy.Program(Model, Msg).init(allocator, tty, model, options);
    defer program.deinit();
    try program.start();
    defer program.tty.leaveRawMode();

    var last_size = size;
    while (true) {
        if (@import("builtin").os.tag == .windows) {
            const wait_result = WaitForSingleObject(stdin_file.handle, 50);
            const current_size = detectTerminalSize();
            if (current_size.width != last_size.width or current_size.height != last_size.height) {
                last_size = current_size;
                const keep_running = try program.processTerminalEvent(.{ .resize = .{
                    .width = current_size.width,
                    .height = current_size.height,
                } });
                if (!keep_running) break;
            }
            if (wait_result == WAIT_TIMEOUT) continue;
            if (wait_result != WAIT_OBJECT_0) break;
        }

        const maybe_event = try readEvent(allocator, stdin_file);
        if (maybe_event == null) break;
        const keep_running = try program.processTerminalEvent(maybe_event.?);
        if (!keep_running) break;
    }
}

pub fn clearPendingConsoleInput() void {
    if (@import("builtin").os.tag == .windows) {
        _ = FlushConsoleInputBuffer(std.fs.File.stdin().handle);
    }
}

pub fn waitForAnyKey(message: []const u8) !void {
    clearPendingConsoleInput();
    var buffer: [512]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll(message);
    try stdout.flush();

    if (@import("builtin").os.tag == .windows) {
        var record: INPUT_RECORD = undefined;
        var read: DWORD = 0;
        while (true) {
            if (ReadConsoleInputW(std.fs.File.stdin().handle, @ptrCast(&record), 1, &read) == 0 or read == 0) break;
            if (record.EventType == KEY_EVENT and record.Event.KeyEvent.bKeyDown != 0) break;
        }
    } else {
        var byte: [1]u8 = undefined;
        _ = try std.fs.File.stdin().read(&byte);
    }

    try stdout.writeAll("\n");
    try stdout.flush();
}
