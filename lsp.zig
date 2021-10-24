const std = @import("std");

pub const RequestHeader = @import("src/RequestHeader.zig");
pub const types = struct {
    pub const common = @import("src/types/common.zig");
    pub const requests = @import("src/types/requests.zig");
    pub const responses = @import("src/types/responses.zig");
};
