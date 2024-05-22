const std = @import("std");
const pos = @import("pos.zig");
const string_2d = @import("string_2d.zig");

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
        // const Transpose = BitSet2D(maxY, maxX);
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
                while (shiftAmt * 2 <= numBits) : (shiftAmt *= 2) {
                    result.mask |= result.mask << shiftAmt;
                }
            }
        }
        pub fn move(self: *Self, by: Pos) void {
            self.internal.mask = std.math.shr(MaskInt, self.internal.mask, by.idx());
        }
        pub fn toString(self: Self) String2D {
            var result = String2D.init('0');
            result.setChars(self, '1');
            return result;
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
    };
}
