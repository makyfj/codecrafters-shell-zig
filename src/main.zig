const std = @import("std");

const Command = enum {
    echo,
    type,
    exit,
    pwd,
    cd,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

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

            try handleCommand(user_input, stdout, allocator);
        }
    }
}

fn handleCommand(user_input: []const u8, stdout: anytype, allocator: std.mem.Allocator) !void {
    var command_split = std.mem.splitSequence(u8, user_input, " ");
    if (command_split.next()) |first_word| {
        if (std.meta.stringToEnum(Command, first_word)) |command| {
            switch (command) {
                .echo => try handleEcho(user_input, stdout),
                .type => try handleType(user_input, stdout, allocator),
                .pwd, .cd => try handleBuiltin(user_input, stdout, allocator),
                .exit => std.process.exit(0),
            }
            return;
        }

        if (try findExecutable(first_word, allocator)) |path| {

            // Create an ArrayList to store command arguments
            var args = std.ArrayList([]const u8).init(allocator);
            defer args.deinit();

            // Add the executable path as the first argument
            try args.append(path);

            // Iterate through the rest of the command arguments
            while (command_split.next()) |arg| {
                try args.append(arg);
            }

            // Initialize a child process with the arguments
            var child = std.process.Child.init(args.items, allocator);

            // Spawn the child process and wait for it to complete
            _ = try child.spawnAndWait();
        } else {
            try stdout.print("{s}: command not found\n", .{user_input});
        }
    }
}

fn handleEcho(user_input: []const u8, stdout: anytype) !void {
    const echo_content = user_input[5..];
    if (echo_content.len == 0) {
        try stdout.print("echo: missing argument\n", .{});
    } else {
        try stdout.print("{s}\n", .{echo_content});
    }
}

fn handleType(user_input: []const u8, stdout: anytype, allocator: std.mem.Allocator) !void {
    const type_content = user_input[5..];
    if (type_content.len == 0) {
        try stdout.print("type: missing argument\n", .{});
    } else {
        if (std.meta.stringToEnum(Command, type_content)) |_| {
            try stdout.print("{s} is a shell builtin\n", .{type_content});
        } else if (try findExecutable(type_content, allocator)) |path| {
            try stdout.print("{s} is {s}\n", .{ type_content, path });
        } else {
            try stdout.print("{s}: not found\n", .{type_content});
        }
    }
}

fn findExecutable(command: []const u8, allocator: std.mem.Allocator) !?[]const u8 {
    // Get the environment variables map and use the provided memeory allocator
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    // Check if the PATH environment variable exists
    if (env_map.get("PATH")) |path_str| {
        // Split the PATH string into individual directories
        var it = std.mem.splitSequence(u8, path_str, ":");
        while (it.next()) |dir| {
            // Construct the full path by joining the directory and command
            const full_path = try std.fs.path.join(allocator, &[_][]const u8{ dir, command });
            defer allocator.free(full_path);
            // Check if the path is absolute
            if (std.fs.path.isAbsolute(full_path)) {
                // Try to access the file
                if (std.fs.cwd().access(full_path, .{})) |_| {
                    // If successful, return a duplicate of the full path
                    return try allocator.dupe(u8, full_path);
                } else |err| switch (err) {
                    // If file not found, continue to the next directory
                    error.FileNotFound => continue,
                    // For other errors, return the error
                    else => return err,
                }
            }
        }
    }
    // If the executable is not found, return null
    return null;
}

fn handleBuiltin(user_input: []const u8, stdout: anytype, allocator: std.mem.Allocator) !void {
    var command_split = std.mem.splitSequence(u8, user_input, " ");

    // Get the first word, which should be the command
    if (command_split.next()) |command| {
        if (std.mem.eql(u8, command, "pwd")) {
            const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");
            defer allocator.free(cwd);
            // Print the current working directory
            try stdout.print("{s}\n", .{cwd});
        } else if (std.mem.eql(u8, command, "cd")) {
            // Get the next argument after the "cd" command
            const maybe_args = command_split.next();
            // Initialize a variable to hold the owned path string
            var path_owned: ?[]u8 = null;
            // Ensure the owned path is freed when we're done
            defer if (path_owned) |p| allocator.free(p);

            // Determine the path to change to
            const path = if (maybe_args) |args| blk: {
                if (std.mem.eql(u8, args, "~")) {
                    // If the argument is "~", get the HOME environment variable
                    path_owned = std.process.getEnvVarOwned(allocator, "HOME") catch {
                        try stdout.print("cd: HOME not set\n", .{});
                        return;
                    };
                    break :blk path_owned.?;
                } else {
                    // Otherwise, use the provided argument
                    break :blk args;
                }
            } else blk: {
                // If no argument is provided, default to HOME
                path_owned = std.process.getEnvVarOwned(allocator, "HOME") catch {
                    try stdout.print("cd: HOME not set\n", .{});
                    return;
                };
                break :blk path_owned.?;
            };

            // Attempt to change the current working directory
            std.process.changeCurDir(path) catch {
                // If changing directory fails, print an error message
                try stdout.print("cd: {s}: No such file or directory\n", .{path});
            };
        }
    }
}
