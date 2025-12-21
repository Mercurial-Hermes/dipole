const std = @import("std");
const semantic_list = @import("semantic_list");

test "TS3-001-001: semantic list emits canonical projection identities" {
    const alloc = std.testing.allocator;
    const bytes = try semantic_list.listProjections(alloc);
    defer alloc.free(bytes);

    // Sorted by (name, version=null then explicit).
    const expected =
        \\[{"permitted_fields":["category"],"projection_id":"event.kind","version":null},{"permitted_fields":["category"],"projection_id":"event.kind","version":{"major":1,"minor":0}}]
    ;

    try std.testing.expectEqualStrings(expected, bytes);
}
