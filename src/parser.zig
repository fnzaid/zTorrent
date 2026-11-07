const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const Reader = std.Io.Reader;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const Dict = StringHashMap(Value);

pub const Value = union(enum) {
    integer: i64,
    string: []const u8,
    list: []Value,
    dict: Dict,

    pub fn parseRawBuffer(allocator: Allocator, reader: *Reader) !Value {
        return switch (try reader.peekByte()) {
            '0'...'9' => {
                const raw_string_size: []u8 = try reader.takeDelimiterExclusive(':');
                const string_size: usize = try std.fmt.parseInt(usize, raw_string_size, 10);
                _ = try reader.takeByte(); // Skip the  ':' delim.

                const string: []u8 = try reader.take(string_size);
                return .{
                    .string = string,
                };
            },
            'i' => {
                _ = try reader.takeByte();
                const raw_int: []u8 = try reader.takeDelimiterExclusive('e');
                const parsed_int: i64 = try std.fmt.parseInt(i64, raw_int, 10);
                _ = try reader.takeByte(); // Skip the 'e' delim.

                return .{
                    .integer = parsed_int,
                };
            },
            'l' => {
                var list: ArrayList(Value) = .empty;

                _ = try reader.takeByte();

                while (try reader.peekByte() != 'e') {
                    const value = try parseRawBuffer(allocator, reader);
                    try list.append(allocator, value);
                }
                _ = try reader.takeByte();

                return .{ .list = list.items };
            },
            'd' => {
                var hash_map: StringHashMap(Value) = .init(allocator);
                _ = try reader.takeByte();

                while (try reader.peekByte() != 'e') {
                    const key: []const u8 = (try parseRawBuffer(allocator, reader)).string;
                    const value: Value = try parseRawBuffer(allocator, reader);

                    try hash_map.put(key, value);
                }
                _ = try reader.takeByte();

                return .{ .dict = hash_map };
            },
            else => unreachable,
        };
    }
};

pub fn mapField(
    comptime T: type,
    allocator: Allocator,
    raw_value: Value,
) !T {
    _ = allocator;
    _ = raw_value;
    return T;
}

test "Parse raw buffers to value." {
    const gpa = std.testing.allocator;
    var arena: ArenaAllocator = .init(gpa);
    defer arena.deinit();

    const allocator = arena.allocator();

    var reader: Reader = undefined;
    {
        const buffer: []const u8 = "i18e";
        reader = .fixed(buffer);

        const parsed_value = try Value.parseRawBuffer(allocator, &reader);
        try std.testing.expectEqual(18, parsed_value.integer);
    }
    {
        const buffer: []const u8 = "8:SriLanka";
        reader = .fixed(buffer);

        const parsed_value = try Value.parseRawBuffer(allocator, &reader);
        try std.testing.expectEqualStrings("SriLanka", parsed_value.string);
    }
    {
        const buffer: []const u8 = "l3:Sri5:Lankae";
        reader = .fixed(buffer);

        const parsed_value = try Value.parseRawBuffer(allocator, &reader);
        try std.testing.expectEqual(2, parsed_value.list.len);
        try std.testing.expectEqualStrings("Sri", parsed_value.list[0].string);
        try std.testing.expectEqualStrings("Lanka", parsed_value.list[1].string);
    }
    {
        const buffer: []const u8 = "d7:Country8:SriLankae";
        reader = .fixed(buffer);

        const parsed_value = try Value.parseRawBuffer(allocator, &reader);
        const has_key = parsed_value.dict.contains("Country");

        try std.testing.expectEqual(true, has_key);
        try std.testing.expectEqualStrings("SriLanka", parsed_value.dict.get("Country").?.string);
    }
    {
        const buffer: []const u8 = "d7:Country8:SriLanka5:Foodsl5:Kottu11:Pol sambola8:Kiribathe11:CountryCodei94ee";
        reader = .fixed(buffer);

        const parsed_value = try Value.parseRawBuffer(allocator, &reader);
        const dict = parsed_value.dict;

        const has_country_key: bool = dict.contains("Country");
        const has_food_key: bool = dict.contains("Foods");
        const has_c_code_key: bool = dict.contains("CountryCode");

        const foods_len: usize = dict.get("Foods").?.list.len;

        try std.testing.expectEqual(true, has_country_key);
        try std.testing.expectEqual(true, has_food_key);
        try std.testing.expectEqual(true, has_c_code_key);

        try std.testing.expectEqual(3, foods_len);

        try std.testing.expectEqualStrings("SriLanka", dict.get("Country").?.string);
        try std.testing.expectEqual(94, dict.get("CountryCode").?.integer);
    }
}
