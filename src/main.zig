const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    var buffer: [1024]u8 = undefined;

    while (true) {
        try stdout.print("$ ", .{});
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');
        if (user_input.len > 0) {
            if (std.mem.eql(u8, user_input, "exit 0")) {
                std.process.exit(0);
            }
            try stdout.print("{s}: command not found\n", .{user_input});
        }
    }
}
