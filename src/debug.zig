const std = @import("std");
const VM = @import("vm.zig").VM;

pub const DebugVM = struct {
    vm: *VM,

    pub fn init(vm: *VM) DebugVM {
        return .{
            .vm = vm,
        };
    }

    pub fn dumpMemory(self: *DebugVM, io: std.Io, file_path: []const u8) !void {
        var file = try std.Io.Dir.cwd().createFile(io, file_path, .{});
        defer file.close(io);

        var buffer: [4096]u8 = undefined;
        var writer = file.writer(io, &buffer);
        try writer.interface.writeAll(&self.vm.memory);
        try writer.interface.flush();
    }

    pub fn dumpState(self: *DebugVM, io: std.Io, file_path: []const u8) !void {
        var file = try std.Io.Dir.cwd().createFile(io, file_path, .{});
        defer file.close(io);

        var buffer: [4096]u8 = undefined;
        var writer = file.writer(io, &buffer);
        try writer.interface.print("PROGRAM_COUNTER={x}; STACK_POINTER={x}; STATE={any}\n", .{ self.vm.program_counter, self.vm.stack_pointer, self.vm.state });
        try writer.interface.print("REGISTERS: {any}\n", .{self.vm.registers});
        try writer.interface.flush();
    }

    pub fn printState(self: *DebugVM) void {
        std.debug.print("PROGRAM_COUNTER={x}; STACK_POINTER={x}; STATE={any}\n", .{ self.vm.program_counter, self.vm.stack_pointer, self.vm.state });
        std.debug.print("REGISTERS: {any}\n", .{self.vm.registers});
    }

    pub fn printNxtOp(self: *DebugVM) void {
        std.debug.print("NEXT_OP={any};\n", .{self.vm.peekNextOp()});
    }
};
