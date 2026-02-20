const std = @import("std");

pub fn build(builder: *std.Build) void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    //const target = builder.resolveTargetQuery(.{
    //    .cpu_arch = .riscv32,
    //    .os_tag = .freestanding,
    //    .abi = .none,
    //});

    //const user_exe = builder.addExecutable(.{
    //    .name = "user.bin",
    //    .root_module = builder.createModule(.{
    //        .root_source_file = builder.path("src/user.zig"),
    //        .target = target,
    //        .optimize = optimize,
    //        .strip = false,
    //    }),
    //});

    //user_exe.entry = .disabled;
    //user_exe.setLinkerScript(builder.path("src/user.ld"));

    //const user_elf =builder.addSystemCommand(&.{
    //    "llvm-objcopy",

    //    "--set-section-flags",
    //    ".bss=alloc,contents",
    //    "-O",
    //    "binary",
    //});

    //user_elf.addArtifactArg(user_exe);
    //const user_bin = user_elf.addOutputFileArg("user.bin");

    //const user_elf_copy = builder.addSystemCommand(&.{
    //    "llvm-objcopy",
    //    "-Ibinary",
    //    "-Oelf32-littleriscv",
    //});

    //user_elf_copy.addFileArg(user_bin);
    //const shell_obj = user_elf_copy.addOutputFileArg("user.bin.o");

    const exe = builder.addExecutable(.{
        .name = "elf.elf",
        .root_module = builder.createModule(.{
            .root_source_file = builder.path("src/elf.zig"),
            .target = target,
            .optimize = optimize,
            //.strip = false,
        }),
    });

    //exe.entry = .disabled;

    //exe.addObjectFile(shell_obj);
    //exe.setLinkerScript(builder.path("src/kernel.ld"));
    builder.installArtifact(exe);

    //const qemu_run = builder.addSystemCommand(&.{"qemu-system-riscv32"});
    //qemu_run.addArgs(&.{
    //    "-machine", "virt",
    //    "-bios", "default",
    //    "-serial", "mon:stdio",
    //    "-nographic", "--no-reboot", 
    //    "-kernel"
    //});

    //qemu_run.addArtifactArg(exe);

    const run_step = builder.step("run", "Run the application");
    run_step.dependOn(&exe.step);
    //run_step.dependOn(&qemu_run.step);
}
