const std = @import("std");
const zv = @import("zig2vec");

const grav_shift = 10;
const drag_shift = 8;
const start_x: i16 = 100 << 8;
const start_vy: i16 = 2 << 8;
const tail_samples = 32;
const tail_buf = 0xC8A0;

fn sat(v: f32) i8 {
    const r = @round(v);
    if (r > 127) return 127;
    if (r < -128) return -128;
    return @as(i8, @intFromFloat(r));
}

fn arc(comptime n: usize, r: f32, a0: f32, a1: f32) [n * 2]i8 {
    var out: [n * 2]i8 = undefined;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const t0 = a0 + (a1 - a0) * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(n));
        const t1 = a0 + (a1 - a0) * @as(f32, @floatFromInt(i + 1)) / @as(f32, @floatFromInt(n));
        out[i * 2] = sat(r * @sin(t1) - r * @sin(t0));
        out[i * 2 + 1] = sat(r * @cos(t1) - r * @cos(t0));
    }
    return out;
}

fn drawPart(a: *zv.Asm, dy: i8, dx: i8, count: usize, name: []const u8) void {
    a.jsr(zv.bios.Reset0Ref);
    a.line(" lda $C882");
    a.fmt(" adda #{d}", .{dy});
    a.line(" ldb $C880");
    a.fmt(" addb #{d}", .{dx});
    a.jsr(zv.bios.Moveto_d);
    a.fmt(" ldb #{d}", .{count});
    a.ldx(name);
    a.jsr(zv.bios.Draw_VLc);
}

fn game(a: *zv.Asm) void {
    const pi = std.math.pi;
    const circle = arc(8, 14, -pi / 2.0, -pi / 2.0 + 2.0 * pi);
    const smile = arc(5, 8, 200.0 * pi / 180.0, 340.0 * pi / 180.0);
    const smile_y = sat(8 * @sin(200.0 * pi / 180.0));
    const smile_x = sat(8 * @cos(200.0 * pi / 180.0));
    const eye = [_]i8{ 3, 2, 0, -4, -3, 2 };

    a.fmt("tailbuf equ ${X:0>4}", .{tail_buf});
    a.fmt("; grav {d}, drag {d}, tail {d} samples", .{ grav_shift, drag_shift, tail_samples });
    zv.header(a, "SMILE");

    a.fmt(" ldd #{d}", .{start_x});
    a.line(" std $C880");
    a.line(" ldd #0");
    a.line(" std $C882");
    a.line(" std $C884");
    a.fmt(" ldd #{d}", .{start_vy});
    a.line(" std $C886");
    a.line(" clr $C888");
    a.line(" clr $C889");
    a.line(" clr $C88F");

    a.label("frame");
    a.jsr(zv.bios.Wait_Recal);
    a.line(" lda #6");
    a.line(" sta $C82A");
    a.line(" lda #4");
    a.line(" sta $C82B");
    a.line(" lda $C888");
    a.line(" beq do_phys");
    a.line(" ldd #0");
    a.line(" std $C884");
    a.line(" std $C886");
    a.line(" lbra after_phys");

    a.label("do_phys");
    a.pull(0xC880, 0xC884, grav_shift, "gravx");
    a.pull(0xC882, 0xC886, grav_shift, "gravy");
    a.pull(0xC884, 0xC884, drag_shift, "dragx");
    a.pull(0xC886, 0xC886, drag_shift, "dragy");
    a.line(" ldd $C880");
    a.line(" addd $C884");
    a.line(" std $C880");
    a.line(" ldd $C882");
    a.line(" addd $C886");
    a.line(" std $C882");
    a.line(" lda $C880");
    a.line(" bpl xabs");
    a.line(" nega");
    a.label("xabs");
    a.line(" cmpa #32");
    a.line(" lbhi after_phys");
    a.line(" lda $C882");
    a.line(" bpl yabs");
    a.line(" nega");
    a.label("yabs");
    a.line(" cmpa #18");
    a.line(" lbhi after_phys");
    a.line(" inc $C888");

    a.label("after_phys");
    a.line(" lda $C889");
    a.line(" lsla");
    a.line(" ldx #tailbuf");
    a.line(" leax a,x");
    a.line(" lda $C882");
    a.line(" sta ,x");
    a.line(" lda $C880");
    a.line(" sta 1,x");
    a.line(" inc $C889");
    a.line(" lda $C889");
    a.line(" anda #$1F");
    a.line(" sta $C889");
    a.line(" lda $C88F");
    a.line(" cmpa #32");
    a.line(" bhs stored");
    a.line(" inca");
    a.line(" sta $C88F");
    a.label("stored");

    a.line(" lda $C888");
    a.line(" lbne use_bye");
    a.line(" ldu #hello");
    a.line(" lbra print_msg");
    a.label("use_bye");
    a.line(" ldu #goodbye");
    a.label("print_msg");
    a.jsr(zv.bios.Intensity_5F);
    a.line(" lda #4");
    a.line(" ldb #-36");
    a.jsr(zv.bios.Print_Str_d);

    a.line(" lda $C884");
    a.line(" bpl vxpos");
    a.line(" nega");
    a.label("vxpos");
    a.line(" sta $C89A");
    a.line(" lda $C886");
    a.line(" bpl vypos");
    a.line(" nega");
    a.label("vypos");
    a.line(" adda $C89A");
    a.line(" cmpa #7");
    a.line(" bls spd_ok");
    a.line(" lda #7");
    a.label("spd_ok");
    a.line(" lsla");
    a.line(" lsla");
    a.line(" adda #3");
    a.line(" cmpa $C88F");
    a.line(" bls len_ok");
    a.line(" lda $C88F");
    a.label("len_ok");
    a.line(" sta $C88E");
    a.line(" cmpa #2");
    a.line(" lblo no_tail");

    a.line(" lda $C889");
    a.line(" suba $C88E");
    a.line(" anda #$1F");
    a.line(" sta $C88C");
    a.jsr(zv.bios.Reset0Ref);
    a.line(" jsr load_slot");
    a.line(" sta $C894");
    a.line(" stb $C895");
    a.jsr(zv.bios.Moveto_d);
    a.line(" lda #$08");
    a.line(" sta $C88D");
    a.line(" lda $C88E");
    a.line(" deca");
    a.line(" sta $C896");

    a.label("seg");
    a.line(" lda $C88C");
    a.line(" inca");
    a.line(" anda #$1F");
    a.line(" sta $C88C");
    a.line(" jsr load_slot");
    a.line(" sta $C897");
    a.line(" stb $C898");
    a.line(" lda $C897");
    a.line(" suba $C894");
    a.line(" sta $C89A");
    a.line(" lda $C898");
    a.line(" suba $C895");
    a.line(" sta $C89B");
    a.line(" lda $C88D");
    a.jsr(zv.bios.Intensity_a);
    a.line(" lda $C89A");
    a.line(" ldb $C89B");
    a.jsr(zv.bios.Draw_Line_d);
    a.line(" lda $C897");
    a.line(" sta $C894");
    a.line(" lda $C898");
    a.line(" sta $C895");
    a.line(" lda $C88D");
    a.line(" adda #6");
    a.line(" cmpa #$5F");
    a.line(" bls bright");
    a.line(" lda #$5F");
    a.label("bright");
    a.line(" sta $C88D");
    a.line(" dec $C896");
    a.line(" lbne seg");

    a.label("no_tail");
    a.jsr(zv.bios.Intensity_5F);
    drawPart(a, sat(14 * @sin(-pi / 2.0)), 0, 8, "circle");
    drawPart(a, 6, -6, 3, "eye");
    drawPart(a, 6, 6, 3, "eye");
    drawPart(a, smile_y, smile_x, 5, "smile");
    a.line(" lbra frame");

    a.label("load_slot");
    a.line(" lda $C88C");
    a.line(" lsla");
    a.line(" ldx #tailbuf");
    a.line(" leax a,x");
    a.line(" lda ,x");
    a.line(" ldb 1,x");
    a.line(" rts");

    a.text("hello", "HELLO WORLD");
    a.text("goodbye", "GOODBYE WORLD");
    a.pairs("circle", &circle);
    a.pairs("eye", &eye);
    a.pairs("smile", &smile);
}

pub fn main() !void {
    var storage: [16384]u8 = undefined;
    var a = zv.Asm{ .buf = &storage };
    game(&a);
    try zv.writeStdout(&a);
}
