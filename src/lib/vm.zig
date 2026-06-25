const std = @import("std");
const OpCode = @import("opcode.zig");
// const Registers = @import("registers.zig");

const VTable = struct {
    display_updated: ?*const fn (display: []const u8) void = null,
};

const State = enum {
    halt,
    running,
};

const MemoryAdresses = struct {
    const stack_start: u16 = 0x0000;
    const stack_end: u16 = 0x003F;
    const scratchpad_start: u16 = 0x0040;
    const scratchpad_end: u16 = 0x004C;
    /// We will store fonts there
    const unused_start: u16 = 0x004D;
    const unused_end: u16 = 0x00FF;
    const display_start: u16 = 0x0100;
    const display_end: u16 = 0x01FF;
    const program_start: u16 = 0x0200;
    const program_end: u16 = 0x0E8F;
    const reserved_start: u16 = 0x0E90;
    const reserved_end: u16 = 0x0FFF;
};

const Timer = struct {
    value: u8 = 0,
    last_tick_at: std.Io.Timestamp = undefined,
};

const Keys = struct {
    is_key_pressed: [16]bool = [1]bool{false} ** 16,
};

const Registers = struct {
    v: [16]u8 = [1]u8{0} ** 16,
    vI: u16 = 0,
};

pub const VM = struct {
    pub const display_width: u8 = 64;
    pub const display_height: u8 = 32;
    pub const display_width_in_bytes: u8 = 8;

    memory: [4096]u8 = undefined,
    registers: Registers = .{},
    program_counter: u16 = 0,
    /// Next free space
    stack_pointer: u16 = 0,
    state: State = .running,
    vTable: VTable = .{},
    keys: Keys = .{},
    io: std.Io,
    delay_timer: Timer = .{},
    sound_timer: Timer = .{},
    rand: std.Random.Xoshiro256,

    pub fn init(io: std.Io, program: ?[]const u8, vTable: VTable, seed: u64) !VM {
        var vm = VM{
            .vTable = vTable,
            .io = io,
            .rand = std.Random.DefaultPrng.init(seed),
        };

        vm.reset();
        if (program) |prog| {
            try vm.loadProgram(prog);
        }
        return vm;
    }

    pub fn reset(self: *VM) void {
        self.registers = .{};
        @memset(&self.memory, 0);
        const font_data = [_]u8{
            0xF0, 0x90, 0x90, 0x90, 0xF0,
            0x20, 0x60, 0x20, 0x20, 0x70,
            0xF0, 0x10, 0xF0, 0x80, 0xF0,
            0xF0, 0x10, 0xF0, 0x10, 0xF0,
            0x90, 0x90, 0xF0, 0x10, 0x10,
            0xF0, 0x80, 0xF0, 0x10, 0xF0,
            0xF0, 0x80, 0xF0, 0x90, 0xF0,
            0xF0, 0x10, 0x20, 0x40, 0x40,
            0xF0, 0x90, 0xF0, 0x90, 0xF0,
            0xF0, 0x90, 0xF0, 0x10, 0xF0,
            0xF0, 0x90, 0xF0, 0x90, 0x90,
            0xE0, 0x90, 0xE0, 0x90, 0xE0,
            0xF0, 0x80, 0x80, 0x80, 0xF0,
            0xE0, 0x90, 0x90, 0x90, 0xE0,
            0xF0, 0x80, 0xF0, 0x80, 0xF0,
            0xF0, 0x80, 0xF0, 0x80, 0x80,
        };
        @memcpy(self.memory[MemoryAdresses.unused_start..][0..font_data.len], &font_data);
        self.state = .running;
        self.stack_pointer = MemoryAdresses.stack_start;
        self.program_counter = MemoryAdresses.program_start;
        //TODO other data?

    }

    pub fn loadProgram(self: *VM, program: []const u8) !void {
        if (program.len > MemoryAdresses.program_end - MemoryAdresses.program_start) {
            return error.ProgramTooLarge;
        }
        @memcpy(self.memory[MemoryAdresses.program_start..][0..program.len], program);
        self.program_counter = MemoryAdresses.program_start;
        self.state = .running;
    }

    pub fn run(self: *VM) !void {
        self.state == .running;
        while (self.state == .running) {
            try self.executeNextOp();
        }
    }

    pub fn executeNextOp(self: *VM) !OpCode.Operation {
        if (self.delay_timer.value > 0) {
            if (self.delay_timer.last_tick_at.untilNow(self.io, .real).toMilliseconds() > (1000 / 60)) {
                self.delay_timer.value -= 1;
                self.delay_timer.last_tick_at = std.Io.Timestamp.now(self.io, .real);
            }
        }
        if (self.sound_timer.value > 0) {
            if (self.sound_timer.last_tick_at.untilNow(self.io, .real).toMilliseconds() > (1000 / 60)) {
                self.sound_timer.value -= 1;
                self.sound_timer.last_tick_at = std.Io.Timestamp.now(self.io, .real);
            }
        }

        const operation = self.peekNextOp();

        self.program_counter += 2; //Most instruction increments by 2, some overwrite it, so put it first

        switch (operation) {
            .no_op => {},
            .clear_screen => @memset(self.memory[MemoryAdresses.display_start..MemoryAdresses.display_end], 0),
            .return_from_call => {
                self.program_counter = try self.popStack(); //We pushed counter that was already incremented past call op
            },
            .jump_to => |adr| {
                self.program_counter = adr.address;
            },
            .call => |adr| {
                try self.pushStack(self.program_counter); //We op after call
                self.program_counter = adr.address;
            },
            .skip_next_op_if_register_equals_value => |reg_val| {
                if (self.registers.v[reg_val.reg] == reg_val.val) {
                    self.program_counter += 2;
                }
            },
            .skip_next_op_if_register_not_equals_value => |reg_val| {
                if (self.registers.v[reg_val.reg] != reg_val.val) {
                    self.program_counter += 2;
                }
            },
            .skip_next_op_if_registers_are_equal => |regs| {
                if (self.registers.v[regs.regX] == self.registers.v[regs.regY]) {
                    self.program_counter += 2;
                }
            },
            .store_value_in_register => |reg_val| self.registers.v[reg_val.reg] = reg_val.val,
            .add_value_to_register => |reg_val| self.registers.v[reg_val.reg] +%= reg_val.val,
            .copy_register_value => |regs| self.registers.v[regs.regX] = self.registers.v[regs.regY],
            .or_registers => |regs| self.registers.v[regs.regX] |= self.registers.v[regs.regY],
            .and_registers => |regs| self.registers.v[regs.regX] &= self.registers.v[regs.regY],
            .xor_registers => |regs| self.registers.v[regs.regX] ^= self.registers.v[regs.regY],
            .add_registers_with_carry => |regs| {
                self.registers.v[0xF] = if (self.registers.v[regs.regX] <= 0xFF - self.registers.v[regs.regY]) 0 else 1;
                self.registers.v[regs.regX] +%= self.registers.v[regs.regY];
            },
            .subtract_registers_with_carry => |regs| {
                self.registers.v[0xF] = if (self.registers.v[regs.regX] >= self.registers.v[regs.regY]) 1 else 0;
                self.registers.v[regs.regX] -%= self.registers.v[regs.regY];
            },
            .shift_right_one_bit_with_carry => |regs| {
                self.registers.v[0xF] = self.registers.v[regs.regY] & 0b1;
                self.registers.v[regs.regX] = self.registers.v[regs.regY] >> 1;
            },
            .subtract_registers_with_carry_another_order => |regs| {
                self.registers.v[0xF] = if (self.registers.v[regs.regY] >= self.registers.v[regs.regX]) 1 else 0;
                self.registers.v[regs.regX] = self.registers.v[regs.regY] -% self.registers.v[regs.regX];
            },
            .shift_left_one_bit_with_carry => |regs| {
                self.registers.v[0xF] = self.registers.v[regs.regY] & 0b10000000;
                self.registers.v[regs.regX] = self.registers.v[regs.regY] << 1;
            },
            .skip_next_op_if_registers_are_not_equal => |regs| {
                if (self.registers.v[regs.regX] != self.registers.v[regs.regY]) {
                    self.program_counter += 2;
                }
            },
            .store_address_in_vi => |adr| self.registers.vI = adr.address,
            .jump_to_address_plus_value_in_v0 => |adr| self.program_counter = adr.address + self.registers.v[0x0],
            .set_register_to_random_number_with_value_mask => |reg_val| self.registers.v[reg_val.reg] = @truncate(reg_val.val & self.rand.next()),
            .draw_sprite => |regs_val| {
                const sprite = self.memory[self.registers.vI..][0..regs_val.val];
                const x_start = self.registers.v[regs_val.regX] % VM.display_width;
                const y_start = self.registers.v[regs_val.regY] % VM.display_height;

                self.registers.v[0xF] = 0;

                for (sprite, 0..) |byte, y_offset| {
                    for (0..8) |bit_offset| {
                        const x: u8 = x_start + @as(u8, @truncate(bit_offset));
                        const y: u8 = y_start + @as(u8, @truncate(y_offset));
                        if (x >= VM.display_width) continue;
                        if (y >= VM.display_height) continue;

                        const pixel: u8 = (byte >> @truncate(7 - bit_offset)) & 0x1;

                        //std.debug.print("x={d},y = {d}, spirte_pixel = {d}, getPixel ={d}= \n", .{ x, y, pixel, self.getPixel(x, y) });

                        // if (pixel == 0) continue; //XORing 0 doens't do anything

                        if (self.getPixel(x, y) == 0x1) self.registers.v[0xF] = 1;

                        self.xorPixel(x, y, pixel);
                    }
                }
            },
            .skip_next_op_if_key_pressed => |reg| {
                if (self.keys.is_key_pressed[reg.reg]) {
                    self.program_counter += 2;
                }
            },
            .skip_next_op_if_key_not_pressed => |reg| {
                if (!self.keys.is_key_pressed[reg.reg]) {
                    self.program_counter += 2;
                }
            },
            .copy_timer_to_register => |reg| self.registers.v[reg.reg] = self.delay_timer.value,
            .wait_for_key_press_and_store_key_in_register => |reg| {
                var pressed_key: ?u8 = null;
                for (0..self.keys.is_key_pressed.len) |key_hex| {
                    if (self.keys.is_key_pressed[key_hex]) {
                        pressed_key = @truncate(key_hex);
                        break;
                    }
                }

                if (pressed_key) |pressed_key_val| {
                    self.registers.v[reg.reg] = pressed_key_val;
                } else {
                    self.program_counter -= 2;
                }
            },
            .set_timer_to_register => |reg| {
                self.delay_timer = .{ .value = self.registers.v[reg.reg], .last_tick_at = std.Io.Timestamp.now(self.io, .real) };
            },
            .set_sound_timer_to_register => |reg| {
                self.sound_timer = .{ .value = self.registers.v[reg.reg], .last_tick_at = std.Io.Timestamp.now(self.io, .real) };
            },
            .add_register_to_vi => |reg| self.registers.vI += self.registers.v[reg.reg],
            .set_vi_to_address_of_hex_digit_from_register => |reg| self.registers.vI = MemoryAdresses.unused_start + 5 * self.registers.v[reg.reg],
            .store_binary_coded_decimal_from_register_at_vi_to_vi_plus_2 => |reg| {
                const memory_to_write_into = self.memory[self.registers.vI..][0..3];
                const val = self.registers.v[reg.reg];
                memory_to_write_into[0] = val / 100;
                memory_to_write_into[1] = (val / 10) % 10;
                memory_to_write_into[2] = val % 10;
            },
            .store_v0_to_vx_inclusive_to_mem_at_vi => |reg| {
                const memory_to_write_into = self.memory[self.registers.vI..];
                for (0..self.registers.v[reg.reg]) |i| {
                    memory_to_write_into[i] = self.registers.v[i];
                }
                memory_to_write_into[reg.reg] = self.registers.v[reg.reg];
                self.registers.vI += self.registers.v[reg.reg] + 1;
            },
            .fill_v0_to_vx_inclusive_from_mem_at_vi => |reg| {
                const memory_to_read_from = self.memory[self.registers.vI..];
                for (0..self.registers.v[reg.reg]) |i| {
                    self.registers.v[i] = memory_to_read_from[i];
                }
                self.registers.v[reg.reg] = memory_to_read_from[reg.reg];
                self.registers.vI += self.registers.v[reg.reg] + 1;
            },
            .unrecognised => {
                std.debug.print("Unrecognised, halting execution {any}", .{operation});
                self.state = .halt;
            },
        }
        return operation;
    }

    pub fn peekNextOp(self: *VM) OpCode.Operation {
        return OpCode.getOperation(.{ self.memory[self.program_counter], self.memory[self.program_counter + 1] });
    }

    pub fn peekStack(self: *VM) []u8 {
        return self.memory[MemoryAdresses.stack_start..][0..MemoryAdresses.stack_end];
    }

    fn pushStack(self: *VM, value: u16) !void {
        if (self.stack_pointer >= MemoryAdresses.stack_end) return error.StackOverflow;
        self.memory[self.stack_pointer] = @truncate(value >> 8);
        self.memory[self.stack_pointer + 1] = @truncate(value);
        self.stack_pointer += 2;
    }

    fn popStack(self: *VM) !u16 {
        if (self.stack_pointer <= MemoryAdresses.stack_start) return error.StackUndeflow;
        self.stack_pointer -= 2;
        return (@as(u16, self.memory[self.stack_pointer]) << 8) | self.memory[self.stack_pointer + 1];
    }

    pub fn getPixel(self: *VM, x: u8, y: u8) u8 {
        const line = self.getDisplayLine(y);
        return (line[x / 8] >> @intCast(x % 8)) & 0x1;
    }

    pub fn xorPixel(self: *VM, x: u8, y: u8, pixel: u8) void {
        const line = self.getDisplayLine(y);
        line[x / 8] ^= pixel << @intCast(x % 8);
    }

    fn getDisplayLine(self: *VM, y: u8) []u8 {
        return self.memory[MemoryAdresses.display_start..][display_width_in_bytes * y ..][0..display_width_in_bytes];
    }
};
