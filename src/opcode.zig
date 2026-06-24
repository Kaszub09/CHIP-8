pub const Operation = union(enum) {
    no_op: void,
    /// 00E0
    clear_screen: void,
    /// 00EE
    return_from_subroutine: void,
    /// 1NNN
    jump_to: Adress,
    /// 2NNN
    execute_subroutine: Adress,
    /// 3XNN
    skip_next_instruction_if_register_equals_value: RegisterValue,
    /// 4XNN
    skip_next_instruction_if_register_not_equals_value: RegisterValue,
    /// 5XY0
    skip_next_instruction_if_registers_are_equal: Registers,
    /// 6XNN
    store_value_in_register: RegisterValue,
    /// 7XNN
    add_value_to_register: RegisterValue,
    /// 8XY0 VY->VX
    copy_register_value: Registers,
    /// 8XY1 VX = VX or VY
    or_registers: Registers,
    /// 8XY2 VX = VX and VY
    and_registers: Registers,
    /// 8XY3 VX = VX VXor VY
    xor_registers: Registers,
    /// 8XY4 VX = VX + VY; VF = 0 with borrrow, 1 without
    add_registers_with_carry: Registers,
    /// 8XY5 VX = VX - VY; VF = 0 with borrrow, 1 without
    subtract_registers_with_carry: Registers,
    /// 8XY6 VX = VY >> 1; F = least significant prior to shift
    shift_right_one_bit_with_carry: Registers,
    /// 8XY7 VX = VY - VX; VF = 0 with borrrow, 1 without
    subtract_registers_with_carry_another_order: Registers,
    /// 8XYE VX = VY << 1; F = least significant prior to shift
    shift_left_one_bit_with_carry: Registers,
    /// 9XY0
    skip_next_instruction_if_registers_are_not_equal: RegisterValue,
    /// ANNN
    store_address_in_vi: Adress,
    /// BNNN
    jump_to_address_plus_valu_in_v0: Adress,
    /// CXNN
    set_register_to_random_number_with_value_mask: RegisterValue,
    /// DXYN Draw sprite at VX,Y with N bytes stored at I; VF = 1 i pixels changed, 0 otherwise;
    draw_sprite: RegisterValue,
    /// EX9E
    skip_next_instruction_if_key_pressed: Register,
    /// EXA1
    skip_next_instruction_if_key_not_pressed: Register,
    /// FX07
    copy_timer_to_register: Register,
    /// FX0A
    wait_for_key_press_and_store_key_in_register: Register,
    /// FX15
    set_timer_to_register: Register,
    /// FX18
    set_sound_timer_to_register: Register,
    /// FX1E
    add_register_to_vi: Register,
    /// FX29
    set_vi_to_address_of_hex_digit_from_register: Register,
    /// FX33
    store_binary_coded_decimal_from_register_at_vi_to_vi_plus_2: Register,
    /// FX55 After op VI = VI + VX + 1
    store_v0_to_vx_inclusive_to_mem_at_vi: Register,
    /// FX65 After op VI = VI + VX + 1
    fill_v0_to_vx_inclusive_from_mem_at_vi: Register,
};

pub fn getOperation(bytes: [2]u8) !Operation {
    const first_nibble = (bytes[0] & 0xF0) >> 4;
    switch (first_nibble) {
        0x0 => switch (bytes[1]) {
            0xE0 => return .clear_screen,
            0xEE => return .return_from_subroutine,
            else => return .no_op,
        },
        0x1 => return .{ .jump_to = .init(bytes) },
        0x2 => return .{ .execute_subroutine = .init(bytes) },
        0x3 => return .{ .skip_next_instruction_if_register_equals_value = .init(bytes) },
        0x4 => return .{ .skip_next_instruction_if_register_not_equals_value = .init(bytes) },
        0x5 => {
            if ((bytes[1] & 0x0F) != 0x00) return error.Unrecognised;
            return .{ .skip_next_instruction_if_registers_are_equal = .init(bytes) };
        },
        0x6 => return .{ .store_value_in_register = .init(bytes) },
        0x7 => return .{ .add_value_to_register = .init(bytes) },
        0x8 => {
            switch (bytes[1] & 0x0F) {
                0x0 => return .{ .copy_register_value = .init(bytes) },
                0x1 => return .{ .or_registers = .init(bytes) },
                0x2 => return .{ .and_registers = .init(bytes) },
                0x3 => return .{ .xor_registers = .init(bytes) },
                0x4 => return .{ .add_registers_with_carry = .init(bytes) },
                0x5 => return .{ .subtract_registers_with_carry = .init(bytes) },
                0x6 => return .{ .shift_right_one_bit_with_carry = .init(bytes) },
                0x7 => return .{ .subtract_registers_with_carry_another_order = .init(bytes) },
                0xE => return .{ .shift_left_one_bit_with_carry = .init(bytes) },
                else => return error.Unrecognised,
            }
        },
        0x9 => {
            if ((bytes[1] & 0x0F) != 0x00) return error.Unrecognised;
            return .{ .skip_next_instruction_if_registers_are_not_equal = .init(bytes) };
        },
        0xA => return .{ .store_address_in_vi = .init(bytes) },
        0xB => return .{ .jump_to_address_plus_valu_in_v0 = .init(bytes) },
        0xC => return .{ .set_register_to_random_number_with_value_mask = .init(bytes) },
        0xD => return .{ .draw_sprite = .init(bytes) },
        0xE => {
            switch (bytes[1]) {
                0x9E => return .{ .skip_next_instruction_if_key_pressed = .init(bytes) },
                0xA1 => return .{ .skip_next_instruction_if_key_not_pressed = .init(bytes) },
                else => return error.Unrecognised,
            }
        },
        0xF => {
            switch (bytes[1]) {
                0x07 => return .{ .copy_timer_to_register = .init(bytes) },
                0x0A => return .{ .wait_for_key_press_and_store_key_in_register = .init(bytes) },
                0x15 => return .{ .set_timer_to_register = .init(bytes) },
                0x18 => return .{ .set_sound_timer_to_register = .init(bytes) },
                0x1E => return .{ .add_register_to_vi = .init(bytes) },
                0x29 => return .{ .set_vi_to_address_of_hex_digit_from_register = .init(bytes) },
                0x33 => return .{ .store_binary_coded_decimal_from_register_at_vi_to_vi_plus_2 = .init(bytes) },
                0x55 => return .{ .store_v0_to_vx_inclusive_to_mem_at_vi = .init(bytes) },
                0x65 => return .{ .fill_v0_to_vx_inclusive_from_mem_at_vi = .init(bytes) },
                else => return error.Unrecognised,
            }
        },
        else => return .no_op,
    }
}

const Adress = struct {
    address: u16,

    pub fn init(bytes: [2]u8) Adress {
        return .{ .address = (@as(u16, bytes[0] & 0x0F) << 8) | bytes[1] };
    }
};

const RegisterValue = struct {
    reg: u8,
    val: u8,

    pub fn init(bytes: [2]u8) RegisterValue {
        return .{ .reg = bytes[0] & 0x0F, .val = bytes[1] };
    }
};

const Register = struct {
    reg: u8,

    pub fn init(bytes: [2]u8) Register {
        return .{ .reg = bytes[0] & 0x0F };
    }
};

const Registers = struct {
    regX: u8,
    regY: u8,

    pub fn init(bytes: [2]u8) Registers {
        return .{ .regX = bytes[0] & 0x0F, .regY = (bytes[1] & 0xF0) >> 4 };
    }
};

const RegistersValue = struct {
    regX: u8,
    regY: u8,
    value: u8,

    pub fn init(bytes: [2]u8) RegisterValue {
        return .{ .regX = bytes[0] & 0x0F, .regY = (bytes[1] & 0xF0) >> 4, .val = bytes[1] & 0x0F };
    }
};
