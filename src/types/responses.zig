const std = @import("std");
const common = @import("common.zig");

/// Params of a response (result)
pub const ResponseParams = union(enum) {
    signature_help: SignatureHelpResponse,
    completion_list: CompletionList,
    // location: Location,
    // hover: Hover,
    // document_symbols: []DocumentSymbol,
    // semantic_tokens_full: struct { data: []const u32 },
    // text_edits: []TextEdit,
    // locations: []Location,
    // workspace_edit: WorkspaceEdit,
    initialize_result: InitializeResult,
};

/// JSONRPC response
pub const Response = struct {
    jsonrpc: []const u8 = "2.0",
    id: common.RequestId,
    result: ResponseParams,
};

pub const SignatureInformation = struct {
    pub const ParameterInformation = struct {
        // TODO Can also send a pair of encoded offsets
        label: []const u8,
        documentation: ?common.MarkupContent,
    };

    label: []const u8,
    documentation: ?common.MarkupContent,
    parameters: ?[]const ParameterInformation,
    activeParameter: ?u32,
};

/// Signature help represents the signature of something
/// callable. There can be multiple signature but only one
/// active and only one active parameter.
///
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#signatureHelp)
pub const SignatureHelpResponse = struct {
    signatures: ?[]const SignatureInformation,
    activeSignature: ?u32,
    activeParameter: ?u32,
};

/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#initializeResult)
pub const InitializeResult = struct {
    offsetEncoding: []const u8,
    capabilities: struct {
        signatureHelpProvider: struct {
            triggerCharacters: []const []const u8,
            retriggerCharacters: []const []const u8,
        },
        textDocumentSync: enum(u32) {
            none = 0,
            full = 1,
            incremental = 2,

            usingnamespace common.EnumStringify(@This());
        },
        renameProvider: bool,
        completionProvider: struct {
            resolveProvider: bool,
            triggerCharacters: []const []const u8,
        },
        documentHighlightProvider: bool,
        hoverProvider: bool,
        codeActionProvider: bool,
        declarationProvider: bool,
        definitionProvider: bool,
        typeDefinitionProvider: bool,
        implementationProvider: bool,
        referencesProvider: bool,
        documentSymbolProvider: bool,
        colorProvider: bool,
        documentFormattingProvider: bool,
        documentRangeFormattingProvider: bool,
        foldingRangeProvider: bool,
        selectionRangeProvider: bool,
        workspaceSymbolProvider: bool,
        rangeProvider: bool,
        documentProvider: bool,
        workspace: ?struct {
            workspaceFolders: ?struct {
                supported: bool,
                changeNotifications: bool,
            },
        },
        semanticTokensProvider: ?struct {
            full: bool,
            range: bool,
            legend: struct {
                tokenTypes: []const []const u8,
                tokenModifiers: []const []const u8,
            },
        } = null,
    },
    serverInfo: struct {
        name: []const u8,
        version: ?[]const u8 = null,
    },
};

pub const CompletionList = struct {
    isIncomplete: bool,
    items: []const CompletionItem,
};

pub const CompletionItem = struct {
    const Kind = enum(i64) {
        text = 1,
        method = 2,
        function = 3,
        constructor = 4,
        field = 5,
        variable = 6,
        class = 7,
        interface = 8,
        module = 9,
        property = 10,
        unit = 11,
        value = 12,
        @"enum" = 13,
        keyword = 14,
        snippet = 15,
        color = 16,
        file = 17,
        reference = 18,
        folder = 19,
        enum_member = 20,
        constant = 21,
        @"struct" = 22,
        event = 23,
        operator = 24,
        type_parameter = 25,

        pub fn jsonStringify(value: Kind, options: std.json.StringifyOptions, out_stream: anytype) !void {
            try std.json.stringify(@enumToInt(value), options, out_stream);
        }
    };

    label: []const u8,
    kind: Kind,
    textEdit: ?common.TextEdit = null,
    filterText: ?[]const u8 = null,
    insertText: []const u8 = "",
    insertTextFormat: ?common.InsertTextFormat = .plaintext,
    detail: ?[]const u8 = null,
    documentation: ?common.MarkupContent = null,
};
