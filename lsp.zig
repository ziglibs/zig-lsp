const std = @import("std");

pub const RequestHeader = @import("src/RequestHeader.zig");
pub const offsets = @import("src/offsets.zig");
pub const types = struct {
    pub const common = @import("src/types/common.zig");
    pub const requests = @import("src/types/requests.zig");
    pub const responses = @import("src/types/responses.zig");
};

/// Sends a request or response
pub fn send(buffer: *std.ArrayList(u8), req_or_res: anytype) !void {
    buffer.items.len = 0;
    try std.json.stringify(req_or_res, .{}, buffer.writer());

    const stdout_stream = std.io.getStdOut().writer();
    try stdout_stream.print("Content-Length: {}\r\n\r\n", .{buffer.items.len});
    try stdout_stream.writeAll(buffer.items);
}
