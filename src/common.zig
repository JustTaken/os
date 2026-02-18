const bss = @extern([*]u8, .{ .name = "__bss" });
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });
pub const stack_top = @extern([*]u8, .{ .name = "__stack_top" });

pub const free_ram = @extern([*]u8, .{ .name = "__free_ram" });
pub const free_ram_end = @extern([*]u8, .{ .name = "__free_ram_end" });
pub const kernel_base = @extern([*]u8, .{ .name = "__kernel_base" });

pub const paddr = usize;
pub const vaddr = usize;
pub const PAGE_SIZE: usize = 4096;

pub const Context = struct {
    process: process.ProcessHandler,
    buffer_allocator: std.heap.FixedBufferAllocator,
    allocator: std.mem.Allocator,

    pub fn init(self: *Context) !void {
        const ram_len: usize = @intFromPtr(free_ram_end) - @intFromPtr(free_ram);
        const ram = free_ram[0..ram_len];

        self.buffer_allocator = std.heap.FixedBufferAllocator.init(ram);
        self.allocator = self.buffer_allocator.allocator();
        self.process = try process.ProcessHandler.init(self.allocator);
    }
};

const console: std.io.AnyWriter = .{
    .context = undefined,
    .writeFn = write,
};

fn write(context: *const anyopaque, bytes: []const u8) anyerror!usize {
    _ = context;

    for (bytes) |c| {
        putChar(c);
    }

    return bytes.len;
}

pub fn putChar(char: u8) void {
    _ = syscall.sbi_call(char, 0, 0, 0, 0, 0, 0, 1);
}

pub fn print(comptime fmt: []const u8, arguments: anytype) !void {
    console.print(fmt, arguments) catch return error.Print;
}

pub fn readCSR(comptime reg: []const u8) usize {
    var tmp: usize = 0;

    const string = "csrr %[arg], " ++ reg;
    _ = asm volatile (string
        : [arg] "=r" (tmp),
    );

    return tmp;
}

pub fn writeCSR(comptime reg: []const u8, value: usize) void {
    const string = "csrw " ++ reg ++ ", %[arg]";

    _ = asm volatile (string
        :
        : [arg] "r" (value),
    );
}

pub fn delay() void {
    for (0..30000000) |_| {
        _ = asm volatile ("nop");
    }
}

pub fn zeroBSSMemory() void {
    const bss_size: usize = @intFromPtr(bss_end) - @intFromPtr(bss);
    @memset(bss[0..bss_size], 0);
}

const syscall = @import("syscall.zig");
const std = @import("std");
const process = @import("process.zig");
