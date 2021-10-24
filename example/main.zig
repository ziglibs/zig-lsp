const std = @import("std");
const lsp = @import("lsp");

// Always set this to debug to make std.log call into our handler, then control the runtime
// value in the definition below.

pub fn main() !void {
    @setEvalBranchQuota(10_000);

    const allocator = std.heap.page_allocator;

    var header_buf: [128]u8 = undefined;
    const stdin = std.io.getStdIn().reader();

    var data_buf = try std.ArrayList(u8).initCapacity(allocator, 1024);

    while (true) {
        var header = try lsp.RequestHeader.decode(stdin, &header_buf);
        std.debug.print("Hey: {s}\n", .{header});

        try data_buf.ensureTotalCapacity(header.content_length);
        data_buf.items.len = header.content_length;
        _ = try stdin.readAll(data_buf.items[0..header.content_length]);

        std.debug.print("Hey2: {s}\n", .{data_buf.items});
        var tok = std.json.TokenStream.init(data_buf.items);
        var request = try std.json.parse(lsp.types.requests.RequestParseTarget, &tok, .{
            .allocator = allocator,
            .ignore_unknown_fields = true,
        });

        switch (request) {
            .initialize => |init| {
                std.debug.print("{s}\n", .{init.params});
            },
        }
    }
}
