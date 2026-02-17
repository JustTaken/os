const std = @import("std");

pub fn build(builder: *std.Build) void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    // const target = builder.resolveTargetQuery(.{
    //     .cpu_arch = riscv32,
    //     .os_tag = .freestanding,
    //     .abi = .none,
    // });

    const exe = builder.addExecutable(.{
        .name = "kernel.elf",
        .root_module = builder.createModule(.{
            .root_source_file = builder.path("src/kernel.zig"),
            .target = target,
            .optimize = optimize,
            .strip = false,
        }),
    });

    exe.entry = .disabled;

    exe.setLinkerScript(builder.path("src/kernel.ld"));
    builder.installArtifact(exe);

    const qemu_run = builder.addSystemCommand(&.{"qemu-system-riscv32"});
    qemu_run.addArgs(&.{
        "-machine", "virt",
        "-bios", "default",
        "-serial", "mon:stdio",
        "-nographic", "--no-reboot", 
        "-kernel"
    });

    qemu_run.addArtifactArg(exe);

    const run_step = builder.step("run", "run QEMU");
    run_step.dependOn(&qemu_run.step);
}
