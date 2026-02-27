pub const Tar = struct {
    pub const Header = extern struct {
        name: [100]u8,
        mode: [8]u8,
        uid: [8]u8,
        gid: [8]u8,
        size: [12]u8,
        mtime: [12]u8,
        checksum: [8]u8,
        typ: u8,
        linkname: [100]u8,
        magic: [6]u8,
        version: [2]u8,
        uname: [32]u8,
        gname: [32]u8,
        devmajor: [8]u8,
        devminor: [8]u8,
        prefix: [155]u8,
        padding: [12]u8,
        data: u8,

        pub fn dataPtr(self: *Header) [*]u8 {
            return @ptrCast(&self.data);
        }
    };
};
