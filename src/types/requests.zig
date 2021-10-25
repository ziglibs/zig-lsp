///! Process client requests / notifications
const std = @import("std");
const json = @import("../json.zig");
const common = @import("./common.zig");

/// A request message to describe a request between the client and the server.
/// Every processed request must send a response back to the sender of the request.
///
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#requestMessage)
pub const RequestMessage = struct {
    jsonrpc: []const u8 = "2.0",

    /// The request id.
    id: common.RequestId,

    /// The method to be invoked.
    method: []const u8,

    /// The method's params.
    params: RequestParams,

    fn fromTarget(target: RequestParseTarget) RequestMessage {
        inline for (std.meta.fields(RequestParseTarget)) |field, i| {
            if (@enumToInt(target) == i) {
                return .{
                    .id = if (@hasField(@TypeOf(@field(target, field.name)), "id")) @field(target, field.name).id else .{ .none = {} },
                    .method = @field(target, field.name).method,
                    .params = @unionInit(RequestParams, field.name, @field(target, field.name).params),
                };
            }
        }

        unreachable;
    }

    pub fn encode(self: RequestMessage, writer: anytype) @TypeOf(writer).Error!void {
        try json.stringify(self, .{}, writer);
    }

    pub fn decode(allocator: *std.mem.Allocator, buf: []const u8) !RequestMessage {
        @setEvalBranchQuota(10_000);

        return fromTarget(try json.parse(RequestParseTarget, &json.TokenStream.init(buf), .{
            .allocator = allocator,
            .ignore_unknown_fields = true,
        }));
    }
};

pub const RequestParams = union(enum) {
    initialize: InitializeParams,
    initialized: InitializedParams,
    didOpen: DidOpenTextDocumentParams,
    completion: CompletionParams,
    didChangeWorkspaceFolders: DidChangeWorkspaceFoldersParams,
};

/// Params of a request (params)
pub const RequestParseTarget = union(enum) {
    initialize: Paramsify(InitializeParams),
    initialized: Paramsify(InitializedParams),
    didOpen: Paramsify(DidOpenTextDocumentParams),
    completion: Paramsify(CompletionParams),
    didChangeWorkspaceFolders: Paramsify(DidChangeWorkspaceFoldersParams),
};

const ParamsifyKind = enum { request, notification };
fn Paramsify(comptime T: type) type {
    return @Type(.{ .Struct = .{
        .layout = .Auto,
        .fields = &([1]std.builtin.TypeInfo.StructField{
            .{
                .name = "method",
                .field_type = []const u8,
                .default_value = std.mem.sliceAsBytes(std.mem.span(@field(T, "method"))),
                .is_comptime = true,
                .alignment = 0,
            },
        } ++ (if (@field(T, "kind") == .request) [1]std.builtin.TypeInfo.StructField{
            .{
                .name = "id",
                .field_type = common.RequestId,
                .default_value = null,
                .is_comptime = false,
                .alignment = 0,
            },
        } else [0]std.builtin.TypeInfo.StructField{}) ++ [1]std.builtin.TypeInfo.StructField{
            .{
                .name = "params",
                .field_type = T,
                .default_value = null,
                .is_comptime = false,
                .alignment = 0,
            },
        }),
        .decls = &.{},
        .is_tuple = false,
    } });
}

/// The base protocol offers support for request cancellation.
/// To cancel a request, a notification message with the following properties is sent.
///
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#cancelRequest)
pub const CancelParams = struct {
    pub const method = "$/cancelRequest";
    pub const kind = ParamsifyKind.notification;

    /// The request id to cancel.
    id: common.RequestId,
};

pub const ProgressToken = union(enum) {
    integer: common.integer,
    string: []const u8,
};

// TODO: Generic T used; what the hell does that mean??
pub const ProgressValue = union(enum) {
    integer: common.integer,
    string: []const u8,
};

/// The base protocol offers also support to report progress in a generic fashion.
/// This mechanism can be used to report any kind of progress including work done progress
/// (usually used to report progress in the user interface using a progress bar)
/// and partial result progress to support streaming of results.
///
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#progress)
pub const ProgressParams = struct {
    pub const method = "$/progress";
    pub const kind = ParamsifyKind.notification;

    /// The progress token provided by the client or server.
    token: ProgressToken,

    /// The progress data.
    value: ProgressValue,
};

/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#semanticTokensClientCapabilities)
pub const SemanticTokensClientCapabilities = struct {
    dynamicRegistration: bool = false,

    /// The token types that the client supports.
    tokenTypes: []const []const u8,

    /// The token modifiers that the client supports.
    tokenModifiers: []const []const u8,

    /// The formats the clients supports.
    formats: []const []const u8,

    /// Whether the client supports tokens that can overlap each other.
    overlappingTokenSupport: bool = false,

    /// Whether the client supports tokens that can span multiple lines.
    multilineTokenSupport: bool = false,
};

pub const ClientCapabilities = struct {
    workspace: ?struct {
        workspaceFolders: bool = false,
    },
    textDocument: ?struct {
        semanticTokens: ?SemanticTokensClientCapabilities = null,
        hover: ?struct {
            contentFormat: []const []const u8 = &.{},
        },
        completion: ?struct {
            completionItem: ?struct {
                snippetSupport: bool = false,
                documentationFormat: []const []const u8 = &.{},
            },
        },
    },
    /// **LSP extension**
    ///
    /// [Docs](https://clangd.llvm.org/extensions.html#utf-8-offsets)
    offsetEncoding: []const []const u8 = &.{},
};

pub const InitializeParams = struct {
    pub const method = "initialize";
    pub const kind = ParamsifyKind.request;

    capabilities: ClientCapabilities,
    workspaceFolders: ?[]const common.WorkspaceFolder,
};

pub const InitializedParams = struct {
    pub const method = "initialized";
    pub const kind = ParamsifyKind.notification;
};

pub const DidChangeWorkspaceFoldersParams = struct {
    pub const method = "workspace/didChangeWorkspaceFolders";
    pub const kind = ParamsifyKind.notification;

    event: struct {
        added: []const common.WorkspaceFolder,
        removed: []const common.WorkspaceFolder,
    },
};

pub const DidOpenTextDocumentParams = struct {
    pub const method = "textDocument/didOpen";
    pub const kind = ParamsifyKind.notification;

    textDocument: struct {
        /// The text document's URI.
        uri: []const u8,

        /// The text document's language identifier.
        languageId: []const u8,

        /// The version number of this document (it will increase after each
        /// change, including undo/redo).
        version: i32,

        /// The content of the opened text document.
        text: []const u8,
    },
};

pub const TextDocumentIdentifier = struct {
    uri: []const u8,
};

pub const ChangeDocument = struct {
    comptime method: []const u8 = "textDocument/didChange",

    params: struct {
        textDocument: TextDocumentIdentifier,
        contentChanges: json.Value,
    },
};

const TextDocumentIdentifierRequestParams = struct {
    textDocument: TextDocumentIdentifier,
};

pub const TextDocumentSaveReason = enum(i64) {
    /// Manually triggered, e.g. by the user pressing save, by starting
    /// debugging, or by an API call.
    manual = 1,

    /// Automatic after a delay.
    after_delay = 2,

    /// When the editor lost focus.
    focus_out = 3,

    usingnamespace common.EnumStringify(@This());
};

pub const SaveDocument = struct {
    comptime method: []const u8 = "textDocument/willSave",

    params: struct {
        textDocument: TextDocumentIdentifier,
        reason: TextDocumentSaveReason,
    },
};

pub const CloseDocument = struct {
    comptime method: []const u8 = "textDocument/didClose",

    params: TextDocumentIdentifierRequestParams,
};

pub const SemanticTokensFull = struct {
    params: TextDocumentIdentifierRequestParams,
};

const TextDocumentIdentifierPositionRequest = struct {
    textDocument: TextDocumentIdentifier,
    position: common.Position,
};

pub const SignatureHelp = struct {
    comptime method: []const u8 = "textDocument/signatureHelp",

    params: struct {
        textDocument: TextDocumentIdentifier,
        position: common.Position,
        context: ?struct {
            triggerKind: enum(u32) {
                invoked = 1,
                trigger_character = 2,
                content_change = 3,
            },
            triggerCharacter: ?[]const u8,
            isRetrigger: bool,
            activeSignatureHelp: ?common.SignatureHelp,
        },
    },
};

// TODO: fully implement
pub const CompletionParams = struct {
    pub const method = "textDocument/completion";
    pub const kind = ParamsifyKind.request;

    textDocument: TextDocumentIdentifier,
    position: common.Position,
};
pub const GotoDefinition = TextDocumentIdentifierPositionRequest;
pub const GotoDeclaration = TextDocumentIdentifierPositionRequest;
pub const Hover = TextDocumentIdentifierPositionRequest;
pub const DocumentSymbols = struct {
    params: TextDocumentIdentifierRequestParams,
};
pub const Formatting = struct {
    params: TextDocumentIdentifierRequestParams,
};
pub const Rename = struct {
    params: struct {
        textDocument: TextDocumentIdentifier,
        position: common.Position,
        newName: []const u8,
    },
};

pub const References = struct {
    params: struct {
        textDocument: TextDocumentIdentifier,
        position: common.Position,
        context: struct {
            includeDeclaration: bool,
        },
    },
};
