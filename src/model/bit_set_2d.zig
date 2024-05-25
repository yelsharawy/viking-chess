const std = @import("std");
const pos = @import("pos.zig");
const string_2d = @import("string_2d.zig");

const assert = std.debug.assert;

pub fn BitSet2D(comptime maxX: comptime_int, comptime maxY: comptime_int) type {
    return struct {
        const width = maxX + 1;
        const height = maxY + 1;
        const numBits = width * height;
        pub const Pos = pos.Pos(maxX, maxY);
        pub const Internal = std.bit_set.IntegerBitSet(@intCast(numBits));
        pub const MaskInt = Internal.MaskInt;
        pub const ShiftInt = Internal.ShiftInt;

        internal: Internal,

        const String2D = string_2d.String2D(maxX + 1, maxY + 1);
        const Self = @This();
        pub fn initEmpty() Self {
            return Self{ .internal = Internal.initEmpty() };
        }
        pub fn initFull() Self {
            return Self{ .internal = Internal.initFull() };
        }

        pub fn unionWith(self: Self, other: Self) Self {
            return Self{ .internal = self.internal.unionWith(other.internal) };
        }
        pub fn complement(self: Self) Self {
            return Self{ .internal = self.internal.complement() };
        }

        pub fn setIntersection(self: *Self, other: Self) void {
            return self.internal.setIntersection(other.internal);
        }

        pub fn set(self: *Self, at: Pos) void {
            self.internal.set(at.idx());
        }
        pub fn unset(self: *Self, at: Pos) void {
            self.internal.unset(at.idx());
        }
        pub fn isSet(self: Self, at: Pos) bool {
            return self.internal.isSet(at.idx());
        }

        pub fn isEmpty(self: Self) bool {
            return self.internal.mask == 0;
        }
        pub fn count(self: Self) usize {
            return self.internal.count();
        }

        pub fn rows(from: usize, to: usize) Self {
            var result = Internal.initEmpty();
            result.setRangeValue(.{ .start = from * width, .end = to * width }, true);
            return .{
                .internal = result,
            };
        }
        pub fn cols(from: usize, to: usize) Self {
            var result = Internal.initEmpty();
            if (from < to) {
                result.setRangeValue(.{ .start = from, .end = to }, true);
                var shiftAmt = @as(ShiftInt, width);
                while (true) : (shiftAmt *= 2) {
                    const shifted = @shlWithOverflow(result.mask, shiftAmt);
                    result.mask |= shifted[0];
                    if (shifted[1] == 1) {
                        break;
                    }
                }
            }
            return Self{ .internal = result };
        }
        pub fn move(self: *Self, by: Pos) void {
            // for now, caller is responsible for nonsensical calls
            assert(-width <= by.x and by.x <= width);
            assert(-height <= by.y and by.y <= height);

            self.internal.mask = std.math.shl(MaskInt, self.internal.mask, by.idxUnbounded());
            const byX: isize = @intCast(by.x);
            const byY: isize = @intCast(by.y);
            switch (std.math.order(by.x, 0)) {
                .lt => self.internal.setIntersection(cols(0, @intCast(width + byX)).internal),
                .gt => self.internal.setIntersection(cols(@intCast(byX), width).internal),
                .eq => {},
            }
            switch (std.math.order(by.y, 0)) {
                .lt => self.internal.setIntersection(rows(0, @intCast(height + byY)).internal),
                .gt => self.internal.setIntersection(rows(@intCast(byY), height).internal),
                .eq => {},
            }
        }
        pub fn moved(self: Self, by: Pos) Self {
            var copy = self;
            copy.move(by);
            return copy;
        }
        pub fn toString2D(self: Self) String2D {
            var result = String2D.init('0');
            result.setChars(self, '1');
            return result;
        }
        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            out_stream: anytype,
        ) !void {
            return self.toString2D().format(fmt, options, out_stream);
        }
    };
}
