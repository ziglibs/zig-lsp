const std = @import("std");
const tres = @import("tres");
const Header = @import("Header.zig");
pub const types = @import("types.zig");

pub const MessageKind = enum { request, notification, response };
pub fn messageKind(method: []const u8) MessageKind {
    inline for (types.notification_metadata) |notif| {
        if (std.mem.eql(u8, method, notif.method)) return .notification;
    }

    inline for (types.request_metadata) |req| {
        if (std.mem.eql(u8, method, req.method)) return .request;
    }

    @panic("Couldn't find method");
}

pub fn Params(comptime method: []const u8) type {
    for (types.notification_metadata) |notif| {
        if (std.mem.eql(u8, method, notif.method)) return notif.Params orelse void;
    }

    for (types.request_metadata) |req| {
        if (std.mem.eql(u8, method, req.method)) return req.Params orelse void;
    }

    @compileError("Couldn't find params for method named " ++ method);
}

pub fn Result(comptime method: []const u8) type {
    for (types.request_metadata) |req| {
        if (std.mem.eql(u8, method, req.method)) return req.Result;
    }

    @compileError("Couldn't find result for method named " ++ method);
}

pub fn Payload(comptime method: []const u8, comptime kind: MessageKind) type {
    return switch (kind) {
        .request, .notification => Params(method),
        .response => Result(method),
    };
}

const StoredCallback = struct {
    method: []const u8,
    onResponse: *const fn () void,
    onError: *const fn () void,
};
pub fn RequestCallback(
    comptime ConnectionType: type,
    comptime method: []const u8,
) type {
    return struct {
        const Self = @This();

        const OnResponse = *const fn (conn: *ConnectionType, result: Result(method)) anyerror!void;
        const OnError = *const fn (conn: *ConnectionType) anyerror!void;

        onResponse: OnResponse,
        onError: OnError,

        pub fn store(self: Self) StoredCallback {
            return .{
                .method = method,
                .onResponse = @ptrCast(*const fn () void, self.onResponse),
                .onError = @ptrCast(*const fn () void, self.onError),
            };
        }

        pub fn unstore(stored: StoredCallback) Self {
            return .{
                .onResponse = @ptrCast(OnResponse, stored.onResponse),
                .onError = @ptrCast(OnError, stored.onError),
            };
        }
    };
}

pub fn connection(allocator: std.mem.Allocator, reader: anytype, writer: anytype, context: anytype) Connection(@TypeOf(reader), @TypeOf(writer), @TypeOf(context)) {
    return Connection(@TypeOf(reader), @TypeOf(writer), @TypeOf(context)).init(allocator, reader, writer, context);
}

pub fn Connection(
    comptime ReaderType: type,
    comptime WriterType: type,
    comptime ContextType: type,
) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        reader: ReaderType,
        writer: WriterType,
        context: *ContextType,
        _resdata: *anyopaque = undefined,

        id: usize = 0,
        write_buffer: std.ArrayListUnmanaged(u8) = .{},

        // TODO: Handle string ids
        callback_map: std.AutoHashMapUnmanaged(usize, StoredCallback) = .{},

        pub fn init(
            allocator: std.mem.Allocator,
            reader: ReaderType,
            writer: WriterType,
            context: *ContextType,
        ) Self {
            return .{
                .allocator = allocator,
                .reader = reader,
                .writer = writer,
                .context = context,
            };
        }

        pub fn send(
            conn: *Self,
            value: anytype,
        ) !void {
            conn.write_buffer.items.len = 0;
            try tres.stringify(value, .{}, conn.write_buffer.writer(conn.allocator));

            try Header.encode(.{
                .content_length = conn.write_buffer.items.len,
            }, conn.writer);
            try conn.writer.writeAll(conn.write_buffer.items);
        }

        pub fn notify(
            conn: *Self,
            comptime method: []const u8,
            params: Params(method),
        ) !void {
            if (comptime messageKind(method) != .notification)
                @compileError("Cannot send request as notification");

            if (@hasDecl(ContextType, "lspSendPre"))
                try ContextType.lspSendPre(conn, method, .notification, null, params);

            try conn.send(.{
                .jsonrpc = "2.0",
                .method = method,
                .params = params,
            });

            if (@hasDecl(ContextType, "lspSendPost"))
                try ContextType.lspSendPost(conn, method, .notification, null, params);
        }

        pub fn request(
            conn: *Self,
            comptime method: []const u8,
            params: Params(method),
            callback: RequestCallback(Self, method),
        ) !void {
            if (comptime messageKind(method) != .request)
                @compileError("Cannot send notification as request");

            if (@hasDecl(ContextType, "lspSendPre"))
                try ContextType.lspSendPre(conn, method, .request, .{ .integer = @intCast(i64, conn.id) }, params);

            try conn.send(.{
                .jsonrpc = "2.0",
                .id = conn.id,
                .method = method,
                .params = params,
            });

            try conn.callback_map.put(conn.allocator, conn.id, callback.store());

            conn.id +%= 1;

            if (@hasDecl(ContextType, "lspSendPost"))
                try ContextType.lspSendPost(conn, method, .request, .{ .integer = @intCast(i64, conn.id -% 1) }, params);
        }

        pub fn requestSync(
            conn: *Self,
            arena: std.mem.Allocator,
            comptime method: []const u8,
            params: Params(method),
        ) !Result(method) {
            var resdata: Result(method) = undefined;
            conn._resdata = &resdata;

            const cb = struct {
                pub fn res(conn_: *Self, result: Result(method)) !void {
                    @ptrCast(*Result(method), @alignCast(@alignOf(Result(method)), conn_._resdata)).* = result;
                }

                pub fn err(_: *Self) !void {}
            };

            try conn.request(method, params, .{ .onResponse = cb.res, .onError = cb.err });
            try conn.acceptUntilResponse(arena);

            return resdata;
        }

        pub fn respond(
            conn: *Self,
            comptime method: []const u8,
            id: types.RequestId,
            result: Result(method),
        ) !void {
            if (@hasDecl(ContextType, "lspSendPre"))
                try ContextType.lspSendPre(conn, method, .response, id, result);

            try conn.send(.{
                .jsonrpc = "2.0",
                .id = id,
                .result = result,
            });

            if (@hasDecl(ContextType, "lspSendPost"))
                try ContextType.lspSendPost(conn, method, .response, id, result);
        }

        pub fn accept(conn: *Self, arena: std.mem.Allocator) !void {
            const allocator = arena;

            const header = try Header.decode(allocator, conn.reader);

            var data = try allocator.alloc(u8, header.content_length);
            _ = try conn.reader.readAll(data);

            var parser = std.json.Parser.init(allocator, false);
            defer parser.deinit();

            var tree = (try parser.parse(data)).root;

            // There are three cases at this point:
            // 1. We have a request (id + method)
            // 2. We have a response (id)
            // 3. We have a notification (method)

            const maybe_id = tree.Object.get("id");
            const maybe_method = tree.Object.get("method");

            if (maybe_id != null and maybe_method != null) {
                const id = try tres.parse(types.RequestId, maybe_id.?, allocator);
                const method = maybe_method.?.String;

                inline for (types.request_metadata) |req| {
                    if (@hasDecl(ContextType, req.method)) {
                        if (std.mem.eql(u8, req.method, method)) {
                            @setEvalBranchQuota(100_000);
                            const value = try tres.parse(Params(req.method), tree.Object.get("params").?, allocator);
                            if (@hasDecl(ContextType, "lspRecvPre")) try ContextType.lspRecvPre(conn, req.method, .request, id, value);
                            try conn.respond(req.method, id, try @field(ContextType, req.method)(conn, id, value));
                            if (@hasDecl(ContextType, "lspRecvPost")) try ContextType.lspRecvPost(conn, req.method, .request, id, value);
                            return;
                        }
                    }
                }

                // TODO: Are ids shared between server and client or not? If not, we can remove the line below
                conn.id +%= 1;

                std.log.warn("Request not handled: {s}", .{method});
                try conn.send(.{
                    .jsonrpc = "2.0",
                    .id = id,
                    .@"error" = .{ .code = -32601, .message = "NotImplemented" },
                });
            } else if (maybe_id) |id_raw| {
                @setEvalBranchQuota(100_000);

                // TODO: Handle errors
                const id = try tres.parse(types.RequestId, id_raw, allocator);
                const iid = @intCast(usize, id.integer);

                const entry = conn.callback_map.fetchRemove(iid) orelse @panic("nothing!");
                inline for (types.request_metadata) |req| {
                    if (std.mem.eql(u8, req.method, entry.value.method)) {
                        const value = try tres.parse(Result(req.method), tree.Object.get("result").?, allocator);
                        if (@hasDecl(ContextType, "lspRecvPre")) try ContextType.lspRecvPre(conn, req.method, .response, id, value);
                        try (RequestCallback(Self, req.method).unstore(entry.value).onResponse(conn, value));
                        if (@hasDecl(ContextType, "lspRecvPost")) try ContextType.lspRecvPost(conn, req.method, .response, id, value);
                        return;
                    }
                }

                std.log.warn("Received unhandled response: {d}", .{iid});
            } else if (maybe_method) |method| {
                inline for (types.notification_metadata) |notif| {
                    if (@hasDecl(ContextType, notif.method)) {
                        if (std.mem.eql(u8, notif.method, method.String)) {
                            const value = try tres.parse(Params(notif.method), tree.Object.get("params").?, allocator);
                            if (@hasDecl(ContextType, "lspRecvPre")) try ContextType.lspRecvPre(conn, notif.method, .notification, null, value);
                            try @field(ContextType, notif.method)(conn, value);
                            if (@hasDecl(ContextType, "lspRecvPost")) try ContextType.lspRecvPost(conn, notif.method, .notification, null, value);
                            return;
                        }
                    }
                }

                std.log.warn("Notification not handled: {s}", .{method.String});
            } else {
                @panic("Invalid JSON-RPC message.");
            }
        }

        pub fn acceptUntilResponse(conn: *Self, arena: std.mem.Allocator) !void {
            const initial_size = conn.callback_map.size;
            while (true) {
                try conn.accept(arena);
                if (initial_size != conn.callback_map.size) return;
            }
        }
    };
}
