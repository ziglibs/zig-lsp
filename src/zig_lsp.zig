const std = @import("std");
const tres = @import("tres");
const Header = @import("Header.zig");
pub const types = @import("types.zig");

const log = std.log.scoped(.zig_lsp);

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
        const OnError = *const fn (conn: *ConnectionType, err: types.ResponseError) anyerror!void;

        onResponse: OnResponse,
        onError: OnError,

        pub fn store(self: Self) StoredCallback {
            return .{
                .method = method,
                .onResponse = @ptrCast(self.onResponse),
                .onError = @ptrCast(self.onError),
            };
        }

        pub fn unstore(stored: StoredCallback) Self {
            return .{
                .onResponse = @ptrCast(stored.onResponse),
                .onError = @ptrCast(stored.onError),
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

        id: usize = 0,
        write_buffer: std.ArrayListUnmanaged(u8) = .{},

        // TODO: Handle string ids
        callback_map: std.AutoHashMapUnmanaged(usize, StoredCallback) = .{},

        _resdata: *anyopaque = undefined,

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

            if (@hasDecl(ContextType, "dataSend")) try ContextType.dataSend(conn, conn.write_buffer.items);

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
                try ContextType.lspSendPre(conn, method, .request, .{ .integer = @intCast(conn.id) }, params);

            try conn.send(.{
                .jsonrpc = "2.0",
                .id = conn.id,
                .method = method,
                .params = params,
            });

            try conn.callback_map.put(conn.allocator, conn.id, callback.store());

            conn.id +%= 1;

            if (@hasDecl(ContextType, "lspSendPost"))
                try ContextType.lspSendPost(conn, method, .request, .{ .integer = @intCast(conn.id -% 1) }, params);
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
                    @as(*Result(method), @ptrCast(@alignCast(conn_._resdata))).* = result;
                }

                pub fn err(_: *Self, resperr: types.ResponseError) !void {
                    return switch (resperr.code) {
                        @intFromEnum(types.ErrorCodes.ParseError) => error.ParseError,
                        @intFromEnum(types.ErrorCodes.InvalidRequest) => error.InvalidRequest,
                        @intFromEnum(types.ErrorCodes.MethodNotFound) => error.MethodNotFound,
                        @intFromEnum(types.ErrorCodes.InvalidParams) => error.InvalidParams,
                        @intFromEnum(types.ErrorCodes.InternalError) => error.InternalError,
                        @intFromEnum(types.ErrorCodes.ServerNotInitialized) => error.ServerNotInitialized,
                        @intFromEnum(types.ErrorCodes.UnknownErrorCode) => error.UnknownErrorCode,
                        else => error.InternalError,
                    };
                }
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

        pub fn respondError(
            conn: *Self,
            arena: std.mem.Allocator,
            id: types.RequestId,
            err: anyerror,
            error_return_trace: ?*std.builtin.StackTrace,
        ) !void {
            const error_code: types.ErrorCodes = switch (err) {
                error.ParseError => .ParseError,
                error.InvalidRequest => .InvalidRequest,
                error.MethodNotFound => .MethodNotFound,
                error.InvalidParams => .InvalidParams,
                error.InternalError => .InternalError,

                error.ServerNotInitialized => .ServerNotInitialized,
                error.UnknownErrorCode => .UnknownErrorCode,

                else => .InternalError,
            };

            log.err("{s}", .{@errorName(err)});
            if (error_return_trace) |trace| {
                std.debug.dumpStackTrace(trace.*);
            }

            try conn.send(.{
                .jsonrpc = "2.0",
                .id = id,
                .@"error" = types.ResponseError{
                    .code = @intFromEnum(error_code),
                    .message = if (error_return_trace) |ert|
                        try std.fmt.allocPrint(arena, "{s}: {any}", .{ @errorName(err), ert })
                    else
                        try std.fmt.allocPrint(arena, "{s}: No error return trace available", .{@errorName(err)}),
                },
            });
        }

        pub fn accept(conn: *Self, arena: std.mem.Allocator) !void {
            const allocator = arena;

            const header = try Header.decode(allocator, conn.reader);

            var data = try allocator.alloc(u8, header.content_length);
            _ = try conn.reader.readAll(data);

            if (@hasDecl(ContextType, "dataRecv")) try ContextType.dataRecv(conn, data);

            var root = try std.json.parseFromSliceLeaky(std.json.Value, arena, data, .{});

            // There are three cases at this point:
            // 1. We have a request (id + method)
            // 2. We have a response (id)
            // 3. We have a notification (method)

            const maybe_id = root.object.get("id");
            const maybe_method = root.object.get("method");

            if (maybe_id != null and maybe_method != null) {
                const id = try tres.parse(types.RequestId, maybe_id.?, allocator);
                const method = maybe_method.?.string;

                inline for (types.request_metadata) |req| {
                    if (@hasDecl(ContextType, req.method)) {
                        if (std.mem.eql(u8, req.method, method)) {
                            @setEvalBranchQuota(100_000);
                            const value = try tres.parse(Params(req.method), root.object.get("params").?, allocator);
                            if (@hasDecl(ContextType, "lspRecvPre")) try ContextType.lspRecvPre(conn, req.method, .request, id, value);
                            try conn.respond(req.method, id, @field(ContextType, req.method)(conn, id, value) catch |err| {
                                try conn.respondError(arena, id, err, @errorReturnTrace());
                                if (@hasDecl(ContextType, "lspRecvPost")) try ContextType.lspRecvPost(conn, req.method, .request, id, value);
                                return;
                            });
                            if (@hasDecl(ContextType, "lspRecvPost")) try ContextType.lspRecvPost(conn, req.method, .request, id, value);
                            return;
                        }
                    }
                }

                // TODO: Are ids shared between server and client or not? If not, we can remove the line below
                conn.id +%= 1;

                log.warn("Request not handled: {s}", .{method});
                try conn.send(.{
                    .jsonrpc = "2.0",
                    .id = id,
                    .@"error" = .{ .code = -32601, .message = "NotImplemented" },
                });
            } else if (maybe_id) |id_raw| {
                @setEvalBranchQuota(100_000);

                // TODO: Handle errors
                const id = try tres.parse(types.RequestId, id_raw, allocator);
                const iid: usize = @intCast(id.integer);

                const entry = conn.callback_map.fetchRemove(iid) orelse @panic("nothing!");
                inline for (types.request_metadata) |req| {
                    if (std.mem.eql(u8, req.method, entry.value.method)) {
                        const value = try tres.parse(Result(req.method), root.object.get("result") orelse {
                            const response_error = try tres.parse(types.ResponseError, root.object.get("error").?, allocator);
                            try (RequestCallback(Self, req.method).unstore(entry.value).onError(conn, response_error));
                            return;
                        }, allocator);
                        if (@hasDecl(ContextType, "lspRecvPre")) try ContextType.lspRecvPre(conn, req.method, .response, id, value);
                        try (RequestCallback(Self, req.method).unstore(entry.value).onResponse(conn, value));
                        if (@hasDecl(ContextType, "lspRecvPost")) try ContextType.lspRecvPost(conn, req.method, .response, id, value);
                        return;
                    }
                }

                log.warn("Received unhandled response: {d}", .{iid});
            } else if (maybe_method) |method| {
                inline for (types.notification_metadata) |notif| {
                    if (@hasDecl(ContextType, notif.method)) {
                        if (std.mem.eql(u8, notif.method, method.string)) {
                            const value = try tres.parse(Params(notif.method), root.object.get("params").?, allocator);
                            if (@hasDecl(ContextType, "lspRecvPre")) try ContextType.lspRecvPre(conn, notif.method, .notification, null, value);
                            try @field(ContextType, notif.method)(conn, value);
                            if (@hasDecl(ContextType, "lspRecvPost")) try ContextType.lspRecvPost(conn, notif.method, .notification, null, value);
                            return;
                        }
                    }
                }

                log.warn("Notification not handled: {s}", .{method.string});
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
