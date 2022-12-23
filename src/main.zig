const std = @import("std");
const lsp = @import("lsp.zig");
const connection = @import("connection.zig");

pub const Handler = struct {
    pub const Error = error{};

    done: bool = false,

    pub fn @"window/logMessage"(handler: *Handler, params: lsp.LogMessageParams) !void {
        _ = handler;
        const logMessage = std.log.scoped(.logMessage);
        switch (params.type) {
            .Error => logMessage.err("{s}", .{params.message}),
            .Warning => logMessage.warn("{s}", .{params.message}),
            .Info => logMessage.info("{s}", .{params.message}),
            .Log => logMessage.debug("{s}", .{params.message}),
        }
    }
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
    const Connection = connection.Connection(
        @TypeOf(reader),
        @TypeOf(writer),
        Handler,
    );

    var handler = Handler{};
    var conn = Connection.init(
        allocator,
        reader,
        writer,
        &handler,
    );

    const cb = struct {
        pub fn res(h: *Handler, result: lsp.InitializeResult) !void {
            std.log.info("bruh {any}", .{result});
            h.done = true;
        }

        pub fn err(h: *Handler) !void {
            _ = h;
        }
    };

    try conn.request("initialize", .{
        .capabilities = .{
            .textDocument = .{
                .documentSymbol = .{
                    .hierarchicalDocumentSymbolSupport = true,
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
        pub fn res(h: *Handler, result: connection.RequestResult("textDocument/documentSymbol")) !void {
            std.log.info("bruh {any}", .{result.?.array_of_DocumentSymbol});
            h.done = true;
        }

        pub fn err(h: *Handler) !void {
            _ = h;
        }
    };

    try conn.request("textDocument/documentSymbol", .{
        .textDocument = .{
            .uri = "file:///file.js",
        },
    }, .{
        .onResponse = cb2.res,
        .onError = cb2.err,
    });

    while (!handler.done) {
        try conn.accept();
    }
    handler.done = false;

    // const cb = struct {
    //     pub fn res(handler: *Handler, result: lsp.InitializeResult) !void {
    //         std.log.info("bruh", .{});
    //         _ = handler;
    //         _ = result;
    //     }

    //     pub fn err(handler: *Handler) !void {
    //         _ = handler;
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
