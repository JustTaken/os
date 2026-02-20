pub const Elf = struct {
    header: Header,
    program_headers: []ProgramHeader,
    section_headers: []SectionHeader,

    const ProgramHeader = ProgramHeaderT();

    pub const Header = packed struct {
        ident: Ident,
        typ: u16,
        machine: u16,
        version: u32,
        entry: usize,
        poff: usize,
        soff: usize,
        flags: u32,
        size: u16,
        psize: u16,
        pnum: u16,
        ssize: u16,
        snum: u16,
        sstri: u16,

        const Ident = packed struct {
            magic: u32,
            class: u8,
            data: u8,
            version: u8,
            os_abi: u8,
            abi_version: u8,
            pad1: u8,
            pad2: u8,
            pad3: u8,
            pad4: u8,
            pad5: u8,
            pad6: u8,
            pad7: u8,
        };
    };

    fn ProgramHeaderT() type {
        if (@sizeOf(usize) == 8) {
            return packed struct {
                typ: u32,
                flags: u32,
                offset: usize,
                vaddr: usize,
                paddr: usize,
                file_size: usize,
                mem_size: usize,
                alignment: usize,
            };
        } else {
            return packed struct {
                typ: u32,
                offset: usize,
                vaddr: usize,
                paddr: usize,
                file_size: usize,
                mem_size: usize,
                flags: u32,
                alignment: usize,
            };
        }
    }

    const SectionHeader = struct {
        name: u32,
        typ: u32,
        flags: usize,
        addr: usize,
        offset: usize,
        size: usize,
        link: u32,
        info: u32,
        addr_align: usize,
        entry_size: usize,

        pub fn fromBytes(bytes: []u8) SectionHeader {
            const header = std.mem.bytesToValue(SectionHeader, bytes);
            return header;
        }
    };

    pub fn fromBytes(bytes: []u8, allocator: std.mem.Allocator) !Elf {
        var self: Elf = undefined;

        self.header = std.mem.bytesToValue(Header, bytes);

        const program_header_offset = self.header.poff;
        const program_header_count = self.header.pnum;
        const program_header_size = self.header.psize;

        self.program_headers = try allocator.alloc(ProgramHeader, program_header_count);

        for (0..program_header_count) |i| {
            const offset = program_header_offset + program_header_size * i;
            self.program_headers[i] = std.mem.bytesToValue(ProgramHeader, bytes[offset..]);
        }

        const section_header_offset = self.header.soff;
        const section_header_count = self.header.snum;
        const section_header_size = self.header.size;

        self.section_headers = try allocator.alloc(SectionHeader, section_header_count);

        for (0..section_header_count) |i| {
            const offset = section_header_offset + i * section_header_size;
            self.section_headers[i] = std.mem.bytesToValue(SectionHeader, bytes[offset..]);
        }

        return self;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
    const allocator = gpa.allocator();
    const file = try std.fs.cwd().openFile("zig-out/bin/elf.elf", .{});
    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);

    const elf = try Elf.fromBytes(content, allocator);

    std.debug.print("HEADER: {any}\n", .{elf.section_headers});
}

const std = @import("std");
