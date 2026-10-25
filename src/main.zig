const std = @import("std");

const io = std.Io;
const mem = std.mem;
const fmt = std.fmt;

//TODO: dict need to be arraylist with Value Type or smth i guess.
const Value = union(enum) {
    const Dict = std.array_hash_map.String(Value);

    number: i64,
    string: []const u8,
    list: []Value,
    dict: Dict,
};

pub fn value(allocator: mem.Allocator, r: *io.Reader) !Value {
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
                allocator,
                try value(allocator, r),
            );
            return .{
                .list = list.items,
            };
        },
        'd' => {
            var dict: Value.Dict = .empty;
            _ = try r.takeByte();

            // Will trust it will always be a string.
            const key_struct: Value = try value(allocator, r);
            while (try r.peekByte() != 'e') try dict.put(
                allocator,
                key_struct.string,
                try value(allocator, r),
            );

            return .{ .dict = dict };
        },
        else => {
            return .{ .number = 1 };
        },
    };
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena;
    const gpa = arena.allocator();

    const bencode: []const u8 = "d4:name4:zaide";
    var reader: io.Reader = .fixed(bencode);

    //    const parsed_str: Value = try value(gpa, &reader);
    //    const parsed_num: Value = try value(gpa, &reader);
    //    const parsed_list: Value = try value(gpa, &reader);
    const parsed_dict: Value = try value(gpa, &reader);
    //    std.debug.print("Parsed: {s} | {d} | {any}\n | {any} | \n", .{
    //        parsed_str.string,
    //        parsed_num.number,
    //        parsed_list.list,
    //        parsed_dict.dict,
    //    });
    std.debug.print("Dict: {s}\n", .{parsed_dict.dict.get("name").?.string});
}
