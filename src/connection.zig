const std = @import("std");
const tres = @import("tres");
const Header = @import("Header.zig");
const lsp = @import("lsp.zig");

pub fn NotificationParams(comptime method: []const u8) type {
    for (lsp.notification_metadata) |notif| {
        if (std.mem.eql(u8, method, notif.method)) return notif.Params orelse void;
    }

    @compileError("Couldn't find notification named " ++ method);
}

pub fn RequestParams(comptime method: []const u8) type {
    for (lsp.request_metadata) |req| {
        if (std.mem.eql(u8, method, req.method)) return req.Params orelse void;
    }

    @compileError("Couldn't find notification named " ++ method);
}

pub fn RequestResult(comptime method: []const u8) type {
    for (lsp.request_metadata) |req| {
        if (std.mem.eql(u8, method, req.method)) return req.Result;
    }

    @compileError("Couldn't find notification named " ++ method);
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

        const OnResponse = *const fn (conn: *ConnectionType, result: RequestResult(method)) anyerror!void;
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
            params: NotificationParams(method),
        ) !void {
            try conn.send(.{
                .jsonrpc = "2.0",
                .method = method,
                .params = params,
            });
        }

        pub fn request(
            conn: *Self,
            comptime method: []const u8,
            params: RequestParams(method),
            callback: RequestCallback(Self, method),
        ) !void {
            try conn.send(.{
                .jsonrpc = "2.0",
                .id = conn.id,
                .method = method,
                .params = params,
            });

            try conn.callback_map.put(conn.allocator, conn.id, callback.store());

            conn.id +%= 1;
        }

        // pub fn callSuccessCallback(
        //     conn: *Self,
        //     id: usize,
        // ) !void {
        //     // TODO: Handle
        //     const entry = conn.callback_map.fetchRemove(id) orelse @panic("nothing!");
        //     inline for (lsp.request_metadata) |req| {
        //         if (std.mem.eql(u8, req.method, entry.value.method)) {
        //             try (RequestCallback(ContextType, req.method).unstore(entry.value).onResponse(&conn.context, undefined));
        //         }
        //     }
        // }

        pub fn accept(conn: *Self) !void {
            var arena = std.heap.ArenaAllocator.init(conn.allocator);
            defer arena.deinit();

            const allocator = arena.allocator();

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
                std.log.info("Received request {s}", .{maybe_method.?.String});
                // const id = try tres.parse(lsp.RequestId, maybe_id.?, allocator);
                // const method = maybe_method.?.String;

                // try conn.handleRequest(allocator, tree, id, method);
            } else if (maybe_id) |id| {
                @setEvalBranchQuota(100_000);

                // TODO: Handle errors
                const iid = @intCast(usize, id.Integer);

                const entry = conn.callback_map.fetchRemove(iid) orelse @panic("nothing!");
                inline for (lsp.request_metadata) |req| {
                    if (std.mem.eql(u8, req.method, entry.value.method)) {
                        const value = try tres.parse(RequestResult(req.method), tree.Object.get("result").?, allocator);
                        try (RequestCallback(Self, req.method).unstore(entry.value).onResponse(conn, value));
                        return;
                    }
                }

                @panic("Received response to non-existent request");
            } else if (maybe_method) |method| {
                inline for (lsp.notification_metadata) |notif| {
                    if (@hasDecl(ContextType, notif.method)) {
                        if (std.mem.eql(u8, notif.method, method.String)) {
                            const value = try tres.parse(NotificationParams(notif.method), tree.Object.get("params").?, allocator);
                            try @field(ContextType, notif.method)(conn, value);
                            return;
                        }
                    }
                }

                std.log.info("Notifications not handled: {s}", .{method.String});

                // @panic("TODO: Handle notification");
            } else {
                @panic("Invalid JSON-RPC message.");
            }
        }

        pub fn acceptUntilResponse(conn: *Self) !void {
            const initial_size = conn.callback_map.size;
            while (true) {
                try conn.accept();
                if (initial_size != conn.callback_map.size) return;
            }
        }

        pub fn handleRequest(
            conn: *Self,
            arena: std.mem.Allocator,
            value: std.json.Value,
            id: lsp.RequestId,
            method: []const u8,
        ) !void {
            inline for (lsp.request_metadata) |entry| {
                if (@hasDecl(ContextType, entry.method)) {
                    const context_func = @field(ContextType, entry.method);
                    const func_info = @Type(context_func).Fn;

                    const params = func_info.params;
                    if (params.len != 3) @compileError("Handler function has invalid number of parameters");
                    const context_param_type = params[0].type;
                    if (context_param_type != *ContextType) @compileError("First parameter of all contexts should be the context instance");
                    const id_type = params[1].type;
                    if (id != lsp.RequestId) @compileError("Expected RequestId found " ++ @typeName(id_type));
                    const params_type = params[2].type;
                    if (params_type != entry.Params) @compileError("Expected " ++ @typeName(entry.Params) ++ " found " ++ @typeName(params_type));

                    // TODO: Handle errors
                    if (func_info.return_type != entry.Result) @compileError("Expected " ++ @typeName(entry.Result) ++ " found " ++ @typeName(func_info.return_type));

                    const output = context_func(conn.context, id, try tres.parse(entry.Params, value, arena));
                    std.log.info("{s}", .{output});
                } else {
                    // TODO: Return error unimplemented
                    std.log.warn("Client asked for unimplemented method: {s}", .{method});
                }
            }

            // TODO: Support custom method contexts
            std.log.err("Encountered unknown method: {s}", .{method});
            @panic("Unknown");
        }
    };
}
