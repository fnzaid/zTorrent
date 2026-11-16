const std = @import("std");
const Process = std.process;
const Reader = std.Io.Reader;

const arg = @import("args.zig");
const Args = arg.Args;

const Bencode = @import("Bencode.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const args = try arg.parse_args(io, init.minimal.args);

    if (args.torrent_file == null) return Process.cleanExit(init.io);

    const gpa = init.gpa;
    const arena = init.arena;
    const arena_allocator = arena.allocator();

    const cwd = std.Io.Dir.cwd();
    const file_buffer = try cwd.readFileAlloc(io, args.torrent_file.?, gpa, .unlimited);
    defer gpa.free(file_buffer);

    var reader: Reader = .fixed(file_buffer);

    const bencode = try Bencode.parse(arena_allocator, &reader);
    //TODO: Read https://www.bittorrent.org/beps/bep_0003.html `peer protocol` and implement.

    std.debug.print("Announce: {s}\n Name: {s}\n Content Size: {d}b\n Pieces: {d}\n", .{
        bencode.announce,
        bencode.info.name,
        bencode.info.@"piece length",
        bencode.info.files.len,
    });
    for (bencode.info.files) |f| {
        const path = try std.mem.join(arena_allocator, "/", f.path);
        std.debug.print("File Size: {d}b\n Path: {s}\n", .{ f.length, path });
    }

    return Process.cleanExit(init.io);
}
