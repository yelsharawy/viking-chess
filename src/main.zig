const std = @import("std");
const Board = @import("Board.zig");

pub fn main() !void {
    var b = Board{};
    // std.debug.print("defenders:\n{s}", .{Board.setToString(b.defenders)});
    // std.debug.print("invaders:\n{s}", .{Board.setToString(b.invaders)});
    std.debug.print("board:\n{s}", .{b.toString2D().internal});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    // const moves = try b.invaderMoves(allocator);
    // defer allocator.free(moves);
    // for (moves) |move| {
    //     var newBoard = b;
    //     newBoard.playInvader(move);
    //     std.debug.print("{}\n{s}\n", .{ move, newBoard.toString() });
    // }
    // std.debug.print("len: {}\n", .{moves.len});
    var prng = std.rand.DefaultPrng.init(0);
    const rand = prng.random();
    for (0..100) |_| {
        { // defender
            const moves = try b.defenderMoves(allocator);
            defer allocator.free(moves);
            const idx = rand.uintLessThan(usize, moves.len);
            const move = moves[idx];
            b.playDefender(move);
        }
        { // invader
            const moves = try b.invaderMoves(allocator);
            defer allocator.free(moves);
            const idx = rand.uintLessThan(usize, moves.len);
            const move = moves[idx];
            b.playInvader(move);
        }
    }

    std.debug.print("\nend board:\n{s}", .{b.toString2D().internal});
}
