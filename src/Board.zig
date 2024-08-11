const std = @import("std");
const assert = std.debug.assert;

const Board = @This();
pub const Player = enum {
    invaders,
    defenders,

    pub fn next(player: Player) Player {
        return switch (player) {
            .defenders => .invaders,
            .invaders => .defenders,
        };
    }
};
const Dim = enum {
    x,
    y,

    pub fn toDelta(self: Dim, amount: Pos.Int) Pos {
        return switch (self) {
            .x => Pos{ .x = amount, .y = 0 },
            .y => Pos{ .x = 0, .y = amount },
        };
    }
};
const length = 11;
const bit_set_2d = @import("bit_set_2d.zig");
pub const BitSet2D = bit_set_2d.BitSet2D(length - 1, length - 1);
const BitSet = BitSet2D.Internal;
const string_2d = @import("string_2d.zig");
pub const String2D = string_2d.String2D(length, length);

const blackSquares = initBlackSquares();
fn initBlackSquares() BitSet2D {
    var result = BitSet.initEmpty();

    const edges = .{ 0, length - 1 };
    for (edges) |x| {
        for (edges) |y| {
            result.set(at(x, y));
        }
    }
    result.set(center.idx());

    return BitSet2D{ .internal = result };
}

const pos = @import("pos.zig");
pub const Pos = pos.Pos(length - 1, length - 1);
const center = Pos{ .x = length / 2, .y = length / 2 };

const initialDefenderCount = initDefenders().count();
const initialInvaderCount = initInvaders().count();

defenders: BitSet2D = initDefenders(),
invaders: BitSet2D = initInvaders(),
king: ?Pos = center,

inline fn at(x: usize, y: usize) usize {
    return y * length + x;
}

inline fn atDelim(x: usize, y: usize) usize {
    return y * (length + 1) + x;
}

pub fn toString2D(self: Board) String2D {
    var result: String2D = comptime String2D.init('.');
    result.setChars(blackSquares, '_');
    result.setChars(self.defenders, 'd');
    result.setChars(self.invaders, 'i');
    if (self.king) |p| {
        result.setChar(p, 'K');
    }
    return result;
}
pub fn format(
    self: Board,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    out_stream: anytype,
) !void {
    return self.toString2D().format(fmt, options, out_stream);
}

fn initDefenders() BitSet2D {
    var result = BitSet.initEmpty();

    const m = length / 2;
    for (.{
        .{ -1, -1 },
        .{ -1, 0 },
        .{ -1, 1 },
        .{ 0, -1 },
        .{ 0, 0 },
        .{ 0, 1 },
        .{ 1, -1 },
        .{ 1, 0 },
        .{ 1, 1 },
        .{ -2, 0 },
        .{ 2, 0 },
        .{ 0, -2 },
        .{ 0, 2 },
    }) |p| {
        result.set(at(p[0] + m, p[1] + m));
    }

    return BitSet2D{ .internal = result };
}

fn initInvaders() BitSet2D {
    var result = BitSet.initEmpty();

    const m = length / 2;
    for (.{ -2, -1, 0, 1, 2 }) |i| {
        result.set(at(m + i, 0));
        result.set(at(m + i, length - 1));
        result.set(at(0, m + i));
        result.set(at(length - 1, m + i));
    }
    result.set(at(m, 1));
    result.set(at(m, length - 2));
    result.set(at(1, m));
    result.set(at(length - 2, m));

    return BitSet2D{ .internal = result };
}

// the board & invaders/defenders is known in context
pub const Move = struct {
    pos: Pos,
    dir: Dim,
    amount: Pos.Int,

    pub fn dest(move: Move) Pos {
        return move.pos.add(move.dir.toDelta(move.amount));
    }

    fn apply(move: Move, set: *BitSet2D) void {
        set.unset(move.pos);
        const d = move.dest();
        set.set(d);
    }
};

pub fn capture(moved: Pos, allies: *BitSet2D, opponents: *BitSet2D, king: ?Pos) void {
    inline for (.{ Dim.x, Dim.y }) |dir| {
        inline for (.{ -1, 1 }) |d| {
            const delta = dir.toDelta(d);
            const adjacent = moved.add(delta);
            // you can't capture the king
            if (king == null or !king.?.eql(adjacent)) {
                if (adjacent.inBounds() and opponents.isSet(adjacent)) {
                    const opposite = adjacent.add(delta);
                    if (opposite.inBounds() and
                        (allies.isSet(opposite) or
                        (blackSquares.isSet(opposite)) and
                        (king == null or !king.?.eql(opposite))))
                    {
                        opponents.unset(adjacent);
                    }
                }
            }
        }
    }
}

pub fn playDefender(self: *Board, move: Move) void {
    move.apply(&self.defenders);
    const dest = move.dest();
    if (self.king) |k| {
        if (k.eql(move.pos)) {
            // king escape condition
            if (blackSquares.isSet(dest) and !dest.eql(center)) {
                self.defenders.unset(dest);
                self.king = null;
            } else {
                self.king = move.dest();
            }
            // we don't want to check black squares again if this is the king
            // also, king can't capture
            return;
        }
    }

    // defender suicide condition
    if (blackSquares.isSet(dest)) {
        self.defenders.unset(dest);
        return;
    }

    capture(dest, &self.defenders, &self.invaders, self.king);
}
pub fn playInvader(self: *Board, move: Move) void {
    move.apply(&self.invaders);
    const dest = move.dest();

    // invader suicide condition
    if (blackSquares.isSet(dest)) {
        self.invaders.unset(dest);
        return;
    }

    capture(dest, &self.invaders, &self.defenders, self.king);
}
pub fn play(self: *Board, player: Player, move: Move) void {
    return switch (player) {
        .defenders => self.playDefender(move),
        .invaders => self.playInvader(move),
    };
}

// const MoveIterator = struct {
//     player: *const BitSet,
//     opponent: *const BitSet,
//     /// `null` if playing as invader or king escaped
//     myKing: ?Pos, // because we don't care about opponent king

//     amount: isize = 0,
//     internal: Internal = Internal{},
//     const Internal = iters.Combinations(.{
//         iters.EnumIterator(Dim), // dim
//         iters.FixedIterator(usize, 0, length), // x
//         iters.FixedIterator(usize, 0, length), // y
//     });
//     const iters = @import("iters.zig");

//     pub fn next() ?Move {

//     }
// };

// pub fn iterDefenderMoves(self: Board) MoveIterator {
//     return MoveIterator{
//         .player = self.defenders,
//         .opponent = self.invaders,
//         .myKing = self.king,
//     };
// }

// pub fn iterInvaderMoves(self: Board) MoveIterator {
//     return MoveIterator{
//         .player = self.invaders,
//         .opponent = self.defenders,
//         .myKing = null,
//     };
// }

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub fn allMoves(player: *const BitSet2D, opponent: *const BitSet2D, myKing: ?Pos, allocator: Allocator) ![]Move {
    _ = myKing; // autofix
    var result: ArrayList(Move) = ArrayList(Move).init(allocator); // TODO: guess capacity

    const clearSpaces = BitSet2D{
        .internal = player.internal.unionWith(opponent.internal).complement(),
    };

    // TODO: consider black squares & king?
    inline for (.{ Dim.x, Dim.y }) |dim| {
        inline for (.{ -1, 1 }) |d| {
            const delta = dim.toDelta(d);

            var playerShifted = player.moved(delta);
            playerShifted.setIntersection(clearSpaces);
            var movedBy: Pos.Int = d;
            while (!playerShifted.isEmpty()) {
                var iter = playerShifted.internal.iterator(.{});
                while (iter.next()) |idx| {
                    const dest = Pos.All[idx];
                    const from = dest.add(dim.toDelta(-movedBy));
                    (try result.addOne()).* = Move{ .amount = movedBy, .dir = dim, .pos = from };
                }

                playerShifted.move(delta);
                playerShifted.setIntersection(clearSpaces);
                movedBy += d;
            }
        }
    }

    return try result.toOwnedSlice();
}

pub fn defenderMoves(self: *const Board, allocator: Allocator) ![]Move {
    return try allMoves(&self.defenders, &self.invaders, self.king, allocator);
}

pub fn invaderMoves(self: *const Board, allocator: Allocator) ![]Move {
    return try allMoves(&self.invaders, &self.defenders, null, allocator);
}

pub fn moves(self: *const Board, player: Player, allocator: Allocator) ![]Move {
    return switch (player) {
        .defenders => self.defenderMoves(allocator),
        .invaders => self.invaderMoves(allocator),
    };
}

pub fn defenderPoints(self: Board) usize {
    const captured = initialInvaderCount - self.invaders.count();
    return if (self.king) |_| captured else captured + 5;
}

pub fn invaderPoints(self: Board) usize {
    const captured = initialDefenderCount - self.defenders.count();
    return captured;
}

pub fn points(self: Board, player: Player) usize {
    return switch (player) {
        .defenders => self.defenderPoints(),
        .invaders => self.invaderPoints(),
    };
}

pub fn deltaPoints(self: Board, player: Player) isize {
    const def: isize = @intCast(self.defenderPoints());
    const inv: isize = @intCast(self.invaderPoints());
    return switch (player) {
        .defenders => def - inv,
        .invaders => inv - def,
    };
}
