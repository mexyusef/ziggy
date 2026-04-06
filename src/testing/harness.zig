const std = @import("std");
const parser = @import("../terminal/parser.zig");

pub fn driveEvents(
    comptime ProgramType: type,
    program: *ProgramType,
    events: []const parser.Event,
) !void {
    for (events) |event| {
        const keep_running = try program.processTerminalEvent(event);
        if (!keep_running) break;
    }
}

pub fn driveTicks(
    comptime ProgramType: type,
    program: *ProgramType,
    deltas_ms: []const u64,
) !void {
    for (deltas_ms) |delta_ms| {
        const keep_running = try program.processTick(delta_ms);
        if (!keep_running) break;
    }
}
