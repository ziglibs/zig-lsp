const std = @import("std");
const lsp = @import("zig_lsp.zig");
const types = lsp.types;

const Connection = lsp.Connection(
    std.fs.File.Reader,
    std.fs.File.Writer,
    Context,
);

pub const Context = struct {
    pub const Error = error{};

    pub fn dataRecv(
        _: *Connection,
        data: []const u8,
    ) !void {
        std.log.info("RECV DATA {s}", .{data});
    }

    pub fn dataSend(
        _: *Connection,
        data: []const u8,
    ) !void {
        std.log.info("SEND DATA {s}", .{data});
    }

    pub fn lspRecvPre(
        _: *Connection,
        comptime method: []const u8,
        comptime kind: lsp.MessageKind,
        id: ?types.RequestId,
        payload: lsp.Payload(method, kind),
    ) !void {
        std.log.info("RECV LSPPRE id {any}: {any} {s} w/ payload type {s}", .{ id, kind, method, @typeName(@TypeOf(payload)) });
    }

    pub fn lspRecvPost(
        _: *Connection,
        comptime method: []const u8,
        comptime kind: lsp.MessageKind,
        id: ?types.RequestId,
        payload: lsp.Payload(method, kind),
    ) !void {
        std.log.info("RECV LSPPOST id {any}: {any} {s} w/ payload type {s}", .{ id, kind, method, @typeName(@TypeOf(payload)) });
    }

    pub fn lspSendPre(
        _: *Connection,
        comptime method: []const u8,
        comptime kind: lsp.MessageKind,
        id: ?types.RequestId,
        payload: lsp.Payload(method, kind),
    ) !void {
        std.log.info("SEND LSPPRE id {any}: {any} {s} w/ payload type {s}", .{ id, kind, method, @typeName(@TypeOf(payload)) });
    }

    pub fn lspSendPost(
        _: *Connection,
        comptime method: []const u8,
        comptime kind: lsp.MessageKind,
        id: ?types.RequestId,
        payload: lsp.Payload(method, kind),
    ) !void {
        std.log.info("SEND LSPPOST id {any}: {any} {s} w/ payload type {s}", .{ id, kind, method, @typeName(@TypeOf(payload)) });
    }

    pub fn @"window/logMessage"(_: *Connection, params: types.LogMessageParams) !void {
        const logMessage = std.log.scoped(.logMessage);
        switch (params.type) {
            .Error => logMessage.err("{s}", .{params.message}),
            .Warning => logMessage.warn("{s}", .{params.message}),
            .Info => logMessage.info("{s}", .{params.message}),
            .Log => logMessage.debug("{s}", .{params.message}),
        }
    }

    pub fn @"textDocument/publishDiagnostics"(_: *Connection, _: types.PublishDiagnosticsParams) !void {}
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // var process = std.ChildProcess.init(&.{ "typescript-language-server", "--stdio" }, allocator);
    var process = std.ChildProcess.init(&.{ "C:\\Programming\\Zig\\zls\\zig-out\\bin\\zls.exe", "--enable-debug-log" }, allocator);

    process.stdin_behavior = .Pipe;
    process.stdout_behavior = .Pipe;

    try process.spawn();
    defer _ = process.kill() catch {};

    var reader = process.stdout.?.reader();
    var writer = process.stdin.?.writer();

    var context = Context{};
    var conn = Connection.init(
        allocator,
        reader,
        writer,
        &context,
    );

    // const cb = struct {
    //     pub fn res(_: *Connection, result: lsp.InitializeResult) !void {
    //         std.log.info("bruh {any}", .{result});
    //     }

    //     pub fn err(_: *Connection) !void {}
    // };
    // _ = .{cb};

    // try conn.request("initialize", .{
    //     .capabilities = .{
    //         .textDocument = .{
    //             .documentSymbol = .{
    //                 .hierarchicalDocumentSymbolSupport = true,
    //             },
    //         },
    //         .workspace = .{
    //             .configuration = true,
    //             .didChangeConfiguration = .{
    //                 .dynamicRegistration = true,
    //             },
    //         },
    //     },
    // }, .{ .onResponse = cb.res, .onError = cb.err });
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    _ = try conn.requestSync(arena_allocator, "initialize", .{
        .capabilities = .{
            .textDocument = .{
                .documentSymbol = .{
                    .hierarchicalDocumentSymbolSupport = true,
                },
            },
            .workspace = .{
                .configuration = true,
                .didChangeConfiguration = .{
                    .dynamicRegistration = true,
                },
            },
        },
    });
    try conn.notify("initialized", .{});

    // try conn.acceptUntilResponse();

    // try conn.notify("textDocument/didOpen", .{
    //     .textDocument = .{
    //         .uri = "file:///file.js",
    //         .languageId = "js",
    //         .version = 123,
    //         .text =
    //         \\/**
    //         \\ * @type {number}
    //         \\ */
    //         \\var abc = 123;
    //         ,
    //     },
    // });

    // const cb2 = struct {
    //     pub fn res(_: *Connection, result: connection.RequestResult("textDocument/documentSymbol")) !void {
    //         std.log.info("bruh {any}", .{result.?.array_of_DocumentSymbol});
    //     }

    //     pub fn err(_: *Connection) !void {}
    // };

    // try conn.request("textDocument/documentSymbol", .{
    //     .textDocument = .{
    //         .uri = "file:///file.js",
    //     },
    // }, .{
    //     .onResponse = cb2.res,
    //     .onError = cb2.err,
    // });

    // try conn.acceptUntilResponse();

    // try conn.notify("workspace/didChangeConfiguration", .{
    //     .settings = .Null,
    // });

    // while (true) {
    //     try conn.accept();
    // }

    // const cb = struct {
    //     pub fn res(context: *Context, result: lsp.InitializeResult) !void {
    //         std.log.info("bruh", .{});
    //         _ = context;
    //         _ = result;
    //     }

    //     pub fn err(context: *Context) !void {
    //         _ = context;
    //     }
    // };

    // try conn.request("initialize", .{
    //     .capabilities = .{},
    // }, .{ .onResponse = cb.res, .onError = cb.err });
    // try conn.callSuccessCallback(0);

    // while (true) {
    //     try conn.accept();
    // }
}

test "simple test" {}
