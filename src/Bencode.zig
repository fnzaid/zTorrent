const Bencode = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const Reader = std.Io.Reader;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const Crypto = std.crypto;
const Sha1 = std.crypto.hash.Sha1;

const Parser = @import("parser.zig");
const Value = @import("parser.zig").Value;

announce: []const u8,
info: Info,
info_hash: [20]u8,

pub const empty: @This() = .{
    .announce = &.{},
    .info = .empty,
    .info_hash = @splat(0),
};

const Info = struct {
    name: []const u8,
    @"piece length": i64,
    pieces: []const u8,
    length: ?i64,
    files: []File,

    pub const empty: @This() = .{
        .name = &.{},
        .@"piece length" = 0,
        .pieces = &.{},
        .length = null,
        .files = &.{},
    };
};

const File = struct {
    length: i64,
    path: []const []const u8,

    pub const empty: @This() = .{
        .length = 0,
        .path = &.{},
    };
};

pub fn parse(
    allocator: Allocator,
    reader: *Reader,
) !Bencode {
    const parsed_value: Value = try Parser.parseRawBuffer(allocator, reader);

    var bencode = try parsed_value.mapField(Bencode, allocator);
    const raw_info: []u8 = try Parser.extractRawInfoBytes(reader);

    Sha1.hash(raw_info, &bencode.info_hash, .{});

    return bencode;
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
