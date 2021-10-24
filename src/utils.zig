const std = @import("std");

/// Sends a request or response
pub fn send(buffer: *std.ArrayList(u8), req_or_res: anytype) !void {
    buffer.items.len = 0;
    try std.json.stringify(req_or_res, .{}, buffer.writer());

    const stdout_stream = std.io.getStdOut().writer();
    try stdout_stream.print("Content-Length: {}\r\n\r\n", .{buffer.items.len});
    try stdout_stream.writeAll(buffer.items);
}
