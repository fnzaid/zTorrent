const std = @import("std");

const io = std.Io;
const mem = std.mem;
const fmt = std.fmt;

// i need something in middle, like after parsing from bencode and before parsing to struct.
// What was i need to build in middle ?
//      - from(Value) -> decode -> Where capture dict and do shit like innerParse from std.json look there.
const Value = union(enum) {
    const Dict = std.array_hash_map.String(Value);

    number: i64,
    string: []const u8,
    list: []Value,
    dict: Dict,
};

pub fn value(arena: mem.Allocator, r: *io.Reader) !Value {
    return switch (try r.peekByte()) {
        '0'...'9' => {
            const length_raw = try r.takeDelimiterExclusive(':');
            _ = try r.takeByte();

            const string = try r.take(try fmt.parseInt(
                usize,
                length_raw,
                10,
            ));
            return .{
                .string = string,
            };
        },
        'i' => {
            _ = try r.takeByte();
            const number_raw = try r.takeDelimiterExclusive('e');
            _ = try r.takeByte();

            const number: i64 = try fmt.parseInt(
                i64,
                number_raw,
                10,
            );
            return .{
                .number = number,
            };
        },
        'l' => {
            var list: std.ArrayList(Value) = .empty;
            _ = try r.takeByte();

            while (try r.peekByte() != 'e') try list.append(
                arena,
                try value(arena, r),
            );
            return .{
                .list = list.items,
            };
        },
        'd' => {
            var dict: Value.Dict = .empty;
            _ = try r.takeByte();

            while (try r.peekByte() != 'e') {
                const key_struct: Value = try value(arena, r);
                try dict.put(
                    arena,
                    key_struct.string,
                    try value(arena, r),
                );
            }
            return .{ .dict = dict };
        },
        else => {
            return error.InvalidPrefix;
        },
    };
}

pub fn field(comptime F: type, arena: mem.Allocator, v: Value) !F {
    switch (@typeInfo(F)) {
        .int => {
            return v.number;
        },
        .pointer => |p| switch (p.size) {
            .slice => {
                return try arena.dupe(u8, v.string);
            },
            else => {
                return error.InvalidString;
            },
        },
        else => {
            return error.InvalidType;
        },
    }
}

pub fn decode(comptime T: type, arena: mem.Allocator, r: *io.Reader) !T {
    const info = @typeInfo(T).@"struct";
    var out: T = undefined;
    const parsed_value = try value(arena, r);

    switch (parsed_value) {
        .dict => |d| {
            for (d.keys(), d.values()) |k, v| {
                inline for (info.field_names, info.field_types) |n, F| {
                    if (std.mem.eql(u8, k, n)) {
                        @field(out, n) = try field(F, arena, v);
                    }
                }
            }
        },
        else => {
            return error.InvalidType;
        },
    }

    return out;
}

const Bencode = struct {
    announce: []const u8,
};

pub fn main(init: std.process.Init) !void {
    const arena = init.arena;

    const gpa = init.gpa;
    const allocator = arena.allocator();
    const cwd = std.Io.Dir.cwd();

    const file_buffer = try cwd.readFileAlloc(init.io, "example-torrent/tiny-iso-test_archive.torrent", gpa, .unlimited);
    defer gpa.free(file_buffer);

    var reader: io.Reader = .fixed(file_buffer);
    const bencode: Bencode = try decode(Bencode, allocator, &reader);

    std.debug.print("Announce: {s}\n", .{bencode.announce});

    //    const parsed_str: Value = try value(gpa, &reader);
    //    const parsed_num: Value = try value(gpa, &reader);
    //    const parsed_list: Value = try value(gpa, &reader);
    //   const parsed_dict: Value = try value(gpa, &reader);
    //    std.debug.print("Parsed: {s} | {d} | {any}\n | {any} | \n", .{
    //        parsed_str.string,
    //        parsed_num.number,
    //        parsed_list.list,
    //        parsed_dict.dict,
    //    });
    // std.debug.print("Dict: {s}\n", .{parsed_dict.dict.get("name").?.string});
    // std.debug.print("TypeInfo: \n : {any}", .{@TypeOf(parsed_dict)});
}
