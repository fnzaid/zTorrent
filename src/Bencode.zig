const Bencode = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const Reader = std.Io.Reader;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const Parser = @import("parser.zig");
const Value = @import("parser.zig").Value;

announce: []const u8,
@"announce list": []const []const u8,
info: Info,

const Info = struct {
    name: []const u8,
};

pub fn parse(
    allocator: Allocator,
    reader: *Reader,
) !Bencode {
    const parsed_value: Value = try Parser.parseRawBuffer(allocator, reader);

    return try parsed_value.mapField(Bencode, allocator);
}

test parse {
    const gpa = std.testing.allocator;
    var arena: ArenaAllocator = .init(gpa);
    defer arena.deinit();

    const allocator = arena.allocator();

    const buffer: []const u8 = "d8:announce17:https://test.teste";
    var reader: Reader = .fixed(buffer);

    const bencode = try parse(allocator, &reader);

    try std.testing.expectEqualStrings("https://test.test", bencode.announce);
}
