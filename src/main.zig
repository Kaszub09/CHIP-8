const std = @import("std");
const Io = std.Io;

const CHIP_8 = @import("CHIP_8");

pub fn main(init: std.process.Init) !void {
    var program = [_]u8{ 0x61, 0x22, 0x74, 0x0, 0xD0, 0x11 };

    var vm = try CHIP_8.VM.init(init.io, &program, .{ .display_fn = display_fn });
    var debug = CHIP_8.DebugVM.init(&vm);

    debug.printState();
    debug.printNxtOp();
    _ = try vm.executeNextOp();

    debug.printState();
    debug.printNxtOp();
    _ = try vm.executeNextOp();

    debug.printState();
    debug.printNxtOp();
    _ = try vm.executeNextOp();

    //try debug.dumpMemory(init.io, "mem");
}

fn display_fn(display: []const u8) void {
    std.debug.print("{any}", .{display});
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    try std.testing.fuzz({}, testOne, .{});
}

fn testOne(context: void, smith: *std.testing.Smith) !void {
    _ = context;
    // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!

    const gpa = std.testing.allocator;
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(gpa);
    while (!smith.eos()) switch (smith.value(enum { add_data, dup_data })) {
        .add_data => {
            const slice = try list.addManyAsSlice(gpa, smith.value(u4));
            smith.bytes(slice);
        },
        .dup_data => {
            if (list.items.len == 0) continue;
            if (list.items.len > std.math.maxInt(u32)) return error.SkipZigTest;
            const len = smith.valueRangeAtMost(u32, 1, @min(32, list.items.len));
            const off = smith.valueRangeAtMost(u32, 0, @intCast(list.items.len - len));
            try list.appendSlice(gpa, list.items[off..][0..len]);
            try std.testing.expectEqualSlices(
                u8,
                list.items[off..][0..len],
                list.items[list.items.len - len ..],
            );
        },
    };
}
