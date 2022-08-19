const std = @import("std");
const testing = std.testing;

const sqlite3 = @import("sqlite3.zig");

pub const UpperFn = struct {
    const Self = @This();

    // allocator used to allocate string space
    allocator: std.mem.Allocator,

    pub fn apply(self: *Self, ctx: *sqlite3.Context, args: []const *sqlite3.Value) void {
        var str = self.allocator.alloc(u8, args[0].get([]const u8).len) catch unreachable;
        defer self.allocator.free(str);

        var value = args[0].get([]const u8);
        for (value) |char, i| {
            str[i] = std.ascii.toUpper(char);
        }

        ctx.result(str);
    }

    pub fn register(self: *Self, db: *sqlite3.Database) !void {
        try db.createScalarFunction(.{ .Name = "zig_upper", .Deterministic = true, .Args = 1 }, self, apply);
    }
};

test "sqlite3 scalar function" {
    const db = try sqlite3.open("file::memory:", .{ .ReadWrite = true });
    defer db.close() catch {};

    var func = UpperFn{ .allocator = std.testing.allocator };
    try func.register(db);

    var stmt = try db.prepare("SELECT zig_upper('sqlite3')");
    defer stmt.finalize() catch {};

    try testing.expectEqual(true, try stmt.step());
    try testing.expectEqualStrings("SQLITE3", stmt.get([]const u8, 0));
}

pub const SumFn = struct {
    const Self = @This();

    const SumContext = struct { sum: i64 = 0 };

    pub fn step(_: *Self, ctx: *sqlite3.Context, args: []const *sqlite3.Value) void {
        ctx.data(SumContext).sum += args[0].get(i64);
    }

    pub fn value(_: *Self, ctx: *sqlite3.Context) void {
        ctx.result(ctx.data(SumContext).sum);
    }

    pub fn inverse(_: *Self, ctx: *sqlite3.Context, args: []const *sqlite3.Value) void {
        ctx.data(SumContext).sum -= args[0].get(i64);
    }

    pub fn final(_: *Self, ctx: *sqlite3.Context) void {
        ctx.result(ctx.data(SumContext).sum);
    }

    fn register(self: *Self, db: *sqlite3.Database) !void {
        try db.createWindowFunction(.{ .Deterministic = true, .Args = 1, .Name = "zig_sum" }, self, step, value, inverse, final);
    }
};

test "sqlite3 window function" {
    const db = try sqlite3.open("file::memory:", .{ .ReadWrite = true });
    defer db.close() catch {};

    var func = SumFn{};
    try func.register(db);

    var stmt = try db.prepare(
        \\ WITH RECURSIVE generate_series(value) AS (
        \\   SELECT 1
        \\	    UNION ALL
        \\   SELECT value+1 FROM generate_series
        \\     WHERE value+1<=10
        \\ ) SELECT zig_sum(value) FROM generate_series
    );

    defer stmt.finalize() catch {};

    try testing.expectEqual(true, try stmt.step());
    try testing.expectEqual(@as(i32, 55), stmt.get(i32, 0));
}
