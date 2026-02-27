pub const FileSystem = struct {
    files: [FILE_COUNT]File,
    disk: [SIZE]u8,

    const FILE_COUNT: usize = 2;
    const SIZE: usize = std.mem.alignForward(usize, @sizeOf(File) * FILE_COUNT, common.SECTOR_SIZE);

    pub const File = struct {
        in_use: bool,
        name: [100]u8,
        data: [1024]u8,
        size: usize,
    };

    pub fn init(block: *virtio.Virtio.Block) !FileSystem {
        var self: FileSystem = undefined;

        for (0..SIZE / common.SECTOR_SIZE) |sector| {
            try block.diskOp(self.disk[sector * common.SECTOR_SIZE..], sector, .read);
        }

        var offset: usize = 0;

        for (0..FILE_COUNT) |i| {
            const header: *tar.Tar.Header = @ptrCast(@alignCast(&self.disk[offset]));

            if (header.name[0] == 0) break;
            if (!std.mem.eql(u8, header.magic[0..5], "ustar")) return error.Magic;

            const file_size = std.fmt.parseInt(usize, header.size[0..11], 8) catch return error.ParseInt;
            const file = &self.files[i];

            const header_data = header.dataPtr();
            @memcpy(file.name[0..100], header.name[0..100]);
            @memcpy(file.data[0..file_size], header_data[0..file_size]);

            file.size = file_size;
            file.in_use = true;

            offset += std.mem.alignForward(usize, @sizeOf(tar.Tar.Header) + file_size, common.SECTOR_SIZE);
        }

        return self;
    }

    pub fn flush(self: *FileSystem, block: *virtio.Virtio.Block) void {
        @memset(self.disk[0..SIZE], 0);
        var offset: usize = 0;

        for (0..FILE_COUNT) |i| {
            const file = &self.files[i];

            if (!file.in_use) continue;

            const header: *tar.Tar.Header = @ptrCast(@alignCast(&self.disk[offset]));
            @memset(std.mem.asBytes(header), 0);

            const mode = "000644";
            const magic = "ustar";
            const version = "00";

            @memcpy(header.name[0..100], file.name[0..100]);
            @memcpy(header.mode[0..6], mode);
            @memcpy(header.magic[0..5], magic);
            @memcpy(header.version[0..2], version);

            header.typ = '0';

            const header_size_size: usize = 12;
            var file_size = file.size;

            for (0..header_size_size) |k| {
                header.size[header_size_size - k - 1] = @intCast((file_size % 8) + '0');
                file_size /= 8;
            }

            const check_sum_size: usize = 8;
            var checksum: usize = ' ' * check_sum_size;

            for (0..@sizeOf(tar.Tar.Header)) |k| {
                checksum += self.disk[offset + k];
            }

            for (0..5) |k| {
                header.checksum[check_sum_size - k - 1] = @intCast((checksum % 8) + '0');
                checksum /= 8;
            }

            const header_data = header.dataPtr();
            @memcpy(header_data[0..file.size], file.data[0..file.size]);

            offset += std.mem.alignForward(usize, @sizeOf(tar.Tar.Header) + file.size, common.SECTOR_SIZE);
        }

        for (0..SIZE / common.SECTOR_SIZE) |sector| {
            block.diskOp(self.disk[sector * common.SECTOR_SIZE..], sector, .write) catch return;
        }

        //common.print("JUST FLUSHED THE FILE SYSTEM\n", .{}) catch @panic("PRINT");
    }

    pub fn lookup(self: *FileSystem, name: []const u8) ?*File {
        if (name.len >= 100) return null;

        for (0..FILE_COUNT) |i| {
            const file = &self.files[i];

            if (std.mem.eql(file.name[0..name.len], name)) {
                return file;
            }
        }

        return null;
    }
};

const tar = @import("tar.zig");
const virtio = @import("virtio.zig");
const common = @import("common.zig");
const std = @import("std");
