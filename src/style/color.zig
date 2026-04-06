pub const Color = union(enum) {
    default,
    ansi: u8,
    rgb: struct {
        r: u8,
        g: u8,
        b: u8,
    },
};
