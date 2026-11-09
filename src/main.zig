const std = @import("std");
const Reader = std.Io.Reader;

const Bencode = @import("Bencode.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const gpa = init.gpa;
    const arena = init.arena;
    const arena_allocator = arena.allocator();

    const cwd = std.Io.Dir.cwd();
    const file_buffer = try cwd.readFileAlloc(io, "example-torrent/tiny-iso-test_archive.torrent", gpa, .unlimited);
    defer gpa.free(file_buffer);

    var reader: Reader = .fixed(file_buffer);

    const bencode = try Bencode.parse(arena_allocator, &reader);
    std.debug.print("Bencode: {any}\n", .{bencode});
    //TODO: Read https://www.bittorrent.org/beps/bep_0003.html `peer protocol` and implement.
}
