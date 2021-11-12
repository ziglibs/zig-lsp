///! Process client requests / notifications
const std = @import("std");
const json = @import("../json.zig");
const common = @import("common.zig");

const general = @import("general.zig");
const language_features = @import("language_features.zig");

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
    // General
    initialize: general.InitializeParams,

    // Window
    // show_message_request
    // show_document

    // Language Features
    completion: language_features.CompletionParams,
};

/// Params of a request (params)
pub const RequestParseTarget = union(enum) {
    // General
    initialize: common.Paramsify(general.InitializeParams),

    // Language Features
    completion: common.Paramsify(language_features.CompletionParams),

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

pub const DidChangeWorkspaceFoldersParams = struct {
    pub const method = "workspace/didChangeWorkspaceFolders";
    pub const kind = common.PacketKind.notification;

    event: struct {
        added: []const common.WorkspaceFolder,
        removed: []const common.WorkspaceFolder,
    },
};

const TextDocumentIdentifierRequestParams = struct {
    textDocument: common.TextDocumentIdentifier,
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
        textDocument: common.TextDocumentIdentifier,
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
    textDocument: common.TextDocumentIdentifier,
    position: common.Position,
};

pub const SignatureHelp = struct {
    comptime method: []const u8 = "textDocument/signatureHelp",

    params: struct {
        textDocument: common.TextDocumentIdentifier,
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
        textDocument: common.TextDocumentIdentifier,
        position: common.Position,
        newName: []const u8,
    },
};

pub const References = struct {
    params: struct {
        textDocument: common.TextDocumentIdentifier,
        position: common.Position,
        context: struct {
            includeDeclaration: bool,
        },
    },
};
