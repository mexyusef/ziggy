# Contributing

Keep changes narrow and testable.

## Development

```powershell
zig build test
zig fmt src examples build.zig
python .\scripts\run_examples.py --build-all
```

## Guidelines

- Preserve cross-platform behavior where possible, especially terminal and UTF-8 handling.
- Prefer small, composable widgets over one-off app-specific abstractions.
- Add or update demos when introducing new visible primitives.
- Include tests for renderer, parser, or input behavior when practical.
