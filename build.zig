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
}
