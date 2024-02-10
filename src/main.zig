//todo: extract token extraction --> done
//lexer: get rid of the member variables, return an arraylist --> done
//parser: erxtract the instruction sequence --> done
//resolve all library accesses with an alias --> done
//instruction sequence: get rid of function pointers for instructinon genaration --> done
//parser: make lexer token and parser token -> when transitioning to parser token, get rid of unecessary fields (maybe provide a function for transition) --> done
//token: provide iterator wrapper for the token list --> done
//parser: proper function numbering (layers) --> done
//token: tagged union for actual values: constant (float64), formula enum (separate formula file), pointer for strings, reference number --> done
//token: write transition functions (string to float, string to formula, string to reference, string to string pointer) --> done

// unit test for floating point number --> done
// unit test for boolean literals

const std = @import("std");
const print = @import("std").debug.print;
const ROW_CHARACTERS = @import("range_unwrap.zig").ROW_CHARACTERS;


pub fn main() !void {

    const b:f64 = 1.24;
    std.debug.print("{d}", .{b});
}

