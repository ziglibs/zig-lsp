const RequestHeader = @This();

const std = @import("std");

/// The length of the content part in bytes. This header is required.
content_length: usize,

pub fn encode(self: RequestHeader, writer: anytype) @TypeOf(writer).Error!void {
    try writer.print("Content-Length: {d}\r\nContent-Type: {s}\r\n\r\n", .{ self.content_length, "application/vscode-jsonrpc; charset=utf-8" });
}

pub fn decode(reader: anytype, buffer: []u8) !RequestHeader {
    var request_header = RequestHeader{
        .content_length = undefined,
    };

    var has_content_length = false;
    while (true) {
        const header = try reader.readUntilDelimiter(buffer, '\n');

        if (header.len == 0 or header[header.len - 1] != '\r') return error.MissingCarriageReturn;
        if (header.len == 1) break;

        const header_name = header[0 .. std.mem.indexOf(u8, header, ": ") orelse return error.MissingColon];
        const header_value = header[header_name.len + 2 .. header.len - 1];
        if (std.mem.eql(u8, header_name, "Content-Length")) {
            if (header_value.len == 0) return error.MissingHeaderValue;
            request_header.content_length = std.fmt.parseInt(usize, header_value, 10) catch return error.InvalidContentLength;
            has_content_length = true;
        } else if (std.mem.eql(u8, header_name, "Content-Type")) {
            // lol no
        } else {
            return error.UnknownHeader;
        }
    }

    if (!has_content_length) return error.MissingContentLength;

    return request_header;
}
