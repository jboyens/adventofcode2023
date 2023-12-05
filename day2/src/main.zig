const std = @import("std");
const testing = std.testing;
const expect = testing.expect;

const ArrayList = std.ArrayList;
const parseUnsigned = std.fmt.parseUnsigned;

const CubeColor = enum {
    red,
    green,
    blue,

    pub fn fromBuf(buf: []u8) !CubeColor {
        if (std.mem.eql(u8, buf, "red")) {
            return .red;
        }

        if (std.mem.eql(u8, buf, "blue")) {
            return .blue;
        }

        if (std.mem.eql(u8, buf, "green")) {
            return .green;
        }

        return error.UnknownColor;
    }
};

const GameResult = struct {
    count: i64,
    color: CubeColor,

    pub fn parse(source: []u8) !GameResult {
        var trimmed = std.mem.trim(u8, source, " ");
        var resultSplits = std.mem.splitScalar(u8, trimmed, ' ');
        var count = try parseUnsigned(u8, resultSplits.first(), 10);
        var colorName = resultSplits.next().?;

        var color: CubeColor = try CubeColor.fromBuf(@constCast(colorName));

        return GameResult{ .count = count, .color = color };
    }
};

const GameSet = struct {
    results: ArrayList(GameResult),

    pub fn parse(allocator: std.mem.Allocator, source: []u8) !GameSet {
        var results = std.mem.tokenizeScalar(u8, source, ',');

        var gameResults = std.ArrayList(GameResult).init(allocator);
        while (results.next()) |result| {
            var gameResult = try GameResult.parse(@constCast(result));
            try gameResults.append(gameResult);
        }

        return GameSet{ .results = gameResults };
    }

    pub fn deinit(self: GameSet) void {
        self.results.deinit();
    }
};

const Game = struct {
    number: i64,
    sets: ArrayList(GameSet),

    pub fn parse(allocator: std.mem.Allocator, source: []u8) !Game {
        var splits = std.mem.splitScalar(u8, source, ':');

        var gameNumber = try parseGameNumber(splits.first());
        var games = std.mem.tokenizeScalar(u8, splits.rest(), ';');

        var gameSets = std.ArrayList(GameSet).init(allocator);

        while (games.next()) |game| {
            var gameSet = try GameSet.parse(allocator, @constCast(game));
            try gameSets.append(gameSet);
        }

        return Game{ .number = gameNumber, .sets = gameSets };
    }

    pub fn deinit(self: Game) void {
        for (self.sets.items) |set| {
            set.deinit();
        }

        self.sets.deinit();
    }

    pub fn possible(self: Game, allocator: std.mem.Allocator, red: i64, green: i64, blue: i64) !bool {
        _ = allocator;
        for (self.sets.items) |gameset| {
            for (gameset.results.items) |result| {
                switch (result.color) {
                    .red => {
                        if (result.count > red) {
                            return false;
                        }
                    },
                    .green => {
                        if (result.count > green) {
                            return false;
                        }
                    },
                    .blue => {
                        if (result.count > blue) {
                            return false;
                        }
                    },
                }
            }
        }

        return true;
    }

    pub fn power(self: Game) !i64 {
        var minRed: i64 = 0;
        var minGreen: i64 = 0;
        var minBlue: i64 = 0;

        for (self.sets.items) |gameset| {
            for (gameset.results.items) |result| {
                switch (result.color) {
                    .red => {
                        if (result.count > minRed) {
                            minRed = result.count;
                        }
                    },
                    .green => {
                        if (result.count > minGreen) {
                            minGreen = result.count;
                        }
                    },
                    .blue => {
                        if (result.count > minBlue) {
                            minBlue = result.count;
                        }
                    },
                }
            }
        }

        return minRed * minGreen * minBlue;
    }
};

pub fn parseGameNumber(s: []const u8) !i64 {
    var splits = std.mem.split(u8, s, " ");

    // discard the first
    _ = splits.first();

    var nrStr = std.mem.trim(u8, splits.next().?, " ");

    return try parseUnsigned(i64, nrStr, 10);
}

test "parseGameNumber" {
    try std.testing.expect(21 == try parseGameNumber("Game 21"));
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const in = std.io.getStdIn();
    var buf = std.io.bufferedReader(in.reader());
    var r = buf.reader();

    const f = try r.readAllAlloc(allocator, @as(u64, @bitCast(std.math.inf(f64))));

    var parsed = try parseGames(allocator, f);

    var possibleSum: i64 = 0;
    for (parsed.items) |game| {
        var possible = try game.possible(allocator, 12, 13, 14);

        var pText = if (possible) "possible" else "impossible";
        std.debug.print("Game {} is {s}\n", .{ game.number, pText });
        if (possible) {
            possibleSum += game.number;
        }
    }

    var powerSum: i64 = 0;
    for (parsed.items) |game| {
        var power = try game.power();

        std.debug.print("Game {} is {}\n", .{ game.number, power });
        powerSum += power;
    }

    std.debug.print("Possible Sum: {}\n", .{possibleSum});
    std.debug.print("Power Sum: {}\n", .{powerSum});
}

pub fn parseGames(allocator: std.mem.Allocator, s: []const u8) !std.ArrayList(Game) {
    var lines = std.mem.tokenize(u8, s, &.{'\n'});

    var gameList = std.ArrayList(Game).init(allocator);

    while (lines.next()) |line| {
        var game = try Game.parse(allocator, @constCast(line));
        try gameList.append(game);
    }

    return gameList;
}

test "parseGames" {
    // const allocator = std.testing.allocator;
    const allocator = std.heap.page_allocator;

    const games =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
    ;

    var parsed = try parseGames(allocator, games);

    try expect(5 == parsed.items.len);

    var firstGame = parsed.items[0];
    try expect(1 == firstGame.number);
    try expect(3 == firstGame.sets.items.len);

    var firstGameSet = firstGame.sets.items[0];
    var secondGameSet = firstGame.sets.items[1];

    var firstGameSetResults = firstGameSet.results.items;
    try expect(2 == firstGameSetResults.len);
    try testing.expectEqualSlices(GameResult, firstGameSetResults, &.{
        GameResult{ .count = 3, .color = .blue },
        GameResult{ .count = 4, .color = .red },
    });

    var secondGameSetResults = secondGameSet.results.items;
    try testing.expectEqualSlices(GameResult, secondGameSetResults, &.{
        GameResult{ .count = 1, .color = .red },
        GameResult{ .count = 2, .color = .green },
        GameResult{ .count = 6, .color = .blue },
    });

    for (parsed.items) |game| {
        game.deinit();
    }
    parsed.deinit();
}

test "power" {
    const allocator = std.heap.page_allocator;

    const games =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
    ;

    var parsed = try parseGames(allocator, games);

    var sum: i64 = 0;
    for (parsed.items) |game| {
        var power = try game.power();

        sum += power;
    }

    try expect(2286 == sum);
}

test "possible" {
    const allocator = std.heap.page_allocator;

    const games =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
    ;

    var parsed = try parseGames(allocator, games);

    var possibleSum: i64 = 0;
    for (parsed.items) |game| {
        var possible = try game.possible(allocator, 12, 13, 14);

        if (possible) {
            possibleSum += game.number;
        }
    }

    try expect(8 == possibleSum);
}
