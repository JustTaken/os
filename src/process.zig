const List = std.DoublyLinkedList;

pub const Process = struct {
    pid: usize,
    sp: common.vaddr,
    stack: [STACK_SIZE]u8 align(4),
    node: List.Node,
    prev: ?*Process,
    page_table: *page.PageTable,

    const STACK_SIZE: usize = 2 * 8192;

    pub fn run(self: *Process) void {
        if (self.prev) |other| {
            const next = &self.sp;
            const prev = &other.sp;

            _ = asm volatile (
                \\addi sp, sp, -2 * 4
                \\sw a0, 0 * 4(sp)
                \\sw a1, 1 * 4(sp)
                \\mv a0, %[prev]
                \\mv a1, %[next]
                \\call switch_assembly
                \\sw a0, 0 * 4(sp)
                \\sw a1, 1 * 4(sp)
                \\addi sp, sp, 2 * 4
                :
                : [prev] "r" (prev),
                  [next] "r" (next),
            );
        } else @panic("NO PREVIOUS PROCESS TO GO AFTER");
    }

    fn init(self: *Process, pid: usize, pc: usize, allocator: std.mem.Allocator) !void {
        self.stack = .{0} ** STACK_SIZE;
        self.prev = null;
        self.pid = pid;

        const register_count: usize = 13; // s0 - s11 + ra
        const sp: [*]usize = @ptrCast(@alignCast(&self.stack[Process.STACK_SIZE - register_count * @sizeOf(usize)]));

        sp[0] = pc;
        for (1..register_count) |i| {
            sp[i] = 0;
        }

        self.sp = @intFromPtr(sp);

        self.page_table = try page.PageTable.init(allocator);
        common.print("PAGE TABLE: {*}\n", .{self.page_table}) catch @panic("PRINT");
        try self.page_table.mapAll(allocator);
    }
};

pub const ProcessHandler = struct {
    unused: List,
    runnable: List,
    running: List,
    default: Process,
    pid: usize = 1,

    pub const MAX_CHILDS: usize = 8;

    pub fn init(allocator: std.mem.Allocator) !ProcessHandler {
        var self: ProcessHandler = undefined;

        self.unused = .{};
        self.runnable = .{};
        self.running = .{};

        try self.default.init(0, 0, allocator);

        for (0..MAX_CHILDS) |_| {
            const process = allocator.create(Process) catch @panic("OUT OF MEMORY");

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

    pub fn alloc(self: *ProcessHandler, pc: usize, allocator: std.mem.Allocator) !*Process {
        const proc = self.getUnused() orelse return error.OutOfUnusedProcess;

        defer self.pid += 1;

        try proc.init(self.pid, pc, allocator);

        self.runnable.append(&proc.node);

        return proc;
    }

    pub fn runNext(self: *ProcessHandler) void {
        const runnable = self.getRunnable() orelse @panic("OUT OF RUNNABLE PROCESS");

        if (self.getRunning()) |running| {
            self.runnable.append(&running.node);
            runnable.prev = running;
        } else {
            runnable.prev = &self.default;
        }

        self.running.append(&runnable.node);

        const runnable_stack: usize = @intFromPtr(&runnable.stack[0]) + Process.STACK_SIZE;

        const sat_mode = page.Sat{ .sv32 = true };
        const runnable_page = sat_mode.maskAddr(runnable.page_table);
        const pc: *usize = @ptrFromInt(runnable.sp);

        common.print("SWAPPING PAGE TABLE: {*}, {*}, pc: {x}\n", .{ runnable.page_table, &runnable.page_table.elements, pc.* }) catch @panic("PRINT");

        _ = asm volatile (
            \\sfence.vma
            \\csrw satp, %[satp]
            \\sfence.vma
            \\csrw sscratch, %[sscratch]
            :
            : [sscratch] "r" (runnable_stack),
              [satp] "r" (runnable_page),
        );

        runnable.run();
    }
};

export fn switch_assembly() callconv(.naked) void {
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
        \\sw sp, (a0)
        \\lw sp, (a1)
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
        \\ret
    );
}

const common = @import("common.zig");
const page = @import("page.zig");
const std = @import("std");
