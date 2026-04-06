from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]

EXAMPLES = {
    "shell": {
        "label": "Shell Demo",
        "build_step": "example-shell",
        "exe": "ziggy-shell-demo.exe",
        "desc": "Static shell layout with header, sidebar, document, and footer.",
    },
    "dialog": {
        "label": "Dialog Demo",
        "build_step": "example-dialog",
        "exe": "ziggy-dialog-demo.exe",
        "desc": "Command palette, picker, toast, and tooltip surfaces.",
    },
    "widgets": {
        "label": "Widgets Demo",
        "build_step": "example-widgets",
        "exe": "ziggy-widgets-demo.exe",
        "desc": "Broader shell/navigation/notification primitive gallery.",
    },
    "interactive": {
        "label": "Interactive Demo",
        "build_step": "example-interactive",
        "exe": "ziggy-interactive-demo.exe",
        "desc": "Interactive keystroke demo using ziggy.Program.",
    },
    "full": {
        "label": "Full Demo",
        "build_step": "example-full",
        "exe": "ziggy-full-demo.exe",
        "desc": "Fuller shell demo combining transcript, dialogs, and footer.",
    },
    "controls": {
        "label": "Controls Demo",
        "build_step": "example-controls",
        "exe": "ziggy-controls-demo.exe",
        "desc": "zigzag-style controls: form, table, tree, virtual list, dropdown, and more.",
    },
}


def run(cmd: list[str]) -> int:
    return subprocess.run(cmd, cwd=REPO).returncode


def build_example(name: str) -> int:
    return run(["zig", "build", EXAMPLES[name]["build_step"]])


def ensure_built(name: str) -> int:
    exe_path = REPO / "zig-out" / "bin" / EXAMPLES[name]["exe"]
    if exe_path.exists():
        return 0
    return run(["zig", "build"])


def launch_example(name: str) -> int:
    code = ensure_built(name)
    if code != 0:
        return code
    exe_path = REPO / "zig-out" / "bin" / EXAMPLES[name]["exe"]
    return subprocess.run([str(exe_path)], cwd=REPO).returncode


def print_examples() -> None:
    print("Available ziggy examples:\n")
    for key, meta in EXAMPLES.items():
        print(f"  {key:<12} {meta['label']}")
        print(f"  {'':12} {meta['desc']}")
        print(f"  {'':12} build step: zig build {meta['build_step']}")
        print(f"  {'':12} exe: zig-out/bin/{meta['exe']}\n")


def interactive_menu() -> int:
    names = list(EXAMPLES.keys())
    while True:
        print_examples()
        raw = input("Select example by name or number (q to quit): ").strip().lower()
        if raw in {"q", "quit", "exit"}:
            return 0
        if raw.isdigit():
            idx = int(raw) - 1
            if 0 <= idx < len(names):
                raw = names[idx]
        if raw in EXAMPLES:
            return launch_example(raw)
        print("Invalid selection.\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build and run ziggy examples.")
    parser.add_argument("example", nargs="?", choices=sorted(EXAMPLES.keys()))
    parser.add_argument("--list", action="store_true", help="List available examples.")
    parser.add_argument("--build", action="store_true", help="Build the selected example instead of running it.")
    parser.add_argument("--build-all", action="store_true", help="Build all examples.")
    args = parser.parse_args()

    if args.list:
        print_examples()
        return 0

    if args.build_all:
        return run(["zig", "build"])

    if args.example and args.build:
        return build_example(args.example)

    if args.example:
        return launch_example(args.example)

    return interactive_menu()


if __name__ == "__main__":
    raise SystemExit(main())
