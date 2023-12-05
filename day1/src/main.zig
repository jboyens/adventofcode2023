const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const in = std.io.getStdIn();

    var buf = std.io.bufferedReader(in.reader());
    var r = buf.reader();

    var list = std.ArrayList(u8).init(allocator);

    var sum: i64 = 0;
    while (true) {
        r.streamUntilDelimiter(list.writer(), '\n', @as(?usize, null)) catch |err| switch (err) {
            error.EndOfStream => {
                break;
            },
            else => |e| return e,
        };

        var result = try calculateLine(allocator, list.items);
        sum += result;
        list.clearAndFree();
    }

    std.debug.print("sum is: {}\n", .{sum});
}

const needles: []const []const u8 = &.{ "one", "two", "three", "four", "five", "six", "seven", "eight", "nine" };

pub fn calculateLine(allocator: std.mem.Allocator, line: []const u8) anyerror!i64 {
    var first: ?i64 = null;
    var firstIdx: usize = line.len - 1;
    var last: ?i64 = null;
    var lastIdx: usize = 0;

    for (line, 0..) |c, idx| {
        if (c >= '0' and c <= '9') {
            var parsed = std.fmt.parseUnsigned(i64, &.{c}, 10) catch unreachable;

            if (idx < firstIdx or first == null) {
                first = parsed;
                firstIdx = idx;
            }

            if (idx > lastIdx or last == null) {
                last = parsed;
                lastIdx = idx;
            }
        }
    }

    for (needles, 1..) |n, val| {
        if (std.mem.indexOf(u8, line, n)) |idx| {
            if (idx < firstIdx or first == null) {
                first = @intCast(val);
                firstIdx = idx;
            }
        }

        if (std.mem.lastIndexOf(u8, line, n)) |idx| {
            if (idx > lastIdx or last == null) {
                last = @intCast(val);
                lastIdx = idx;
            }
        }
    }

    var num = try std.fmt.allocPrint(allocator, "{}{}", .{ first.?, last.? });
    defer allocator.free(num);

    return std.fmt.parseUnsigned(i64, num, 10);
}

test "calculateLine" {
    const allocator = std.testing.allocator;

    var inputs: []const []const u8 = &.{
        "1abc2",
        "pqr3stu8vwx",
        "a1b2c3d4e5f",
        "treb7uchet",
    };

    var expectations: []const i64 = &.{ 12, 38, 15, 77 };

    for (inputs, 0..) |i, idx| {
        var result = try calculateLine(allocator, i);
        try std.testing.expectEqual(@as(i64, expectations[idx]), result);
    }
}

test "calculateLine - Part 2" {
    const allocator = std.heap.page_allocator;

    const inputs: []const []const u8 = &.{
        "two1nine",
        "eightwothree",
        "abcone2threexyz",
        "xtwone3four",
        "4nineeightseven2",
        "zoneight234",
        "7pqrstsixteen",
        "3onefqltjzdrfourcpkfhceightwomc",
        "llnshf1",
        "ninetwo2eighttwo",
    };

    const expectations: []const i64 = &.{ 29, 83, 13, 24, 42, 14, 76, 32, 11, 92 };

    for (inputs, 0..) |i, idx| {
        var result = try calculateLine(allocator, i);
        var expected = expectations[idx];

        try std.testing.expectEqual(expected, result);
    }
}
