const std = @import("std");
const testing = std.testing;

const sqlite3 = @import("sqlite3.zig");

test "should be able to open blob for reading" {
    const allocator = std.testing.allocator;

    const db = try sqlite3.open("file::memory:", .{ .ReadWrite = true });
    defer db.close() catch {};

    // create a temporary table with a blob column
    var stmt = try db.prepare("CREATE TABLE x(a)");
    _ = try stmt.step();
    try stmt.finalize();

    stmt = try db.prepare("INSERT INTO x (a) VALUES (?)");
    try stmt.bind(.{ .Index = 1 }, sqlite3.blob.ZeroBlob{ .len = 5 });
    _ = try stmt.step();
    try stmt.finalize();

    const id = db.lastInsertRowid(); // rowid of the last inserted row
    const blob = try db.openBlob(.main, "x", "a", id, false);
    defer blob.close() catch {};
    try testing.expectEqual(@as(usize, 5), blob.len());

    var buffer = try allocator.alloc(u8, blob.len());
    defer allocator.free(buffer);

    const n = try blob.read(0, buffer);
    try testing.expectEqual(blob.len(), n);
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0, 0 }, buffer);
}

test "should be able to open blob for writing" {
    const allocator = std.testing.allocator;

    const db = try sqlite3.open("file::memory:", .{ .ReadWrite = true });
    defer db.close() catch {};

    // create a temporary table with a blob column
    var stmt = try db.prepare("CREATE TABLE x(a)");
    _ = try stmt.step();
    try stmt.finalize();

    stmt = try db.prepare("INSERT INTO x (a) VALUES (?)");
    try stmt.bind(.{ .Index = 1 }, sqlite3.blob.ZeroBlob{ .len = 5 });
    _ = try stmt.step();
    try stmt.finalize();

    const id = db.lastInsertRowid(); // rowid of the last inserted row
    const blob = try db.openBlob(.main, "x", "a", id, true);
    defer blob.close() catch {};
    try testing.expectEqual(@as(usize, 5), blob.len());

    const nw = try blob.write(0, @as([]const u8, "hello"));
    try testing.expectEqual(@as(usize, 5), nw);

    var buffer = try allocator.alloc(u8, blob.len());
    defer allocator.free(buffer);

    const nr = try blob.read(0, buffer);
    try testing.expectEqual(blob.len(), nr);
    try testing.expectEqualSlices(u8, "hello", buffer);
}
