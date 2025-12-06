const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const trace_mod = b.createModule(.{
        .root_source_file = b.path("lib/core/trace.zig"),
    });

    const simple = b.addExecutable(.{
        .name = "simple",
        .target = target,
        .optimize = optimize,
    });
    simple.addCSourceFile(.{
        .file = b.path("targets/c/simple.c"),
        .flags = &.{"-g"},
    });
    simple.linkLibC();
    const install_simple = b.addInstallArtifact(simple, .{});
    const simple_step = b.step("simple", "Install the simple executable");
    simple_step.dependOn(&install_simple.step);

    const simple_add = b.addExecutable(.{
        .name = "simple_add",
        .target = target,
        .optimize = optimize,
    });
    simple_add.addCSourceFile(.{
        .file = b.path("targets/c/simple_add_int.c"),
        .flags = &.{"-g"},
    });
    simple_add.linkLibC();
    const install_simple_add = b.addInstallArtifact(simple_add, .{});
    const simple_add_step = b.step("simple_add", "Install the simple_add executable");
    simple_add_step.dependOn(&install_simple_add.step);

    // dipole executables
    const dipole = b.addExecutable(.{
        .name = "dipole",
        .root_source_file = b.path("cmd/dipole/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const install_dipole = b.addInstallArtifact(dipole, .{});
    const dipole_step = b.step("dipole", "Install the dipole executable");
    dipole_step.dependOn(&install_dipole.step);

    // wire installs into the default install step so `zig build` produces zig-out
    const install = b.getInstallStep();
    install.dependOn(&install_simple.step);
    install.dependOn(&install_simple_add.step);
    install.dependOn(&install_dipole.step);

    const exp_0_4 = b.addExecutable(.{
        .name = "exp-0.4-trace-step",
        .root_source_file = b.path("exp/0.4-trace-step/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exp_0_4.root_module.addImport("trace", trace_mod);

    const install_exp_0_4 = b.addInstallArtifact(exp_0_4, .{});

    const build_exp_0_4_step = b.step("exp-0-4-trace-step", "Build experiment 0.4 (single-step trace)");
    build_exp_0_4_step.dependOn(&install_exp_0_4.step);
}
