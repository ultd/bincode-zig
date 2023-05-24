const std = @import("std");
const testing = std.testing;
const bincode = @import("./bincode.zig");

// a struct that holds an ipv4
const IpAddrV4 = struct {
    octet: [4]u8,

    const Self = @This();

    pub fn format(self: Self, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return writer.print("{}.{}.{}.{}", .{ self.octet[0], self.octet[1], self.octet[2], self.octet[3] });
    }

    pub fn fromString(str: []const u8) !Self {
        var out = Self{
            .octet = .{ 0, 0, 0, 0 },
        };
        var split = std.mem.split(u8, str, ".");
        var idx: usize = 0;
        while (split.next()) |item| {
            if (idx > 3) {
                return error.InvalidIpV4Format;
            }
            out.octet[idx] = std.fmt.parseUnsigned(u8, item, 10) catch return error.InvalidIpV4Format;
            idx += 1;
        }

        if (idx != 4) {
            return error.InvalidIpV4Format;
        }

        return out;
    }
};

// our custome serializer for ipv4
fn serializeForIpv4(writer: anytype, data: anytype, params: bincode.Params) !void {
    var buf: [15]u8 = undefined;
    var out = try std.fmt.bufPrint(&buf, "{}", .{data});
    return bincode.write(writer, out, params);
}

// our custome deserializer for ipv4
fn deserializeForIpv4(_: std.mem.Allocator, comptime T: type, reader: anytype, params: bincode.Params) !T {
    var str = try bincode.read(testing.allocator, []const u8, reader, params);
    defer bincode.readFree(testing.allocator, str);

    return try IpAddrV4.fromString(str);
}

const Entity = struct {
    version: []const u8,
    ip: IpAddrV4,

    const Self = @This();

    pub fn format(self: Self, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return writer.print("{s} - {}", .{ self.version, self.ip });
    }

    pub const @"!bincode-config:id" = bincode.FieldConfig{
        .serializer = serializeForIpv4,
        .deserializer = deserializeForIpv4,
    };
};

test "custom serializer" {
    testing.log_level = .debug;

    var entity = Entity{
        .version = "v0.0.1",
        .ip = IpAddrV4{ .octet = [4]u8{ 192, 168, 0, 1 } },
    };

    std.log.debug("original {}", .{entity});

    var buf = std.ArrayList(u8).init(testing.allocator);
    defer buf.deinit();

    try bincode.write(buf.writer(), entity, bincode.Params.standard);

    std.log.debug("serialized: {any}", .{buf.items});

    var stream = std.io.fixedBufferStream(buf.items);
    var other_entity = try bincode.read(testing.allocator, Entity, stream.reader(), bincode.Params.standard);
    defer bincode.readFree(testing.allocator, other_entity);

    std.log.debug("deserialized: {any}", .{other_entity});

    try testing.expect(std.mem.eql(u8, other_entity.version, entity.version));
    try testing.expect(std.mem.eql(u8, &entity.ip.octet, &other_entity.ip.octet));
}

const NonCustomSerializerType = struct { a: u32, b: bool, c: struct { d: bool, e: f32 } };

test "non-custom serializer" {
    testing.log_level = .debug;

    var entity = NonCustomSerializerType{
        .a = 4,
        .b = true,
        .c = .{
            .d = false,
            .e = 3.14,
        },
    };

    std.log.debug("original {any}", .{entity});

    var buf = std.ArrayList(u8).init(testing.allocator);
    defer buf.deinit();

    try bincode.write(buf.writer(), entity, bincode.Params.standard);

    std.log.debug("serialized: {any}", .{buf.items});

    var stream = std.io.fixedBufferStream(buf.items);
    var other_entity = try bincode.read(testing.allocator, NonCustomSerializerType, stream.reader(), bincode.Params.standard);
    defer bincode.readFree(testing.allocator, other_entity);

    std.log.debug("deserialized: {any}", .{other_entity});

    try testing.expect(entity.a == other_entity.a);
    try testing.expect(entity.b == other_entity.b);
    try testing.expect(entity.c.d == other_entity.c.d);
    try testing.expect(entity.c.e == other_entity.c.e);
}

const C = struct { d: bool, e: f32 };

const ASkipStruct = struct {
    a: u32,
    b: bool,
    c: C = .{ .d = true, .e = 4.4 },

    pub const @"!bincode-config:c" = bincode.FieldConfig{ .skip = true };
};

test "skip a field" {
    testing.log_level = .debug;

    var entity = ASkipStruct{
        .a = 4,
        .b = true,
        .c = .{
            .d = false,
            .e = 3.14,
        },
    };

    std.log.debug("original {any}", .{entity});

    var buf = std.ArrayList(u8).init(testing.allocator);
    defer buf.deinit();

    try bincode.write(buf.writer(), entity, bincode.Params.standard);

    std.log.debug("serialized: {any}", .{buf.items});

    var stream = std.io.fixedBufferStream(buf.items);
    var other_entity = try bincode.read(testing.allocator, ASkipStruct, stream.reader(), bincode.Params.standard);
    defer bincode.readFree(testing.allocator, other_entity);

    std.log.debug("deserialized: {any}", .{other_entity});

    try testing.expect(entity.a == other_entity.a);
    try testing.expect(entity.b == other_entity.b);
    try testing.expect(true == other_entity.c.d);
    try testing.expect(4.4 == other_entity.c.e);
}

const SelfSerializerStruct = struct {
    some: u64,
    value: u16,

    pub const @"bincode-config" = bincode.StructConfig{
        .serializer = serializeForSelfSerializeStruct,
        .deserializer = deserializeForSelfSerializeStruct,
    };
};

// our custome serializer for ipv4
fn serializeForSelfSerializeStruct(writer: anytype, data: anytype, params: bincode.Params) !void {
    var buf: [15]u8 = undefined;
    var out = try std.fmt.bufPrint(&buf, "{}.{}", .{ data.some, data.balue });
    return try bincode.write(writer, out, params);
}

// our custome deserializer for ipv4
fn deserializeForSelfSerializeStruct(_: std.mem.Allocator, comptime T: type, reader: anytype, params: bincode.Params) !T {
    var str = try bincode.read(testing.allocator, []const u8, reader, params);
    defer bincode.readFree(testing.allocator, str);

    var out: T = undefined;
    var split = std.mem.split(u8, str, ".");

    out.some = std.fmt.parseUnsigned(u64, split.next().?, 10) catch return error.InvalidFormat;
    out.value = std.fmt.parseUnsigned(u16, split.next().?, 10) catch return error.InvalidFormat;

    return out;
}

test "custom struct serialize" {
    testing.log_level = .debug;

    var entity = SelfSerializerStruct{
        .some = 2356257257257,
        .value = 23433,
    };

    std.log.debug("original {any}", .{entity});

    var buf = std.ArrayList(u8).init(testing.allocator);
    defer buf.deinit();

    try bincode.write(buf.writer(), entity, bincode.Params.standard);

    std.log.debug("serialized: {any}", .{buf.items});

    var stream = std.io.fixedBufferStream(buf.items);
    var other_entity = try bincode.read(testing.allocator, SelfSerializerStruct, stream.reader(), bincode.Params.standard);
    defer bincode.readFree(testing.allocator, other_entity);

    std.log.debug("deserialized: {any}", .{other_entity});

    try testing.expect(entity.some == other_entity.some);
    try testing.expect(entity.value == other_entity.value);
}
