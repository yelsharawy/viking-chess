const std = @import("std");
const Board = @import("Board.zig");

pub fn main() !void {
    var b = Board{};
    // std.debug.print("defenders:\n{s}", .{Board.setToString(b.defenders)});
    // std.debug.print("invaders:\n{s}", .{Board.setToString(b.invaders)});
    std.debug.print("board:\n{s}", .{b.toString2D().internal});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // const moves = try b.defenderMoves(allocator);
    // defer allocator.free(moves);
    // for (moves) |move| {
    //     var newBoard = b;
    //     newBoard.playDefender(move);
    //     std.debug.print("{}\n{s}\n", .{ move, newBoard.toString2D().internal });
    // }
    // std.debug.print("len: {}\n", .{moves.len});

    var prng = std.rand.DefaultPrng.init(0);
    const rand = prng.random();
    for (0..100) |_| {
        { // defender
            const moves = try b.defenderMoves(allocator);
            defer allocator.free(moves);
            if (moves.len == 0) break;
            const idx = rand.uintLessThan(usize, moves.len);
            const move = moves[idx];
            b.playDefender(move);
        }
        { // invader
            const moves = try b.invaderMoves(allocator);
            defer allocator.free(moves);
            if (moves.len == 0) break;
            const idx = rand.uintLessThan(usize, moves.len);
            const move = moves[idx];
            b.playInvader(move);
        }
    }
    std.debug.print("\nend board:\n{s}", .{b.toString2D().internal});
    std.debug.print("defender points: {}\n", .{b.defenderPoints()});
    std.debug.print("invader points: {}\n", .{b.invaderPoints()});
    std.debug.print("points: {}\n", .{b.deltaPoints()});

    // std.debug.print("rows(11, 11):\n{s}", .{Board.BitSet2D.rows(11, 11).toString().internal});
    // std.debug.print("cols(11, 11):\n{s}", .{Board.BitSet2D.cols(11, 11).toString().internal});
    // var y: isize = -9;
    // while (y <= 9) : (y += 3) {
    //     var x: isize = -9;
    //     while (x <= 9) : (x += 3) {
    //         std.debug.print("{}, {}:\n{s}", .{ x, y, Board.BitSet2D.initFull().moved(Board.Pos.init(x, y)).toString().internal });
    //     }
    // }
}
