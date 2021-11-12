const std = @import("std");
const common = @import("common.zig");

const general = @import("general.zig");
const window = @import("window.zig");
const text_sync = @import("text_sync.zig");

pub const NotificationMessage = struct {
    jsonrpc: []const u8 = "2.0",

    /// The method to be invoked.
    method: []const u8,

    /// The notification's params.
    params: NotificationParams,
};

pub const NotificationParams = union(enum) {
    // General
    progress: ProgressParams,
    initialized: general.InitializedParams,

    // Window
    show_message: window.ShowMessageParams,
    log_message: window.LogMessageParams,

    // Text Sync
    did_open: text_sync.DidOpenTextDocumentParams,
    did_change: text_sync.DidChangeTextDocumentParams,
};

/// Params of a request (params)
pub const NotificationParseTarget = union(enum) {
    // General
    progress: common.Paramsify(ProgressParams),
    initialized: common.Paramsify(general.InitializedParams),

    // Window
    show_message: common.Paramsify(window.ShowMessageParams),
    log_message: common.Paramsify(window.LogMessageParams),

    // Text Sync
    did_open: common.Paramsify(text_sync.DidOpenTextDocumentParams),
    did_change: common.Paramsify(text_sync.DidChangeTextDocumentParams),

    pub fn toMessage(self: NotificationParseTarget) NotificationMessage {
        inline for (std.meta.fields(NotificationParseTarget)) |field, i| {
            if (@enumToInt(self) == i) {
                return .{
                    .method = @field(self, field.name).method,
                    .params = @unionInit(NotificationParams, field.name, @field(self, field.name).params),
                };
            }
        }

        unreachable;
    }
};

pub const ProgressToken = union(enum) {
    integer: common.integer,
    string: []const u8,
};

// TODO: Generic T used; what the hell does that mean??
pub const ProgressValue = union(enum) {
    integer: common.integer,
    string: []const u8,
};

/// The base protocol offers also support to report progress in a generic fashion.
/// This mechanism can be used to report any kind of progress including work done progress
/// (usually used to report progress in the user interface using a progress bar)
/// and partial result progress to support streaming of results.
///
/// [Docs](https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#progress)
pub const ProgressParams = struct {
    pub const method = "$/progress";
    pub const kind = common.PacketKind.notification;

    /// The progress token provided by the client or server.
    token: ProgressToken,

    /// The progress data.
    value: ProgressValue,
};
