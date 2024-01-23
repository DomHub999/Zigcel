const std = @import("std");


const Errors = error{
    functions_function_not_configures,
};

pub const Function = enum {
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


const MAP_SIZE: usize = @typeInfo(Function).Enum.fields.len * 2;

const FunctTab = struct{
    function_table:[MAP_SIZE]?Function,
    magic_number:usize, 
};

const FUNCTION_TABLE = createFunctionTable();
fn getMagicNumber()usize{
    return FUNCTION_TABLE.magic_number;
}


pub fn getFunction(function:[]const u8)!Function{
    const index = calcHash(function, FUNCTION_TABLE.magic_number);
    return FUNCTION_TABLE.function_table[index] orelse return Errors.functions_function_not_configures;
}


fn createFunctionTable() FunctTab {
    var funct_tab = FunctTab{.function_table = [_]?Function{null} ** MAP_SIZE, .magic_number = 0 };

    while (loadFunctions(&funct_tab.function_table, funct_tab.magic_number)) {
        @memset(&funct_tab.function_table, null);
        funct_tab.magic_number += 1;
    }

    return funct_tab;
}

fn loadFunctions(function_table:[]?Function, m_number:usize)bool{

    if (insertFunction(function_table, "SUM"[0..], Function.sum, m_number)) {return true;}
    if (insertFunction(function_table, "AVERAGE"[0..], Function.average, m_number)) {return true;}
    if (insertFunction(function_table, "IF"[0..], Function.if_function, m_number)) {return true;}
    if (insertFunction(function_table, "LOOKUP"[0..], Function.lookup, m_number)) {return true;}
    if (insertFunction(function_table, "VLOOKUP"[0..], Function.vlookup, m_number)) {return true;}
    if (insertFunction(function_table, "HLOOKUP"[0..], Function.hlookup, m_number)) {return true;}
    if (insertFunction(function_table, "MATCH"[0..], Function.match, m_number)) {return true;}
    if (insertFunction(function_table, "CHOOSE"[0..], Function.choose, m_number)) {return true;}
    if (insertFunction(function_table, "DATE"[0..], Function.date, m_number)) {return true;}

    return false;
}

fn insertFunction(function_table:[]?Function, function_string:[]const u8, function:Function, m_number:usize)bool{
    
    const index = calcHash(function_string, m_number);

    if (function_table[index] == null) {
        function_table[index] = function;
        return false;
    } 
    return true;

}

fn calcHash(string: []const u8, m_number:usize) usize {
    var hash: usize = 0;
    for (string, 0..) |value, idx| {
        hash += @intCast(value);
        const scramble_mul = @mulWithOverflow(hash, m_number);
        hash = scramble_mul[0];
        const shift: u6 = @intCast(idx);
        hash = hash >> shift;
    }
    hash = @rem(hash, MAP_SIZE);
    return hash;
}


test "hash" {
    const magic = getMagicNumber();
    _ = magic;

    try std.testing.expect(try getFunction("SUM"[0..])==Function.sum);
    try std.testing.expect(try getFunction("IF"[0..])==Function.if_function);
    try std.testing.expect(try getFunction("VLOOKUP"[0..])==Function.vlookup);
    try std.testing.expect(try getFunction("CHOOSE"[0..])==Function.choose);
    try std.testing.expect(try getFunction("DATE"[0..])==Function.date);

}
