const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const trace_mod = b.createModule(.{
        .root_source_file = b.path("lib/core/trace.zig"),
    });

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("lib/core/debugger/LLDBDriver.zig"),
        .target = target,
        .optimize = optimize,
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

    const simple_add_infinite_loop = b.addExecutable(.{
        .name = "simple_add_infinite_loop",
        .target = target,
        .optimize = optimize,
    });
    simple_add_infinite_loop.addCSourceFile(.{
        .file = b.path("targets/c/simple_add_inf_loop.c"),
        .flags = &.{"-g"},
    });
    simple_add_infinite_loop.linkLibC();
    const install_simple_add_infinite_loop = b.addInstallArtifact(simple_add_infinite_loop, .{});
    const simple_add_infinite_loop_step = b.step("simple_add_infinite_loop", "Install the simple_add_infinite_loop executable");
    simple_add_infinite_loop_step.dependOn(&install_simple_add_infinite_loop.step);

    // dipole executables
    const dipole = b.addExecutable(.{
        .name = "dipole",
        .root_source_file = b.path("cmd/dipole/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    dipole.root_module.addImport("lib", lib_mod);

    const install_dipole = b.addInstallArtifact(dipole, .{});
    const dipole_step = b.step("dipole", "Install the dipole executable");
    dipole_step.dependOn(&install_dipole.step);

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

    const exp_0_5 = b.addExecutable(.{
        .name = "exp-0.5-trace-n-step",
        .root_source_file = b.path("exp/0.5-trace-n-step/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exp_0_5.root_module.addImport("trace", trace_mod);

    const install_exp_0_5 = b.addInstallArtifact(exp_0_5, .{});

    const build_exp_0_5_n_step = b.step("exp-0-5-trace-n-step", "Build experiment 0.5 (mutli-step trace)");
    build_exp_0_5_n_step.dependOn(&install_exp_0_5.step);

    const exp_0_6 = b.addExecutable(.{
        .name = "exp-0.6-pty-lldb-interactive",
        .root_source_file = b.path("exp/0.6-pty-lldb-interactive/exp0_6.zig"),
        .target = target,
        .optimize = optimize,
    });

    const install_exp_0_6 = b.addInstallArtifact(exp_0_6, .{});

    const build_exp_0_6_pty_lldb_interactive = b.step("exp-0-6-pty-lldb-interactive", "Build experiment 0.6 (pty-lldb-interactive)");
    build_exp_0_6_pty_lldb_interactive.dependOn(&install_exp_0_6.step);

    const exp_0_7 = b.addExecutable(.{
        .name = "exp-0.7-dipole-repl",
        .root_source_file = b.path("exp/0.7-lldb-driver-api/exp0_7.zig"),
        .target = target,
        .optimize = optimize,
    });

    exp_0_7.root_module.addImport("lib", lib_mod);

    const install_exp_0_7 = b.addInstallArtifact(exp_0_7, .{});

    const build_exp_0_7_dipole_repl = b.step("exp-0-7-dipole-repl-interactive", "Build experiment 0.7 (dipole-repl-interactive)");
    build_exp_0_7_dipole_repl.dependOn(&install_exp_0_7.step);

    // wire installs into the default install step so `zig build` produces zig-out
    const install = b.getInstallStep();
    // simple C programs
    install.dependOn(&install_simple.step);
    install.dependOn(&install_simple_add.step);
    install.dependOn(&install_simple_add_infinite_loop.step);

    // main dipole executable
    install.dependOn(&install_dipole.step);

    // experiment executables
    install.dependOn(&install_exp_0_4.step);
    install.dependOn(&install_exp_0_5.step);
    install.dependOn(&install_exp_0_6.step);
    install.dependOn(&install_exp_0_7.step);
}
