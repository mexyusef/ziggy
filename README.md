# ziggy

`ziggy` is a Zig terminal UI library for building structured text interfaces, interactive shells, and agent-style applications.

Open-source home: `https://github.com/mexyusef/ziggy`

## Status

The library is already usable for real experiments and internal tools, but the API is still settling.

## Highlights

- `Program(Model, Msg)` runtime for state-driven terminal apps
- Screen model, diff renderer, terminal parser, and console setup helpers
- Layout primitives such as `Box`, `Pane`, `Split`, `HStack`, `VStack`, `Spacer`, and `Divider`
- Input and data widgets including `Input`, `TextArea`, `List`, `Table`, `Checkbox`, `Dropdown`, `Slider`, and more
- Agent-oriented UI pieces such as command dialogs, overlays, toasts, breadcrumbs, and shell chrome helpers

## Project Layout

- `src/` library code
- `examples/` runnable demos
- `scripts/` helper launcher for examples
- `docs/` working notes

## Requirements

- Zig `0.15.2`

## Build And Test

```powershell
zig build test
zig build example-shell
zig build example-dialog
zig build example-widgets
zig build example-interactive
zig build example-full
zig build example-controls
zig build example-editor
```

## Run Examples

```powershell
python .\scripts\run_examples.py --list
python .\scripts\run_examples.py
python .\scripts\run_examples.py interactive
python .\scripts\run_examples.py controls --build
python .\scripts\run_examples.py editor
python .\scripts\run_examples.py editor --new-window
```

`example-interactive` and `example-editor` should be run inside a real terminal window rather than piped stdin.

## Use As A Local Dependency

Until tagged releases are published, the simplest setup is a local path dependency:

```zig
.dependencies = .{
    .ziggy = .{
        .path = "../ziggy",
    },
},
```

## Related Repositories

- `cirebronx`: uses `ziggy` for its TUI mode
- `fmus-zig`: shared utility foundation

## License

MIT. See [LICENSE](LICENSE).
