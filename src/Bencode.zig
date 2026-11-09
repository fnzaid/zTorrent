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
@"announce-list": []const []const u8,
comment: []const u8,
@"created by": []const u8,
@"creation date": i64,
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
    const io = std.testing.io;
    var arena: ArenaAllocator = .init(gpa);
    defer arena.deinit();

    const allocator = arena.allocator();

    const cwd = std.Io.Dir.cwd();
    const file_buffer = try cwd.readFileAlloc(io, "example-torrent/tiny-iso-test_archive.torrent", gpa, .unlimited);
    defer gpa.free(file_buffer);

    var reader: Reader = .fixed(file_buffer);

    const bencode = try parse(allocator, &reader);

    try std.testing.expectEqualStrings("http://bt1.archive.org:6969/announce", bencode.announce);
}
