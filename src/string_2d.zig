const std = @import("std");
const pos = @import("pos.zig");
const bit_set_2d = @import("bit_set_2d.zig");

pub fn String2D(comptime width: comptime_int, comptime height: comptime_int) type {
    return struct {
        pub const size = (width + 1) * height;
        pub const Internal = [size]u8;

        internal: Internal,

        const Pos = pos.Pos(width - 1, height - 1);
        const BitSet2D = bit_set_2d.BitSet2D(width - 1, height - 1);
        const Self = @This();

        pub fn init(fill: u8) Self {
            var result: Self = undefined;
            for (0..height) |y| {
                result.internal[y * (width + 1)] = '\n';
            }
            for (Pos.All) |p| {
                result.internal[p.idxDelim()] = fill;
            }
            return result;
        }
        pub fn setChar(self: *Self, at: Pos, char: u8) void {
            self.internal[at.idxDelim()] = char;
        }
        pub fn setChars(self: *Self, set: BitSet2D, char: u8) void {
            var iter = set.internal.iterator(.{});
            while (iter.next()) |idx| {
                const skipDelims = idx / width;
                self.internal[idx + skipDelims + 1] = char;
            }
        }
        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            out_stream: anytype,
        ) !void {
            _ = fmt; // autofix
            _ = options; // autofix
            return out_stream.writeAll(&self.internal);
        }
    };
}
