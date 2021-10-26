//! Common types, including Basic Structures

const std = @import("std");
const json = @import("../json.zig");

// Utils

pub fn EnumStringify(comptime T: type) type {
    return struct {
        pub fn jsonStringify(value: T, options: json.StringifyOptions, out_stream: anytype) !void {
            try json.stringify(@enumToInt(value), options, out_stream);
        }
    };
}

pub const PacketKind = enum { request, response, notification };
pub fn Paramsify(comptime T: type) type {
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
                .field_type = RequestId,
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

// LSP types
// https://microsoft.github.io/language-server-protocol/specifications/specification-3-16/

/// Defines an integer number in the range of -2^31 to 2^31 - 1.
pub const integer = i64;

/// Defines an unsigned integer number in the range of 0 to 2^31 - 1.
pub const uinteger = i64;

/// Defines a decimal number. Since decimal numbers are very
/// rare in the language server specification we denote the
/// exact range with every decimal using the mathematics
/// interval notation (e.g. [0, 1] denotes all decimals d with
/// 0 <= d <= 1.
pub const decimal = i64;

/// Many of the interfaces contain fields that correspond to the URI of a document.
/// For clarity, the type of such a field is declared as a DocumentUri.
/// Over the wire, it will still be transferred as a string, but this guarantees
/// that the contents of that string can be parsed as a valid URI.
const DocumentUri = []const u8;
/// There is also a tagging interface for normal non document URIs. It maps to a string as well.
const Uri = []const u8;

/// Position in a text document expressed as zero-based line and zero-based character offset.
/// A position is between two characters like an ‘insert’ cursor in an editor.
/// Special values like for example -1 to denote the end of a line are not supported.
///
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#position)
pub const Position = struct {
    /// Line position in a document (zero-based).
    line: uinteger,

    /// Character offset on a line in a document (zero-based). Assuming that
    /// the line is represented as a string, the `character` value represents
    /// the gap between the `character` and `character + 1`.
    ///
    /// If the character value is greater than the line length it defaults back
    /// to the line length.
    character: uinteger,
};

/// A range in a text document expressed as (zero-based) start and end positions.
/// A range is comparable to a selection in an editor. Therefore the end position is exclusive.
/// If you want to specify a range that contains a line including the line ending character(s)
/// then use an end position denoting the start of the next line.
///
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#range)
pub const Range = struct {
    /// The range's start position.
    start: Position,

    /// The range's end position.
    end: Position,
};

/// Represents a location inside a resource, such as a line inside a text file.
///
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#location)
pub const Location = struct {
    uri: DocumentUri,
    range: Range,
};

/// Represents a link between a source and a target location.
///
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#locationLink)
pub const LocationLink = struct {
    /// Span of the origin of this link.
    ///
    /// Used as the underlined span for mouse interaction. Defaults to the word
    /// range at the mouse position.
    originSelectionRange: Range,

    /// The target resource identifier of this link.
    targetUri: DocumentUri,

    /// The full target range of this link. If the target for example is a symbol
    /// then target range is the range enclosing this symbol not including
    /// leading/trailing whitespace but everything else like comments. This
    /// information is typically used to highlight the range in the editor.
    targetRange: Range,

    /// The range that should be selected and revealed when this link is being
    /// followed, e.g the name of a function. Must be contained by the the
    /// `targetRange`. See also `DocumentSymbol#range`
    targetSelectionRange: Range,
};

pub const DiagnosticSeverity = enum(i64) {
    err = 1,
    warn = 2,
    info = 3,
    log = 4,

    pub fn jsonStringify(value: DiagnosticSeverity, options: json.StringifyOptions, out_stream: anytype) !void {
        try json.stringify(@enumToInt(value), options, out_stream);
    }
};

pub const DiagnosticCode = union(enum) {
    integer: integer,
    string: []const u8,
};

/// The diagnostic tags.
///
/// Ssince 3.15.0
pub const DiagnosticTag = enum(i64) {
    /// Unused or unnecessary code.
    /// 
    /// Clients are allowed to render diagnostics with this tag faded out
    /// instead of having an error squiggle.
    unnecessary = 1,

    /// Deprecated or obsolete code.
    ///
    /// Clients are allowed to rendered diagnostics with this tag strike through.
    deprecated = 2,
};

/// Structure to capture a description for an error code.
/// 
/// Since 3.16.0
pub const CodeDescription = struct {
    /// An URI to open with more information about the diagnostic error.
    href: Uri,
};

/// Represents a related message and source code location for a diagnostic.
/// This should be used to point to code locations that cause or are related to
/// a diagnostics, e.g when duplicating a symbol in a scope.
pub const DiagnosticRelatedInformation = struct {
    /// The location of this related diagnostic information.
    location: Location,

    /// The message of this related diagnostic information.
    message: []const u8,
};

/// Represents a diagnostic, such as a compiler error or warning.
/// Diagnostic objects are only valid in the scope of a resource.
///
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#diagnostic)
pub const Diagnostic = struct {
    /// The range at which the message applies.
    range: Range,

    /// The diagnostic's severity. Can be omitted. If omitted it is up to the
    /// client to interpret diagnostics as error, warning, info or hint.
    severity: ?DiagnosticSeverity = null,

    /// The diagnostic's code, which might appear in the user interface.
    code: DiagnosticCode,

    /// An optional property to describe the error code.
    /// 
    /// Since 3.16.0
    codeDescription: CodeDescription = null,

    /// A human-readable string describing the source of this
    /// diagnostic, e.g. 'typescript' or 'super lint'.
    source: []const u8 = null,

    /// The diagnostic's message.
    message: []const u8,

    /// Additional metadata about the diagnostic.
    /// 
    /// Since 3.15.0
    tags: ?[]DiagnosticTag = null,

    // An array of related diagnostic information, e.g. when symbol-names within
    // a scope collide all definitions can be marked via this property.
    relatedInformation: ?[]DiagnosticRelatedInformation = null,

    // TODO: wtf is going on here???
    // A data entry field that is preserved between a
    // `textDocument/publishDiagnostics` notification and
    // `textDocument/codeAction` request.
    //
    // Since 3.16.0
    // data?: unknown;
};

/// Hover response
pub const Hover = struct {
    contents: MarkupContent,
};

pub const TextDocumentIdentifier = struct {
    uri: []const u8,
};

/// Id of a request
pub const RequestId = union(enum) {
    string: []const u8,
    integer: i64,
    float: f64,
};

pub const TextDocument = struct {
    uri: []const u8,
    // This is a substring of mem starting at 0
    text: [:0]const u8,
    // This holds the memory that we have actually allocated.
    mem: []u8,

    const Held = struct {
        document: *const TextDocument,
        popped: u8,
        start_index: usize,
        end_index: usize,

        pub fn data(self: @This()) [:0]const u8 {
            return self.document.mem[self.start_index..self.end_index :0];
        }

        pub fn release(self: *@This()) void {
            self.document.mem[self.end_index] = self.popped;
        }
    };

    pub fn borrowNullTerminatedSlice(self: *const @This(), start_idx: usize, end_idx: usize) Held {
        std.debug.assert(end_idx >= start_idx);
        const popped_char = self.mem[end_idx];
        self.mem[end_idx] = 0;
        return .{
            .document = self,
            .popped = popped_char,
            .start_index = start_idx,
            .end_index = end_idx,
        };
    }
};

pub const WorkspaceEdit = struct {
    changes: ?std.StringHashMap([]TextEdit),

    pub fn jsonStringify(self: WorkspaceEdit, options: json.StringifyOptions, writer: anytype) @TypeOf(writer).Error!void {
        try writer.writeByte('{');
        if (self.changes) |changes| {
            try writer.writeAll("\"changes\": {");
            var it = changes.iterator();
            var idx: usize = 0;
            while (it.next()) |entry| : (idx += 1) {
                if (idx != 0) try writer.writeAll(", ");

                try writer.writeByte('"');
                try writer.writeAll(entry.key_ptr.*);
                try writer.writeAll("\":");
                try json.stringify(entry.value_ptr.*, options, writer);
            }
            try writer.writeByte('}');
        }
        try writer.writeByte('}');
    }
};

pub const TextEdit = struct {
    range: Range,
    newText: []const u8,
};

pub const MarkupContent = struct {
    pub const Kind = enum(u1) {
        plaintext = 0,
        markdown = 1,

        pub fn jsonStringify(value: Kind, options: json.StringifyOptions, out_stream: anytype) !void {
            const str = switch (value) {
                .plaintext => "plaintext",
                .markdown => "markdown",
            };
            try json.stringify(str, options, out_stream);
        }
    };

    kind: Kind = .markdown,
    value: []const u8,
};

pub const InsertTextFormat = enum(i64) {
    plaintext = 1,
    snippet = 2,

    pub fn jsonStringify(value: InsertTextFormat, options: json.StringifyOptions, writer: anytype) !void {
        try json.stringify(@enumToInt(value), options, writer);
    }
};

pub const DocumentSymbol = struct {
    const Kind = enum(u32) {
        file = 1,
        module = 2,
        namespace = 3,
        package = 4,
        class = 5,
        method = 6,
        property = 7,
        field = 8,
        constructor = 9,
        @"enum" = 10,
        interface = 11,
        function = 12,
        variable = 13,
        constant = 14,
        string = 15,
        number = 16,
        boolean = 17,
        array = 18,
        object = 19,
        key = 20,
        @"null" = 21,
        enum_member = 22,
        @"struct" = 23,
        event = 24,
        operator = 25,
        type_parameter = 26,

        pub fn jsonStringify(value: Kind, options: json.StringifyOptions, writer: anytype) !void {
            try json.stringify(@enumToInt(value), options, writer);
        }
    };

    name: []const u8,
    detail: ?[]const u8 = null,
    kind: Kind,
    deprecated: bool = false,
    range: Range,
    selectionRange: Range,
    children: []const DocumentSymbol = &[_]DocumentSymbol{},
};

pub const WorkspaceFolder = struct {
    uri: []const u8,
    name: []const u8,
};
