const std = @import("std");

const c = @import("c.zig").c;
const sqlite3 = @import("sqlite3.zig");

/// PrimaryError is a subset of primary error codes that sqlite returns by default.
/// See: https://www.sqlite.org/rescode.html for more details.
pub const PrimaryError = error{
    SQLITE_OK,
    SQLITE_ROW, // do not use in Error
    SQLITE_DONE, // do not use in Error
    SQLITE_ERROR,
    SQLITE_INTERNAL,
    SQLITE_PERM,
    SQLITE_ABORT,
    SQLITE_BUSY,
    SQLITE_LOCKED,
    SQLITE_NOMEM,
    SQLITE_READONLY,
    SQLITE_INTERRUPT,
    SQLITE_IOERR,
    SQLITE_CORRUPT,
    SQLITE_NOTFOUND,
    SQLITE_FULL,
    SQLITE_CANTOPEN,
    SQLITE_PROTOCOL,
    SQLITE_EMPTY,
    SQLITE_SCHEMA,
    SQLITE_TOOBIG,
    SQLITE_CONSTRAINT,
    SQLITE_MISMATCH,
    SQLITE_MISUSE,
    SQLITE_NOLFS,
    SQLITE_AUTH,
    SQLITE_FORMAT,
    SQLITE_RANGE,
    SQLITE_NOTADB,
    SQLITE_NOTICE,
    SQLITE_WARNING,
};

/// Error is a superset containing all possible error
/// values that sqlite might return.
pub const Error = PrimaryError;

/// From returns the corresponding error value
/// for the given result code.
pub fn from(code: c_int) Error {
    switch (code) {
        c.SQLITE_OK => return Error.SQLITE_OK,
        c.SQLITE_ROW => return Error.SQLITE_ROW,
        c.SQLITE_DONE => return Error.SQLITE_DONE,
        c.SQLITE_ERROR => return Error.SQLITE_ERROR,
        c.SQLITE_INTERNAL => return Error.SQLITE_INTERNAL,
        c.SQLITE_PERM => return Error.SQLITE_PERM,
        c.SQLITE_ABORT => return Error.SQLITE_ABORT,
        c.SQLITE_BUSY => return Error.SQLITE_BUSY,
        c.SQLITE_LOCKED => return Error.SQLITE_LOCKED,
        c.SQLITE_NOMEM => return Error.SQLITE_NOMEM,
        c.SQLITE_READONLY => return Error.SQLITE_READONLY,
        c.SQLITE_INTERRUPT => return Error.SQLITE_INTERRUPT,
        c.SQLITE_IOERR => return Error.SQLITE_IOERR,
        c.SQLITE_CORRUPT => return Error.SQLITE_CORRUPT,
        c.SQLITE_NOTFOUND => return Error.SQLITE_NOTFOUND,
        c.SQLITE_FULL => return Error.SQLITE_FULL,
        c.SQLITE_CANTOPEN => return Error.SQLITE_CANTOPEN,
        c.SQLITE_PROTOCOL => return Error.SQLITE_PROTOCOL,
        c.SQLITE_EMPTY => return Error.SQLITE_EMPTY,
        c.SQLITE_SCHEMA => return Error.SQLITE_SCHEMA,
        c.SQLITE_TOOBIG => return Error.SQLITE_TOOBIG,
        c.SQLITE_CONSTRAINT => return Error.SQLITE_CONSTRAINT,
        c.SQLITE_MISMATCH => return Error.SQLITE_MISMATCH,
        c.SQLITE_MISUSE => return Error.SQLITE_MISUSE,
        c.SQLITE_NOLFS => return Error.SQLITE_NOLFS,
        c.SQLITE_AUTH => return Error.SQLITE_AUTH,
        c.SQLITE_FORMAT => return Error.SQLITE_FORMAT,
        c.SQLITE_RANGE => return Error.SQLITE_RANGE,
        c.SQLITE_NOTADB => return Error.SQLITE_NOTADB,
        c.SQLITE_NOTICE => return Error.SQLITE_NOTICE,
        c.SQLITE_WARNING => return Error.SQLITE_WARNING,

        else => std.debug.panic("unknown code {d}", .{code}),
    }
}
