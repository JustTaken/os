pub const Sat = packed struct(u1) {
    sv32: bool = false,

    const Mask = packed struct(u32) {
        addr: u31,
        spa: Sat,
    };

    pub fn maskAddr(self: Sat, page: *PageTable) usize {
        const mask = Mask{
            .spa = self,
            .addr = @intCast(@intFromPtr(page) / common.PAGE_SIZE),
        };

        return @bitCast(mask);
    }
};

pub const PageTable = extern struct {
    elements: [ELEMENT_COUNT]Element align(common.PAGE_SIZE),

    const Vpn = packed struct(u32) {
        offset: u12,
        zero: u10,
        one: u10,
    };

    const Flag = packed struct(u10) {
        valid: bool = false,
        read: bool = false,
        write: bool = false,
        execute: bool = false,
        user: bool = false,
        _: u5 = 0,
    };

    const Element = packed struct(u32) {
        flag: Flag = .{},
        addr: u22 = 0,

        fn init(self: *Element, addr: usize, flag: Flag) void {
            self.addr = @intCast(addr / common.PAGE_SIZE);
            self.flag = flag;
        }

        fn getTable(self: *Element) *PageTable {
            const addr: usize = self.addr;
            const table: *PageTable = @ptrFromInt(addr * common.PAGE_SIZE);

            return table;
        }
    };

    const TEN_BYTES_MASK: usize = 0b1111111111;
    const FIRST_LEVEL_SHIFT: usize = 22;
    const SECOND_LEVEL_SHIFT: usize = 12;
    const ELEMENT_COUNT: usize = common.PAGE_SIZE / @sizeOf(usize);

    pub fn init(allocator: std.mem.Allocator) !*PageTable {
        const table = try allocator.create(PageTable);
        table.elements = .{Element{}} ** ELEMENT_COUNT;

        return table;
    }

    pub fn mapAll(self: *PageTable, allocator: std.mem.Allocator) !void {
        const available_bytes: usize = @intFromPtr(common.free_ram_end) - @intFromPtr(common.kernel_base);
        const available_pages: usize = available_bytes / common.PAGE_SIZE;
        common.print("AVAILABLE PAGES: {d}\n", .{available_pages}) catch @panic("PRINT");

        for (0..available_pages) |index| {
            const addr = @intFromPtr(common.kernel_base) + common.PAGE_SIZE * index;
            //common.print("PAGE INDEX: {d}, PAGE ADDR: {x}\n", .{index, addr}) catch @panic("PRINT");
            try self.map(addr, addr, .{ .read = true, .write = true, .execute = true, .valid = true }, allocator);
        }
    }

    pub fn map(self: *PageTable, vaddr: common.vaddr, paddr: common.paddr, flags: Flag, allocator: std.mem.Allocator) !void {
        if (!std.mem.isAligned(vaddr, common.PAGE_SIZE)) {
            return error.MisalignedVAddr;
        }

        if (!std.mem.isAligned(paddr, common.PAGE_SIZE)) {
            return error.MisalignedPAddr;
        }

        const vpn: Vpn = @bitCast(vaddr);

        if (!self.elements[vpn.one].flag.valid) {
            const child = try PageTable.init(allocator);
            self.elements[vpn.one].init(@intFromPtr(child), .{ .valid = true });
            common.print("FIRST LEVEL: {*}, {x}, VADDR: {x}\n", .{ child, self.elements[vpn.one].addr, vaddr }) catch @panic("PRINT");
        }

        const table0 = self.elements[vpn.one].getTable();
        table0.elements[vpn.zero].init(paddr, flags);

        // common.print("SECOND LEVEL: {*}, {x}, VADDR: {x}\n", .{ table0.elements, table0.elements[vpn.zero].addr, vaddr }) catch @panic("PRINT");  8026b000, 80259000
    }

    pub fn ptr(self: *PageTable) usize {
        return @intFromPtr(self.elements);
    }
};

const common = @import("common.zig");
const std = @import("std");
