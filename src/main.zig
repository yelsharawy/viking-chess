const std = @import("std");
const Board = @import("Board.zig");
const GameTree = @import("GameTree.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn main() !void {
    var gameTree = try GameTree.init(allocator, Board{}, .defenders);
    defer {
        gameTree.deinit();
        _ = gpa.detectLeaks();
    }

    std.log.debug("loop start\n", .{});
    for (0..1_000_000) |i| {
        const candidate = gameTree.nextCandidate() orelse {
            std.debug.print("stopped at index: {}\n", .{i});
            break;
        };
        // if (candidate.score() == -1) {
        //     std.debug.print("candidate:{}\n", .{candidate.board});
        //     std.debug.print("score: {}\n\n", .{candidate.score()});
        //     return;
        // }
        try gameTree.expand(candidate);
        if (i % 10_000 == 0) {
            std.debug.print("\ni: {}\n", .{i});
            // std.debug.print("candidate:{}\n", .{candidate.board});
            std.debug.print("root score: {}\n", .{gameTree.root.score()});
            std.debug.print("first child score: {}\n", .{gameTree.root.state.calculated[0].score()});
            std.debug.print("depth: {}\n", .{candidate.depth()});
        }
    }

    const root_score = gameTree.root.score();
    std.debug.print("\n\nroot score: {}\n", .{root_score});
    // std.debug.print("level 1 contributors:\n", .{});
    // for (gameTree.root.state.calculated) |child| {
    //     if (child.score() == -root_score) {
    //         std.debug.print("child: {}\n", .{child.board});
    //     }
    // }
}
