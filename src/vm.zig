const std = @import("std");
const OpCode = @import("opcode.zig");
// const Registers = @import("registers.zig");

const VTable = struct {
    display_fn: ?*const fn (display: []const u8) void = null,
    //TODO
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
    const unused_start: u16 = 0x004D;
    const unused_end: u16 = 0x00FF;
    const display_start: u16 = 0x0100;
    const display_end: u16 = 0x01FF;
    const program_start: u16 = 0x0200;
    const program_end: u16 = 0x0E8F;
    const reserved_start: u16 = 0x0E90;
    const reserved_end: u16 = 0x0FFF;
};

const Registers = struct {
    v: [16]u8 = [1]u8{0} ** 16,
    vI: u16 = 0,
};

pub const VM = struct {
    memory: [4096]u8 = undefined,
    registers: Registers = .{},
    program_counter: u16 = 0,
    /// Next free space
    stack_pointer: u16 = 0,
    state: State = .running,
    vTable: VTable = .{},

    const Display = struct {
        const x: u8 = 64;
        const y: u8 = 32;
    };

    pub fn init(program: ?[]u8, vTable: VTable) !VM {
        var vm = VM{ .vTable = vTable };
        vm.reset();
        if (program) |prog| {
            try vm.loadProgram(prog);
        }
        return vm;
    }

    pub fn reset(self: *VM) void {
        self.registers = .{};
        @memset(&self.memory, 0);
        self.state = .running;
        self.stack_pointer = MemoryAdresses.stack_start;
        self.program_counter = MemoryAdresses.program_start;
        //TODO other data?
    }

    pub fn loadProgram(self: *VM, program: []u8) !void {
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
        const operation = try self.peekNextOp();

        self.program_counter += 2; //Most instruction increments by 2, some overwrite it, so put it first

        switch (operation) {
            .no_op => {},
            .clear_screen => @memset(self.memory[MemoryAdresses.display_start..][0..MemoryAdresses.display_end], 0),
            .return_from_call => {
                self.program_counter = try self.pop(); //We pushed counter that was already incremented past call op
            },
            .jump_to => |adr| {
                self.program_counter = adr.address;
            },
            .call => |adr| {
                try self.push(self.program_counter); //We op after call
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
            //TODO
            .set_register_to_random_number_with_value_mask => |reg_val| {
                _ = reg_val;
            },
            .draw_sprite => |regs_val| {
                var display: []u8 = self.memory[MemoryAdresses.display_start..][0..MemoryAdresses.display_end];
                const sprite = self.memory[self.registers.vI..][0..regs_val.val];
                const x = self.registers.v[regs_val.regX] % VM.Display.x;
                const y = self.registers.v[regs_val.regX] % VM.Display.y;

                for (sprite, 0..) |byte, y_offset| {
                    var display_line: []u8 = display[VM.Display.x * (y + y_offset) ..][0..VM.Display.x];
                    if (x % 8 == 0) {
                        display_line[x / 8] ^= byte;
                    } else {
                        display_line[x / 8] ^= (byte >> @intCast(x % 8));
                        display_line[(x / 8) + 1] ^= (byte << @intCast(8 - (x % 8)));
                    }
                    //TODO set register
                }
                if (self.vTable.display_fn) |display_fn| display_fn(display);
            },
            else => std.debug.print("Not yet implemented {any}", .{operation}),
        }
        //std.debug.print("{any}", .{@sizeOf(OpCode.Operation)});
        return operation;
    }

    pub fn peekNextOp(self: *VM) !OpCode.Operation {
        return OpCode.getOperation(.{ self.memory[self.program_counter], self.memory[self.program_counter + 1] });
    }

    pub fn peekStack(self: *VM) []u8 {
        return self.memory[MemoryAdresses.stack_start..][0..MemoryAdresses.stack_end];
    }

    fn push(self: *VM, value: u16) !void {
        if (self.stack_pointer >= MemoryAdresses.stack_end) return error.StackOverflow;
        self.memory[self.stack_pointer] = @truncate(value >> 8);
        self.memory[self.stack_pointer + 1] = @truncate(value);
        self.stack_pointer += 2;
    }

    fn pop(self: *VM) !u16 {
        if (self.stack_pointer <= MemoryAdresses.stack_start) return error.StackUndeflow;
        self.stack_pointer -= 2;
        return (@as(u16, self.memory[self.stack_pointer]) << 8) | self.memory[self.stack_pointer + 1];
    }
};
