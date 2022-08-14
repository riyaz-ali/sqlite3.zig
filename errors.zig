const sqlite3 = @import("sqlite3.zig");

/// Error is a superset containing all possible error
/// values that sqlite might return.
pub const Error = error{SQLITE_ERROR};

/// From returns the corresponding error value
/// for the given result code.
pub fn from(code: c_int) Error {
    // TODO(@riyaz): use code to return actual sub-class of error rather
    //               than a generic catch-all error.
    _ = code;
    return Error.SQLITE_ERROR;
}
