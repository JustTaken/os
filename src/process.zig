// const List = collection.List(*Process);
// const BackList = collection.List(Process);
const List = std.DoublyLinkedList;

pub const Process = struct {
    pid: usize = 0,
    sp: common.vaddr = 0,
    stack: [STACK_SIZE]u8 align(4) = .{0} ** STACK_SIZE,
    node: List.Node = .{},
    prev: ?*Process = null,

    const STACK_SIZE: usize = 8192;

    pub fn run(self: *Process) void {
        if (self.prev) |other| {
            const next = &self.sp;
            const prev = &other.sp;

            common.print("switching from {x} to {x}\n", .{ other.sp, self.sp }) catch @panic("PRINT");

            jump(prev, next);
        } else @panic("NO PREVIOUS PROCESS TO GO AFTER");
    }
};

pub const ProcessHandler = struct {
    unused: List = .{},
    runnable: List = .{},
    running: List = .{},
    default: Process = .{},
    pid: usize = 1,

    pub const MAX_CHILDS: usize = 8;

    pub fn init(allocator: std.mem.Allocator) !ProcessHandler {
        var self: ProcessHandler = .{};

        for (0..MAX_CHILDS) |_| {
            const process = allocator.create(Process) catch @panic("OUT OF MEMORY");

            process.* = .{};

            self.unused.append(&process.node);
        }

        return self;
    }

    fn getUnused(self: *ProcessHandler) ?*Process {
        const n = self.unused.popFirst() orelse return null;
        return @fieldParentPtr("node", n);
    }

    fn getRunnable(self: *ProcessHandler) ?*Process {
        const n = self.runnable.popFirst() orelse return null;
        return @fieldParentPtr("node", n);
    }

    fn getRunning(self: *ProcessHandler) ?*Process {
        const n = self.running.popFirst() orelse return null;
        return @fieldParentPtr("node", n);
    }

    pub fn alloc(self: *ProcessHandler, pc: usize) !*Process {
        const proc = self.getUnused() orelse return error.OutOfUnusedProcess;

        defer self.pid += 1;

        const register_count: usize = 13; // s0 - s11 + ra
        const sp: [*]usize = @ptrCast(@alignCast(&proc.stack[Process.STACK_SIZE - register_count * @sizeOf(usize)]));

        sp[0] = pc;
        for (1..register_count) |i| {
            sp[i] = 0;
        }

        proc.pid = self.pid;
        proc.sp = @intFromPtr(sp);

        self.runnable.append(&proc.node);

        return proc;
    }

    pub fn nextToRun(self: *ProcessHandler) *Process {
        const runnable = self.getRunnable() orelse @panic("OUT OF RUNNABLE PROCESS");

        if (self.getRunning()) |running| {
            self.runnable.append(&running.node);
            runnable.prev = running;
        } else {
            runnable.prev = &self.default;
        }

        self.running.append(&runnable.node);

        return runnable;
    }
};

pub noinline fn jump(prev: *usize, next: *usize) void {
    _ = asm volatile (
        \\addi sp, sp, -13 * 4
        \\sw ra,  0  * 4(sp)
        \\sw s0,  1  * 4(sp)
        \\sw s1,  2  * 4(sp)
        \\sw s2,  3  * 4(sp)
        \\sw s3,  4  * 4(sp)
        \\sw s4,  5  * 4(sp)
        \\sw s5,  6  * 4(sp)
        \\sw s6,  7  * 4(sp)
        \\sw s7,  8  * 4(sp)
        \\sw s8,  9  * 4(sp)
        \\sw s9,  10 * 4(sp)
        \\sw s10, 11 * 4(sp)
        \\sw s11, 12 * 4(sp)
        \\sw sp, (%[arg0])
        \\lw sp, (%[arg1])
        \\lw ra,  0  * 4(sp)
        \\lw s0,  1  * 4(sp)
        \\lw s1,  2  * 4(sp)
        \\lw s2,  3  * 4(sp)
        \\lw s3,  4  * 4(sp)
        \\lw s4,  5  * 4(sp)
        \\lw s5,  6  * 4(sp)
        \\lw s6,  7  * 4(sp)
        \\lw s7,  8  * 4(sp)
        \\lw s8,  9  * 4(sp)
        \\lw s9,  10 * 4(sp)
        \\lw s10, 11 * 4(sp)
        \\lw s11, 12 * 4(sp)
        \\addi sp, sp, 13 * 4
        :
        : [arg0] "r" (prev),
          [arg1] "r" (next),
    );
}

const common = @import("common.zig");
// const collection = @import("collection.zig");
const std = @import("std");
