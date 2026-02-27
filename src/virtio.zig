pub const Virtio = struct {
    const MAGIC: usize = 0x00;
    const VERSION: usize = 0x04;
    const DEVICE_ID: usize = 0x08;
    const PAGE_SIZE: usize = 0x28;
    const QUEUE_SEL: usize = 0x30;
    const QUEUE_MAX: usize = 0x34;
    const QUEUE_NUM: usize = 0x38;
    const QUEUE_PFN: usize = 0x40;
    const QUEUE_READY: usize = 0x44;
    const QUEUE_NOTIFY: usize = 0x50;
    const DEVICE_STATUS: usize = 0x70;
    const DEVICE_CONFIG: usize = 0x100;

    const Driver = extern struct {
        magic: u32,
        version: u32,
        id: u32,
        _padding1: [0x1c]u8,
        page_size: u32,
        _padding2: [0x04]u8,
        queue_sel: u32,
        queue_max: u32,
        queue_num: u32,
        _padding3: [0x04]u8,
        queue_pfn: u32,
        queue_ready: u32,
        _padding4: [0x08]u8,
        queue_notify: u32,
        _padding5: [0x1c]u8,
        device_status: Status,
        _padding6: [0x8c]u8,
        device_config: u64,

        const Status = packed struct(u32) {
            reset: u1 = 0,
            ack: bool = false,
            driver: bool = false,
            ok: bool = false,
            _: u28 = 0,
        };
    };

    //const DeviceStatus = enum(u32) {
    //    init = 0x0,
    //    ack = 0x1,
    //    driver = 0x2,
    //    ok = 0x4,
    //};

    pub const Block = struct {
        driver: *Driver,
        queue: *Queue,
        request: *Request,
        capacity: usize,

        pub const ENTRY_COUNT: usize = 16;
        pub const DEVICE: usize = 2;
        pub const PADDR: usize = 0x10001000;

        const Operation = enum(u32) {
            read = 0x0,
            write = 0x1,
        };

        pub const Descriptor = extern struct {
            addr: u64,
            len: u32,
            flags: Flag,
            next: u16,

            pub const Flag = packed struct(u16) {
                next: bool,
                write: bool,
                _: u14 = 0,
            };
        };

        pub const Available = extern struct {
            flags: u16,
            index: u16,
            ring: [ENTRY_COUNT]Element,

            pub const Element = u16;
        };

        pub const Used = extern struct {
            flags: u16,
            index: u16,
            ring: [ENTRY_COUNT]Element,

            pub const Element = extern struct {
                id: u32,
                len: u32,
            };
        };

        pub const Queue = extern struct {
            descriptors: [ENTRY_COUNT]Descriptor,
            available: Available,
            used: Used align(common.PAGE_SIZE),
            index: u32,
            used_index: *volatile u16,
            last_used_index: u16,

            pub fn init(index: u32, driver: *Driver, allocator: std.mem.Allocator) !*Queue {
                const size = std.mem.alignForward(usize, @sizeOf(Queue), common.PAGE_SIZE);
                const ptr = try allocator.alignedAlloc(u8, common.PAGE_ALIGNMENT, size);
                @memset(ptr, 0);

                const queue: *Queue = @ptrCast(@alignCast(ptr.ptr));

                queue.index = index;
                queue.used_index = &queue.used.index;

                driver.queue_sel = index;
                driver.queue_num = ENTRY_COUNT;
                driver.queue_pfn = @intCast(@intFromPtr(queue) / common.PAGE_SIZE);
                //_ = driver;

                //write32(QUEUE_SEL, index);
                //write32(QUEUE_NUM, ENTRY_COUNT);
                //write32(QUEUE_PFN, @intFromPtr(queue) / common.PAGE_SIZE);

                return queue;
            }
        };

        pub const Request = extern struct {
            typ: u32,
            reserved: u32,
            sector: u64,
            data: [common.SECTOR_SIZE]u8,
            status: u8,
        };

        //pub fn read32(offset: usize) u32 {
        //    const addr: *u32 = @ptrFromInt(PADDR + offset);
        //    return addr.*;
        //}

        //pub fn read64(offset: usize) u64 {
        //    const addr: *u64 = @ptrFromInt(PADDR + offset);
        //    return addr.*;
        //}

        //pub fn write32(offset: usize, value: u32) void {
        //    const ptr: *volatile u32 = @ptrFromInt(PADDR + offset);
        //    ptr.* = value;
        //}

        //pub fn or32(offset: usize, value: u32) void {
        //    const read = read32(offset);
        //    write32(offset, value | read);
        //}

        pub fn init(allocator: std.mem.Allocator) !Block {
            const driver: *Driver = @ptrFromInt(PADDR);

            if (driver.magic != 0x74726976) return error.Magic;
            if (driver.version != 1) return error.Version;
            if (driver.id != DEVICE) return error.DeviceId;


            //if (read32(MAGIC) != 0x74726976) return error.Magic;
            //if (read32(VERSION) != 1) return error.Version;
            //if (read32(DEVICE_ID) != DEVICE) return error.DeviceId;

            //write32(DEVICE_STATUS, @intFromEnum(DeviceStatus.init));
            //or32(DEVICE_STATUS, @intFromEnum(DeviceStatus.ack));
            //or32(DEVICE_STATUS, @intFromEnum(DeviceStatus.driver));
            //write32(DEVICE_STATUS, @intFromEnum(DeviceStatus.ok));

            driver.device_status = .{ };
            driver.device_status.ack = true;
            driver.device_status.driver = true;

            //try common.print("PAGE SIZE AT: {*}\n", .{&driver.page_size});
            //try common.print("VALUE: {*} MAGIC\n", .{&driver.magic});
            //try common.print("VALUE: {*} VERSION\n", .{&driver.version});
            //try common.print("VALUE: {*} ID\n", .{&driver.id});
            //try common.print("VALUE: {*} PAGE_SIZE\n", .{&driver.page_size});
            //try common.print("VALUE: {*} QUEUE_SEL\n", .{&driver.queue_sel});
            //try common.print("VALUE: {*} QUEUE_MAX\n", .{&driver.queue_max});
            //try common.print("VALUE: {*} QUEUE_NUM\n", .{&driver.queue_num});
            //try common.print("VALUE: {*} QUEUE_PFN\n", .{&driver.queue_pfn});
            //try common.print("VALUE: {*} QUEUE_READY\n", .{&driver.queue_ready});
            //try common.print("VALUE: {*} QUEUE_NOTIFY\n", .{&driver.queue_notify});
            //try common.print("VALUE: {*} DEVICE_STATUS\n", .{&driver.device_status});
            //try common.print("VALUE: {*} DEVICE_CONFIG\n", .{&driver.device_config});
            driver.page_size = @intCast(common.PAGE_SIZE);
            //write32(PAGE_SIZE, @intCast(common.PAGE_SIZE));

            const queue = try Queue.init(0, driver, allocator);

            driver.device_status.ok = true;

            const request_size = std.mem.alignForward(usize, @sizeOf(usize), common.PAGE_SIZE);
            const request_addr = try allocator.alignedAlloc(u8, common.PAGE_ALIGNMENT, request_size);

            const request: *Request = @ptrCast(@alignCast(request_addr));
            //const capacity: usize = @intCast(read64(DEVICE_CONFIG) * common.SECTOR_SIZE);
            const capacity = driver.device_config * common.SECTOR_SIZE;

            return .{
                .driver = driver,
                .capacity = @intCast(capacity),
                .queue = queue,
                .request = request,
            };
        }

        pub fn kick(self: *Block, index: usize) void {
            self.queue.available.ring[self.queue.available.index % ENTRY_COUNT] = @intCast(index);
            self.queue.available.index += 1;

            self.driver.queue_notify = self.queue.index;
            //write32(QUEUE_NOTIFY, self.queue.index);
            self.queue.last_used_index += 1;
        }

        pub fn isBusy(self: *Block) bool {
            return self.queue.last_used_index != self.queue.used_index.*;
        }

        pub fn diskOp(self: *Block, buf: []u8, sector: usize, op: Operation) !void {
            if (sector >= self.capacity / common.SECTOR_SIZE) return error.OutOfMemory;

            self.request.sector = sector;
            self.request.typ = @intFromEnum(op);

            if (op == .write) {
                @memcpy(self.request.data[0..common.SECTOR_SIZE], buf[0..common.SECTOR_SIZE]);
            }

            const first_descriptor: usize = 0;

            self.queue.descriptors[first_descriptor + 0].addr = @intFromPtr(self.request);
            self.queue.descriptors[first_descriptor + 0].len = @sizeOf(u32) + @sizeOf(u32) + @sizeOf(u64);
            self.queue.descriptors[first_descriptor + 0].flags = .{ .next = true, .write = false };
            self.queue.descriptors[first_descriptor + 0].next = first_descriptor + 1;

            self.queue.descriptors[first_descriptor + 1].addr = @intFromPtr(self.request) + @offsetOf(Request, "data");
            self.queue.descriptors[first_descriptor + 1].len = common.SECTOR_SIZE;
            self.queue.descriptors[first_descriptor + 1].flags = .{ .next = true, .write = op != .write };
            self.queue.descriptors[first_descriptor + 1].next = first_descriptor + 2;

            self.queue.descriptors[first_descriptor + 2].addr = @intFromPtr(self.request) + @offsetOf(Request, "status");
            self.queue.descriptors[first_descriptor + 2].len = @sizeOf(u8);
            self.queue.descriptors[first_descriptor + 2].flags = .{ .write = true, .next = false };

            self.kick(first_descriptor);

            while (self.isBusy()) {
            }

            if (self.request.status != 0) {
                return error.DiskOpFailed;
            }

            if (op == .read) {
                @memcpy(buf[0..common.SECTOR_SIZE], self.request.data[0..common.SECTOR_SIZE]);
            }
        }
    };
};

const common = @import("common.zig");
const std = @import("std");
