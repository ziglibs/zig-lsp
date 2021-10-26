const std = @import("std");
const lsp = @import("lsp");

var server: lsp.Server = undefined;

// TODO: Log level bruh
// pub fn log(
//     comptime level: std.log.Level,
//     comptime scope: @TypeOf(.EnumLiteral),
//     comptime format: []const u8,
//     args: anytype,
// ) void {
//     var hacky_buffer: [1024]u8 = undefined;

//     server.notify(.{
//         .log_message = .{
//             .@"type" = switch (level) {
//                 .err => .err,
//                 .warn => .warn,
//                 .info => .info,
//                 .debug => .log,
//             },
//             .message = std.fmt.bufPrint(&hacky_buffer, "(" ++ @tagName(scope) ++ ") " ++ format, args),
//         },
//     });
// }

pub fn main() !void {
    comptime @setEvalBranchQuota(10_000);

    const allocator = std.heap.page_allocator;

    server = try lsp.Server.init(allocator);

    while (true) {
        var message = try server.readMessage();
        defer server.flushArena();

        std.debug.print("{s}\n", .{message});

        switch (message) {
            .notification => |notification| switch (notification.params) {
                .initialized => {
                    std.debug.print("Successfully initialized!\n", .{});
                },
                .did_open => |open| {
                    std.debug.print("{s}!\n", .{open});
                },
                else => @panic("NO!"),
            },
            .request => |request| switch (request.params) {
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
                .completion => |comp| {
                    _ = comp;
                    try server.respond(request, .{
                        .completion = .{
                            .completion_list = .{
                                .isIncomplete = false,
                                .items = &[1]lsp.types.language_features.CompletionItem{
                                    .{
                                        .label = "joe mama",
                                        .kind = .text,
                                        .textEdit = null,
                                        .filterText = null,
                                        .insertText = "joe mama",
                                        .insertTextFormat = .plaintext,
                                        .detail = "Joe Mama.",
                                        .documentation = .{ .kind = .markdown, .value = 
                                        \\A clever name used to insult another individual's mother.
                                        \\It is a play on words that refers to the saying, "Yo mama!"
                                        \\
                                        \\Person 1: "Where's Joe?"\
                                        \\Victim 1: "Joe? ... Joe who?"\
                                        \\Person 1: "JOE MAMA!"\
                                        \\Victim 1: *Proceeds to feel insulted*
                                        },
                                    },
                                },
                            },
                        },
                    });
                },
                // else => {},
            },
        }
    }
}
