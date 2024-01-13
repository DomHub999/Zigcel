const std = @import("std");

pub const Function = enum{
    sum,
    average,
    if_function,
    lookup,
    vlookup,
    hlookup,
    match,
    choose,
    date,
};


