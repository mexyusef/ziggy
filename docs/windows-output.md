# Windows Output Model

`ziggy` avoids Windows mojibake by separating terminal text output from plain byte output.

## Console Strategy

- If the target is a real Windows console handle, `ziggy` writes text spans with `WriteConsoleW`
- ANSI / OSC escape sequences are preserved as raw bytes
- If the target is a pipe or file, `ziggy` writes the original UTF-8 bytes unchanged

## Public APIs

- `ziggy.writeStdout(...)`
- `ziggy.writeStderr(...)`
- `ziggy.writeFile(...)`

## App Rules

- Call `ziggy.prepareConsole()` before rendering to the terminal
- For static output, render to a string and then write with `ziggy.writeStdout(...)`
- For interactive apps, attach the real stdout file as `Tty.output_file` so redraws and title/tab-status commands use the same safe path

## Limits

This removes encoding-related mojibake. It does not guarantee that every terminal font contains every glyph. Missing glyphs are a font/host issue, not an encoding issue.
