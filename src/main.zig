const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    var buffer: [1024]u8 = undefined;
    const commands = [_][]const u8{"echo"};

    while (true) {
        try stdout.print("$ ", .{});
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');
        if (user_input.len > 0) {
            if (std.mem.eql(u8, user_input, "exit 0")) {
                std.process.exit(0);
            }

            var command_found = false;
            var command_split = std.mem.splitSequence(u8, user_input, " ");
            if (command_split.next()) |first_word| {
                for (commands) |command| {
                    if (std.mem.eql(u8, first_word, command)) {
                        command_found = true;
                        if (std.mem.eql(u8, command, "echo")) {
                            const echo_content = user_input[5..];
                            if (echo_content.len == 0) {
                                try stdout.print("echo: missing argument\n", .{});
                            } else {
                                try stdout.print("{s}\n", .{echo_content});
                            }
                        }
                        break;
                    }
                }
            }
            if (!command_found) {
                try stdout.print("{s}: command not found\n", .{user_input});
            }
        }
    }
}
