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
    initialized: general.InitializedParams,

    // Window
    log_message: window.LogMessageParams,

    // Text Sync
    did_open: text_sync.DidOpenTextDocumentParams,
};

/// Params of a request (params)
pub const NotificationParseTarget = union(enum) {
    // General
    initialized: common.Paramsify(general.InitializedParams),

    // Window
    log_message: common.Paramsify(window.LogMessageParams),

    // Text Sync
    did_open: common.Paramsify(text_sync.DidOpenTextDocumentParams),

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
