pub const Call = enum(usize) {
    putchar = 0x1,
    getchar = 0x2,
    readfile = 0x3,
    writefile = 0x4,
    _,
};

pub const SbiReturn = struct {
    value1: usize,
    value2: usize,
};

pub fn sbi_call(arg0: isize, arg1: isize, arg2: isize, arg3: isize, arg4: isize, arg5: isize, arg6: isize, arg7: Call) SbiReturn {
    var value1: usize = 0;
    var value2: usize = 0;
    const call: usize = @intFromEnum(arg7);

    _ = asm volatile (
        \\ecall
        : [value1] "={a0}" (value1),
          [value2] "={a1}" (value2),
        : [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
          [arg3] "{a3}" (arg3),
          [arg4] "{a4}" (arg4),
          [arg5] "{a5}" (arg5),
          [arg6] "{a6}" (arg6),
          [call] "{a7}" (call),
        : .{ .memory = true });

    return .{
        .value1 = value1,
        .value2 = value2,
    };
}

pub fn handle(frame: *trap.TrapFrame) void {
    const call: Call = @enumFromInt(frame.a3);

    switch (call) {
        .putchar => common.putChar(@intCast(frame.a0)),
        .getchar => {
            while (true) {
                const char = common.getChar();
                if (char >= 0) {
                    frame.a0 = char;
                    break;
                }

                common.context.process.runNext();
            }
        },
        else => {
            std.debug.panic("Unhandled syscall {d}\n", .{frame.a3});
        }
    }
}

const common = @import("common.zig");
const trap = @import("trap.zig");
const std = @import("std");
