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


const std = @import("std");
pub fn main() !void {

    const arr1 = [4]u8{'a','b','c','d'};
    var arr2 = [_]u8{0}**4;

    arr2 = arr1;

    for (arr2) |value| {

        std.debug.print("{c}\n",.{value});
    }


}
