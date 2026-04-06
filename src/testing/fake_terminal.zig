const std = @import("std");
const capabilities_mod = @import("../terminal/capabilities.zig");
const tty_mod = @import("../terminal/tty.zig");
const screen_mod = @import("../terminal/screen.zig");

pub const FakeTerminal = struct {
    allocator: std.mem.Allocator,
    size: screen_mod.Size,
    capabilities: capabilities_mod.Capabilities = .{},
    output_buffer: std.Io.Writer.Allocating,

    pub fn init(allocator: std.mem.Allocator, size: screen_mod.Size) FakeTerminal {
        return .{
            .allocator = allocator,
            .size = size,
            .output_buffer = .init(allocator),
        };
    }

    pub fn deinit(self: *FakeTerminal) void {
        self.output_buffer.deinit();
    }

    pub fn tty(self: *FakeTerminal) tty_mod.Tty {
        return tty_mod.Tty.withCapabilities(null, &self.output_buffer.writer, self.size, self.capabilities);
    }

    pub fn output(self: *FakeTerminal) []u8 {
        return self.output_buffer.written();
    }
};
