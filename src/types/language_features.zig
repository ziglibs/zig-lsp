const json = @import("../json.zig");
const common = @import("common.zig");

// TODO: fully implement
pub const CompletionParams = struct {
    pub const method = "textDocument/completion";
    pub const kind = common.PacketKind.request;

    textDocument: common.TextDocumentIdentifier,
    position: common.Position,
};

pub const CompletionResult = union(enum) {
    /// If this is provided it is interpreted to be complete.
    /// So it is the same as { isIncomplete: false, items }.
    array: []const CompletionItem,
    completion_list: CompletionList,
};

pub const CompletionList = struct {
    isIncomplete: bool,
    items: []const CompletionItem,
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

        pub fn jsonStringify(value: Kind, options: json.StringifyOptions, out_stream: anytype) !void {
            try json.stringify(@enumToInt(value), options, out_stream);
        }
    };

    label: []const u8,
    kind: Kind,
    textEdit: ?common.TextEdit = null,
    filterText: ?[]const u8 = null,
    insertText: []const u8 = "",
    insertTextFormat: ?common.InsertTextFormat = .plaintext,
    detail: ?[]const u8 = null,
    documentation: ?common.MarkupContent = null,
};
