const std = @import("std");
const VM = @import("vm.zig").VM;

pub const DebugVM = struct {
    vm: *VM,

    pub fn init(vm: *VM) DebugVM {
        return .{
            .vm = vm,
        };
    }

    pub fn printRegisters(self: *DebugVM) void {
        std.debug.print("REGISTERS: {any}\n", .{self.vm.registers});
    }
};
