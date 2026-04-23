# Terminal Modes

`ziggy` now separates terminal capability detection from render policy.

Detected profile fields:

- `encoding_safe`
- `unicode_safe`
- `icon_safe`

Explicit policy fields:

- `render_mode`
  - `auto`
  - `ascii`
  - `unicode`
  - `unicode_force`
- `icon_mode`
  - `auto`
  - `ascii`
  - `unicode`
  - `nerd_font`

Environment overrides:

```powershell
set ZIGGY_RENDER_MODE=unicode_force
set ZIGGY_ICON_MODE=unicode
zig build example-glyph-probe
```

Use the probe to inspect the current terminal:

```powershell
zig build example-glyph-probe
```

The current model is intentionally conservative on plain Windows `cmd.exe` in `auto` mode. Use explicit overrides when you know the host and font can render the glyphs you want.
