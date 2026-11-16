const Self = @This();

const Event = enum([]const u8) {
    started = "started",
    completed = "completed",
    stopped = "stopped",
};

allocator: Allocator,
/// The 20 byte sha1 hash of the bencode form of the `info` value.
info_hash: [20]u8,
/// A string of length 20 which this tracker uses as it's id.
peer_id: [20]u8,
/// Total amount uploaded so far.
uploaded: usize,
/// Total amount downloaded so far.
downloaded: usize,
/// The number of bytes so far left to download.
left: usize,

pub fn init(allocator: Allocator, info_hash: [20]u8) Self {
    var peer_id_bytes: []u8 = @splat(0);
    const random: Random.Xoshiro256 = .init(8);
    const rand_id = random.random().bytes(&peer_id_bytes);
    return .{
        .allocator = allocator,
        .info_hash = info_hash,
        .peer_id = crypto.hash.Sha1.init(.{}).hash(rand_id),
    };
}

const crypto = std.crypto;

const Random = std.Random;
const Allocator = std.mem.Allocator;

const std = @import("std");
