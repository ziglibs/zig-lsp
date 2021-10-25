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

    pub fn jsonStringify(value: MessageType, options: json.StringifyOptions, out_stream: anytype) !void {
        try json.stringify(@enumToInt(value), options, out_stream);
    }
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
