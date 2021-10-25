const Server = @This();

const std = @import("std");
const utils = @import("utils.zig");
const offsets = @import("offsets.zig");
const requests = @import("types/requests.zig");
const responses = @import("types/responses.zig");
const RequestHeader = @import("RequestHeader.zig");

allocator: *std.mem.Allocator,
arena: std.heap.ArenaAllocator,
offset_encoding: offsets.Encoding,

read_buf: std.ArrayList(u8),
write_buf: std.ArrayList(u8),

pub fn init(allocator: *std.mem.Allocator) !Server {
    return Server{
        .allocator = allocator,
        .arena = std.heap.ArenaAllocator.init(allocator),
        .offset_encoding = .utf16,

        .read_buf = try std.ArrayList(u8).initCapacity(allocator, 1024),
        .write_buf = try std.ArrayList(u8).initCapacity(allocator, 1024),
    };
}

/// Caller must call `flushArena` after use.
pub fn readRequest(self: *Server) !requests.RequestMessage {
    const stdin = std.io.getStdIn().reader();

    var header_buf: [128]u8 = undefined;
    var header = try RequestHeader.decode(stdin, &header_buf);

    try self.read_buf.ensureTotalCapacity(header.content_length);
    self.read_buf.items.len = header.content_length;
    _ = try stdin.readAll(self.read_buf.items[0..header.content_length]);

    std.debug.print("{s}\n", .{self.read_buf.items});

    return try requests.RequestMessage.decode(&self.arena.allocator, self.read_buf.items);
}

pub fn flushArena(self: *Server) void {
    self.arena.deinit();
    self.arena.state = .{};
}

pub fn respond(self: *Server, request: requests.RequestMessage, result: responses.ResponseParams) !void {
    if (request.id == .none) @panic("Cannot respond to notifications!");

    try utils.send(&self.write_buf, responses.ResponseMessage{
        .id = request.id,
        .result = result,
    });
}

/// Processes an `initialize` message
/// * Sets the offset encoding
pub fn processInitialize(self: *Server, initalize: requests.InitializeParams) void {
    for (initalize.capabilities.offsetEncoding) |encoding| {
        if (std.mem.eql(u8, encoding, "utf-8")) {
            self.offset_encoding = .utf8;
        }
    }
}
