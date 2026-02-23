pub const Call = enum(usize) {
    putchar = 0x1,
    _,
};

pub const SbiReturn = struct {
    err: isize,
    value: isize,
};

pub fn sbi_call(arg0: isize, arg1: isize, arg2: isize, arg3: isize, arg4: isize, arg5: isize, arg6: isize, arg7: usize) SbiReturn {
    var err: isize = 0;
    var value: isize = 0;

    _ = asm volatile (
        \\ecall
        : [err] "={a0}" (err),
          [value] "={a1}" (value),
        : [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
          [arg3] "{a3}" (arg3),
          [arg4] "{a4}" (arg4),
          [arg5] "{a5}" (arg5),
          [arg6] "{a6}" (arg6),
          [arg7] "{a7}" (arg7),
        : .{ .memory = true });

    return .{
        .err = err,
        .value = value,
    };
}

pub fn handle(frame: *trap.TrapFrame) void {
    const call: Call = @enumFromInt(frame.a3);
    switch (call) {
        .putchar => common.putChar(@intCast(frame.a0)),
        _ => {
            std.debug.panic("Unexpected syscall {d}\n", .{frame.a3});
        }
    }
}

const common = @import("common.zig");
const trap = @import("trap.zig");
const std = @import("std");
