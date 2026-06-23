const Self = @This();

memory: [4096]u8,
program_counter: u8,
stack_pointer: u8,

const Adresses = struct {
    const stack_start: u8 = 0x0000;
    const stack_end: u8 = 0x003F;
    const scratchpad_start: u8 = 0x0040;
    const scratchpad_end: u8 = 0x004C;
    const unused_start: u8 = 0x004D;
    const unused_end: u8 = 0x00FF;
    const display_start: u8 = 0x0100;
    const display_end: u8 = 0x01FF;
    const program_start: u8 = 0x0200;
    const program_end: u8 = 0x0E8F;
    const reserved_start: u8 = 0x0E90;
    const reserved_end: u8 = 0x0FFF;
};

pub fn init() Self {
    return .{};
}

pub inline fn peekByte(self: *Self) u8 {
    return self.memory[self.program_counter];
}
