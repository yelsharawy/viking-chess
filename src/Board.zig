const std = @import("std");

const Board = @This();
const Player = enum {
    invaders,
    defenders,
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
const size = length * length;
const BitSet = std.bit_set.ArrayBitSet(usize, size);
const BoardString = [size + length]u8;

const blackSquares = initBlackSquares();
fn initBlackSquares() BitSet {
    var result = BitSet.initEmpty();

    const edges = .{ 0, length - 1 };
    for (edges) |x| {
        for (edges) |y| {
            result.set(at(x, y));
        }
    }
    result.set(center.idx());

    return result;
}

const pos = @import("pos.zig");
const Pos = pos.Pos(length - 1, length - 1);
const center = Pos{ .x = length / 2, .y = length / 2 };

defenders: BitSet = initDefenders(),
invaders: BitSet = initInvaders(),
king: ?Pos = center,

defender_points: i6 = 0,

inline fn at(x: usize, y: usize) usize {
    return y * length + x;
}

inline fn atDelim(x: usize, y: usize) usize {
    return y * (length + 1) + x;
}

pub fn initStr(fill: u8) BoardString {
    var result: BoardString = undefined;
    for (0..length) |y| {
        result[atDelim(length, y)] = '\n';
    }
    for (Pos.All) |p| {
        result[p.idxDelim()] = fill;
    }
    return result;
}

pub fn setChars(str: *BoardString, set: BitSet, char: u8) void {
    for (Pos.All) |p| {
        if (set.isSet(p.idx())) {
            str[p.idxDelim()] = char;
        }
    }
}

pub fn setToString(set: BitSet) BoardString {
    var result: BoardString = comptime initStr('0');
    setChars(&result, set, '1');
    return result;
}

pub fn toString(self: Board) BoardString {
    var result: BoardString = comptime initStr('.');
    setChars(&result, blackSquares, '_');
    setChars(&result, self.defenders, 'd');
    setChars(&result, self.invaders, 'i');
    if (self.king) |p| {
        result[p.idxDelim()] = 'K';
    }
    return result;
}

fn initDefenders() BitSet {
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

    return result;
}

fn initInvaders() BitSet {
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

    return result;
}

// the board & invaders/defenders is known in context
const Move = struct {
    pos: Pos,
    dir: Dim,
    amount: Pos.Int,

    pub fn dest(move: Move) Pos {
        return move.pos.add(move.dir.toDelta(move.amount));
    }

    fn apply(move: Move, set: *BitSet) void {
        set.unset(move.pos.idx());
        const toIdx = move.dest().idx();
        if (blackSquares.isSet(toIdx)) {}
        set.set(toIdx);
    }
};

pub fn playDefender(self: *Board, move: Move) void {
    move.apply(&self.defenders);
    if (self.king) |k| {
        if (k.eql(move.pos)) {
            self.king = move.dest();
        }
    }
}
pub fn playInvader(self: *Board, move: Move) void {
    move.apply(&self.invaders);
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

pub fn allMoves(player: *const BitSet, opponent: *const BitSet, myKing: ?Pos, allocator: Allocator) ![]Move {
    _ = myKing; // autofix
    var result: ArrayList(Move) = ArrayList(Move).init(allocator); // TODO: guess capacity

    for (Pos.All) |p| {
        if (player.isSet(p.idx())) {
            inline for (.{ Dim.x, Dim.y }) |dim| {
                inline for (.{ -1, 1 }) |d| {
                    const delta = switch (dim) {
                        .x => Pos{ .x = d, .y = 0 },
                        .y => Pos{ .x = 0, .y = d },
                    };
                    var moveTo: Pos = p.add(delta);
                    var movedBy: Pos.Int = d;
                    while (moveTo.inBounds() and !player.isSet(moveTo.idx()) and !opponent.isSet(moveTo.idx())) {
                        (try result.addOne()).* = Move{ .amount = movedBy, .dir = dim, .pos = p };
                        moveTo = moveTo.add(delta);
                        movedBy += d;
                    }
                    // TODO: consider black squares & king
                }
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
