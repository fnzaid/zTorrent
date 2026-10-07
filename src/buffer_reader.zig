const BufferReader = @This();

buffer: []const u8,
cursor: u64 = 0,

pub fn init(buffer: []const u8) BufferReader {
    return .{ .buffer = buffer, .cursor = 0 };
}

pub fn readUint8(self: *BufferReader) !u8 {
    const buffer_len = self.buffer.len;
    const read_len = self.cursor + 1;
    if (buffer_len < read_len) {
        return error.EndOfBuffer;
    }

    const byte = self.buffer[self.cursor];
    self.cursor += 1;
    return byte;
}

pub fn readBytes(self: *BufferReader, size: usize) ![]const u8 {
    const buffer_len = self.buffer.len;
    const read_len = self.cursor + size;
    if (buffer_len < read_len) {
        return error.EndOfBuffer;
    }

    const bytes: []const u8 = self.buffer[self.cursor..read_len];
    self.cursor += size;
    return bytes;
}

pub fn fallbackUint8(self: *BufferReader) void {
    self.cursor -= 1;
}

pub fn findNearestScalar(self: *BufferReader, value: u8) ?usize {
    const slice = self.buffer[self.cursor..self.buffer.len];
    return std.mem.indexOfScalar(u8, slice, value);
}

const std = @import("std");

const testing = std.testing;

test "Read one byte." {
    const buff: []const u8 = "Test";
    var decoder: BufferReader = .init(buff);

    const read_one_byte = try decoder.readUint8();

    try testing.expectEqual(@as(u8, 0x54), read_one_byte);
}

test "Fail on read after End of buffer." {
    const buff: []const u8 = "Test";

    var decoder: BufferReader = .init(buff);

    decoder.cursor = 4;

    try testing.expectError(error.EndOfBuffer, decoder.readUint8());
}
