const std = @import("std");
const lsp = @import("lsp.zig");
const connection = @import("connection.zig");

const Connection = connection.Connection(
    std.fs.File.Reader,
    std.fs.File.Writer,
    Context,
);

pub const Context = struct {
    pub const Error = error{};

    pub fn @"window/logMessage"(_: *Connection, params: lsp.LogMessageParams) !void {
        const logMessage = std.log.scoped(.logMessage);
        switch (params.type) {
            .Error => logMessage.err("{s}", .{params.message}),
            .Warning => logMessage.warn("{s}", .{params.message}),
            .Info => logMessage.info("{s}", .{params.message}),
            .Log => logMessage.debug("{s}", .{params.message}),
        }
    }

    pub fn @"textDocument/publishDiagnostics"(_: *Connection, _: lsp.PublishDiagnosticsParams) !void {}
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var process = std.ChildProcess.init(&.{ "typescript-language-server", "--stdio" }, allocator);

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

    const cb = struct {
        pub fn res(conn_: *Connection, result: lsp.InitializeResult) !void {
            std.log.info("bruh {any}", .{result});
            try conn_.notify("initialized", .{});
        }

        pub fn err(_: *Connection) !void {}
    };

    try conn.request("initialize", .{
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
    }, .{ .onResponse = cb.res, .onError = cb.err });

    try conn.acceptUntilResponse();

    try conn.notify("textDocument/didOpen", .{
        .textDocument = .{
            .uri = "file:///file.js",
            .languageId = "js",
            .version = 123,
            .text =
            \\/**
            \\ * @type {number}
            \\ */
            \\var abc = 123;
            ,
        },
    });

    const cb2 = struct {
        pub fn res(_: *Connection, result: connection.RequestResult("textDocument/documentSymbol")) !void {
            std.log.info("bruh {any}", .{result.?.array_of_DocumentSymbol});
        }

        pub fn err(_: *Connection) !void {}
    };

    try conn.request("textDocument/documentSymbol", .{
        .textDocument = .{
            .uri = "file:///file.js",
        },
    }, .{
        .onResponse = cb2.res,
        .onError = cb2.err,
    });

    try conn.acceptUntilResponse();

    try conn.notify("workspace/didChangeConfiguration", .{
        .settings = .Null,
    });

    while (true) {
        try conn.accept();
    }

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
