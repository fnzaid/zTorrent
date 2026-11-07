const Bencode = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const Reader = std.Io.Reader;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

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
) Bencode {
    _ = allocator;
    _ = reader;
}
