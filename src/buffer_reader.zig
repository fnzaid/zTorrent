const BufferReader = @This();

pub const Error = error{
    /// Read after buffer end.
    ReadingOverflow,

    /// No equal delimeter found.
    NoDelimFound,
};

buffer: []const u8,
cursor: usize,

pub fn init(buffer: []const u8) BufferReader {
    return .{ .buffer = buffer, .cursor = 0 };
}

pub fn peek(self: *BufferReader) Error!u8 {
    const buff_length = self.buffer.len;
    const read_until = self.cursor + 1;

    if (read_until > buff_length) return Error.ReadingOverflow;

    const byte: u8 = self.buffer[self.cursor];
    return byte;
}

pub fn readUint8(self: *BufferReader) Error!u8 {
    const buff_length = self.buffer.len;
    const read_until = self.cursor + 1;

    if (read_until > buff_length) return Error.ReadingOverflow;

    const byte: []const u8 = try self.readBytes(1);
    return byte[0];
}

pub fn readBytes(self: *BufferReader, length: usize) Error![]const u8 {
    const buff_length = self.buffer.len;
    const read_until = self.cursor + length;

    if (read_until > buff_length) return Error.ReadingOverflow;

    const data: []const u8 = self.buffer[self.cursor..length];
    self.cursor += length;
    return data;
}

pub fn delimOffset(self: *BufferReader, delim: u8) Error!usize {
    var offset: usize = 0;

    // TODO: i need to find a way to read each byte without getting cursor moved.
    while (self.readUint8()) |byte| {
        if (byte == delim) break;

        offset += 1;
    } else |err| {
        return err;
    }

    return offset;
}

const std = @import("std");

test peek {
    const buffer: []const u8 = "PeekMe";
    var reader: BufferReader = .init(buffer);

    const byte: u8 = try reader.peek();
    try std.testing.expectEqual('P', byte);
    try std.testing.expectEqual(0, reader.cursor);
}

test "Peek more than buffer length" {
    const buffer: []const u8 = "PeekMe";
    var reader: BufferReader = .init(buffer);

    reader.cursor += 10;

    try std.testing.expectError(Error.ReadingOverflow, reader.peek());
}

test readUint8 {
    const buffer: []const u8 = "H";
    var reader: BufferReader = .init(buffer);

    const byte: u8 = try reader.readUint8();
    try std.testing.expectEqual('H', byte);
    try std.testing.expectEqual(1, reader.cursor);
}

test readBytes {
    const buffer: []const u8 = "Hello!";
    var reader: BufferReader = .init(buffer);

    const string: []const u8 = try reader.readBytes(6);
    try std.testing.expectEqual("Hello!", string);
    try std.testing.expectEqual(6, reader.cursor);
}

test "Try to read more than length of buffer." {
    const buffer: []const u8 = "H";
    var reader: BufferReader = .init(buffer);

    try std.testing.expectError(Error.ReadingOverflow, reader.readBytes(6));
}
