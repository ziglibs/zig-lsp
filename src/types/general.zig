//! General messages

const common = @import("common.zig");

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
    pub const kind = common.PacketKind.request;

    capabilities: ClientCapabilities,
    workspaceFolders: ?[]const common.WorkspaceFolder,
};

pub const InitializedParams = struct {
    pub const method = "initialized";
    pub const kind = common.PacketKind.notification;
};
