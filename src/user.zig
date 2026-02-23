const stack_top = @extern([*]u8, .{ .name = "__stack_top" });

fn syscall(no: usize, arg0: usize, arg1: usize, arg2: usize) void {
    //var err: usize = 0;

    _ = asm volatile (
        \\ecall
        : 
          //[err] "={a0}" (err),
        : [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
          [arg3] "{a3}" (no),
        : .{ .memory = true }
    );
}

fn putChar(ch: u8) void {
    syscall(1, ch, 0, 0);
}

fn print(string: []const u8) void {
    for (string) |s| {
        putChar(s);
    }
}

export fn exit() noreturn {
    while (true) {
    }
}

export fn main() noreturn {
    print("Hello world, from user land\n");

    while (true) {
    }
}

export fn start() linksection(".text.start") callconv(.naked) noreturn {
    _ = asm volatile (
        \\mv sp, %[stack_top]
        \\call main
        \\call exit
        :: [stack_top] "r" (stack_top),
    );
}

