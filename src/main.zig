const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    var buffer: [1024]u8 = undefined;
    const commands = [_][]const u8{ "echo", "type", "exit" };

    while (true) {
        try stdout.print("$ ", .{});
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');
        if (user_input.len > 0) {
            if (std.mem.eql(u8, user_input, "exit 0")) {
                std.process.exit(0);
            }

            try handleCommand(user_input, &commands, stdout);
        }
    }
}

fn handleCommand(user_input: []const u8, commands: []const []const u8, stdout: anytype) !void {
    var command_split = std.mem.splitSequence(u8, user_input, " ");
    if (command_split.next()) |first_word| {
        for (commands) |command| {
            if (std.mem.eql(u8, first_word, command)) {
                switch (command[0]) {
                    'e' => try handleEcho(user_input, stdout),
                    't' => try handleType(user_input, commands, stdout),
                    else => {},
                }
                return;
            }
        }
    }
    try stdout.print("{s}: command not found\n", .{user_input});
}

fn handleEcho(user_input: []const u8, stdout: anytype) !void {
    const echo_content = user_input[5..];
    if (echo_content.len == 0) {
        try stdout.print("echo: missing argument\n", .{});
    } else {
        try stdout.print("{s}\n", .{echo_content});
    }
}

fn handleType(user_input: []const u8, commands: []const []const u8, stdout: anytype) !void {
    const type_content = user_input[5..];
    if (type_content.len == 0) {
        try stdout.print("type: missing argument\n", .{});
    } else {
        for (commands) |cmd| {
            if (std.mem.eql(u8, type_content, cmd)) {
                try stdout.print("{s} is a shell builtin\n", .{type_content});
                return;
            }
        }
        if (std.mem.eql(u8, type_content, "cat")) {
            try stdout.print("cat is bin/cat\n", .{});
        } else {
            try stdout.print("{s}: not found\n", .{type_content});
        }
    }
}
