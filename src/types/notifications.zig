const std = @import("std");
const common = @import("common.zig");

const general = @import("general.zig");

pub const NotificationMessage = struct {
    /// The method to be invoked.
    method: []const u8,

    /// The notification's params.
    params: NotificationParams,
};

pub const NotificationParams = union(enum) {
    initialized: general.InitializedParams,
};

/// Params of a request (params)
pub const NotificationParseTarget = union(enum) {
    initialized: common.Paramsify(general.InitializedParams),

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
