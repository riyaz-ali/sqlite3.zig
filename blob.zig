//! Module provides support for Incremental Blob I/O
const c = @import("c.zig").c;

const sqlite3 = @import("sqlite3.zig");
const errors = @import("errors.zig");

/// Blob is a slice of bytes treated as an opaque array,
/// whose structure is interpreted or enforced in any ways.
pub const Blob = []const u8;

/// ZeroBlob is a blob with a fixed length containing only zeroes.
///
/// A ZeroBlob is intended to serve as a placeholder; content can later be written with incremental i/o.
/// See "zeroblob" on https://sqlite.org/c3ref/blob_open.html for more details.
pub const ZeroBlob = struct { len: u64 };

/// ReadWriter is an interface to sqlite3's Incremental Blob I/O
/// 
/// In practice, it's a reference to sqlite3_blob object.
pub const ReadWriter = opaque {
    const Self = @This();

    /// Close closes this blob object.
    /// The handle is closed unconditionally, ie. even if this routine returns an error code, the handle is still closed.
    pub fn close(self: *Self) !void {
        const blob = @ptrCast(*c.sqlite3_blob, self);
        const ret = c.sqlite3_blob_close(blob);
        if (ret != c.SQLITE_OK) {
            return errors.from(ret);
        }
    }

    /// Len returns the size in bytes of the blob object.
    pub fn len(self: *Self) usize {
        const blob = @ptrCast(*c.sqlite3_blob, self);
        return @intCast(usize, c.sqlite3_blob_bytes(blob));
    }

    /// Read reads from the blob at the given offset into the provided buffer.
    /// It returns the number of bytes read.
    pub fn read(self: *Self, offset: usize, buffer: []u8) errors.Error!usize {
        const blob = @ptrCast(*c.sqlite3_blob, self);
        if (offset >= self.len()) {
            return 0;
        }

        var tmp = blk: {
            const remaining = self.len() - offset;
            break :blk if (buffer.len > remaining) buffer[0..remaining] else buffer;
        };

        const ret = c.sqlite3_blob_read(blob, tmp.ptr, @intCast(c_int, tmp.len), @intCast(c_int, offset));
        if (ret != c.SQLITE_OK) {
            return errors.from(ret);
        }

        return tmp.len;
    }

    /// Write writes to the blob at the given offset from the provided buffer.
    /// It returns the number of bytes written.
    pub fn write(self: *Self, offset: usize, data: []const u8) errors.Error!usize {
        const blob = @ptrCast(*c.sqlite3_blob, self);
        const ret = c.sqlite3_blob_write(blob, data.ptr, @intCast(c_int, data.len), @intCast(c_int, offset));
        if (ret != c.SQLITE_OK) {
            return errors.from(ret);
        }
        return data.len;
    }
};
