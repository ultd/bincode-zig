const bincode = @import("./bincode.zig");
const std = @import("std");
const testing = std.testing;

pub fn main() !void { 
    const alloc = std.heap.c_allocator;

    const Foo = union(enum(u8)) {
        A: u32, 
        B: u32
    };

    const expected = [_]u8 { 1, 0, 0, 0, 1, 1, 1, 1};
    const value = Foo {
        .B = 16843009
    };

    var buffer = [_]u8{ 0 } ** 10;
    const buf = try bincode.writeToSlice(&buffer, value, bincode.Params.standard);
    try testing.expectEqualSlices(u8, &expected, buf[0..buf.len]);

    // read it back 
    const rvalue = try bincode.readFromSlice(alloc, Foo, &buffer, bincode.Params.standard);
    std.debug.print("{any}\n", .{rvalue});
    try testing.expectEqual(value, rvalue);
}