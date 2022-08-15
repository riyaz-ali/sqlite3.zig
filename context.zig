//! This module defines wrapper around sqlite3_context and sqlite3_value type.
const c = @import("c.zig").c;
const sqlite3 = @import("sqlite3.zig");

/// Context represents a handle to *C.struct_sqlite3_context.
/// It is used by custom functions to return result values.
pub const Context = opaque {
    const Self = @This();

    /// Result sets the result value for the context.
    /// See: https://www.sqlite.org/c3ref/result_blob.html
    pub fn result(self: *Self, value: anytype) void {
        const T = @TypeOf(value);
        const ctx = @ptrCast(*c.sqlite3_context, self);

        _ = switch (T) {
            *Value => c.sqlite3_result_value(ctx, @ptrCast(*c.sqlite3_value, value)),
            sqlite3.ZeroBlob => c.sqlite3_result_zeroblob64(ctx, @intCast(c.sqlite3_uint64, value.len)),
            else => switch (@typeInfo(T)) {
                .Int => |info| if ((info.bits + if (info.signedness == .unsigned) 1 else 0) <= 32) {
                    c.sqlite3_result_int(ctx, value);
                } else if ((info.bits + if (info.signedness == .unsigned) 1 else 0) <= 64) {
                    c.sqlite3_result_int64(ctx, value);
                } else {
                    @compileError("integer " ++ @typeName(T) ++ " is not representable in sqlite");
                },

                .Float => c.sqlite3_result_double(ctx, value),
                .Bool => c.sqlite3_result_int(ctx, if (value) 1 else 0),
                .Null => c.sqlite3_result_null(ctx),
                .Pointer => |ptr| switch (ptr.size) {
                    .Slice => switch (ptr.child) {
                        u8 => c.sqlite3_result_text(ctx, value.ptr, @intCast(c_int, value.len), c.SQLITE_TRANSIENT),
                        else => @compileError("unsupported slice type: " ++ @typeName(ptr.child)),
                    },
                    else => @compileError("unsupported pointer type: " ++ @typeName(T)),
                },
                else => @compileError("unsupported type: " ++ @typeName(T)),
            },
        };
    }

    /// SubType function causes the subtype of the result to be the given value.
    /// Only the lower 8 bits of the subtype T are preserved in current versions of SQLite; higher order bits are discarded.
    /// See: https://www.sqlite.org/c3ref/result_subtype.html
    pub fn subType(self: *Self, value: usize) void {
        const ctx = @ptrCast(*c.sqlite3_context, self);
        c.sqlite3_result_subtype(ctx, @intCast(c_uint, value));
    }

    /// Data allocates and returns a pointer to T.
    /// Implementations of aggregate functions use this routine to allocate memory for storing their state.
    ///
    /// The first time it's called for a particular aggregate function, SQLite allocates @sizeOf(T) bytes of memory, zeroes out that memory, 
    /// and returns a pointer to the new memory. On subsequent invocations for the same aggregate function instance, the same buffer is returned.
    ///
    /// Calling this routine outside of an aggregate function will lead to segmentation faults at runtime.
    pub fn data(self: *Self, comptime T: type) *T {
        const ctx = @ptrCast(*c.sqlite3_context, self);
        return @ptrCast(*T, @alignCast(@alignOf(T), c.sqlite3_aggregate_context(ctx, @sizeOf(T))));
    }
};

/// Value represents a handle to *C.sqlite3_value.
/// Value represent all values that can be stored in a database table.
/// It is used to extract column values from sql queries.
pub const Value = opaque {
    const Self = @This();

    /// Get returns the value associated with this sqlite3_value object, interpreted as T.
    ///
    /// It doesn't perform any allocation. Values of type text / blob references
    /// the underlying C-managed memory directly, that stops being valid as soon as 
    /// the function call returns.
    pub fn get(self: *Self, comptime T: type) T {
        const value = @ptrCast(*c.sqlite3_value, self);

        switch (@typeInfo(T)) {
            .Int => |info| if ((info.bits + if (info.signedness == .unsigned) 1 else 0) <= 32) {
                return @intCast(T, c.sqlite3_value_int(value));
            } else if ((info.bits + if (info.signedness == .unsigned) 1 else 0) <= 64) {
                return @intCast(T, c.sqlite3_value_int64(value));
            } else {
                @compileError("integer " ++ @typeName(T) ++ " is not representable in sqlite");
            },

            .Float => return @floatCast(T, c.sqlite3_value_double(value)),
            .Bool => return @intCast(i32, c.sqlite3_value_int(value)) > 0,
            .Pointer => |ptr| switch (ptr.size) {
                .Slice => switch (ptr.child) {
                    u8 => {
                        if (comptime !ptr.is_const) {
                            @compileError("buffer must be a constant type");
                        }

                        const size = @intCast(usize, c.sqlite3_value_bytes(value));
                        const bytes = c.sqlite3_value_text(value);
                        if (bytes != null) {
                            return @ptrCast([*]const u8, bytes)[0..size];
                        }

                        return @as([]const u8, "");
                    },
                    else => @compileError("unsupported slice type:" ++ @typeName(ptr.child)),
                },
                else => @compileError("unsupported pointer type:" ++ @typeName(T)),
            },
            else => @compileError("unsupported type: " ++ @typeName(T)),
        }
    }

    /// Datatype returns the datatype affinity for the initial value of the object.
    pub fn datatype(self: *Self) ColumnType {
        const value = @ptrCast(*c.sqlite3_value, self);
        return @intToEnum(ColumnType, c.sqlite3_value_type(value));
    }

    /// SubType returns the subtype for the value object. 
    /// The subtype information can be used to pass a limited amount of context from one function to another.
    pub fn subType(self: *Self) usize {
        const value = @ptrCast(*c.sqlite3_value, self);
        return @intCast(usize, c.sqlite3_value_subtype(value));
    }
};

/// ColumnType are codes for each of the SQLite fundamental data types:
/// https://www.sqlite.org/c3ref/c_blob.html
pub const ColumnType = enum(u8) {
    SQLITE_INTEGER = c.SQLITE_INTEGER,
    SQLITE_FLOAT = c.SQLITE_FLOAT,
    SQLITE_TEXT = c.SQLITE3_TEXT,
    SQLITE_BLOB = c.SQLITE_BLOB,
    SQLITE_NULL = c.SQLITE_NULL,
};
