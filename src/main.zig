const std = @import("std");
const lex = @import("lexer.zig");
const par = @import("parser.zig");

pub fn main() !void {
    var lexer = lex.Lexer{};
    lexer.init();

    const source = "100/50+10*20";
    try lexer.lex(source);

    var parser = par.Parser{};
    parser.init(&lexer);
    const instruction_sequence = try parser.parse();

    for (instruction_sequence.instruction_list.items) |value| {
        switch (value) {
            par.Instruction.single_instruction => {
                std.debug.print("{s}\n", .{@tagName(value.single_instruction)});
            },

            par.Instruction.stack_operation => {
                std.debug.print("{s} {s}\n", .{@tagName(value.stack_operation.instruction), lex.Lexer.extractToken(&value.stack_operation.token.token) });
            },
        }
    }
}
