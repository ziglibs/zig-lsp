const Server = @This();

const std = @import("std");
const json = @import("json.zig");
const utils = @import("utils.zig");
const types = @import("types.zig");
const offsets = @import("offsets.zig");
const RequestHeader = @import("RequestHeader.zig");

pub const ServerMessage = union(enum) {
    request: types.requests.RequestMessage,
    notification: types.notifications.NotificationMessage,

    pub fn encode(self: ServerMessage, writer: anytype) @TypeOf(writer).Error!void {
        try json.stringify(self, .{}, writer);
    }

    pub fn decode(allocator: *std.mem.Allocator, buf: []const u8) !ServerMessage {
        @setEvalBranchQuota(10_000);

        return (try json.parse(ServerMessageParseTarget, &json.TokenStream.init(buf), .{
            .allocator = allocator,
            .ignore_unknown_fields = true,
        })).toMessage();
    }
};

const ServerMessageParseTarget = union(enum) {
    request: types.requests.RequestParseTarget,
    notification: types.notifications.NotificationParseTarget,

    pub fn toMessage(self: ServerMessageParseTarget) ServerMessage {
        return switch (self) {
            .request => |r| .{ .request = r.toMessage() },
            .notification => |n| .{ .notification = n.toMessage() },
        };
    }
};

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

/// Reads a message (request or notification).
/// Caller must call `flushArena` after use.
pub fn readMessage(self: *Server) !ServerMessage {
    const stdin = std.io.getStdIn().reader();

    var header_buf: [128]u8 = undefined;
    var header = try RequestHeader.decode(stdin, &header_buf);

    try self.read_buf.ensureTotalCapacity(header.content_length);
    self.read_buf.items.len = header.content_length;
    _ = try stdin.readAll(self.read_buf.items[0..header.content_length]);

    std.debug.print("{s}\n", .{self.read_buf.items});

    return try ServerMessage.decode(&self.arena.allocator, self.read_buf.items);
}

pub fn flushArena(self: *Server) void {
    self.arena.deinit();
    self.arena.state = .{};
}

pub fn respond(self: *Server, request: types.requests.RequestMessage, result: types.responses.ResponseParams) !void {
    try utils.send(&self.write_buf, types.responses.ResponseMessage{
        .id = request.id,
        .result = result,
    });
}

/// Processes an `initialize` message
/// * Sets the offset encoding
pub fn processInitialize(self: *Server, initalize: types.general.InitializeParams) void {
    for (initalize.capabilities.offsetEncoding) |encoding| {
        if (std.mem.eql(u8, encoding, "utf-8")) {
            self.offset_encoding = .utf8;
        }
    }
}
