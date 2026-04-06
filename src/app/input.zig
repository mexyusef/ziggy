const std = @import("std");
const parser = @import("../terminal/parser.zig");

pub const KeyEvent = struct {
    key: parser.Key,
    repeated: bool = false,
    released: bool = false,
    default_prevented: bool = false,
    propagation_stopped: bool = false,

    pub fn preventDefault(self: *KeyEvent) void {
        self.default_prevented = true;
    }

    pub fn stopPropagation(self: *KeyEvent) void {
        self.propagation_stopped = true;
    }
};

pub const PasteEvent = struct {
    text: []const u8,
    default_prevented: bool = false,
    propagation_stopped: bool = false,

    pub fn preventDefault(self: *PasteEvent) void {
        self.default_prevented = true;
    }

    pub fn stopPropagation(self: *PasteEvent) void {
        self.propagation_stopped = true;
    }
};

pub const Handler = struct {
    ctx: ?*anyopaque = null,
    on_key: ?*const fn (?*anyopaque, *KeyEvent) void = null,
    on_paste: ?*const fn (?*anyopaque, *PasteEvent) void = null,
};

pub const DispatchResult = struct {
    handled: bool = false,
    default_prevented: bool = false,
    propagation_stopped: bool = false,
};

pub const Dispatcher = struct {
    allocator: std.mem.Allocator,
    global_handlers: std.ArrayList(Handler) = .empty,
    local_handlers: std.ArrayList(Handler) = .empty,

    pub fn init(allocator: std.mem.Allocator) Dispatcher {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Dispatcher) void {
        self.global_handlers.deinit(self.allocator);
        self.local_handlers.deinit(self.allocator);
    }

    pub fn addGlobal(self: *Dispatcher, handler: Handler) !void {
        try self.global_handlers.append(self.allocator, handler);
    }

    pub fn addLocal(self: *Dispatcher, handler: Handler) !void {
        try self.local_handlers.append(self.allocator, handler);
    }

    pub fn clearLocal(self: *Dispatcher) void {
        self.local_handlers.clearRetainingCapacity();
    }

    pub fn dispatchKey(self: *Dispatcher, key: parser.Key) DispatchResult {
        var event: KeyEvent = .{ .key = key };
        const handled = dispatchToHandlers(self.global_handlers.items, &event) or
            dispatchToHandlers(self.local_handlers.items, &event);
        return .{
            .handled = handled,
            .default_prevented = event.default_prevented,
            .propagation_stopped = event.propagation_stopped,
        };
    }

    pub fn dispatchPaste(self: *Dispatcher, text: []const u8) DispatchResult {
        var event: PasteEvent = .{ .text = text };
        const handled = dispatchPasteHandlers(self.global_handlers.items, &event) or
            dispatchPasteHandlers(self.local_handlers.items, &event);
        return .{
            .handled = handled,
            .default_prevented = event.default_prevented,
            .propagation_stopped = event.propagation_stopped,
        };
    }
};

fn dispatchToHandlers(handlers: []const Handler, event: *KeyEvent) bool {
    var handled = false;
    for (handlers) |handler| {
        if (handler.on_key) |on_key| {
            handled = true;
            on_key(handler.ctx, event);
            if (event.propagation_stopped) break;
        }
    }
    return handled;
}

fn dispatchPasteHandlers(handlers: []const Handler, event: *PasteEvent) bool {
    var handled = false;
    for (handlers) |handler| {
        if (handler.on_paste) |on_paste| {
            handled = true;
            on_paste(handler.ctx, event);
            if (event.propagation_stopped) break;
        }
    }
    return handled;
}

test "dispatcher honors stopPropagation for key handlers" {
    const State = struct {
        first: bool = false,
        second: bool = false,
    };

    const firstHandler = struct {
        fn call(ctx: ?*anyopaque, event: *KeyEvent) void {
            const state: *State = @ptrCast(@alignCast(ctx.?));
            state.first = true;
            event.preventDefault();
            event.stopPropagation();
        }
    }.call;

    const secondHandler = struct {
        fn call(ctx: ?*anyopaque, event: *KeyEvent) void {
            _ = event;
            const state: *State = @ptrCast(@alignCast(ctx.?));
            state.second = true;
        }
    }.call;

    var state: State = .{};
    var dispatcher = Dispatcher.init(std.testing.allocator);
    defer dispatcher.deinit();
    try dispatcher.addGlobal(.{ .ctx = &state, .on_key = firstHandler });
    try dispatcher.addLocal(.{ .ctx = &state, .on_key = secondHandler });

    const result = dispatcher.dispatchKey(.tab);
    try std.testing.expect(result.handled);
    try std.testing.expect(result.default_prevented);
    try std.testing.expect(result.propagation_stopped);
    try std.testing.expect(state.first);
    try std.testing.expect(!state.second);
}

test "dispatcher routes paste handlers" {
    const State = struct {
        seen: bool = false,
    };

    const pasteHandler = struct {
        fn call(ctx: ?*anyopaque, event: *PasteEvent) void {
            const state: *State = @ptrCast(@alignCast(ctx.?));
            state.seen = std.mem.eql(u8, event.text, "hello");
        }
    }.call;

    var state: State = .{};
    var dispatcher = Dispatcher.init(std.testing.allocator);
    defer dispatcher.deinit();
    try dispatcher.addGlobal(.{ .ctx = &state, .on_paste = pasteHandler });

    const result = dispatcher.dispatchPaste("hello");
    try std.testing.expect(result.handled);
    try std.testing.expect(state.seen);
}
