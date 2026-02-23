const stack_top = @extern([*]u8, .{ .name = "__stack_top" });

export fn exit() noreturn {
    while (true) {
        _ = asm volatile ("wfi");
    }
}

export fn main() noreturn {
    while (true) {
        _ = asm volatile ("wfi");
    }
}

export fn start() linksection(".text.start") callconv(.naked) noreturn {
    //while (true) {
    //    asm volatile ("wfi");
    //}
    _ = asm volatile (
        \\mv sp, %[stack_top]
        \\mv a0, sp
        \\call main
        \\call exit
        :: [stack_top] "r" (stack_top),
    );
}

