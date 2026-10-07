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

const BufferReader = @import("buffer_reader.zig");

const Bencode = struct {
    gpa: std.mem.Allocator,
    buff_reader: *BufferReader,

    const Self = @This();

    pub fn init(gpa: std.mem.Allocator, buff_reader: *BufferReader) Bencode {
        return .{ .gpa = gpa, .buff_reader = buff_reader };
    }

    pub fn parse(self: *const Self) ![]const u8 {
        while (self.buff_reader.readUint8()) |byte| {
            switch (byte) {
                49...57 => {
                    var size_str_arr: std.ArrayList(u8) = .empty;
                    {
                        try size_str_arr.append(self.gpa, byte);
                        while (self.buff_reader.readUint8()) |b| {
                            switch (b) {
                                49...57 => {
                                    try size_str_arr.append(self.gpa, b);
                                },
                                58 => {
                                    break;
                                },
                                else => {
                                    return error.InvalidStringLength;
                                },
                            }
                        } else |err| {
                            return err;
                        }
                    }

                    const string_length_int: usize = try std.fmt.parseUnsigned(u8, size_str_arr.items, 10);
                    const string: []const u8 = try self.buff_reader.readBytes(string_length_int);
                    size_str_arr.deinit(self.gpa);
                    return string;
                },
                else => {
                    std.debug.print(" else Byte: {any}\n", .{byte});
                },
            }
        } else |err| {
            return err;
        }
    }

    fn parse_string(self: *const Self, size: usize) ![]const u8 {
        const string: []const u8 = try self.buff_reader.readBytes(size);
        return string;
    }
};

const std = @import("std");

const testing = std.testing;

test "Parse valid string 4 bytes." {
    const test_t_buff: []const u8 = "4:test";
    var buff_reader: BufferReader = .init(test_t_buff);

    const tpa = testing.allocator;

    const decoder: Bencode = .init(tpa, &buff_reader);

    const parsed_string = try decoder.parse();

    const expected_string: []const u8 = "test";
    try testing.expectEqualStrings(expected_string, parsed_string);
}

test "Parse a valid large size string." {
    const test_t_buff: []const u8 = "11:LmaoLmaoLma";
    var buff_reader: BufferReader = .init(test_t_buff);

    const tpa = testing.allocator;

    const decoder: Bencode = .init(tpa, &buff_reader);

    const parsed_string = try decoder.parse();

    const expected_string: []const u8 = "LmaoLmaoLma";
    try testing.expectEqualStrings(expected_string, parsed_string);
}
