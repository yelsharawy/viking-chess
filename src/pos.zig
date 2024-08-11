const std = @import("std");
const assert = std.debug.assert;

pub fn Pos(comptime maxX: comptime_int, comptime maxY: comptime_int) type {
    return struct {

        // TODO: make these functions inline?
        const width = maxX + 1;
        const height = maxY + 1;
        const numSpaces = width * height;
        x: Int,
        y: Int,

        const Self = @This();
        pub const Int = std.math.IntFittingRange(-1, @max(maxX, maxY));
        pub fn init(x: anytype, y: anytype) Self {
            return Self{ .x = @intCast(x), .y = @intCast(y) };
        }
        pub fn inBounds(pos: Self) bool {
            return pos.x >= 0 and pos.x <= maxX and pos.y >= 0 and pos.y <= maxY;
        }
        pub fn idxUnbounded(pos: Self) isize {
            const castX: isize = @intCast(pos.x);
            const castY: isize = @intCast(pos.y);
            return castY * width + castX;
        }
        pub fn idx(pos: Self) usize {
            assert(pos.inBounds());
            const castX: usize = @intCast(pos.x);
            const castY: usize = @intCast(pos.y);
            return castY * width + castX;
        }
        pub fn idxDelim(pos: Self) usize {
            assert(pos.inBounds());
            const castX: usize = @intCast(pos.x);
            const castY: usize = @intCast(pos.y);
            return castY * (width + 1) + castX + 1;
        }
        pub fn add(pos: Self, delta: Self) Self {
            return Self{ .x = pos.x + delta.x, .y = pos.y + delta.y };
        }
        pub fn scale(pos: Self, scalar: Int) Self {
            return Self{ .x = pos.x * scalar, .y = pos.y * scalar };
        }
        pub fn eql(pos: Self, other: Self) bool {
            return pos.x == other.x and pos.y == other.y;
        }
        // pub fn add(pos: Self, dx: Int, dy: Int) Self {
        //     return Self{ .x = pos.x + dx, .y = pos.y + dy };
        // }

        pub const All: [numSpaces]Self = genAll();
        fn genAll() [numSpaces]Self {
            var result: [numSpaces]Self = undefined;

            for (0..height) |y| {
                for (0..width) |x| {
                    const p = Self{ .x = @intCast(x), .y = @intCast(y) };
                    result[p.idx()] = p;
                }
            }

            // for (0..11) |i| {
            //     var a: [11]Self = undefined;
            //     std.mem.copyForwards(Self, &a, result[11 * i .. 11 * (i + 1)]);
            //     @compileLog(a);
            //     @compileLog(a[0].idxDelim());
            // }

            return result;
        }
    };
}
