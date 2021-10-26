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
