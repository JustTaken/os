pub var context: common.Context = undefined;

pub fn main() !void {
    try context.init();

    _ = try context.process.alloc(@intFromPtr(&procAEntry), context.allocator);
    _ = try context.process.alloc(@intFromPtr(&procBEntry), context.allocator);

    try common.print("{s}", .{"Hello Kernel!\n"});

    context.process.runNext();
}

fn procAEntry() void {
    common.print("{s}", .{"A PROCESS!\n"}) catch @panic("PRINT");

    while (true) {
        common.putChar('A');
        context.process.runNext();
        common.delay();
    }
}

fn procBEntry() void {
    common.print("{s}", .{"B PROCESS!\n"}) catch @panic("PRINT");

    while (true) {
        common.putChar('B');
        context.process.runNext();
        common.delay();
    }
}

pub fn panic(message: []const u8, return_trace: ?*std.builtin.StackTrace, return_address: ?usize) noreturn {
    _ = return_trace;
    _ = return_address;

    common.print("PANIC: {s}\n", .{message}) catch {};

    while (true) {
        asm volatile ("wfi");
    }
}

export fn kernelMain() noreturn {
    common.zeroBSSMemory();
    trap.setTrapEntry();

    main() catch |err| std.debug.panic("error: {s}", .{@errorName(err)});

    while (true) {
        asm volatile ("wfi");
    }
}

export fn boot() linksection(".text.boot") callconv(.naked) noreturn {
    const stack_top = common.stack_top;

    _ = asm volatile (
        \\mv sp, %[stack_top]
        \\j kernelMain
        :
        : [stack_top] "r" (stack_top),
    );
}

const trap = @import("trap.zig");
const common = @import("common.zig");
const process = @import("process.zig");
const std = @import("std");
