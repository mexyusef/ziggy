const parser = @import("../terminal/parser.zig");

pub const SystemMessage = union(enum) {
    init,
    tick,
    event: parser.Event,
};
