pub fn main() !void {
    try common.context.init();
    defer common.context.deinit();

    try common.context.process.allocFromElf(common.user_application, common.context.allocator);

    try common.print("{s}", .{"Hello Kernel!\n"});

    //var buffer: [512]u8 = .{0} ** 512;
    //try context.block.diskOp(&buffer, 0, .read);

    //common.print("DRIVE CONTENT: {s}\n", .{buffer}) catch @panic("PRINT");

    //const hello = "Hello world fron kernel storage device\n";
    //@memcpy(buffer[0..hello.len], hello);
    //try context.block.diskOp(&buffer, 0, .write);

    //common.context.process.runNext();
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

//fn procAEntry() void {
//    while (true) {
//        context.process.runNext();
//        common.delay();
//    }
//}
//
//fn procBEntry() void {
//    while (true) {
//        context.process.runNext();
//        common.delay();
//    }
//}

