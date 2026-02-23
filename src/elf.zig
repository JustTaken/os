pub const Elf = struct {
    header: Header,
    program_headers: []ProgramHeader.T,
    //section_headers: []SectionHeader,
    bytes: []const u8,

    pub const ProgramHeader = struct {
        pub const Type = enum(u32) {
            nil = 0x0,
            load = 0x1,
            dynamic = 0x2,
            interp = 0x3,
            note = 0x4,
            shlib = 0x5,
            phdr = 0x6,
            tls = 0x7,
            loos = 0x60000000,
            hios = 0x6FFFFFFF,
            loproc = 0x70000000,
            hiproc = 0x7FFFFFFF,
            _,
        };

        pub const Flag = packed struct(u32) {
            x: bool,
            w: bool,
            r: bool,
            _: u29,
        };

        pub const T = ProgramHeaderT();
    };

    pub const Header = packed struct {
        ident: Ident,
        typ: Type,
        machine: Machine,
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
            class: Class,
            data: Endianess,
            version: u8,
            os_abi: Abi,
            abi_version: u8,
            pad1: u8,
            pad2: u8,
            pad3: u8,
            pad4: u8,
            pad5: u8,
            pad6: u8,
            pad7: u8,
        };

        const Endianess = enum(u8) {
            little = 0x1,
            big = 0x2,
            _,
        };

        const Class = enum(u8) {
            u64 = 0x1,
            u32 = 0x2,
            _,
        };

        const Type = enum(u16) {
            none = 0x0,
            rel = 0x1,
            exec = 0x2,
            dyn = 0x3,
            core = 0x4,
            loos = 0xFE00,
            hios = 0xFEFF,
            loproc = 0xFF00,
            hiproc = 0xFFFF,
            _,
        };

        const Machine = enum(u16) {
            non = 0x00,
            at_t_we_32100 = 0x01,
            sparc = 0x02,
            x86 = 0x03,
            motorola_68000 = 0x04,
            motorola_88000 = 0x05,
            intel_mcu = 0x06,
            intel_80860 = 0x07,
            mips = 0x08,
            ibm_system = 0x09,
            mips_rs3000 = 0x0A,
            hewlett_packard = 0x0F,
            intel_80960 = 0x13,
            powerpc = 0x14,
            powerpc_64 = 0x15,
            s390 = 0x16,
            ibm_spu_spc = 0x17,
            nec_v800 = 0x24,
            fujitsu = 0x25,
            trw = 0x26,
            motorola_rce = 0x27,
            arm = 0x28,
            digital_alpha = 0x29,
            superh = 0x2A,
            spartc_9 = 0x2B,
            siemens = 0x2C,
            argonaut = 0x2D,
            hitachi_h8_300 = 0x2E,
            hitachi_h8_300h = 0x2F,
            hitachi_h8s = 0x30,
            hitachi_h8_500 = 0x31,
            ia_64 = 0x32,
            stanford_mips_x = 0x33,
            motorola_coldfire = 0x34,
            motorola_m68hc12 = 0x35,
            fujitsu_mma = 0x36,
            siemens_pcp = 0x37,
            sony_risc = 0x38,
            denso_ndr1 = 0x39,
            motorola_start_core = 0x3A,
            toyota_me16 = 0x3B,
            stm_st100 = 0x3C,
            advanced_logic_corp_tinyj = 0x3D,
            amd_x86_64 = 0x3E,
            sony_dps = 0x3F,
            pdp_10 = 0x40,
            pdp_11 = 0x41,
            siemens_fx66 = 0x42,
            stm_st9 = 0x43,
            stm_st7 = 0x44,
            motorola_mc68hc16 = 0x45,
            motorola_mc68hc11 = 0x46,
            motorola_mc68hc08 = 0x47,
            motorola_mc68hc05 = 0x48,
            silicon_graphics_svx = 0x49,
            stm_st19 = 0x4A,
            digital_vax = 0x4B,
            axis_communications = 0x4C,
            infineon = 0x4D,
            element = 0x4E,
            lsi_logic = 0x4F,
            tms320c6000 = 0x8C,
            mcst = 0xAF,
            arm_64 = 0xB7,
            zilog_z80 = 0xDC,
            riscv = 0xF3,
            berkeley_packet = 0xF7,
            wdc_65c816 = 0x101,
            loong_arch = 0x102,
            _,
        };

        const Abi = enum(u8) {
            system_v = 0x0,
            hp_ux = 0x1,
            net_bsd = 0x2,
            linux = 0x3,
            gnu_hurd = 0x4,
            solaris = 0x6,
            aix = 0x7,
            irix = 0x8,
            free_bsd = 0x9,
            tru_64 = 0xA,
            novell_modesto = 0xB,
            open_bsd = 0xC,
            open_vms = 0xD,
            non_stop_kernel = 0xE,
            aros = 0xF,
            fenix_os = 0x10,
            nuxi_clound_abi = 0x11,
            stratus_technologies_open_vos = 0x12,
            _,
        };
    };

    pub fn ProgramHeaderT() type {
        if (@sizeOf(usize) == 8) {
            return packed struct {
                typ: ProgramHeader.Type,
                flags: ProgramHeader.Flag,
                offset: usize,
                vaddr: usize,
                paddr: usize,
                file_size: usize,
                mem_size: usize,
                alignment: usize,
            };
        } else {
            return packed struct {
                typ: ProgramHeader.Type,
                offset: usize,
                vaddr: usize,
                paddr: usize,
                file_size: usize,
                mem_size: usize,
                flags: ProgramHeader.Flag,
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

        const Type = enum(u32) {
            nil = 0x0,
            progbits = 0x1,
            symtab = 0x2,
            strtab = 0x3,
            rela = 0x4,
            hash = 0x5,
            dynamic = 0x6,
            note = 0x7,
            nobits = 0x8,
            rel = 0x9,
            shlib = 0xA,
            dynsym = 0xB,
            init_array = 0xE,
            fini_array = 0xF,
            preinit_array = 0x10,
            group = 0x11,
            symtab_shndx = 0x12,
            num = 0x13,
            loos = 0x60000000,
        };
    };

    pub fn fromBytes(bytes: []const u8, allocator: std.mem.Allocator) !Elf {
        var self: Elf = undefined;

        self.bytes = bytes;
        self.header = std.mem.bytesToValue(Header, bytes);

        const magic = 0x464C457F; // This is for little endian
        if (magic != self.header.ident.magic) return error.MagicNumber;

        const program_header_offset = self.header.poff;
        const program_header_count = self.header.pnum;
        const program_header_size = self.header.psize;

        self.program_headers = try allocator.alloc(ProgramHeader.T, program_header_count);

        //var total_offset: usize = 0;
        //var last_size: usize = 0;
        for (0..program_header_count) |i| {
            const offset = program_header_offset + program_header_size * i;
            self.program_headers[i] = std.mem.bytesToValue(ProgramHeader.T, bytes[offset..]);

            //if (self.program_headers[i].offset > offset) {
            //    total_offset = self.program_headers[i].offset;
            //    last_size = self.program_headers[i].mem_size;

            //    if (self.program_headers[i].mem_size != self.program_headers[i].file_size) return error.SizeMissmatch;
            //}
        }

        //const start_offset = self.program_headers[0].offset;
        //const total_size = total_offset + last_size - start_offset;

        //self.load_bytes = bytes[start_offset..start_offset + total_size];

        //const section_header_offset = self.header.soff;
        //const section_header_count = self.header.snum;
        //const section_header_size = self.header.size;

        //self.section_headers = try allocator.alloc(SectionHeader, section_header_count);

        //for (0..section_header_count) |i| {
        //    const offset = section_header_offset + i * section_header_size;
        //    //common.print("OFFSET: {d} end: {d}\n", .{offset, bytes.len}) catch @panic("PRINT");
        //    self.section_headers[i] = std.mem.bytesToValue(SectionHeader, bytes[offset..]);
        //}

        return self;
    }
};

//fn _main() !void {
//    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
//    const allocator = gpa.allocator();
//    const file = try std.fs.cwd().openFile("zig-out/bin/elf.elf", .{});
//    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
//
//    const elf = try Elf.fromBytes(content, allocator);
//    _ = elf;
//
//    //std.debug.print("HEADER: {any}\n", .{elf.header});
//}
//
//pub export fn main() void {
//    comptime std.options.page_size_max = 4096;
//
//    _main() catch {
//    };
//}

const common = @import("common.zig");
const std = @import("std");
