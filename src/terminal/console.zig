const std = @import("std");
const builtin = @import("builtin");

const UINT = std.os.windows.UINT;
extern "kernel32" fn SetConsoleOutputCP(code_page: UINT) callconv(.winapi) std.os.windows.BOOL;
extern "kernel32" fn SetConsoleCP(code_page: UINT) callconv(.winapi) std.os.windows.BOOL;

pub const PrepareResult = struct {
    ansi_enabled: bool = false,
    utf8_enabled: bool = false,
};

pub fn prepareStdIo() PrepareResult {
    var result: PrepareResult = .{};
    if (builtin.os.tag == .windows) {
        _ = SetConsoleCP(65001);
        _ = SetConsoleOutputCP(65001);
        result.utf8_enabled = true;
    }
    _ = std.fs.File.stdout().getOrEnableAnsiEscapeSupport();
    result.ansi_enabled = true;
    return result;
}

test "prepare result reports ansi enabled" {
    const result = prepareStdIo();
    try std.testing.expect(result.ansi_enabled);
}
