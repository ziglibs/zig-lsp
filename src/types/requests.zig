///! Process client requests / notifications
const std = @import("std");
const json = @import("../json.zig");
const common = @import("common.zig");

const general = @import("general.zig");

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
};

pub const RequestParams = union(enum) {
    initialize: general.InitializeParams,
};

/// Params of a request (params)
pub const RequestParseTarget = union(enum) {
    initialize: common.Paramsify(general.InitializeParams),

    pub fn toMessage(self: RequestParseTarget) RequestMessage {
        inline for (std.meta.fields(RequestParseTarget)) |field, i| {
            if (@enumToInt(self) == i) {
                return .{
                    .id = @field(self, field.name).id,
                    .method = @field(self, field.name).method,
                    .params = @unionInit(RequestParams, field.name, @field(self, field.name).params),
                };
            }
        }

        unreachable;
    }
};

/// The base protocol offers support for request cancellation.
/// To cancel a request, a notification message with the following properties is sent.
///
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#cancelRequest)
pub const CancelParams = struct {
    pub const method = "$/cancelRequest";
    pub const kind = common.PacketKind.notification;

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
    pub const kind = common.PacketKind.notification;

    /// The progress token provided by the client or server.
    token: ProgressToken,

    /// The progress data.
    value: ProgressValue,
};

pub const DidChangeWorkspaceFoldersParams = struct {
    pub const method = "workspace/didChangeWorkspaceFolders";
    pub const kind = common.PacketKind.notification;

    event: struct {
        added: []const common.WorkspaceFolder,
        removed: []const common.WorkspaceFolder,
    },
};

pub const DidOpenTextDocumentParams = struct {
    pub const method = "textDocument/didOpen";
    pub const kind = common.PacketKind.notification;

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
    pub const kind = common.PacketKind.request;

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
