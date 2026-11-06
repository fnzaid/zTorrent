const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;
const StringHashMap = std.StringHashMap;

const Bencode = struct {
    announce: []const u8,
    @"announce list": std.ArrayList([]const u8),

    info: Info,

    const Info = struct {
        name: []const u8,
    };

    pub fn parse(
        allocator: Allocator,
        reader: *Reader,
    ) Bencode {
        _ = allocator;
        _ = reader;
    }
};

const Value = union(enum) {
    string: []const u8,
    int: i64,
    array: []Value,
    object: Object,

    const Object = StringHashMap(Value);
};

fn mapField(
    comptime T: type,
    allocator: Allocator,
    raw_value: Value,
) !T {
    _ = allocator;
    _ = raw_value;
    return T;
}

fn parseRawBuffer(reader: *Reader) !Value {
    return switch (try reader.peekByte()) {
        'i' => {
            _ = try reader.takeByte();
            const raw_int: []u8 = try reader.takeDelimiterExclusive('e');
            const parsed_int: i64 = try std.fmt.parseInt(i64, raw_int, 10);
            return .{
                .int = parsed_int,
            };
        },
        else => {
            return error.InvalidPrefix;
        },
    };
}

test "Parse raw buffers to value." {
    //   const allocator = std.testing.allocator;
    var reader: Reader = undefined;
    {
        const buffer: []const u8 = "i18e";
        reader = .fixed(buffer);

        const parsed_value = try parseRawBuffer(&reader);
        try std.testing.expectEqual(18, parsed_value.int);
    }
}
