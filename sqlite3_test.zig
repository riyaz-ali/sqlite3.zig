const std = @import("std");
const testing = std.testing;

const sqlite3 = @import("sqlite3.zig");

test "reports library version correctly" {
    try testing.expectEqual(sqlite3.version(), 3038002);
}

test "reports auto-commit status" {
    const db = try sqlite3.open("file::memory:", .{ .ReadWrite = true });
    defer db.close() catch {};

    try testing.expect(db.getAutoCommit());

    var stmt = try db.prepare("BEGIN");
    _ = try stmt.step();
    try stmt.finalize();

    try testing.expect(!db.getAutoCommit());
}

test "reports last error" {
    const db = try sqlite3.open("file::memory:", .{ .ReadWrite = true });
    defer db.close() catch {};

    // no such function as now(); prepare should fail
    _ = db.prepare("SELECT now()") catch {
        try testing.expectEqualStrings(db.lastError(), "no such function: now");
    };
}

test "can successfully bind all supported types" {
    const db = try sqlite3.open("file::memory:", .{ .ReadWrite = true });
    defer db.close() catch {};

    // create a temporary table with columns for all supported datatypes
    var stmt = try db.prepare("CREATE TABLE x(a, b, c, d, e, f)");
    _ = try stmt.step();
    try stmt.finalize();

    stmt = try db.prepare("INSERT INTO x (a, b, c, d, e, f) VALUES (?, ?, ?, ?, ?, ?)");
    try stmt.bind(.{ .Index = 1 }, 10);
    try stmt.bind(.{ .Index = 2 }, 20.25);
    try stmt.bind(.{ .Index = 3 }, true);
    try stmt.bind(.{ .Index = 4 }, @as([]const u8, "hello"));
    try stmt.bind(.{ .Index = 5 }, null);
    try stmt.bind(.{ .Index = 6 }, sqlite3.ZeroBlob{ .len = 10 });
    _ = try stmt.step();
    try stmt.finalize();

    stmt = try db.prepare("INSERT INTO x (a, b, c, d, e, f) VALUES ($a, $b, $c, $d, $e, $f)");
    try stmt.bind(.{ .Named = "$a" }, 10);
    try stmt.bind(.{ .Named = "$b" }, 20.25);
    try stmt.bind(.{ .Named = "$c" }, true);
    try stmt.bind(.{ .Named = "$d" }, @as([]const u8, "hello"));
    try stmt.bind(.{ .Named = "$e" }, null);
    try stmt.bind(.{ .Named = "$f" }, sqlite3.ZeroBlob{ .len = 10 });
    _ = try stmt.step();
    try stmt.finalize();
}

test "can read values back from database" {
    const db = try sqlite3.open("file::memory:", .{ .ReadWrite = true });
    defer db.close() catch {};

    // create a temporary table with columns for all supported datatypes
    var stmt = try db.prepare("CREATE TABLE x(a, b, c, d, e)");
    _ = try stmt.step();
    try stmt.finalize();

    stmt = try db.prepare("INSERT INTO x (a, b, c, d) VALUES (?, ?, ?, ?)");
    try stmt.bind(.{ .Index = 1 }, 10);
    try stmt.bind(.{ .Index = 2 }, 20.25);
    try stmt.bind(.{ .Index = 3 }, true);
    try stmt.bind(.{ .Index = 4 }, @as([]const u8, "hello"));
    _ = try stmt.step();
    try stmt.finalize();

    stmt = try db.prepare("SELECT * FROM x");
    try testing.expectEqual(true, try stmt.step());

    try testing.expectEqual(@as(i32, 10), stmt.get(i32, 0));
    try testing.expectEqual(@as(f32, 20.25), stmt.get(f32, 1));
    try testing.expectEqual(true, stmt.get(bool, 2));
    try testing.expectEqualStrings("hello", stmt.get([]const u8, 3));

    try testing.expectEqual(false, try stmt.step());
    try stmt.finalize();
}

test "reports correct bind and column counts" {
    const db = try sqlite3.open("file::memory:", .{ .ReadWrite = true });
    defer db.close() catch {};

    var stmt = try db.prepare("SELECT abs(?)");
    try testing.expectEqual(@as(i32, 1), stmt.bindParamCount());

    try stmt.bind(.{ .Index = 1 }, -10);
    try testing.expectEqual(true, try stmt.step());
    try testing.expectEqual(@as(i32, 1), stmt.columnCount());

    try testing.expectEqual(false, try stmt.step());
    try stmt.finalize();
}
