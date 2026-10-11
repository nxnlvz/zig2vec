const zv = @import("zig2vec");

fn game(a: *zv.Asm) void {
    zv.header(a, "HELLO");
    a.label("frame");
    a.jsr(zv.bios.Wait_Recal);
    a.jsr(zv.bios.Intensity_5F);
    a.line(" ldu #hello");
    a.line(" lda #16");
    a.line(" ldb #-80");
    a.jsr(zv.bios.Print_Str_d);
    a.line(" bra frame");
    a.text("hello", "HELLO WORLD");
}

pub fn main() !void {
    var storage: [2048]u8 = undefined;
    var a = zv.Asm{ .buf = &storage };
    game(&a);
    try zv.writeStdout(&a);
}
