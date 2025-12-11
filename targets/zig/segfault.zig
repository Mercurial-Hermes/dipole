pub fn main() void {
    // Use a C pointer so null is permitted; deref to force a crash.
    const p: [*c]volatile u8 = @ptrFromInt(0);
    p[0] = 1;
}
