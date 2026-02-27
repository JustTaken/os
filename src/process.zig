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

    const LoadProgramSegment = struct {
        vaddr: usize,
        offset: usize,
        mem_size: usize,
        flag: elf.Elf.ProgramHeader.Flag,
        bytes: []u8,

        fn init(header: elf.Elf.ProgramHeader.T, last_load: ?LoadProgramSegment, bytes: []const u8, allocator: std.mem.Allocator) !?LoadProgramSegment {
            if (header.typ != .load) return null;

            var self: LoadProgramSegment = undefined;

            const start = header.offset;
            const end = start  + header.file_size;

            self.vaddr = std.mem.alignBackward(usize, header.vaddr, common.PAGE_SIZE);

            const vaddr_diff = header.vaddr - self.vaddr;
            const mem_size = header.mem_size + vaddr_diff;

            self.flag = header.flags;
            self.mem_size = std.mem.alignForward(usize, mem_size, common.PAGE_SIZE);
            self.bytes = try allocator.alignedAlloc(u8, common.PAGE_ALIGNMENT, self.mem_size);

            if (last_load) |last| {
                const last_occupied = last.vaddr + last.mem_size;

                if (last_occupied > self.vaddr) {
                    const copy_start = self.vaddr - last.vaddr;
                    const copy_end = copy_start + last_occupied - self.vaddr;
                    const copy_len = copy_end - copy_start;

                    @memcpy(self.bytes[0..copy_len], last.bytes[copy_start..copy_end]);
                }
            }

            const bytes_start = vaddr_diff;

            @memcpy(self.bytes[bytes_start..bytes_start + header.file_size], bytes[start..end]);

            return self;
        }
    };

    fn fromElfBytes(self: *Process, bytes: []const u8, pid: usize, allocator: std.mem.Allocator) !void {
        const elf_file = try elf.Elf.fromBytes(bytes, allocator);
        const entry_point = elf_file.header.entry;

        try self.init(pid, entry_point, allocator);

        var last_load: ?LoadProgramSegment = null;
        var loads = try std.ArrayList(LoadProgramSegment).initCapacity(allocator, elf_file.program_headers.len);

        for (elf_file.program_headers) |program_header| {
            const load = try LoadProgramSegment.init(program_header, last_load, bytes, allocator) orelse continue;
            loads.appendAssumeCapacity(load);
            last_load = load;
        }

        for (loads.items) |load| {
            const paddr = @intFromPtr(load.bytes.ptr);
            const vaddr = load.vaddr;
            const size = load.mem_size;
            const flag = page.PageTable.Flag.fromElfFlag(load.flag, true);

            try self.page_table.mapRange(vaddr, paddr, size, flag, allocator);
        }
    }

    fn init(self: *Process, pid: usize, pc: usize, allocator: std.mem.Allocator) !void {
        self.stack = .{0} ** STACK_SIZE;
        self.prev = null;
        self.pid = pid;

        const register_count: usize = 14; // s0 - s11 + ra + user_entry
        const sp: [*]usize = @ptrCast(@alignCast(&self.stack[Process.STACK_SIZE - register_count * @sizeOf(usize)]));

        sp[0] = pc;
        sp[1] = @intFromPtr(&user_entry);
        for (2..register_count) |i| {
            sp[i] = 0;
        }

        self.sp = @intFromPtr(sp) + 1 * @sizeOf(usize);
        self.page_table = try page.PageTable.init(allocator);

        const addr_base: usize = @intFromPtr(common.kernel_base);
        const addr_end: usize = @intFromPtr(common.free_ram_end);
        const flag: page.PageTable.Flag = .{ .read = true, .write = true, .execute = true, .valid = true };

        common.print("CREATING PAGE TABLE: {*}\n", .{self.page_table}) catch @panic("PRINT");

        try self.page_table.mapRange(addr_base, addr_base, addr_end - addr_base, flag, allocator);
        try self.page_table.mapRange(virtio.Virtio.Block.PADDR, virtio.Virtio.Block.PADDR, common.PAGE_SIZE, .{ .read = true, .write = true, .valid = true }, allocator);
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

    pub fn alloc(self: *ProcessHandler, pc: usize, allocator: std.mem.Allocator) !void {
        const proc = self.getUnused() orelse return error.OutOfUnusedProcess;

        defer self.pid += 1;

        try proc.init(self.pid, pc, allocator);

        self.runnable.append(&proc.node);

        return proc;
    }

    pub fn allocFromElf(self: *ProcessHandler, bytes: []const u8, allocator: std.mem.Allocator) !void {
        const proc = self.getUnused() orelse return error.OutOfUnusedProcess;
        defer self.pid += 1;

        try proc.fromElfBytes(bytes, self.pid, allocator);

        self.runnable.append(&proc.node);
    }

    pub fn runNext(self: *ProcessHandler) void {
        const runnable = self.getRunnable() orelse return;

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

const Sstatus = packed struct(u32) {
    _1: u4 = 0,
    spie: bool = false,
    _2: u12 = 0,
    sum: bool = false,
    _3: u14 = 0,
};

const sstatus: usize = @bitCast(Sstatus {
    .spie = true,
    .sum = true,
});

export fn user_entry() callconv(.naked) void {
    _ = asm volatile (
        \\addi sp, sp, -14 * 4
        \\lw a0, 0 * 4(sp)
        \\addi sp, sp, 14 * 4
        \\csrw sepc, a0
        \\csrw sstatus, %[sstatus]
        \\sret
        :
        : [sstatus] "r" (sstatus),
    );
}

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
const elf = @import("elf.zig");
const page = @import("page.zig");
const virtio = @import("virtio.zig");
const std = @import("std");
