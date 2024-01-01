const std = @import("std");

pub fn usizeToString(num:usize, buf:[]u8)void{
    const limb = [1]std.math.big.Limb{num};
    const cons = std.math.big.int.Const{ .limbs = &limb, .positive = true };
    var limb_buf: [10]std.math.big.Limb = undefined;
    _ = std.math.big.int.Const.toString(cons, buf, 10, std.fmt.Case.lower, &limb_buf);
}



test "usizeToString"{
    var buf = [_]u8{0}**10;
    usizeToString(1234567, &buf);
    try std.testing.expect(buf[0]=='1');
    try std.testing.expect(buf[6]=='7');
    try std.testing.expect(buf[7]==0);
}