//! This module provides routines that enable
//! user to register custom functions that can be
//! invoked from within sqlite3, as custom sql functions.

const std = @import("std");
const assert = std.debug.assert;

const errors = @import("errors.zig");
const sqlite3 = @import("sqlite3.zig");
const c = @import("c.zig").c;

pub const FuncOptions = struct {
    /// Name of the function to register with sqlite3
    Name: [:0]const u8,

    /// Deterministic must be true if the function will always return
    /// the same result given the same inputs within a single SQL statement
    Deterministic: bool,

    /// Args is the number of arguments that this function accepts
    Args: usize,
};

/// createScalarFunction registers the custom scalar function with the provided database connection object.
pub fn createScalarFunction(
    db: *sqlite3.Database,
    opts: FuncOptions,
    ptr: anytype,
    comptime apply: fn (@TypeOf(ptr), *sqlite3.Context, []const *sqlite3.Value) void,
) !void {
    const conn = @ptrCast(*c.sqlite3, db);

    const Ptr = @TypeOf(ptr);
    const ptr_info = @typeInfo(Ptr);

    assert(ptr_info == .Pointer); // Must be a pointer
    assert(ptr_info.Pointer.size == .One); // Must be a single-item pointer

    const alignment = ptr_info.Pointer.alignment;

    const gen = struct {
        fn apply(ctx: ?*c.sqlite3_context, argc: c_int, argv: [*c]?*c.sqlite3_value) callconv(.C) void {
            var self: ?Ptr = if (@sizeOf(Ptr) != 0) @ptrCast(Ptr, @alignCast(alignment, c.sqlite3_user_data(ctx.?))) else null;
            var args = @ptrCast([*]*sqlite3.Value, argv)[0..@intCast(usize, argc)];

            @call(.{ .modifier = .always_inline }, apply, .{ self.?, @ptrCast(*sqlite3.Context, ctx.?), args });
        }
    };

    var flags = @as(c_int, c.SQLITE_UTF8);
    if (opts.Deterministic) {
        flags |= c.SQLITE_DETERMINISTIC;
    }

    const userData = if (@sizeOf(Ptr) != 0) @ptrCast(*anyopaque, ptr) else null;

    const ret = c.sqlite3_create_function_v2(conn, opts.Name, @intCast(c_int, opts.Args), flags, userData, gen.apply, null, null, null);
    if (ret != c.SQLITE_OK) {
        return errors.from(ret);
    }
}

/// createAggregateFunction registers the custom aggregate function with the provided database connection object.
pub fn createAggregateFunction(
    db: *sqlite3.Database,
    opts: FuncOptions,
    ptr: anytype,
    comptime step: fn (@TypeOf(ptr), *sqlite3.Context, []const *sqlite3.Value) void,
    comptime final: fn (@TypeOf(ptr), *sqlite3.Context) void,
) !void {
    const conn = @ptrCast(*c.sqlite3, db);

    const Ptr = @TypeOf(ptr);
    const ptr_info = @typeInfo(Ptr);

    assert(ptr_info == .Pointer); // Must be a pointer
    assert(ptr_info.Pointer.size == .One); // Must be a single-item pointer

    const alignment = ptr_info.Pointer.alignment;

    const gen = struct {
        fn step(ctx: ?*c.sqlite3_context, argc: c_int, argv: [*c]?*c.sqlite3_value) callconv(.C) void {
            var self: ?Ptr = if (@sizeOf(Ptr) != 0) @ptrCast(Ptr, @alignCast(alignment, c.sqlite3_user_data(ctx.?))) else null;
            var args = @ptrCast([*]*sqlite3.Value, argv)[0..@intCast(usize, argc)];

            @call(.{ .modifier = .always_inline }, step, .{ self.?, @ptrCast(*sqlite3.Context, ctx.?), args });
        }

        fn final(ctx: ?*c.sqlite3_context) callconv(.C) void {
            var self: ?Ptr = if (@sizeOf(Ptr) != 0) @ptrCast(Ptr, @alignCast(alignment, c.sqlite3_user_data(ctx.?))) else null;
            @call(.{ .modifier = .always_inline }, final, .{ self.?, @ptrCast(*sqlite3.Context, ctx.?) });
        }
    };

    var flags = @as(c_int, c.SQLITE_UTF8);
    if (opts.Deterministic) {
        flags |= c.SQLITE_DETERMINISTIC;
    }

    const userData = if (@sizeOf(Ptr) != 0) @ptrCast(*anyopaque, ptr) else null;

    const ret = c.sqlite3_create_function_v2(conn, opts.Name, @intCast(c_int, opts.Args), flags, userData, null, gen.step, gen.final, null);
    if (ret != c.SQLITE_OK) {
        return errors.from(ret);
    }
}

/// createWindowFunction registers the custom window function with the provided database connection object.
pub fn createWindowFunction(
    db: *sqlite3.Database,
    opts: FuncOptions,
    ptr: anytype,
    comptime step: fn (@TypeOf(ptr), *sqlite3.Context, []const *sqlite3.Value) void,
    comptime value: fn (@TypeOf(ptr), *sqlite3.Context) void,
    comptime inverse: fn (@TypeOf(ptr), *sqlite3.Context, []const *sqlite3.Value) void,
    comptime final: fn (@TypeOf(ptr), *sqlite3.Context) void,
) !void {
    const conn = @ptrCast(*c.sqlite3, db);

    const Ptr = @TypeOf(ptr);
    const ptr_info = @typeInfo(Ptr);

    assert(ptr_info == .Pointer); // Must be a pointer
    assert(ptr_info.Pointer.size == .One); // Must be a single-item pointer

    const alignment = ptr_info.Pointer.alignment;

    const gen = struct {
        fn step(ctx: ?*c.sqlite3_context, argc: c_int, argv: [*c]?*c.sqlite3_value) callconv(.C) void {
            var self: ?Ptr = if (@sizeOf(Ptr) != 0) @ptrCast(Ptr, @alignCast(alignment, c.sqlite3_user_data(ctx.?))) else null;
            var args = @ptrCast([*]*sqlite3.Value, argv)[0..@intCast(usize, argc)];

            @call(.{ .modifier = .always_inline }, step, .{ self.?, @ptrCast(*sqlite3.Context, ctx.?), args });
        }

        fn value(ctx: ?*c.sqlite3_context) callconv(.C) void {
            var self: ?Ptr = if (@sizeOf(Ptr) != 0) @ptrCast(Ptr, @alignCast(alignment, c.sqlite3_user_data(ctx.?))) else null;
            @call(.{ .modifier = .always_inline }, value, .{ self.?, @ptrCast(*sqlite3.Context, ctx.?) });
        }

        fn inverse(ctx: ?*c.sqlite3_context, argc: c_int, argv: [*c]?*c.sqlite3_value) callconv(.C) void {
            var self: ?Ptr = if (@sizeOf(Ptr) != 0) @ptrCast(Ptr, @alignCast(alignment, c.sqlite3_user_data(ctx.?))) else null;
            var args = @ptrCast([*]*sqlite3.Value, argv)[0..@intCast(usize, argc)];

            @call(.{ .modifier = .always_inline }, inverse, .{ self.?, @ptrCast(*sqlite3.Context, ctx.?), args });
        }

        fn final(ctx: ?*c.sqlite3_context) callconv(.C) void {
            var self: ?Ptr = if (@sizeOf(Ptr) != 0) @ptrCast(Ptr, @alignCast(alignment, c.sqlite3_user_data(ctx.?))) else null;
            @call(.{ .modifier = .always_inline }, final, .{ self.?, @ptrCast(*sqlite3.Context, ctx.?) });
        }
    };

    var flags = @as(c_int, c.SQLITE_UTF8);
    if (opts.Deterministic) {
        flags |= c.SQLITE_DETERMINISTIC;
    }

    const userData = if (@sizeOf(Ptr) != 0) @ptrCast(*anyopaque, ptr) else null;

    const ret = c.sqlite3_create_window_function(conn, opts.Name, @intCast(c_int, opts.Args), flags, userData, gen.step, gen.final, gen.value, gen.inverse, null);
    if (ret != c.SQLITE_OK) {
        return errors.from(ret);
    }
}
