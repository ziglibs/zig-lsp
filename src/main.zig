const std = @import("std");
const lsp = @import("lsp.zig");
const connection = @import("connection.zig");

pub const Handler = struct {
    pub const Error = error{};

    // pub fn initialize(
    //     handler: *Handler,
    //     id: connection.lsp.RequestId,
    //     params: connection.lsp.InitializeParams,
    // ) connection.lsp.InitializeResult {
    //     return .{
    //         .capabilities = .{},
    //     };
    // }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var reader = std.io.getStdIn().reader();
    var writer = std.io.getStdOut().writer();
    const Connection = connection.Connection(
        @TypeOf(reader),
        @TypeOf(writer),
        Handler,
    );

    var conn = Connection.init(
        allocator,
        reader,
        writer,
        .{},
    );

    try conn.notify("textDocument/didOpen", .{
        .textDocument = .{
            .uri = "uri",
            .languageId = "abc",
            .version = 123,
            .text = "bruh",
        },
    });

    const cb = struct {
        pub fn res(handler: *Handler, result: lsp.InitializeResult) !void {
            std.log.info("bruh", .{});
            _ = handler;
            _ = result;
        }

        pub fn err(handler: *Handler) !void {
            _ = handler;
        }
    };

    try conn.request("initialize", .{
        .capabilities = .{},
    }, .{ .onResponse = cb.res, .onError = cb.err });
    try conn.callSuccessCallback(0);

    // while (true) {
    //     try conn.accept();
    // }
}

test "simple test" {}
