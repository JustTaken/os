const std = @import("std");

pub fn build(builder: *std.Build) void {
    //const target = builder.resolveTargetQuery(.{
    //    .cpu_arch = .riscv32,
    //    .os_tag = .freestanding,
    //    .abi = .none,
    //});

    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    const user = builder.option(bool, "user", "Build user elf") orelse false;

    if (user) {
        const user_exe = builder.addExecutable(.{
            .name = "user.elf",
            .root_module = builder.createModule(.{
                .root_source_file = builder.path("src/user.zig"),
                .target = target,
                .optimize = optimize,
                .strip = false,
            }),
        });

        user_exe.entry = .disabled;
        user_exe.setLinkerScript(builder.path("src/user.ld"));
        builder.installArtifact(user_exe);

        return;
    }

    const exe = builder.addExecutable(.{
        .name = "kernel.elf",
        .root_module = builder.createModule(.{
            .root_source_file = builder.path("src/kernel.zig"),
            .target = target,
            .optimize = optimize,
            .strip = false,
        }),
    });

    runQemu(exe, builder);


    //const run_exe = builder.addRunArtifact(exe);
    //run_step.dependOn(&run_exe.step);
}

fn runQemu(exe: *std.Build.Step.Compile, builder: *std.Build) void {
    exe.entry = .disabled;

    exe.setLinkerScript(builder.path("src/kernel.ld"));
    builder.installArtifact(exe);

    const qemu_run = builder.addSystemCommand(&.{"qemu-system-riscv32"});
    qemu_run.addArgs(&.{
        //"-s", "-S", "-gdb", "tcp::1234",
        "-machine", "virt",
        "-bios", "default",
        "-serial", "mon:stdio",
        "-nographic", "--no-reboot", 
        "-d", "unimp,guest_errors,int,cpu_reset",
        "-D", "qemu.log",
        "-drive", "id=drive0,file=asset/disk.tar,format=raw,if=none",
        "-device", "virtio-blk-device,drive=drive0,bus=virtio-mmio-bus.0",
        "-kernel"
    });

    qemu_run.addArtifactArg(exe);

    const run_step = builder.step("run", "Run the application");
    run_step.dependOn(&qemu_run.step);
}
