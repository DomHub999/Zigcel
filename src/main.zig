//todo: extract token extraction
//parser: erxtract the instruction sequence
//token: tagged union for actual values: constant (float64), formula enum (separate formula file), pointer for strings, reference number
//token: extraction functions for actual values
//instruction sequence: get rid of function pointers for instructinon genaration
//lexer: get rid of the member variables, return an arraylist
//parser: proper function numbering (layers)
//token: provide iterator wrapper for the token list
//parser: make lexer token and parser token -> when transitioning to parser token, get rid of unecessary fields (maybe provide a function for transition)
//parser: make "parser token" payload heap memory
//token: make character in in tokens heap memory -> infinite chara length
//token: write transition functions (string to float, string to formula, string to reference, string to string pointer)
//parser: get rid of members, pass the token list around

const std = @import("std");
const lex = @import("lexer.zig");
const par = @import("parser.zig");

pub fn main() !void {}
