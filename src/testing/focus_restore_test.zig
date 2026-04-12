const std = @import("std");
const fake = @import("fake_terminal.zig");
const parser = @import("../terminal/parser.zig");
const program_mod = @import("../app/program.zig");
const command_mod = @import("../app/command.zig");
const context_mod = @import("../app/context.zig");
const text_widget = @import("../widget/text.zig");
const style_mod = @import("../style/style.zig");

test "program restores terminal modes after focus regain" {
    const Model = struct {
        pub fn update(self: *@This(), event: parser.Event, ctx: *context_mod.Context) command_mod.Command(parser.Event) {
            _ = self;
            _ = event;
            _ = ctx;
            return .none;
        }

        pub fn viewNode(self: *@This(), ctx: *context_mod.Context) !*const @import("../widget/node.zig").Node {
            _ = self;
            return try text_widget.build(ctx.allocator, try ctx.allocator.dupe(u8, "focus"), style_mod.Style{});
        }
    };

    var term = fake.FakeTerminal.init(std.testing.allocator, .{ .width = 20, .height = 3 });
    defer term.deinit();
    term.capabilities.mouse = true;
    term.capabilities.bracketed_paste = true;
    term.capabilities.alternate_screen = true;

    var program = try program_mod.Program(Model, parser.Event).init(std.testing.allocator, term.tty(), .{}, .{});
    defer program.deinit();
    try program.start();

    const before_len = term.output().len;
    _ = try program.processTerminalEvent(.{ .focus = false });
    _ = try program.processTerminalEvent(.{ .focus = true });
    const output = term.output()[before_len..];
    try std.testing.expect(std.mem.indexOf(u8, output, "\x1b[?1000h\x1b[?1006h") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\x1b[?2004h") != null);
}
