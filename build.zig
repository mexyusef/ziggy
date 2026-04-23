const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/ziggy.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "ziggy",
        .root_module = mod,
    });
    b.installArtifact(lib);

    const shell_demo = b.addExecutable(.{
        .name = "ziggy-shell-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/shell_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    shell_demo.root_module.addImport("ziggy", mod);
    b.installArtifact(shell_demo);

    const dialog_demo = b.addExecutable(.{
        .name = "ziggy-dialog-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/dialog_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    dialog_demo.root_module.addImport("ziggy", mod);
    b.installArtifact(dialog_demo);

    const widgets_demo = b.addExecutable(.{
        .name = "ziggy-widgets-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/widgets_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    widgets_demo.root_module.addImport("ziggy", mod);
    b.installArtifact(widgets_demo);

    const interactive_demo = b.addExecutable(.{
        .name = "ziggy-interactive-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/interactive_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    interactive_demo.root_module.addImport("ziggy", mod);
    b.installArtifact(interactive_demo);

    const full_demo = b.addExecutable(.{
        .name = "ziggy-full-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/full_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    full_demo.root_module.addImport("ziggy", mod);
    b.installArtifact(full_demo);

    const controls_demo = b.addExecutable(.{
        .name = "ziggy-controls-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/controls_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    controls_demo.root_module.addImport("ziggy", mod);
    b.installArtifact(controls_demo);

    const editor_demo = b.addExecutable(.{
        .name = "ziggy-editor-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/editor_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    editor_demo.root_module.addImport("ziggy", mod);
    b.installArtifact(editor_demo);

    const log_demo = b.addExecutable(.{
        .name = "ziggy-log-viewer-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/log_viewer_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    log_demo.root_module.addImport("ziggy", mod);
    b.installArtifact(log_demo);

    const text_buffer_demo = b.addExecutable(.{
        .name = "ziggy-text-buffer-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/text_buffer_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    text_buffer_demo.root_module.addImport("ziggy", mod);
    b.installArtifact(text_buffer_demo);

    const render_to_string_demo = b.addExecutable(.{
        .name = "ziggy-render-to-string-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/render_to_string_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    render_to_string_demo.root_module.addImport("ziggy", mod);
    b.installArtifact(render_to_string_demo);

    const glyph_probe_demo = b.addExecutable(.{
        .name = "ziggy-glyph-probe-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/glyph_probe_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    glyph_probe_demo.root_module.addImport("ziggy", mod);
    b.installArtifact(glyph_probe_demo);

    const unified_demo = b.addExecutable(.{
        .name = "ziggy-unified-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/unified_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    unified_demo.root_module.addImport("ziggy", mod);
    b.installArtifact(unified_demo);
    const install_unified_demo = b.addInstallArtifact(unified_demo, .{});

    const agent_primitives_demo = b.addExecutable(.{
        .name = "ziggy-agent-primitives-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/agent_primitives_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    agent_primitives_demo.root_module.addImport("ziggy", mod);
    b.installArtifact(agent_primitives_demo);

    const tests = b.addTest(.{
        .root_module = mod,
    });
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run ziggy tests");
    test_step.dependOn(&run_tests.step);

    const run_shell_demo = b.addRunArtifact(shell_demo);
    const shell_demo_step = b.step("example-shell", "Run the shell demo");
    shell_demo_step.dependOn(&run_shell_demo.step);

    const run_dialog_demo = b.addRunArtifact(dialog_demo);
    const dialog_demo_step = b.step("example-dialog", "Run the command dialog demo");
    dialog_demo_step.dependOn(&run_dialog_demo.step);

    const run_widgets_demo = b.addRunArtifact(widgets_demo);
    const widgets_demo_step = b.step("example-widgets", "Run the widget gallery demo");
    widgets_demo_step.dependOn(&run_widgets_demo.step);

    const run_interactive_demo = b.addRunArtifact(interactive_demo);
    const interactive_demo_step = b.step("example-interactive", "Run the interactive keystroke demo");
    interactive_demo_step.dependOn(&run_interactive_demo.step);

    const run_full_demo = b.addRunArtifact(full_demo);
    const full_demo_step = b.step("example-full", "Run the full shell demo");
    full_demo_step.dependOn(&run_full_demo.step);

    const run_controls_demo = b.addRunArtifact(controls_demo);
    const controls_demo_step = b.step("example-controls", "Run the controls and form demo");
    controls_demo_step.dependOn(&run_controls_demo.step);

    const run_editor_demo = b.addRunArtifact(editor_demo);
    const editor_demo_step = b.step("example-editor", "Run the editor workspace demo");
    editor_demo_step.dependOn(&run_editor_demo.step);

    const run_log_demo = b.addRunArtifact(log_demo);
    const log_demo_step = b.step("example-log-viewer", "Run the sticky log viewer demo");
    log_demo_step.dependOn(&run_log_demo.step);

    const run_text_buffer_demo = b.addRunArtifact(text_buffer_demo);
    const text_buffer_demo_step = b.step("example-text-buffer", "Run the text buffer history demo");
    text_buffer_demo_step.dependOn(&run_text_buffer_demo.step);

    const run_render_to_string_demo = b.addRunArtifact(render_to_string_demo);
    const render_to_string_demo_step = b.step("example-render-to-string", "Run the non-interactive themed render demo");
    render_to_string_demo_step.dependOn(&run_render_to_string_demo.step);

    const run_glyph_probe_demo = b.addRunArtifact(glyph_probe_demo);
    const glyph_probe_demo_step = b.step("example-glyph-probe", "Run the terminal glyph capability probe");
    glyph_probe_demo_step.dependOn(&run_glyph_probe_demo.step);

    const run_unified_demo = b.addRunArtifact(unified_demo);
    const unified_demo_step = b.step("example-all", "Run the unified demo gallery");
    unified_demo_step.dependOn(&run_unified_demo.step);

    const run_agent_primitives_demo = b.addRunArtifact(agent_primitives_demo);
    const agent_primitives_demo_step = b.step("example-agent-primitives", "Run the agent-oriented primitives demo");
    agent_primitives_demo_step.dependOn(&run_agent_primitives_demo.step);

    const unified_demo_build_step = b.step("example-all-build", "Build and install the unified demo binary");
    unified_demo_build_step.dependOn(&install_unified_demo.step);
}
