//! General messages

const common = @import("common.zig");

pub const InitializeParams = struct {
    pub const method = "initialize";
    pub const kind = common.PacketKind.request;

    capabilities: ClientCapabilities,
    workspaceFolders: ?[]const common.WorkspaceFolder,
};

pub const RegularExpressEngineVersion = union(enum) {
    none: void,
    string: []const u8,
};

/// Client capabilities specific to regular expressions.
///
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#regExp)
pub const RegularExpressionsClientCapabilities = struct {
    /// The engine's name.
    engine: []const u8,

    /// The engine's version.
    version: RegularExpressEngineVersion,
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

pub const ShowMessageRequestClientCapabilities = struct {
    /// Capabilities specific to the `MessageActionItem` type.
    messageActionItem: ?struct {
        additionalPropertiesSupport: ?bool = null,
    } = null,
};

/// Capabilities that existed in the 2.x version of the protocol are still mandatory for clients.
/// Clients cannot opt out of providing them. So even if a client omits the ClientCapabilities.textDocument.synchronization
/// it is still required that the client provides text document synchronization (e.g. open, changed and close notifications).
///
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#clientCapabilities)
pub const ClientCapabilities = struct {
    general: ?struct {
        regularExpressions: ?RegularExpressionsClientCapabilities = null,
    } = null,
    window: ?struct {
        showMessage: ?ShowMessageRequestClientCapabilities = null,
    } = null,
    workspace: ?struct {
        workspaceFolders: bool = false,
    } = null,
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
    } = null,
    /// **LSP extension**
    ///
    /// [Docs](https://clangd.llvm.org/extensions.html#utf-8-offsets)
    offsetEncoding: []const []const u8 = &.{},

    pub const Feature = enum {
        window,
        show_message,
        show_message_action_item,
        show_message_additional_properties,
    };

    /// `ClientCapabilities` is **thicc** so this helps make it simpler :) <3
    pub fn isSupported(self: ClientCapabilities, feature: Feature) bool {
        return switch (feature) {
            .window => self.window != null,
            .show_message => self.isSupported(.window) and self.window.?.showMessage != null,
            .show_message_action_item => self.isSupported(.show_message) and self.window.?.showMessage.?.messageActionItem != null,
            .show_message_additional_properties => self.isSupported(.show_message_action_item) and if (self.window.?.showMessage.?.messageActionItem.?.additionalPropertiesSupport) |v| v else false,
        };
    }
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

pub const InitializedParams = struct {
    pub const method = "initialized";
    pub const kind = common.PacketKind.notification;
};
