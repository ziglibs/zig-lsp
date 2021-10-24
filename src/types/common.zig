const std = @import("std");

// Utils

pub const EnumStringify = struct {
    pub fn jsonStringify(value: @This(), options: std.json.StringifyOptions, out_stream: anytype) !void {
        try std.json.stringify(@enumToInt(value), options, out_stream);
    }
};

// LSP types
// https://microsoft.github.io/language-server-protocol/specifications/specification-3-16/

pub const Position = struct {
    line: i64,
    character: i64,
};

pub const Range = struct {
    start: Position,
    end: Position,
};

pub const Location = struct {
    uri: []const u8,
    range: Range,
};

/// Hover response
pub const Hover = struct {
    contents: MarkupContent,
};

/// Id of a request
pub const RequestId = union(enum) {
    string: []const u8,
    integer: i64,
    float: f64,
};

/// JSONRPC notifications
pub const Notification = struct {
    pub const Params = union(enum) {
        log_message: struct {
            @"type": MessageType,
            message: []const u8,
        },
        publish_diagnostics: struct {
            uri: []const u8,
            diagnostics: []Diagnostic,
        },
        show_message: struct {
            @"type": MessageType,
            message: []const u8,
        },
    };

    jsonrpc: []const u8 = "2.0",
    method: []const u8,
    params: Params,
};

/// Type of a debug message
/// https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#messageType
pub const MessageType = enum(i64) {
    err = 1,
    warn = 2,
    info = 3,
    log = 4,

    pub fn jsonStringify(value: MessageType, options: std.json.StringifyOptions, out_stream: anytype) !void {
        try std.json.stringify(@enumToInt(value), options, out_stream);
    }
};

pub const DiagnosticSeverity = enum(i64) {
    err = 1,
    warn = 2,
    info = 3,
    log = 4,

    pub fn jsonStringify(value: DiagnosticSeverity, options: std.json.StringifyOptions, out_stream: anytype) !void {
        try std.json.stringify(@enumToInt(value), options, out_stream);
    }
};

pub const Diagnostic = struct {
    range: Range,
    severity: DiagnosticSeverity,
    code: []const u8,
    source: []const u8,
    message: []const u8,
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

    pub fn jsonStringify(self: WorkspaceEdit, options: std.json.StringifyOptions, writer: anytype) @TypeOf(writer).Error!void {
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
                try std.json.stringify(entry.value_ptr.*, options, writer);
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

        pub fn jsonStringify(value: Kind, options: std.json.StringifyOptions, out_stream: anytype) !void {
            const str = switch (value) {
                .plaintext => "plaintext",
                .markdown => "markdown",
            };
            try std.json.stringify(str, options, out_stream);
        }
    };

    kind: Kind = .Markdown,
    value: []const u8,
};

pub const CompletionList = struct {
    isIncomplete: bool,
    items: []const CompletionItem,
};

pub const InsertTextFormat = enum(i64) {
    plaintext = 1,
    snippet = 2,

    pub fn jsonStringify(value: InsertTextFormat, options: std.json.StringifyOptions, writer: anytype) !void {
        try std.json.stringify(@enumToInt(value), options, writer);
    }
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
    textEdit: ?TextEdit = null,
    filterText: ?[]const u8 = null,
    insertText: []const u8 = "",
    insertTextFormat: ?InsertTextFormat = .PlainText,
    detail: ?[]const u8 = null,
    documentation: ?MarkupContent = null,
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

        pub fn jsonStringify(value: Kind, options: std.json.StringifyOptions, writer: anytype) !void {
            try std.json.stringify(@enumToInt(value), options, writer);
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

// Only includes options we set in our initialize result.
const InitializeResult = struct {
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

            usingnamespace EnumStringify;
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
        semanticTokensProvider: struct {
            full: bool,
            range: bool,
            legend: struct {
                tokenTypes: []const []const u8,
                tokenModifiers: []const []const u8,
            },
        },
    },
    serverInfo: struct {
        name: []const u8,
        version: ?[]const u8 = null,
    },
};
