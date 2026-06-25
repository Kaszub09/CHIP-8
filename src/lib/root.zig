//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;

pub const VM = @import("vm.zig").VM;
pub const DebugVM = @import("debug.zig").DebugVM;
