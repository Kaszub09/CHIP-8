const std = @import("std");
const rl = @import("raylib");
const Io = std.Io;

const CHIP_8 = @import("CHIP_8_lib");
const pixel_multiplier: u8 = 16;

const octojam_title = @embedFile("octojam1title.ch8");

pub fn main(init: std.process.Init) !void {
    var iterator = try init.minimal.args.iterateAllocator(init.gpa);
    defer iterator.deinit();

    //Load defualt program, then overwrite from file if supplied
    var program: ?[]const u8 = octojam_title;
    std.debug.print("{any}", .{program.?});

    var file: ?[]u8 = null;
    _ = iterator.next(); // Skip EXE file
    if (iterator.next()) |arg_1| {
        file = try std.Io.Dir.cwd().readFileAlloc(init.io, arg_1, init.gpa, .unlimited);
        program = file;
    }
    defer if (file) |_| {
        init.gpa.free(file.?);
    };

    var vm = try CHIP_8.VM.init(init.io, program, .{}, 0);
    //var debug = CHIP_8.DebugVM.init((&vm));

    // RAYLIB
    rl.initWindow(@as(i32, CHIP_8.VM.display_width) * pixel_multiplier, @as(i32, CHIP_8.VM.display_height) * pixel_multiplier, "CHIP-8 Emulator");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        for (0..0xF) |key_hex| {
            vm.keys.is_key_pressed[key_hex] = rl.isKeyDown(get_key(@truncate(key_hex)));
        }

        _ = try vm.executeNextOp();

        // if (rl.isKeyDown(.space) or rl.isKeyPressed(.enter)) {
        //     _ = try vm.executeNextOp();
        //     debug.printNextOp();
        //     debug.printState();
        // }

        rl.clearBackground(.black);
        for (0..CHIP_8.VM.display_height) |y| {
            for (0..CHIP_8.VM.display_width) |x| {
                if (vm.getPixel(@truncate(x), @truncate(y)) == 1) {
                    rl.drawRectangle(@intCast(x * pixel_multiplier), @intCast(y * pixel_multiplier), pixel_multiplier, pixel_multiplier, .green);
                }
            }
        }
    }
}

fn get_key(hex_key: u8) rl.KeyboardKey {
    return switch (hex_key) {
        0x1 => .one,
        0x2 => .two,
        0x3 => .three,
        0xC => .four,
        0x4 => .q,
        0x5 => .w,
        0x6 => .e,
        0xD => .r,
        0x7 => .a,
        0x8 => .s,
        0x9 => .d,
        0xE => .f,
        0xA => .z,
        0x0 => .x,
        0xB => .c,
        0xF => .v,
        else => .null,
    };
}
