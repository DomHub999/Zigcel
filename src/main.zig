const std = @import("std");
const lex = @import("lexer.zig");



pub fn main() !void {

    // const rule = lex.Tokenizer.getRule('(');
    // std.debug.print("{}", .{rule.token_type});

    // const Enum = enum{
    //     first,
    //     second,
    // };

    // const Union = union(Enum){
    //     first: struct{
    //         age:usize,
    //         married:bool,
    //     },

    //     second: struct{
    //         sausage: bool,
    //     },
    // };

    // const u = Union{.first = .{.age = 10, .married = false}};

    // switch(u){
    //     Enum.first => std.debug.print("{}", .{u.first.age}),
    //     Enum.second => unreachable,
    // }

    // const num1 =  try std.fmt.parseFloat(f64, "10.5"[0..]);
    // const num2 =  try std.fmt.parseFloat(f64, "9.5"[0..]);

    // const result = num1 + num2;
    // std.debug.print("{}", .{result});

    parseSum();

    //  var ts: ?usize = null;
    //  _ = ts;

    //  var num:usize = 150;

    // var point: ?*usize = &num;

    // if (point) |p| {
    //      std.debug.print("{}", .{p.*});
         
    //      }


    //  if (ts != 100) {
    //     std.debug.print("{s}", .{"is hundred"});
    //  }

    // if (ts) |*t| {
    //     t.* = 50;
    // }

    // std.debug.print("{}", .{ts.?});

    

}

const s = "2*8+5*8";
//const s = "2*8+5";
//const s = "2+8*5";
//const s = "1+2+3*5";
//const s = "1+1";
// const s = "8/2";
//const s = "3+8/2";

var i: usize = 0;
var first = true;

fn parseSum() void {
    var result = parseProduct();

    while (s[i] == '+') {
        i += 1;
        var result2 = parseProduct();

        if (first) {
            std.debug.print("{s} {c}\n", .{ "push ", result.? });
            std.debug.print("{s} {c}\n", .{ "push ", result2.? });
            first = false;
        } else {
                if(result != null){
                std.debug.print("{s} {c}\n", .{ "push ", result.? });
            }
                if(result2 != null){
                std.debug.print("{s} {c}\n", .{ "push ", result2.? });
            }
        }

        result = null;
        //result2 = null;

        std.debug.print("add\n", .{});
    }

}

fn parseProduct() ?u8 {
    var result = parseFactor();


    while (s[i] == '*') {
        i += 1;
        var result2 = parseFactor();

        if (first) {
            std.debug.print("{s} {c}\n", .{ "push ", result.? });
            std.debug.print("{s} {c}\n", .{ "push ", result2.? });
            first = false;
        } else {
                if(result != null){
                std.debug.print("{s} {c}\n", .{ "push ", result.? });
            }
                if(result2 != null){
                std.debug.print("{s} {c}\n", .{ "push ", result2.? });
            }
        }
         result = null;
         //result2 = null;

        std.debug.print("mul\n", .{});
        return null;
    }

    while (s[i] == '/') {
        i += 1;
        var result2 = parseFactor();

        if (first) {
            std.debug.print("{s} {c}\n", .{ "push ", result.? });
            std.debug.print("{s} {c}\n", .{ "push ", result2.? });
            first = false;
        } else {
                if(result != null){
                std.debug.print("{s} {c}\n", .{ "push ", result.? });
            }
                if(result2 != null){
                std.debug.print("{s} {c}\n", .{ "push ", result2.? });
            }
        }

        result = null;
        //result2 = null;

        std.debug.print("div\n", .{});
        return null;
    }



    return result;
}

fn parseFactor() ?u8 {
    const c = s[i];
    i += 1;
    return c;
}
