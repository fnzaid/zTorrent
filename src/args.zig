const std = @import("std");
const Io = std.Io;
const Reader = Io.Reader;
const Process = std.process;
const ProcessArgs = Process.Args;

const usage =
    \\Usage: zTorrent [options] [file]
    \\
    \\Options: 
    \\  No options yet.
    \\
    \\
;

pub const Args = struct {
    torrent_file: ?[]const u8,
};

pub fn parse_args(io: Io, args: ProcessArgs) !Args {
    var iterater = args.iterate();
    _ = iterater.skip();
    var out: Args = .{ .torrent_file = null };

    while (iterater.next()) |arg| {
        if (std.mem.eql(u8, "-h", arg) or std.mem.eql(u8, "--help", arg)) {
            try writeToStdout(io, usage);
        } else {
            const has_file = try validTorrentFilePath(arg);

            if (!has_file) {
                const default_msg: []const u8 = "Try 'zTorrent -h' or 'zTorrent --help' for more information.\n";
                try writeToStdout(io, default_msg);
                return out;
            }

            out.torrent_file = arg;
        }
    }

    return out;
}

fn validTorrentFilePath(path: []const u8) !bool {
    if (path.len < 9) return false;

    var reader: Reader = .fixed(path);

    _ = try reader.discard(.limited(reader.end - 8));

    const torrent_ext = try reader.take(8);

    return std.mem.eql(u8, ".torrent", torrent_ext);
}

fn writeToStdout(io: Io, bytes: []const u8) !void {
    try Io.File.stdout().writeStreamingAll(
        io,
        bytes,
    );
}
