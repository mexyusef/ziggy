const std = @import("std");
const builtin = @import("builtin");
const ansi = @import("ansi.zig");
const capabilities_mod = @import("capabilities.zig");
const screen_mod = @import("screen.zig");

const UINT = std.os.windows.UINT;

extern "kernel32" fn GetConsoleCP() callconv(.winapi) UINT;
extern "kernel32" fn SetConsoleCP(code_page: UINT) callconv(.winapi) std.os.windows.BOOL;

pub const Tty = struct {
    reader: ?*std.Io.Reader = null,
    writer: ?*std.Io.Writer = null,
    size: screen_mod.Size = .{ .width = 80, .height = 24 },
    capabilities: capabilities_mod.Capabilities = .{},
    raw_mode: bool = false,
    alternate_screen_active: bool = false,
    original_console_mode: ?u32 = null,
    original_output_console_mode: ?u32 = null,
    original_input_code_page: ?u32 = null,
    original_output_code_page: ?u32 = null,

    pub fn init(reader: ?*std.Io.Reader, writer: ?*std.Io.Writer, size: screen_mod.Size) Tty {
        return .{
            .reader = reader,
            .writer = writer,
            .size = size,
        };
    }

    pub fn withCapabilities(
        reader: ?*std.Io.Reader,
        writer: ?*std.Io.Writer,
        size: screen_mod.Size,
        capabilities: capabilities_mod.Capabilities,
    ) Tty {
        return .{
            .reader = reader,
            .writer = writer,
            .size = size,
            .capabilities = capabilities,
        };
    }

    pub fn enterRawMode(self: *Tty) void {
        if (builtin.os.tag == .windows) {
            const windows = std.os.windows;
            const stdin_file = std.fs.File.stdin();
            const stdout_file = std.fs.File.stdout();
            self.original_input_code_page = GetConsoleCP();
            self.original_output_code_page = windows.kernel32.GetConsoleOutputCP();
            _ = SetConsoleCP(65001);
            _ = windows.kernel32.SetConsoleOutputCP(65001);
            var original: windows.DWORD = 0;
            if (windows.kernel32.GetConsoleMode(stdin_file.handle, &original) != 0) {
                self.original_console_mode = @intCast(original);
                const enable_virtual_terminal_input: windows.DWORD = 0x0200;
                const disable_mask: windows.DWORD = 0x0001 | 0x0002 | 0x0004;
                const requested = (original & ~disable_mask) | enable_virtual_terminal_input;
                _ = windows.kernel32.SetConsoleMode(stdin_file.handle, requested);
            }
            var stdout_original: windows.DWORD = 0;
            if (windows.kernel32.GetConsoleMode(stdout_file.handle, &stdout_original) != 0) {
                self.original_output_console_mode = @intCast(stdout_original);
                const enable_virtual_terminal_processing: windows.DWORD = 0x0004;
                const requested = stdout_original | enable_virtual_terminal_processing;
                _ = windows.kernel32.SetConsoleMode(stdout_file.handle, requested);
            }
        }
        if (self.writer) |writer| {
            if (self.capabilities.alternate_screen and !self.alternate_screen_active) {
                ansi.writeEnterAlternateScreen(writer) catch {};
                ansi.writeClearScreen(writer) catch {};
                self.alternate_screen_active = true;
            }
            if (self.capabilities.mouse) {
                ansi.writeEnableMouse(writer) catch {};
            }
            if (self.capabilities.bracketed_paste) {
                ansi.writeEnableBracketedPaste(writer) catch {};
            }
            writer.flush() catch {};
        }
        self.raw_mode = true;
    }

    pub fn leaveRawMode(self: *Tty) void {
        if (self.writer) |writer| {
            if (self.capabilities.bracketed_paste) {
                ansi.writeDisableBracketedPaste(writer) catch {};
            }
            if (self.capabilities.mouse) {
                ansi.writeDisableMouse(writer) catch {};
            }
            if (self.alternate_screen_active) {
                ansi.writeLeaveAlternateScreen(writer) catch {};
                self.alternate_screen_active = false;
            }
            writer.flush() catch {};
        }
        if (builtin.os.tag == .windows) {
            if (self.original_input_code_page) |original| {
                _ = SetConsoleCP(@intCast(original));
            }
            if (self.original_output_code_page) |original| {
                _ = std.os.windows.kernel32.SetConsoleOutputCP(@intCast(original));
            }
            if (self.original_console_mode) |original| {
                _ = std.os.windows.kernel32.SetConsoleMode(std.fs.File.stdin().handle, @intCast(original));
            }
            if (self.original_output_console_mode) |original| {
                _ = std.os.windows.kernel32.SetConsoleMode(std.fs.File.stdout().handle, @intCast(original));
            }
        }
        self.raw_mode = false;
    }
};
