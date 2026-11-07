const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const Reader = std.Io.Reader;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const value = @import("parser.zig");
const Value = value.Value;

const Bencode = @This();

const Info = struct {
    name: []const u8,
};

announce: []const u8,
@"announce list": ArrayList([]const u8),
info: Info,

pub fn parse(
    allocator: Allocator,
    reader: *Reader,
) Bencode {
    _ = allocator;
    _ = reader;
}
