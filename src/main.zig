const bincode = @import("./bincode.zig");
const std = @import("std");
const testing = std.testing;
const DynamicBitSet = std.bit_set.DynamicBitSet;

pub const BitVec = struct {
    bits: ?[]u64,
    len: u64,

    const Self = @This();

    pub fn initFromBitSet(bitset: DynamicBitSet) Self {
        if (bitset.capacity() > 0) {
            return Self{
                .bits = bitset.unmanaged.masks[0..(bitset.unmanaged.bit_length / 64)],
                .len = @as(u64, bitset.unmanaged.bit_length),
            };
        }
        return Self{
            .bits = null,
            .len = @as(u64, bitset.unmanaged.bit_length),
        };
    }

    pub fn toBitSet(self: *const Self, allocator: std.mem.Allocator) !DynamicBitSet {
        var bitset = try DynamicBitSet.initEmpty(allocator, self.len);
        switch (self.bits) {
            .some => |bits| {
                for (0..(self.len / 64)) |i| {
                    bitset.unmanaged.masks[i] = bits[i];
                }
            },
            else => {},
        }
        return bitset;
    }
};

pub fn main() !void { 
    const alloc = std.heap.c_allocator;

    var rust_bit_vec_serialized = [_]u8{
        1,   2,   0,   0,   0,   0,   0, 0, 0, 255, 255, 239, 191, 255, 255, 255, 255, 255, 255, 255,
        255, 255, 255, 255, 255, 128, 0, 0, 0, 0,   0,   0,   0,
    };
    var bitset = try DynamicBitSet.initFull(alloc, 128);

    bitset.setValue(20, false);
    bitset.setValue(30, false);
    defer bitset.deinit();

    // buf needs to be at least :
    //   4 (32 bits enum for option)
    //   n (size * 8 (64 bits for u64 block sizes))
    //   8 + (len of slice above)
    // + 8 (u64 for len field)
    // -------------------------
    //   z <- size of buf

    var buf: [10000]u8 = undefined;

    const original = BitVec.initFromBitSet(bitset);
    var out = try bincode.writeToSlice(buf[0..], original, bincode.Params.standard);
    std.debug.print("{any}\n", .{ out[0..out.len] });

    var deserialied = try bincode.readFromSlice(alloc, BitVec, out, bincode.Params.standard);
    defer bincode.readFree(alloc, deserialied);

    try testing.expect(std.mem.eql(u64, original.bits.?[0..], deserialied.bits.?[0..]));
    try testing.expectEqualSlices(u8, rust_bit_vec_serialized[0..], out[0..]);

    // const Foo = union(enum(u8)) {
    //     A: u32, 
    //     B: u32
    // };

    // const expected = [_]u8 { 1, 0, 0, 0, 1, 1, 1, 1};
    // const value = Foo {
    //     .B = 16843009
    // };

    // var buffer = [_]u8{ 0 } ** 10;
    // const buf = try bincode.writeToSlice(&buffer, value, bincode.Params.standard);
    // try testing.expectEqualSlices(u8, &expected, buf[0..buf.len]);

    // // read it back 
    // const rvalue = try bincode.readFromSlice(alloc, Foo, &buffer, bincode.Params.standard);
    // std.debug.print("{any}\n", .{rvalue});
    // try testing.expectEqual(value, rvalue);
}