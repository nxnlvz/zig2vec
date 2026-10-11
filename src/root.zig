const std = @import("std");

/// Vectrex BIOS entries used by the emitters. Addresses are the stock ROM.
pub const bios = struct {
    pub const Wait_Recal = 0xF192;
    pub const Intensity_5F = 0xF2A5;
    pub const Intensity_a = 0xF2AB;
    pub const Reset0Ref = 0xF354;
    pub const Moveto_d = 0xF312;
    pub const Draw_Line_d = 0xF3DF;
    pub const Draw_VLc = 0xF3CE;
    pub const Print_Str_d = 0xF37A;
    pub const music1 = 0xFD0D;
};

/// Writes 6809 text for lwasm. The buffer is caller-owned.
pub const Asm = struct {
    buf: []u8,
    len: usize = 0,

    pub fn append(self: *Asm, text: []const u8) void {
        @memcpy(self.buf[self.len..][0..text.len], text);
        self.len += text.len;
    }

    pub fn line(self: *Asm, text: []const u8) void {
        self.append(text);
        self.append("\n");
    }

    pub fn fmt(self: *Asm, comptime spec: []const u8, args: anytype) void {
        var tmp: [96]u8 = undefined;
        const s = std.fmt.bufPrint(&tmp, spec, args) catch unreachable;
        self.line(s);
    }

    pub fn label(self: *Asm, name: []const u8) void {
        self.append(name);
        self.append(":\n");
    }

    pub fn jsr(self: *Asm, addr: u16) void {
        self.fmt(" jsr ${X:0>4}", .{addr});
    }

    pub fn ldx(self: *Asm, name: []const u8) void {
        self.append(" ldx #");
        self.append(name);
        self.append("\n");
    }

    /// Uppercase string terminated by $80, which Print_Str_d requires.
    pub fn text(self: *Asm, name: []const u8, message: []const u8) void {
        self.label(name);
        self.append(" fcc \"");
        self.append(message);
        self.line("\"");
        self.line(" fcb $80");
    }

    /// Vector list as y,x pairs. `bytes.len` must be even.
    pub fn pairs(self: *Asm, name: []const u8, bytes: []const i8) void {
        self.label(name);
        var i: usize = 0;
        while (i < bytes.len) : (i += 2) {
            self.fmt(" fcb {d},{d}", .{ bytes[i], bytes[i + 1] });
        }
    }

    /// Arithmetic shift of D, `times` times. `loop` is the local label.
    pub fn asrD(self: *Asm, times: usize, loop: []const u8) void {
        self.fmt(" ldy #{d}", .{times});
        self.label(loop);
        self.line(" asra");
        self.line(" rorb");
        self.line(" leay -1,y");
        self.append(" bne ");
        self.append(loop);
        self.append("\n");
    }

    /// `vel = vel - (pos >> shift)`, using $C88A as scratch.
    pub fn pull(self: *Asm, pos: u16, vel: u16, shift: usize, loop: []const u8) void {
        self.fmt(" ldd ${X:0>4}", .{pos});
        self.asrD(shift, loop);
        self.line(" std $C88A");
        self.fmt(" ldd ${X:0>4}", .{vel});
        self.line(" subd $C88A");
        self.fmt(" std ${X:0>4}", .{vel});
    }
};

/// Standard cartridge header. Execution continues at the next emitted line.
pub fn header(a: *Asm, title: []const u8) void {
    a.line(" org $0000");
    a.line(" fcc \"g GCE 2026\"");
    a.line(" fcb $80");
    a.fmt(" fdb ${X:0>4}", .{bios.music1});
    a.line(" fcb $F8,$50,$20,$C8");
    a.append(" fcc \"");
    a.append(title);
    a.line("\"");
    a.line(" fcb $80");
    a.line(" fcb $00");
}

pub fn writeStdout(a: *const Asm) !void {
    try std.posix.write(std.posix.STDOUT_FILENO, a.buf[0..a.len]);
}
