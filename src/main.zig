const std = @import("std");

const Bencode = @import("Bencode.zig");

fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const arena = init.arena;
}
