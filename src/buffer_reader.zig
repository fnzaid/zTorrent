const BufferReader = @This();

pub const Error = error{
    /// Try to read after buffer end.
    ReadingOverflow,
};

buffer: []const u8,
cursor: usize,

pub fn init(buffer: []const u8) BufferReader {
    return .{ .buffer = buffer, .cursor = 0 };
}

pub fn readUint8(self: *BufferReader) Error!u8 {
    const buff_length = self.buffer.len;
    const read_until = self.cursor + 1;

    if (read_until > buff_length) return Error.ReadingOverflow;

    const byte: []const u8 = try self.readBytes(1);
    return byte[0];
}

pub fn readBytes(self: *BufferReader, size: usize) Error![]const u8 {
    const buff_length = self.buffer.len;
    const read_until = self.cursor + size;

    if (read_until > buff_length) return Error.ReadingOverflow;

    const data: []const u8 = self.buffer[self.cursor..size];
    self.cursor += size;
    return data;
}

const std = @import("std");

test readUint8 {
    const buffer: []const u8 = "H";
    var reader: BufferReader = .init(buffer);

    const byte: u8 = try reader.readUint8();
    try std.testing.expectEqual('H', byte);
}

test "Try to read more than lenth of buffer." {
    const buffer: []const u8 = "H";
    var reader: BufferReader = .init(buffer);

    try std.testing.expectError(Error.ReadingOverflow, reader.readBytes(6));
}
