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
    list: []const Value,
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

                return .{ .list = try list.toOwnedSlice(allocator) };
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

    pub fn mapField(
        self: @This(),
        comptime T: type,
        allocator: Allocator,
    ) !T {
        const type_info = @typeInfo(T);
        const out: T = undefined;

        switch (self) {
            .dict => |d| {
                const field_names = type_info.@"struct".field_names;
                const field_types = type_info.@"struct".field_types;

                for (field_names, field_types) |f_name, f_type| {
                    if (d.get(f_name)) |value| {
                        @field(out, f_name) = try unwrapFieldValue(f_type, allocator, value);
                    }
                }
            },
            else => unreachable,
        }

        return out;
    }

    fn unwrapFieldValue(comptime T: type, allocator: Allocator, v: Value) !T {
        return switch (@typeInfo(T)) {
            .pointer => |p| switch (p.size) {
                .slice => switch (p.child) {
                    u8 => switch (v) {
                        .string => |s| s,
                        else => error.InvalidType,
                    },
                    else => switch (v) {
                        .list => |l| {
                            var array_list: std.ArrayList(p.child) = .empty;

                            for (l) |val| {
                                try array_list.append(
                                    allocator,
                                    try unwrapFieldValue(p.child, allocator, val),
                                );
                            }

                            return try array_list.toOwnedSlice(allocator);
                        },
                        else => error.InvalidType,
                    },
                },
                else => error.InvalidType,
            },
            .int => |i| switch (i.signedness == .signed and i.bits == 64) {
                true => {
                    return v.integer;
                },
                false => error.InvalidType,
            },
            else => @panic("TODO: Received value unimplemented type."),
        };
    }
};

test "Parse raw buffers to Value." {
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

// TODO: Write test for mapField

test "Parse Value to zig type" {
    const gpa = std.testing.allocator;
    var arena: ArenaAllocator = .init(gpa);
    defer arena.deinit();

    const allocator = arena.allocator();

    {
        const parsed_value: Value = .{ .string = "SriLanka" };
        const unwrapped_value = try Value.unwrapFieldValue([]const u8, allocator, parsed_value);

        try std.testing.expectEqualStrings("SriLanka", unwrapped_value);
    }
    {
        const parsed_value: Value = .{ .integer = 1948 };
        const unwrapped_value = try Value.unwrapFieldValue(i64, allocator, parsed_value);

        try std.testing.expectEqual(1948, unwrapped_value);
    }
    {
        var value_list: [2]Value = .{
            .{ .string = "Sri" },
            .{ .string = "Lanka" },
        };

        const parsed_value: Value = .{ .list = &value_list };
        const unwrapped_value = try Value.unwrapFieldValue([][]const u8, allocator, parsed_value);

        try std.testing.expectEqual(2, unwrapped_value.len);
        try std.testing.expectEqualStrings("Sri", unwrapped_value[0]);
        try std.testing.expectEqualStrings("Lanka", unwrapped_value[1]);
    }
}
