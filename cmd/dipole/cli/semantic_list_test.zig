const std = @import("std");
const semantic_list = @import("semantic_list");

test "TS3-001-001: semantic list emits canonical projection identities" {
    const alloc = std.testing.allocator;
    const bytes = try semantic_list.listProjections(alloc);
    defer alloc.free(bytes);

    // Sorted by (name, version=null then explicit). Registry now includes breakpoint.list@1.0 and register.snapshot@1.0 (opaque snapshot projections).
    const expected =
        \\[{"permitted_fields":["category"],"projection_id":"breakpoint.list","version":{"major":1,"minor":0}},{"permitted_fields":["category"],"projection_id":"event.kind","version":null},{"permitted_fields":["category"],"projection_id":"event.kind","version":{"major":1,"minor":0}},{"permitted_fields":["category"],"projection_id":"register.snapshot","version":{"major":1,"minor":0}}]
    ;

    try std.testing.expectEqualStrings(expected, bytes);
}
