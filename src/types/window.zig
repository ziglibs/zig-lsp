const json = @import("../json.zig");
const common = @import("common.zig");

/// Type of a debug message
/// 
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#messageType)
pub const MessageType = enum(i64) {
    err = 1,
    warn = 2,
    info = 3,
    log = 4,

    pub fn jsonStringify(value: MessageType, options: json.StringifyOptions, out_stream: anytype) !void {
        try json.stringify(@enumToInt(value), options, out_stream);
    }
};

/// The log message notification is sent from the server to the client to ask the client to log a particular message.
///
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-16/#window_logMessage)
pub const LogMessageParams = struct {
    pub const method = "window/logMessage";
    pub const kind = common.PacketKind.notification;

    /// The message type. See `MessageType`.
    @"type": MessageType,

    /// The actual message.
    message: []const u8,
};
