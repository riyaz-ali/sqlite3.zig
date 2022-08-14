//! This module provides a Zig wrapper over sqlite3.
//!
//! It exports handy types and low-level utilities that makes
//! it easy to work with sqlite3 in zig rather than using it via ffi.
//! 
//! The Module's API is modelled after native sqlite3 API and doesn't provide
//! any single 'opinionated' way.

const std = @import("std");
const c = @import("c.zig").c;

const errors = @import("errors.zig");

/// Version returns the sqlite3 library version
pub fn version() i32 {
    return @as(i32, c.sqlite3_libversion_number());
}

// OpenFlags represents flags to pass to open() method.
pub const OpenFlags = struct { ReadWrite: bool = false, Create: bool = false, OpenWal: bool = false };

/// Open opens a new database connection using sqlite3_open_v2 api.
pub fn open(path: [:0]const u8, opts: OpenFlags) errors.Error!*Database {
    var flags: c_int = c.SQLITE_OPEN_URI;
    flags |= @as(c_int, if (opts.ReadWrite) c.SQLITE_OPEN_READWRITE else c.SQLITE_OPEN_READONLY);

    if (opts.Create) {
        flags |= c.SQLITE_OPEN_CREATE;
    }

    if (opts.OpenWal) {
        flags |= c.SQLITE_OPEN_WAL;
    }

    var db: ?*c.sqlite3 = undefined;
    const result = c.sqlite3_open_v2(path, &db, flags, null);
    if (result != c.SQLITE_OK or db == null) {
        return errors.from(result); // failed to open database
    }

    return @ptrCast(*Database, db.?);
}

/// Database is an opaque handle to an open sqlite3 database.
pub const Database = opaque {
    const Self = @This();

    /// Close closes the current database connection,
    /// freeing up any allocated resources.
    pub fn close(self: *Self) errors.Error!void {
        const conn = @ptrCast(*c.sqlite3, self);
        const ret = c.sqlite3_close(conn);
        if (ret != c.SQLITE_OK) {
            return errors.from(ret);
        }
    }

    /// GetAutoCommit returns true if the given database connection is in autocommit mode. 
    /// Autocommit mode is on by default, but gets disabled by a BEGIN statement. It is re-enabled by a COMMIT or ROLLBACK.
    /// Therefore, autocommit can be used to detect whether the connection is in a transaction or not.
    pub fn getAutoCommit(self: *Self) bool {
        const conn = @ptrCast(*c.sqlite3, self);
        return c.sqlite3_get_autocommit(conn) != 0;
    }

    // LastInsertRowid reports the rowid of the most recently successful INSERT.
    pub fn lastInsertRowid(self: *Self) i64 {
        const conn = @ptrCast(*c.sqlite3, self);
        return @as(i64, c.sqlite3_last_insert_rowid(conn));
    }

    /// LastError returns text message that describes the error.
    ///
    /// Memory to hold the error message string is managed internally. 
    /// The application does not need to worry about freeing the result. 
    /// However, the error string might be overwritten or deallocated by subsequent calls to other SQLite interface functions.
    pub fn lastError(self: *Self) [:0]const u8 {
        const conn = @ptrCast(*c.sqlite3, self);
        return std.mem.sliceTo(c.sqlite3_errmsg(conn), 0);
    }

    /// Prepare prepares the given string query and converts it into a prepared statement.
    /// See: https://www.sqlite.org/c3ref/prepare.html for details.
    pub fn prepare(self: *Self, query: []const u8) errors.Error!*Statement {
        const conn = @ptrCast(*c.sqlite3, self);

        var s: ?*c.sqlite3_stmt = undefined;
        const ret = c.sqlite3_prepare_v2(conn, query.ptr, @intCast(c_int, query.len), &s, null);
        if (ret != c.SQLITE_OK) {
            return errors.from(ret);
        }

        return @ptrCast(*Statement, s.?);
    }
};

// BindParam union is used to select between positional and named parameters while binding
// arguments to the prepared statement.
pub const BindParam = union(enum) { Named: [:0]const u8, Index: usize };

/// Statement is an opaque handle to an open sqlite3 prepared statement
pub const Statement = opaque {
    const Self = @This();

    /// Step moves through the statement cursor using sqlite3_step.
    /// If a row of data is available then it returns true, else false.
    /// 
    /// Any other errors are reported as appropriate error value.
    pub fn step(self: *Self) errors.Error!bool {
        const stmt = @ptrCast(*c.sqlite3_stmt, self);
        const ret = c.sqlite3_step(stmt);
        if (ret != c.SQLITE_ROW and ret != c.SQLITE_DONE) {
            return errors.from(ret);
        }

        return ret == c.SQLITE_ROW;
    }

    /// Reset resets a prepared statement so it can be executed again.
    /// Any parameter values bound to the statement are retained.
    pub fn reset(self: *Self) errors.Error!void {
        const stmt = @ptrCast(*c.sqlite3_stmt, self);
        const ret = c.sqlite3_reset(stmt);
        if (ret != c.SQLITE_OK) {
            return errors.from(ret);
        }
    }

    /// ClearBindings clears all bound parameter values on a statement.
    pub fn clearBindings(self: *Self) void {
        const stmt = @ptrCast(*c.sqlite3_stmt, self);
        _ = c.sqlite3_clear_bindings(stmt);
    }

    /// Finalize deletes a prepared statement.
    /// It returns an error if the most recent evaluation of the statement encountered
    /// some error, else it does not return any value.
    ///
    /// This routine can be called at any point during the life cycle of prepared statement.
    /// The application must finalize every prepared statement in order to avoid resource leaks.
    pub fn finalize(self: *Self) errors.Error!void {
        const stmt = @ptrCast(*c.sqlite3_stmt, self);
        const ret = c.sqlite3_finalize(stmt);
        if (ret != c.SQLITE_OK) {
            return errors.from(ret);
        }
    }

    /// Database returns the database connection handle to which a prepared statement belongs
    pub fn database(self: *Self) *Database {
        const stmt = @ptrCast(*c.sqlite3_stmt, self);
        const db: *c.sqlite3 = c.sqlite3_db_handle(stmt);
        return @ptrCast(*Database, db);
    }

    /// BindParamCount reports the number of parameters in stmt.
    pub fn bindParamCount(self: *Self) i32 {
        const stmt = @ptrCast(*c.sqlite3_stmt, self);
        return @as(i32, c.sqlite3_bind_parameter_count(stmt));
    }

    /// Bind binds the given value at the specified index or named parameter.
    ///
    /// Value of type []u8 is bound as text. Use Blob to bind as byte slices.
    pub fn bind(self: *Self, param: BindParam, value: anytype) errors.Error!void {
        const stmt = @ptrCast(*c.sqlite3_stmt, self);
        const Type = @TypeOf(value);

        const pos = switch (param) {
            .Index => |i| blk: {
                break :blk @intCast(c_int, i);
            },
            .Named => |name| blk: {
                break :blk @intCast(c_int, c.sqlite3_bind_parameter_index(stmt, name));
            },
        };

        var ret: i32 = 0;
        switch (@typeInfo(Type)) {
            .Int, .ComptimeInt => {
                ret = c.sqlite3_bind_int64(stmt, pos, @intCast(c_longlong, value));
            },

            .Float, .ComptimeFloat => {
                ret = c.sqlite3_bind_double(stmt, pos, value);
            },

            .Bool => {
                ret = c.sqlite3_bind_int64(stmt, pos, @boolToInt(value));
            },

            .Pointer => |ptr| switch (ptr.size) {
                .Slice => switch (ptr.child) {
                    u8 => {
                        ret = c.sqlite3_bind_text(stmt, pos, value.ptr, @intCast(c_int, value.len), null);
                    },
                    else => @compileError("unsupported slice type:" ++ @typeName(ptr.child)),
                },
                else => @compileError("unsupported pointer type:" ++ @typeName(Type)),
            },

            .Null => {
                ret = c.sqlite3_bind_null(stmt, pos);
            },

            else => @compileError("unsupported type:" ++ @typeName(Type)),
        }

        if (ret != c.SQLITE_OK) {
            return errors.from(ret);
        }
    }

    /// ColumnCount returns the number of columns in the result set 
    /// returned by the prepared statement.
    pub fn columnCount(self: *Self) i32 {
        const stmt = @ptrCast(*c.sqlite3_stmt, self);
        return @as(i32, c.sqlite3_column_count(stmt));
    }

    /// Get returns the value at the given column, interpreted as the provided type.
    ///
    /// It doesn't perform any allocation. Values of type text / blob references
    /// the underlying C-managed memory directly, that stops being valid as soon as 
    /// the statement row resets.
    pub fn get(self: *Self, comptime T: type, col: usize) T {
        const stmt = @ptrCast(*c.sqlite3_stmt, self);

        switch (@typeInfo(T)) {
            .Int => {
                const n = c.sqlite3_column_int64(stmt, @intCast(c_int, col));
                return @intCast(T, n);
            },

            .Float => {
                const n = c.sqlite3_column_double(stmt, @intCast(c_int, col));
                return @floatCast(T, n);
            },

            .Bool => {
                const n = c.sqlite3_column_int64(stmt, @intCast(c_int, col));
                return n > 0;
            },

            .Pointer => |ptr| switch (ptr.size) {
                .Slice => switch (ptr.child) {
                    u8 => {
                        if (comptime !ptr.is_const) {
                            @compileError("buffer must be a constant type");
                        }

                        const size = @intCast(usize, c.sqlite3_column_bytes(stmt, @intCast(c_int, col)));
                        const data = c.sqlite3_column_text(stmt, @intCast(c_int, col));
                        if (data != null) {
                            return @ptrCast([*]const u8, data)[0..size];
                        }

                        return @as([]const u8, "");
                    },

                    else => @compileError("unsupported slice type:" ++ @typeName(ptr.child)),
                },

                else => @compileError("unsupported pointer type:" ++ @typeName(T)),
            },

            else => @compileError("unsupported type:" ++ @typeName(T)),
        }
    }
};

/// ZeroBlob is a blob with a fixed length containing only zeroes.
///
/// A ZeroBlob is intended to serve as a placeholder; content can later be written with incremental i/o.
/// See "zeroblob" on https://sqlite.org/c3ref/blob_open.html for more details.
pub const ZeroBlob = struct { len: usize };
