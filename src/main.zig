const std = @import("std");
pub const connection = @import("connection.zig");

pub const Handler = struct {
    pub const Error = error{};

    pub fn initialize(
        handler: *Handler,
        id: connection.lsp.RequestId,
        params: connection.lsp.InitializeParams,
    ) connection.lsp.InitializeResult {
        return .{
            .capabilities = .{},
        };
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var conn = connection.initStdioConnection(allocator, Handler{});
    while (true) {
        try conn.accept();
    }
}

test "simple test" {}
