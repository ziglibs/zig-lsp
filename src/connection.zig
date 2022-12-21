const std = @import("std");
const tres = @import("tres");
pub const lsp = @import("lsp");

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
        handler: Handler,

        header_buffer: std.ArrayListUnmanaged(u8) = .{},

        pub fn init(
            allocator: std.mem.Allocator,
            reader: ReaderType,
            writer: WriterType,
            handler: Handler,
        ) Self {
            return .{
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
                @panic("TODO: Handle response");
            } else if (maybe_method) |method| {
                @panic("TODO: Handle notification");
            } else {
                @panic("Invalid JSON-RPC message.");
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
                    if (handler_param_type != HandlerType and handler_param_type != *HandlerType and handler_param_type != *const HandlerType) @compileError("First parameter of all handlers should be the handler instance");
                    const id_type = params[1].type;
                    if (id != lsp.RequestId) @compileError("Expected RequestId found " ++ @typeName(id_type));
                    const params_type = params[2].type;
                    if (params_type != entry.Params) @compileError("Expected " ++ @typeName(entry.Params) ++ " found " ++ @typeName(params_type));

                    // TODO: Handle errors
                    if (func_info.return_type != entry.Result) @compileError("Expected " ++ @typeName(entry.Result) ++ " found " ++ @typeName(func_info.return_type));

                    const output = handler_func(conn.handler, id, try tres.parse(entry.Params, value, arena));
                    // tres.stringify(
                    //     output,
                    //     .{},
                    // );
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

pub const FileConnection = Connection(std.fs.File.Reader, std.fs.File.Writer);

/// Raw stdio connection, probably not the most efficient
pub fn initStdioConnection(allocator: std.mem.Allocator, handler: anytype) FileConnection {
    return FileConnection.init(
        allocator,
        std.io.getStdIn().reader(),
        std.io.getStdOut().writer(),
        @TypeOf(handler),
    );
}
