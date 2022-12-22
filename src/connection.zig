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
    comptime HandlerType: type,
    comptime method: []const u8,
) type {
    return struct {
        const Self = @This();

        const OnResponse = *const fn (handler: *HandlerType, result: RequestResult(method)) anyerror!void;
        const OnError = *const fn (handler: *HandlerType) anyerror!void;

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

pub fn Connection(
    comptime ReaderType: type,
    comptime WriterType: type,
    comptime HandlerType: type,
) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        reader: ReaderType,
        writer: WriterType,
        handler: HandlerType,

        id: usize = 0,
        write_buffer: std.ArrayListUnmanaged(u8) = .{},
        callback_map: std.AutoHashMapUnmanaged(usize, StoredCallback) = .{},

        pub fn init(
            allocator: std.mem.Allocator,
            reader: ReaderType,
            writer: WriterType,
            handler: HandlerType,
        ) Self {
            return .{
                .allocator = allocator,
                .reader = reader,
                .writer = writer,
                .handler = handler,
            };
        }

        pub const AcceptError = std.mem.Allocator.Error || ReaderType.Error || WriterType.Error || HandlerType.Error;

        pub fn accept(conn: *Self) AcceptError!void {
            var arena = std.heap.ArenaAllocator.init(conn.allocator);
            defer arena.deinit();

            const allocator = arena.allocator();

            var data = "";
            var parser = std.json.Parser.init(allocator, false);
            defer parser.deinit();

            var tree = try parser.parse(data);

            // There are three cases at this point:
            // 1. We have a request (id + method)
            // 2. We have a response (id)
            // 3. We have a notification (method)

            const maybe_id = tree.Object.get("id");
            const maybe_method = tree.Object.get("method");

            if (maybe_id != null and maybe_method != null) {
                const id = try tres.parse(lsp.RequestId, maybe_id.?);
                const method = maybe_method.?.String;

                conn.handleRequest(arena, tree, id, method);
            } else if (maybe_id) |id| {
                _ = id;
                @panic("TODO: Handle response");
            } else if (maybe_method) |method| {
                _ = method;
                @panic("TODO: Handle notification");
            } else {
                @panic("Invalid JSON-RPC message.");
            }
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
            callback: RequestCallback(HandlerType, method),
        ) !void {
            try conn.send(.{
                .jsonrpc = "2.0",
                .method = method,
                .params = params,
            });

            try conn.callback_map.put(conn.allocator, conn.id, callback.store());

            conn.id +%= 1;
        }

        pub fn callSuccessCallback(
            conn: *Self,
            id: usize,
        ) !void {
            // TODO: Handle
            const entry = conn.callback_map.fetchRemove(id) orelse @panic("nothing!");
            inline for (lsp.request_metadata) |req| {
                if (std.mem.eql(u8, req.method, entry.value.method)) {
                    try (RequestCallback(HandlerType, req.method).unstore(entry.value).onResponse(&conn.handler, undefined));
                }
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
                if (@hasDecl(HandlerType, entry.method)) {
                    const handler_func = @field(HandlerType, entry.method);
                    const func_info = @Type(handler_func).Fn;

                    const params = func_info.params;
                    if (params.len != 3) @compileError("Handler function has invalid number of parameters");
                    const handler_param_type = params[0].type;
                    if (handler_param_type != *HandlerType) @compileError("First parameter of all handlers should be the handler instance");
                    const id_type = params[1].type;
                    if (id != lsp.RequestId) @compileError("Expected RequestId found " ++ @typeName(id_type));
                    const params_type = params[2].type;
                    if (params_type != entry.Params) @compileError("Expected " ++ @typeName(entry.Params) ++ " found " ++ @typeName(params_type));

                    // TODO: Handle errors
                    if (func_info.return_type != entry.Result) @compileError("Expected " ++ @typeName(entry.Result) ++ " found " ++ @typeName(func_info.return_type));

                    const output = handler_func(conn.handler, id, try tres.parse(entry.Params, value, arena));
                    std.log.info("{s}", .{output});
                } else {
                    // TODO: Return error unimplemented
                    std.log.warn("Client asked for unimplemented method: {s}", .{method});
                }
            }

            // TODO: Support custom method handlers
            std.log.err("Encountered unknown method: {s}", .{method});
            @panic("Unknown");
        }
    };
}
