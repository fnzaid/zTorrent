// bencoding
// Strings are length-prefixed base ten followed by a colon and the string.
// For example 4:spam corresponds to 'spam'.
// Integers are represented by an 'i' followed by the number in base 10 followed by an 'e'.
// For example i3e corresponds to 3 and i-3e corresponds to -3.
// Integers have no size limitation. i-0e is invalid.
// All encodings with a leading zero, such as i03e, are invalid, other than i0e, which of course corresponds to 0.
// Lists are encoded as an 'l' followed by their elements (also bencoded) followed by an 'e'.
// For example l4:spam4:eggse corresponds to ['spam', 'eggs'].
// Dictionaries are encoded as a 'd' followed by a list of alternating keys and their corresponding values followed by an 'e'. For example, d3:cow3:moo4:spam4:eggse corresponds to {'cow': 'moo', 'spam': 'eggs'} and d4:spaml1:a1:bee corresponds to {'spam': ['a', 'b']}. Keys must be strings and appear in sorted order (sorted as raw strings, not alphanumerics).

const Parser = @This();

const std = @import("std");

const fmt = std.fmt;
const testing = std.testing;

const Allocator = std.mem.Allocator;

const BufferReader = @import("./buffer_reader.zig");

const Error = error{InvalidBencodePrefix};

gpa: Allocator,

/// BufferReader helper
reader: *BufferReader,

pub fn init(gpa: Allocator, reader: *BufferReader) Parser {
    return .{ .gpa = gpa, .reader = reader };
}

pub fn parse(self: *Parser) !void {
    var reader = self.reader;
    while (reader.peek()) |byte| {
        switch (byte) {
            '0'...'9' => {
                self.parseString();
            },
            'i' => {
                self.parseInt();
            },
            else => {
                return Error.InvalidBencodePrefix;
            },
        }
    } else |err| {
        return err;
    }
}

fn parseString(self: *const Parser) ![]const u8 {
    const reader = self.reader;

    const delim_offset: usize = try reader.delimOffset(':');
    const size_bytes: []const u8 = try reader.readBytes(delim_offset - 1);
    _ = try reader.readUint8();
    const size: usize = try fmt.parseUnsigned(u8, size_bytes, 10);

    const string: []const u8 = try reader.readBytes(size);
    return string;
}

fn parseInt(self: *const Parser) !i64 {
    const reader = self.reader;

    _ = try reader.readUint8();
    const delim_offset: usize = try reader.delimOffset('e');
    const size_bytes: []const u8 = try reader.readBytes(delim_offset - 1);
    _ = try reader.readUint8();
    const parsed_int: i64 = try fmt.parseInt(i64, size_bytes, 10);

    return parsed_int;
}

test parseString {
    const buffer: []const u8 = "11:HelloWorld!";
    var reader: BufferReader = .init(buffer);

    const gpa = testing.allocator;

    const parser: Parser = .init(gpa, &reader);
    const string: []const u8 = try parser.parseString();

    try testing.expectEqualStrings("HelloWorld!", string);
}

test "Invalid string length-prefixed" {
    const buffer: []const u8 = "100:HelloWorld!";
    var reader: BufferReader = .init(buffer);

    const gpa = testing.allocator;

    const parser: Parser = .init(gpa, &reader);
    try testing.expectError(error.EndOfStream, parser.parseString());
}

test parseInt {
    const buffer: []const u8 = "i123456789e";
    var reader: BufferReader = .init(buffer);

    const gpa = testing.allocator;

    const parser: Parser = .init(gpa, &reader);
    const parsed_int: i64 = try parser.parseInt();
    try testing.expectEqual(123456789, parsed_int);
}

test "Try to parse invalid integer" {
    const buffer: []const u8 = "i22te";
    var reader: BufferReader = .init(buffer);

    const gpa = testing.allocator;

    const parser: Parser = .init(gpa, &reader);
    try testing.expectError(error.InvalidCharacter, parser.parseInt());
}
