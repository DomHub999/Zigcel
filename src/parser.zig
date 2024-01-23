const std = @import("std");

const unwrapRange = @import("range_unwrap.zig").unwrapRange;

const usizeToString = @import("libfunc.zig").usizeToString;

const TokenType = @import("lexer_token.zig").TokenType;
const LexerToken = @import("lexer_token.zig").LexerToken;
const TokenPair = @import("lexer_token.zig").TokenPair;
const TokenListIterator = @import("lexer_token.zig").TokenListIterator;
const token_list_type = @import("lexer_token.zig").token_list_type;
const makeTokenListIterator = @import("lexer_token.zig").TokenListIterator.makeTokenListIterator;
const createParserTokenFromLexTok = @import("parser_token.zig").ParserToken.createParserTokenFromLexTok;
const extractToken = @import("lexer_token.zig").extractToken;

const lex = @import("lexer.zig").lex;


const InstructionSequence = @import("instruction_sequence.zig").InstructionSequence;
const Instruction = @import("instruction_sequence.zig").Instruction;
const Instructions = @import("instruction_sequence.zig").Instructions;
const InstructionType = @import("instruction_sequence.zig").InstructionType;

const ParserToken = @import("parser_token.zig").ParserToken;

const Error = error{
    parser_expected_operand_is_missing,
    parser_token_type_not_supported,
    parser_no_operand_to_negate_available,
    parser_closing_bracket_expected,
    OutOfMemory,
    Overflow,
    rangeunwrapper_range_colon_divisor_na,
    rangeunwrapper_no_row_part_in_range,
    InvalidCharacter,

    parser_token_no_payload_exceeded_max,
};

pub const Parser = struct {
    token_list_iterator: *TokenListIterator = undefined,
    current_token: ?*LexerToken = null,
    instruction_sequence: InstructionSequence = undefined,

    pub fn init(this: *@This(), token_list_iterator: *TokenListIterator) void {
        this.instruction_sequence = InstructionSequence{};
        this.instruction_sequence.init();
        this.token_list_iterator = token_list_iterator;
    }

    pub fn parse(this: *@This()) !InstructionSequence {
        this.consumeToken();
        var arg_count: usize = 0;
        try this.Layer05(&arg_count);
        return this.instruction_sequence;
    }

    fn consumeToken(this: *@This()) void {
        this.current_token = this.token_list_iterator.getNext();
    }

    const LayerFunction = *const fn (this: *@This(), arg_count: *usize) Error!?ParserToken;
    fn callToUnderlLayer(this: *@This(), instruction: Instructions, lhs: *?ParserToken, funToUnderlLayer: LayerFunction, arg_count: *usize) !void {
        this.consumeToken();
        const result_rhs = try funToUnderlLayer(this, arg_count);
        try this.instruction_sequence.triggerStackSequenceBinary(instruction, lhs, &result_rhs);
    }

    //comparison =, >, <, >=, <=, <>
    fn Layer05(this: *@This(), arg_count: *usize) !void {
        var result_lhs = try this.Layer04(arg_count);

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.equal_sign) {
                try this.callToUnderlLayer(Instructions.equal, &result_lhs, Parser.Layer04, arg_count);
            }
            while (token_operator.token_type == TokenType.greater_than_sign) {
                try this.callToUnderlLayer(Instructions.greaterThan, &result_lhs, Parser.Layer04, arg_count);
            }
            while (token_operator.token_type == TokenType.less_than_sign) {
                try this.callToUnderlLayer(Instructions.lessThan, &result_lhs, Parser.Layer04, arg_count);
            }
            while (token_operator.token_type == TokenType.greater_equal_to_sign) {
                try this.callToUnderlLayer(Instructions.greaterEqualThan, &result_lhs, Parser.Layer04, arg_count);
            }
            while (token_operator.token_type == TokenType.less_equal_to_sign) {
                try this.callToUnderlLayer(Instructions.lessEqualThan, &result_lhs, Parser.Layer04, arg_count);
            }
            while (token_operator.token_type == TokenType.not_equal_to_sign) {
                try this.callToUnderlLayer(Instructions.notEqualTo, &result_lhs, Parser.Layer04, arg_count);
            }
        }

        //necessary for a single number, negated numer etc.
        if (result_lhs) |lhs| {
            try this.instruction_sequence.triggerStackSequenceUnary(&lhs);
        }
    }

    //concatenation &
    fn Layer04(this: *@This(), arg_count: *usize) Error!?ParserToken {
        var result_lhs = try this.Layer03(arg_count);

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.ampersand) {
                try this.callToUnderlLayer(Instructions.concat_strings, &result_lhs, Parser.Layer03, arg_count);
                return null;
            }
        }

        return result_lhs;
    }

    //addition and subtraction +,-
    fn Layer03(this: *@This(), arg_count: *usize) Error!?ParserToken {
        var result_lhs = try this.Layer02(arg_count);

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.plus) {
                try this.callToUnderlLayer(Instructions.add, &result_lhs, Parser.Layer02, arg_count);
                return null;
            }
            while (token_operator.token_type == TokenType.minus) {
                try this.callToUnderlLayer(Instructions.subtract, &result_lhs, Parser.Layer02, arg_count);
                return null;
            }
        }

        return result_lhs;
    }

    //multiplication and division *,/
    fn Layer02(this: *@This(), arg_count: *usize) Error!?ParserToken {
        var result_lhs = try this.Layer01(arg_count);

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.asterisk) {
                try this.callToUnderlLayer(Instructions.multiply, &result_lhs, Parser.Layer01, arg_count);
                return null;
            }
            while (token_operator.token_type == TokenType.forward_slash) {
                try this.callToUnderlLayer(Instructions.divide, &result_lhs, Parser.Layer01, arg_count);
                return null;
            }
        }

        return result_lhs;
    }

    //exponentiation ^
    fn Layer01(this: *@This(), arg_count: *usize) Error!?ParserToken {
        var result_lhs = try this.Layer00(arg_count);

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.caret) {
                try this.callToUnderlLayer(Instructions.to_the_power_of, &result_lhs, Parser.Layer00, arg_count);
                return null;
            }
        }

        return result_lhs;
    }

    //constant, string, negation, opening bracket, function, reference, range
    fn Layer00(this: *@This(), arg_count: *usize) Error!?ParserToken {
        if (this.current_token) |token_operand| {
            switch (token_operand.token_type) {

                //CONSTANT
                TokenType.constant => {
                    // var parser_token = ParserToken{ .token = token_operand.* }; delete
                    var parser_token = createParserTokenFromLexTok(token_operand);
                    this.consumeToken();
                    try this.dealWithPercentSign(&parser_token);
                    arg_count.* += 1;
                    return parser_token;
                },

                //STRING
                TokenType.string => {
                    // const parser_token = ParserToken{ .token = token_operand.* }; delete
                    const parser_token = createParserTokenFromLexTok(token_operand);
                    this.consumeToken();
                    return parser_token;
                },

                //NEGATION
                TokenType.minus => {
                    var parser_token = ParserToken{};
                    try parser_token.pushBackPayload(Instructions.negate);
                    this.consumeToken();

                    while (this.current_token) |token_unwrapped| {
                        if (token_unwrapped.token_type == TokenType.minus) {
                            try parser_token.pushBackPayload(Instructions.negate);
                        } else {
                            break;
                        }
                        this.consumeToken();
                    }

                    if (this.current_token) |operand_negate| {
                        parser_token.copyAttributesFromLexTok(operand_negate);    
                        this.consumeToken();
                    } else {
                        return Error.parser_no_operand_to_negate_available;
                    }

                    try this.dealWithPercentSign(&parser_token);

                    return parser_token;
                },

                //OPENING BRACKET
                TokenType.bracket_open => {
                    this.consumeToken();
                    try this.Layer05(arg_count);
                    if (this.current_token) |token| {
                        if (token.token_type == TokenType.bracket_close) {
                            this.consumeToken();
                        } else {
                            return Error.parser_closing_bracket_expected;
                        }
                    } else {
                        return Error.parser_closing_bracket_expected;
                    }

                    return null;
                },

                //FUNCTION
                TokenType.function => {

                    //temp, until the lexer delivers the function
                    const function = token_operand.token;

                    this.consumeToken(); //function
                    this.consumeToken(); //opening bracket

                    var this_arg_count: usize = 0;

                    while (this.current_token != null and this.current_token.?.token_type != TokenType.bracket_close) {
                        if (this.current_token.?.token_type == TokenType.argument_deliminiter) {
                            this.consumeToken();
                        } else {
                            try this.Layer05(&this_arg_count);
                        }
                    }

                    if (this.current_token != null and this.current_token.?.token_type == TokenType.bracket_close) {
                        this.consumeToken(); //closing bracket
                    } else {
                        return Error.parser_closing_bracket_expected;
                    }

                    var parser_token = ParserToken{};
                    parser_token.token_type = TokenType.constant;
                    
                    usizeToString(this_arg_count, &parser_token.token);

                    //temp, until the lexer delivers the function
                    if (function[0] == 'S' and function[1] == 'U' and function[2] == 'M') {
                        try parser_token.pushBackPayload(Instructions.f_sum);
                    }

                    try this.instruction_sequence.triggerStackSequenceUnary(&parser_token);

                    arg_count.* += 1;
                    return null;
                },

                //REFERENCE
                TokenType.reference => {
                    var parser_token = createParserTokenFromLexTok(token_operand);
                    try parser_token.pushBackPayload(Instructions.resolve_reference);
                    this.consumeToken();
                    arg_count.* += 1;
                    return parser_token;
                },

                else => {
                    return Error.parser_token_type_not_supported;
                },
            }
        } else {
            return Error.parser_expected_operand_is_missing;
        }
    }

    fn dealWithPercentSign(this: *@This(), token_fnc: *ParserToken) !void {
        while (this.current_token) |token_unwrapped| {
            if (token_unwrapped.token_type == TokenType.percent_sign) {
                try token_fnc.pushBackPayload(Instructions.percent_of);
                this.consumeToken();
            } else {
                break;
            }
        }
    }
};

test "division/multiplication and addition precendence" {
    const instruction_sequence = try testingGetInstructionSequence("100/50+10*20");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant  } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant  } },
        Instruction{ .single_instruction = Instructions.divide },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant  } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant  } },
        Instruction{ .single_instruction = Instructions.multiply },
        Instruction{ .single_instruction = Instructions.add },
    };

    @memcpy(solution[0].stack_operation.token[0..3], "100");
    @memcpy(solution[1].stack_operation.token[0..2], "50");
    @memcpy(solution[3].stack_operation.token[0..2], "10");
    @memcpy(solution[4].stack_operation.token[0..2], "20");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "strings" {
    const instruction_sequence = try testingGetInstructionSequence("\"abc\"&\"def\"");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.string  } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.string  } },
        Instruction{ .single_instruction = Instructions.concat_strings },
    };

    @memcpy(solution[0].stack_operation.token[0..3], "abc");
    @memcpy(solution[1].stack_operation.token[0..3], "def");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "negate/percent/power 1" {
    const instruction_sequence = try testingGetInstructionSequence("-10^300%");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant  } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant  } },
        Instruction{ .single_instruction = Instructions.percent_of },
        Instruction{ .single_instruction = Instructions.to_the_power_of },
    };

    @memcpy(solution[0].stack_operation.token[0..2], "10");
    @memcpy(solution[2].stack_operation.token[0..3], "300");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "negate/percent/power 2" {
    const instruction_sequence = try testingGetInstructionSequence("10^-300%");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant  } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant  } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.percent_of },
        Instruction{ .single_instruction = Instructions.to_the_power_of },
    };

    @memcpy(solution[0].stack_operation.token[0..2], "10");
    @memcpy(solution[1].stack_operation.token[0..3], "300");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "brackets" {
    const instruction_sequence = try testingGetInstructionSequence("50*(7-3)");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant  } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant  } },
        Instruction{ .single_instruction = Instructions.subtract },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant  } },
        Instruction{ .single_instruction = Instructions.multiply },
    };

    @memcpy(solution[0].stack_operation.token[0..1], "7");
    @memcpy(solution[1].stack_operation.token[0..1], "3");
    @memcpy(solution[3].stack_operation.token[0..2], "50");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "references" {

    const instruction_sequence = try testingGetInstructionSequence("100+F7*20");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference  } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant  } },
        Instruction{ .single_instruction = Instructions.multiply },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant  } },
        Instruction{ .single_instruction = Instructions.add },
    };

    @memcpy(solution[0].stack_operation.token[0..2], "F7");
    @memcpy(solution[2].stack_operation.token[0..2], "20");
    @memcpy(solution[4].stack_operation.token[0..3], "100");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "function 1" {
    const instruction_sequence = try testingGetInstructionSequence("SUM(A1:B2,R5)");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference } },
        Instruction{ .single_instruction = Instructions.resolve_reference },

        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference } },
        Instruction{ .single_instruction = Instructions.resolve_reference },

        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant } },
        Instruction{ .single_instruction = Instructions.f_sum },
    };

    @memcpy(solution[0].stack_operation.token[0..2], "A1");
    @memcpy(solution[2].stack_operation.token[0..2], "A2");
    @memcpy(solution[4].stack_operation.token[0..2], "B1");
    @memcpy(solution[6].stack_operation.token[0..2], "B2");
    @memcpy(solution[8].stack_operation.token[0..2], "R5");
    @memcpy(solution[10].stack_operation.token[0..1], "5");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "function 2" {
    const instruction_sequence = try testingGetInstructionSequence("SUM(A1,Z51,2024,SUM(B1,B2))");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference } },
        Instruction{ .single_instruction = Instructions.resolve_reference },

        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant } },

        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference } },
        Instruction{ .single_instruction = Instructions.resolve_reference },

        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant } },
        Instruction{ .single_instruction = Instructions.f_sum },

        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant } },
        Instruction{ .single_instruction = Instructions.f_sum },
    };

    @memcpy(solution[0].stack_operation.token[0..2], "A1");
    @memcpy(solution[2].stack_operation.token[0..3], "Z51");
    @memcpy(solution[4].stack_operation.token[0..4], "2024");
    @memcpy(solution[5].stack_operation.token[0..2], "B1");
    @memcpy(solution[7].stack_operation.token[0..2], "B2");
    @memcpy(solution[9].stack_operation.token[0..1], "2");
    @memcpy(solution[11].stack_operation.token[0..1], "4");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "negation sequence" {
    const instruction_sequence = try testingGetInstructionSequence("1+-----5");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.add },
    };

    @memcpy(solution[0].stack_operation.token[0..1], "1");
    @memcpy(solution[1].stack_operation.token[0..1], "5");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "addition and negation" {
    const instruction_sequence = try testingGetInstructionSequence("5+-9%");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.percent_of },
        Instruction{ .single_instruction = Instructions.add },
    };

    @memcpy(solution[0].stack_operation.token[0..1], "5");
    @memcpy(solution[1].stack_operation.token[0..1], "9");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "division 1" {
    const instruction_sequence = try testingGetInstructionSequence("10/5");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant } },
        Instruction{ .single_instruction = Instructions.divide },
    };

    @memcpy(solution[0].stack_operation.token[0..2], "10");
    @memcpy(solution[1].stack_operation.token[0..1], "5");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "division 2" {
    const instruction_sequence = try testingGetInstructionSequence("10/-5");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.divide },
    };

    @memcpy(solution[0].stack_operation.token[0..2], "10");
    @memcpy(solution[1].stack_operation.token[0..1], "5");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "division 3" {
    const instruction_sequence = try testingGetInstructionSequence("91%/-8");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant } },
        Instruction{ .single_instruction = Instructions.percent_of },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.divide },
    };

    @memcpy(solution[0].stack_operation.token[0..2], "91");
    @memcpy(solution[2].stack_operation.token[0..1], "8");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

fn testingGetInstructionSequence(source: [*:0]const u8) !InstructionSequence {
    const token_list = try lex(source);
    var token_list_iterator = makeTokenListIterator(token_list);
    defer token_list_iterator.drop();

    var parser = Parser{};
    parser.init(&token_list_iterator);
    return try parser.parse();
}

fn compareSolutionToinstrSeq(solution: []Instruction, instruction_sequence: *const InstructionSequence) !void {
    for (solution, instruction_sequence.*.instruction_list.items) |sol, itm| {
        switch (sol) {
            InstructionType.single_instruction => {
                try std.testing.expect(sol.single_instruction == itm.single_instruction);
            },
            InstructionType.stack_operation => {
                try std.testing.expect(sol.stack_operation.instruction == itm.stack_operation.instruction);
                try std.testing.expect(std.mem.eql(u8, sol.stack_operation.token[0..], itm.stack_operation.token[0..]));
            },
        }
    }
}

fn printInstructionSequence(instruction_sequence: *const InstructionSequence) void {
    std.debug.print("{c}\n", .{' '});

    for (instruction_sequence.instruction_list.items) |value| {
        switch (value) {
            InstructionType.single_instruction => {
                std.debug.print("{s}\n", .{@tagName(value.single_instruction)});
            },
            InstructionType.stack_operation => {
                std.debug.print("{s} {s}\n", .{ @tagName(value.stack_operation.instruction), extractToken(&value.stack_operation.token) });
            },
        }
    }
}
