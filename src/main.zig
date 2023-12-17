const std = @import("std");
const lex = @import("lexer.zig");
const par = @import("parser.zig");

pub fn main() !void {
    // var lexer = lex.Lexer{};
    // lexer.init();

    //const source = "-10^300%";
    // const source = "10^-300%";
    // const source = "10/-5";
    //const source = "10/5";
    // const source = "100/50+10*20";
    //const source = "1+-----5";
    //const source = "5+-9%";
    //const source = "=91%/-8";
    // const source = "A1:A2";

    // try lexer.lex(source);

    // var parser = par.Parser{};
    // parser.init(&lexer);
    // defer lexer.drop();

    // const instruction_sequence = try parser.parse();
    // defer instruction_sequence.drop();

    // for (instruction_sequence.instruction_list.items) |value| {
    //     switch (value) {
    //         par.InstructionType.single_instruction => {
    //              std.debug.print("{s}\n", .{@tagName(value.single_instruction)});
    //         },
    //         par.InstructionType.stack_operation => {
    //             std.debug.print("{s} {s}\n", .{@tagName(value.stack_operation.instruction), lex.Lexer.extractToken(&value.stack_operation.token.token)});
    //         },
    //     }
    // }

    var unwrapper = RangeUnwrapper{};

    var result = unwrapper.unwrapRange("abc"[0..]);
    _ = result;
}

const RangeUnwrapper = struct {
    pub fn unwrapRange(this: *@This(), range: []const u8) std.ArrayList([10]u8) {
        _ = this;
        _ = range;

        var reference_list = std.ArrayList([10]u8).init(std.heap.page_allocator);

        return reference_list;
    }
};
