const std = @import("std");
const lsp = @import("lsp");

// Always set this to debug to make std.log call into our handler, then control the runtime
// value in the definition below.

pub fn main() !void {
    comptime @setEvalBranchQuota(10_000);

    const allocator = std.heap.page_allocator;

    var server = try lsp.Server.init(allocator);

    while (true) {
        var request = try server.readRequest();
        defer server.flushArena();

        switch (request.params) {
            .initialize => |init| {
                server.processInitialize(init);

                try server.respond(request, .{
                    .initialize_result = .{
                        .offsetEncoding = if (server.offset_encoding == .utf8)
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
                            .renameProvider = false,
                            .completionProvider = .{
                                .resolveProvider = false,
                                .triggerCharacters = &[_][]const u8{ ".", ":", "@" },
                            },
                            .documentHighlightProvider = false,
                            .hoverProvider = false,
                            .codeActionProvider = false,
                            .declarationProvider = false,
                            .definitionProvider = false,
                            .typeDefinitionProvider = false,
                            .implementationProvider = false,
                            .referencesProvider = false,
                            .documentSymbolProvider = false,
                            .colorProvider = false,
                            .documentFormattingProvider = false,
                            .documentRangeFormattingProvider = false,
                            .foldingRangeProvider = false,
                            .selectionRangeProvider = false,
                            .workspaceSymbolProvider = false,
                            .rangeProvider = false,
                            .documentProvider = false,
                            .workspace = .{
                                .workspaceFolders = .{
                                    .supported = false,
                                    .changeNotifications = false,
                                },
                            },
                            .semanticTokensProvider = null,
                        },
                    },
                });
            },
            .initialized => {
                std.debug.print("Successfully initialized!\n", .{});
            },
            .didOpen => |open| {
                std.debug.print("{s}!\n", .{open});
            },
            .didChangeWorkspaceFolders => |change| {
                std.debug.print("FOLDERS! {s}\n", .{change});
            },
        }
    }
}
