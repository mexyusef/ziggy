pub const Capabilities = struct {
    truecolor: bool = true,
    ansi256: bool = true,
    mouse: bool = false,
    bracketed_paste: bool = true,
    kitty_keyboard: bool = false,
    synchronized_output: bool = false,
    alternate_screen: bool = false,
    terminal_title: bool = true,
    tab_status: bool = false,
};
