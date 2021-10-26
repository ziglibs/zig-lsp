const common = @import("common.zig");

/// The document open notification is sent from the client
/// to the server to signal newly opened text documents.
/// The document’s content is now managed by the client and
/// the server must not try to read the document’s content
/// using the document’s Uri. Open in this sense means it
/// is managed by the client. It doesn’t necessarily mean
/// that its content is presented in an editor. An open
/// notification must not be sent more than once without a
/// corresponding close notification send before. This means
/// open and close notification must be balanced and the
/// max open count for a particular textDocument is one.
///
/// Note that a server’s ability to fulfill requests is independent of whether a text document is open or closed.
///
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-16/#textDocument_didOpen)
pub const DidOpenTextDocumentParams = struct {
    pub const method = "textDocument/didOpen";
    pub const kind = common.PacketKind.notification;

    textDocument: common.TextDocumentItem,
};

/// An event describing a change to a text document. If range and rangeLength are
/// omitted the new text is considered to be the full content of the document.
///
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#textDocumentContentChangeEvent)
pub const TextDocumentContentChangeEvent = union(enum) {
    partial: struct {
        /// The range of the document that changed.
        range: common.Range,
        /// he new text for the provided range.
        text: []const u8,
    },
    full: struct {
        /// The new text of the whole document.
        text: []const u8,
    },
};

/// The document change notification is sent from the client to the server to signal changes to a text document.
/// Before a client can change a text document it must claim ownership of its content using the textDocument/didOpen notification.
/// In 2.0 the shape of the params has changed to include proper version numbers.
///
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#didChangeTextDocumentParams)
pub const DidChangeTextDocumentParams = struct {
    pub const method = "textDocument/didChange";
    pub const kind = common.PacketKind.notification;

    /// The document that did change. The version number points
    /// to the version after all provided content changes have
    /// been applied.
    textDocument: common.VersionedTextDocumentIdentifier,
    contentChanges: []TextDocumentContentChangeEvent,
};
