const std = @import("std");
// const Registers = @import("registers.zig");

const State = enum {
    initial,
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
    I: u16 = 0,
};

pub const VM = struct {
    memory: [4096]u8 = undefined,
    registers: Registers = .{},
    program_counter: u16 = 0,
    stack_pointer: u16 = 0,
    state: State = .initial,

    pub fn init(program: ?[]u8) !VM {
        var vm = VM{};
        vm.reset();
        if (program) |prog| {
            try vm.loadProgram(prog);
        }
        return vm;
    }

    pub fn loadProgram(self: *VM, program: []u8) !void {
        if (program.len > MemoryAdresses.program_end - MemoryAdresses.program_start) {
            return error.ProgramSizeTooLarge;
        }
        @memcpy(self.memory[MemoryAdresses.program_start..][0..program.len], program);
        self.program_counter = MemoryAdresses.program_start;
        self.state = .initial;
    }

    pub fn reset(self: *VM) void {
        self.registers = .{};
        @memset(&self.memory, 0);
        self.state = .halt;
        self.stack_pointer = MemoryAdresses.stack_start;
        //TODO other data?
    }

    pub fn run(self: *VM) void {
        self.state == .executing;
        while (self.state == .executing) {
            self.execute();
        }
    }

    pub fn executeNextInstruction(self: *VM) void {
        const opcode = (@as(u16, self.memory[self.program_counter]) << 8) | self.memory[self.program_counter + 1];
        const first_nibble: u4 = @intCast((opcode & 0xF000) >> 12);

        std.debug.print("OP={x}\n", .{opcode});
        std.debug.print("NIB={x}\n", .{first_nibble});
        switch (first_nibble) {
            0x6 => {
                const register_index: u4 = @intCast((opcode & 0x0F00) >> 8);
                self.registers.v[register_index] = @intCast(opcode & 0x00FF);
            },
            else => {},
        }
        self.program_counter += 2;
    }
};
