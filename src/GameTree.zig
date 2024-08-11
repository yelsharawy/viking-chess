const std = @import("std");
const Allocator = std.mem.Allocator;
const Order = std.math.Order;

const Board = @import("Board.zig");

const Self = @This();

const Score = isize;

pub const Node = struct {
    pub const State = union(enum) {
        estimated: Score,
        /// dynamically allocated, should never be resized,
        /// so pointer to a node has lifetime until deinit
        calculated: []Node,
    };
    board: Board,
    player: Board.Player,
    state: State,

    parent: ?*Node,

    pub fn deinit(self: Node, allocator: Allocator) void {
        switch (self.state) {
            .calculated => {
                for (self.children) |child| {
                    child.deinit(allocator);
                }
            },
            else => {},
        }
        allocator.free(self.children);
    }

    /// aka "how good is this state for the person whose turn it is?"
    pub fn score(self: Node) Score {
        switch (self.state) {
            .estimated => |s| return s,
            .calculated => |children| {
                if (children.len == 0) return 0;

                var result = -children[0].score();
                for (children[1..]) |child| {
                    result = @max(result, -child.score());
                }
                return result;
            },
        }
    }

    pub fn depth(self: Node) usize {
        if (self.parent) |p| {
            return 1 + p.depth();
        } else {
            return 0;
        }
    }
};

// const CandidateQueue = struct {
//     const Internal = std.ArrayList(*Node);
//     prng: std.rand.DefaultPrng,
//     internal: Internal,

//     const CQ = @This();
//     pub fn init(allocator: Allocator) CQ {
//         return CQ{ .prng = std.rand.DefaultPrng.init(0), .internal = Internal.init(allocator) };
//     }

//     pub fn add(self: *CQ, node: *Node) !void {
//         return self.internal.append(node);
//     }

//     pub fn pop(self: *CQ) ?*Node {
//         const idx = self.prng.random().uintLessThan(usize, self.internal.items.len);
//         return self.internal.swapRemove(idx);
//     }

//     pub fn deinit(self: *CQ) void {
//         return self.internal.deinit();
//     }
// };

const CandidateQueue = struct {
    const Internal = std.SinglyLinkedList(*Node);
    last: ?*Internal.Node = null,
    arena: std.heap.ArenaAllocator,
    internal: Internal,

    const CQ = @This();
    pub fn init(allocator: Allocator) CQ {
        return CQ{ .arena = std.heap.ArenaAllocator.init(allocator), .internal = Internal{} };
    }
    pub fn add(self: *CQ, node: *Node) !void {
        const list_node = try self.arena.allocator().create(Internal.Node);
        list_node.data = node;
        if (self.last) |l| {
            l.insertAfter(list_node);
        } else {
            self.internal.first = list_node;
        }
        self.last = list_node;
    }
    pub fn pop(self: *CQ) ?*Node {
        const list_node = self.internal.popFirst() orelse return null;
        if (self.last == list_node) {
            self.last = null;
        }
        defer self.arena.allocator().destroy(list_node);
        return list_node.data;
    }
    pub fn deinit(self: *CQ) void {
        self.internal = Internal{};
        self.arena.deinit();
    }
};

// const CandidateQueue = struct {
//     const Internal = std.PriorityQueue(*Node, void, compareCandidates);
//     internal: Internal,

//     const CQ = @This();
//     pub fn init(allocator: Allocator) CQ {
//         return CQ{ .internal = Internal.init(allocator, {}) };
//     }

//     fn compareCandidates(_: void, a: *Node, b: *Node) Order {
//         _ = a; // autofix
//         _ = b; // autofix
//         return .eq;
//     }
//     pub fn add(self: *CQ, node: *Node) !void {
//         return self.internal.add(node);
//     }
//     pub fn pop(self: *CQ) *Node {
//         return self.internal.remove();
//     }
// };

allocator: Allocator,
arena: std.heap.ArenaAllocator,
/// the root of the tree should be the current state of the board
/// must be a pointer so copies of the tree do not invalidate root pointer
root: *Node,
playing_as: Board.Player,

candidates: CandidateQueue,

pub fn init(allocator: Allocator, board: Board, player: Board.Player) !Self {
    var arena = std.heap.ArenaAllocator.init(allocator);
    const root = try arena.allocator().create(Node);
    root.* = Node{
        .board = board,
        .player = player,
        .state = .{ .estimated = board.deltaPoints(player) },
        .parent = null,
    };
    var candidates = CandidateQueue.init(allocator);
    try candidates.add(root);
    return Self{
        .allocator = allocator,
        .arena = arena,
        .root = root,
        .playing_as = player,
        .candidates = candidates,
    };
}

pub fn nextCandidate(self: *Self) ?*Node {
    return self.candidates.pop();
}

pub fn expand(self: *Self, candidate: *Node) !void {
    switch (candidate.state) {
        .estimated => {
            const moves = try candidate.board.moves(candidate.player, self.allocator);
            defer self.allocator.free(moves);
            const children = try self.arena.allocator().alloc(Node, moves.len);
            for (moves, children) |move, *child| {
                var newBoard = candidate.board;
                newBoard.play(candidate.player, move);
                child.* = Node{
                    .parent = candidate,
                    .board = newBoard,
                    .player = candidate.player.next(),
                    .state = .{
                        .estimated = newBoard.deltaPoints(candidate.player.next()),
                    },
                };
                try self.candidates.add(child);
            }
            candidate.state = .{
                .calculated = children,
            };
        },
        else => |t| std.debug.panic("expected estimated node, got '{s}'", .{@tagName(t)}),
    }
}

pub fn deinit(self: *Self) void {
    // self.root.deinit(self.allocator);
    self.arena.deinit();
    self.candidates.deinit();
}

pub fn focus(self: *Self, move: *Board.Move) void {
    _ = self; // autofix
    _ = move; // autofix

}
