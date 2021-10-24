const std = @import("std");
const lsp = @import("lsp");

// Always set this to debug to make std.log call into our handler, then control the runtime
// value in the definition below.

pub fn main() !void {
    @setEvalBranchQuota(10_000);

    const allocator = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    const arena_allocator = &arena.allocator;

    var header_buf: [128]u8 = undefined;
    const stdin = std.io.getStdIn().reader();

    var read_buf = try std.ArrayList(u8).initCapacity(allocator, 1024);
    var write_buf = try std.ArrayList(u8).initCapacity(allocator, 1024);

    var offset_encoding = lsp.offsets.Encoding.utf16;

    while (true) {
        var header = try lsp.RequestHeader.decode(stdin, &header_buf);
        std.debug.print("Hey: {s}\n", .{header});

        try read_buf.ensureTotalCapacity(header.content_length);
        read_buf.items.len = header.content_length;
        _ = try stdin.readAll(read_buf.items[0..header.content_length]);

        std.debug.print("Hey2: {s}\n", .{read_buf.items});
        var request = try lsp.types.requests.Request.parse(arena_allocator, read_buf.items);

        switch (request.params) {
            .initialize => |init| {
                for (init.capabilities.offsetEncoding) |encoding| {
                    if (std.mem.eql(u8, encoding, "utf-8")) {
                        offset_encoding = .utf8;
                    }
                }

                try lsp.send(&write_buf, lsp.types.responses.Response{
                    .id = request.id,
                    .result = .{
                        .initialize_result = .{
                            .offsetEncoding = if (offset_encoding == .utf8)
                                @as([]const u8, "utf-8")
                            else
                                "utf-16",
                            .serverInfo = .{
                                .name = "zls",
                                .version = "0.1.0",
                            },
                            .capabilities = .{
                                .signatureHelpProvider = .{
                                    .triggerCharacters = &.{"("},
                                    .retriggerCharacters = &.{","},
                                },
                                .textDocumentSync = .full,
                                .renameProvider = true,
                                .completionProvider = .{
                                    .resolveProvider = false,
                                    .triggerCharacters = &[_][]const u8{ ".", ":", "@" },
                                },
                                .documentHighlightProvider = false,
                                .hoverProvider = true,
                                .codeActionProvider = false,
                                .declarationProvider = true,
                                .definitionProvider = true,
                                .typeDefinitionProvider = true,
                                .implementationProvider = false,
                                .referencesProvider = true,
                                .documentSymbolProvider = true,
                                .colorProvider = false,
                                .documentFormattingProvider = true,
                                .documentRangeFormattingProvider = false,
                                .foldingRangeProvider = false,
                                .selectionRangeProvider = false,
                                .workspaceSymbolProvider = false,
                                .rangeProvider = false,
                                .documentProvider = true,
                                .workspace = .{
                                    .workspaceFolders = .{
                                        .supported = false,
                                        .changeNotifications = false,
                                    },
                                },
                                .semanticTokensProvider = null,
                            },
                        },
                    },
                });
            },
            .didChangeWorkspaceFolders => |change| {
                std.debug.print("FOLDERS! {s}\n", .{change});
            },
        }

        arena.deinit();
        arena.state = .{};
    }
}
