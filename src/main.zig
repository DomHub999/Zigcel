//todo: extract token extraction --> done
//lexer: get rid of the member variables, return an arraylist --> done
//parser: erxtract the instruction sequence --> done
//resolve all library accesses with an alias --> done
//instruction sequence: get rid of function pointers for instructinon genaration --> done
//parser: make lexer token and parser token -> when transitioning to parser token, get rid of unecessary fields (maybe provide a function for transition) --> done
//token: provide iterator wrapper for the token list --> done
//parser: proper function numbering (layers) --> done

//token: tagged union for actual values: constant (float64), formula enum (separate formula file), pointer for strings, reference number
//token: write transition functions (string to float, string to formula, string to reference, string to string pointer)
//token: extraction functions for actual values
//parser: make "parser token" payload heap memory
//rename function to formula
// unit test for floating point number
// unit test for boolean literals

const std = @import("std");
const print = @import("std").debug.print;
const ROW_CHARACTERS = @import("range_unwrap.zig").ROW_CHARACTERS;
pub fn main() !void {


//   const f = try std.fmt.parseFloat(f64, "100"[0..]);
//   const f2:f64 = 0.0;
//   const result = f - f2;



  
//  const row_idx = std.mem.indexOfAny(u8, "A100"[0..], ROW_CHARACTERS) orelse 0;
//  print("{}", .{row_idx});

// const enum_fields = @typeInfo(e).Enum.fields;
// for (enum_fields) |value| {
//     print("{s}", .{value});
// }

var tab = [_]u8{0}**100;
modifyTab(&tab);
print("{}", .{tab[0]});

}

// const e = enum{
//     a,
//     b,
//     c,
// };

fn modifyTab(tab:[]u8)void{
    tab[0] = 111;
}


