//! Module provides support for Incremental Blob I/O

const sqlite3 = @import("sqlite3.zig");

/// Blob is a slice of bytes treated as an opaque array,
/// whose structure is interpreted or enforced in any ways.
pub const Blob = []const u8;

/// ZeroBlob is a blob with a fixed length containing only zeroes.
///
/// A ZeroBlob is intended to serve as a placeholder; content can later be written with incremental i/o.
/// See "zeroblob" on https://sqlite.org/c3ref/blob_open.html for more details.
pub const ZeroBlob = struct { len: u64 };
