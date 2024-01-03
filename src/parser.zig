const std = @import("std");

const unwrapRange = @import("range_unwrap.zig").unwrapRange;

const usizeToString = @import("libfunc.zig").usizeToString;

const TokenType = @import("token.zig").TokenType;
const Token = @import("token.zig").Token;
const TokenPair = @import("token.zig").TokenPair;
const TokenListIterator = @import("token.zig").TokenListIterator;
const makeTokenListIterator = @import("token.zig").makeTokenListIterator;

const lex = @import("lexer.zig").lex;
const extractToken = @import("lexer.zig").extractToken;

const InstructionSequence = @import("instruction_sequence.zig").InstructionSequence;
const Instruction = @import("instruction_sequence.zig").Instruction;
const Instructions = @import("instruction_sequence.zig").Instructions;
const InstructionType = @import("instruction_sequence.zig").InstructionType;

const Error = error{
    parser_expected_operand_is_missing,
    parser_token_type_not_supported,
    parser_no_operand_to_negate_available,
    parser_no_payload_exceeded_max,
    parser_closing_bracket_expected,
    OutOfMemory,
    Overflow,
    rangeunwrapper_range_colon_divisor_na,
    rangeunwrapper_no_row_part_in_range,
    InvalidCharacter,
};

const NUMBER_OF_PAYLOADS: usize = 10;
pub const TokenOperatorFunc = struct {
    token: Token = Token{},
    payload: [NUMBER_OF_PAYLOADS]?InstructionSequence.OperatorFunction = [_]?InstructionSequence.OperatorFunction{null} ** NUMBER_OF_PAYLOADS,
    idx_payload: usize = 0,

    fn pushBackPayload(this: *@This(), func: InstructionSequence.OperatorFunction) !void {
        if (this.idx_payload >= NUMBER_OF_PAYLOADS) {
            return Error.parser_no_payload_exceeded_max;
        }

        this.payload[this.idx_payload] = func;
        this.idx_payload += 1;
    }
};

pub const Parser = struct {
    token_list_iterator: *TokenListIterator = undefined,
    current_token: ?*Token = null,
    instruction_sequence: InstructionSequence = undefined,

    pub fn init(this: *@This(), token_list_iterator: *TokenListIterator) void {
        this.instruction_sequence = InstructionSequence{};
        this.instruction_sequence.init();
        this.token_list_iterator = token_list_iterator;
    }

    pub fn parse(this: *@This()) !InstructionSequence {
        this.consumeToken();
        var arg_count: usize = 0;
        try this.stage06(&arg_count);
        return this.instruction_sequence;
    }

    fn consumeToken(this: *@This()) void {
        this.current_token = this.token_list_iterator.getNext();
    }

    const LayerFunction = *const fn (this: *@This(), arg_count: *usize) Error!?TokenOperatorFunc;
    fn callToUnderlLayer(this: *@This(), operator_function: InstructionSequence.OperatorFunction, lhs: *?TokenOperatorFunc, funToUnderlLayer: LayerFunction, arg_count: *usize) !void {
        this.consumeToken();
        const result_rhs = try funToUnderlLayer(this, arg_count);
        try this.instruction_sequence.triggerStackSequenceBinary(operator_function, lhs, &result_rhs);
    }

    //comparison =, >, <, >=, <=, <>
    fn stage06(this: *@This(), arg_count: *usize) !void {
        var result_lhs = try this.stage05(arg_count);

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.equal_sign) {
                try this.callToUnderlLayer(InstructionSequence.equal, &result_lhs, Parser.stage05, arg_count);
            }
            while (token_operator.token_type == TokenType.greater_than_sign) {
                try this.callToUnderlLayer(InstructionSequence.greaterThan, &result_lhs, Parser.stage05, arg_count);
            }
            while (token_operator.token_type == TokenType.less_than_sign) {
                try this.callToUnderlLayer(InstructionSequence.lessThan, &result_lhs, Parser.stage05, arg_count);
            }
            while (token_operator.token_type == TokenType.greater_equal_to_sign) {
                try this.callToUnderlLayer(InstructionSequence.greaterEqualThan, &result_lhs, Parser.stage05, arg_count);
            }
            while (token_operator.token_type == TokenType.less_equal_to_sign) {
                try this.callToUnderlLayer(InstructionSequence.lessEqualThan, &result_lhs, Parser.stage05, arg_count);
            }
            while (token_operator.token_type == TokenType.not_equal_to_sign) {
                try this.callToUnderlLayer(InstructionSequence.notEqualTo, &result_lhs, Parser.stage05, arg_count);
            }
        }

        //necessary for a single number, negated numer etc.
        if (result_lhs) |lhs| {
            try this.instruction_sequence.triggerStackSequenceUnary(&lhs);
        }
    }

    //concatenation &
    fn stage05(this: *@This(), arg_count: *usize) Error!?TokenOperatorFunc {
        var result_lhs = try this.stage04(arg_count);

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.ampersand) {
                try this.callToUnderlLayer(InstructionSequence.concatenate, &result_lhs, Parser.stage04, arg_count);
                return null;
            }
        }

        return result_lhs;
    }

    //addition and subtraction +,-
    fn stage04(this: *@This(), arg_count: *usize) Error!?TokenOperatorFunc {
        var result_lhs = try this.stage03(arg_count);

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.plus) {
                try this.callToUnderlLayer(InstructionSequence.add, &result_lhs, Parser.stage03, arg_count);
                return null;
            }
            while (token_operator.token_type == TokenType.minus) {
                try this.callToUnderlLayer(InstructionSequence.subtract, &result_lhs, Parser.stage03, arg_count);
                return null;
            }
        }

        return result_lhs;
    }

    //multiplication and division *,/
    fn stage03(this: *@This(), arg_count: *usize) Error!?TokenOperatorFunc {
        var result_lhs = try this.stage02(arg_count);

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.asterisk) {
                try this.callToUnderlLayer(InstructionSequence.multipy, &result_lhs, Parser.stage02, arg_count);
                return null;
            }
            while (token_operator.token_type == TokenType.forward_slash) {
                try this.callToUnderlLayer(InstructionSequence.divide, &result_lhs, Parser.stage02, arg_count);
                return null;
            }
        }

        return result_lhs;
    }

    //exponentiation ^
    fn stage02(this: *@This(), arg_count: *usize) Error!?TokenOperatorFunc {
        var result_lhs = try this.stage00(arg_count);

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.caret) {
                try this.callToUnderlLayer(InstructionSequence.toThePowerOf, &result_lhs, Parser.stage00, arg_count);
                return null;
            }
        }

        return result_lhs;
    }

    //constant, string, negation, opening bracket, formula, reference, range
    fn stage00(this: *@This(), arg_count: *usize) Error!?TokenOperatorFunc {
        if (this.current_token) |token_operand| {
            switch (token_operand.token_type) {

                //CONSTANT
                TokenType.constant => {
                    var token_fnc = TokenOperatorFunc{ .token = token_operand.* };
                    this.consumeToken();
                    try this.dealWithPercentSign(&token_fnc);
                    arg_count.* += 1;
                    return token_fnc;
                },

                //STRING
                TokenType.string => {
                    const token_fnc = TokenOperatorFunc{ .token = token_operand.* };
                    this.consumeToken();
                    return token_fnc;
                },

                //NEGATION
                TokenType.minus => {
                    var token_fnc = TokenOperatorFunc{};
                    try token_fnc.pushBackPayload(InstructionSequence.negate);
                    this.consumeToken();

                    while (this.current_token) |token_unwrapped| {
                        if (token_unwrapped.token_type == TokenType.minus) {
                            try token_fnc.pushBackPayload(InstructionSequence.negate);
                        } else {
                            break;
                        }
                        this.consumeToken();
                    }

                    if (this.current_token) |operand_negate| {
                        token_fnc.token = operand_negate.*;

                        this.consumeToken();
                    } else {
                        return Error.parser_no_operand_to_negate_available;
                    }

                    try this.dealWithPercentSign(&token_fnc);

                    return token_fnc;
                },

                //OPENING BRACKET
                TokenType.bracket_open => {
                    this.consumeToken();
                    try this.stage06(arg_count);
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

                //FORMULA
                TokenType.formula => {

                    //temp, until the lexer delivers the formula
                    const formula = token_operand.token;

                    this.consumeToken(); //formula
                    this.consumeToken(); //opening bracket

                    var this_arg_count: usize = 0;

                    while (this.current_token != null and this.current_token.?.token_type != TokenType.bracket_close) {
                        if (this.current_token.?.token_type == TokenType.argument_deliminiter) {
                            this.consumeToken();
                        } else {
                            try this.stage06(&this_arg_count);
                        }
                    }

                    if (this.current_token != null and this.current_token.?.token_type == TokenType.bracket_close) {
                        this.consumeToken(); //closing bracket
                    } else {
                        return Error.parser_closing_bracket_expected;
                    }

                    var token_fnc = TokenOperatorFunc{};
                    token_fnc.token.token_type = TokenType.constant;
                    token_fnc.token.valid_token = true;
                    usizeToString(this_arg_count, &token_fnc.token.token);

                    //temp, until the lexer delivers the formula
                    if (formula[0] == 'S' and formula[1] == 'U' and formula[2] == 'M') {
                        try token_fnc.pushBackPayload(InstructionSequence.f_sum);
                    }

                    try this.instruction_sequence.triggerStackSequenceUnary(&token_fnc);

                    arg_count.* += 1;
                    return null;
                },

                //REFERENCE
                TokenType.reference => {
                    var token_fnc = TokenOperatorFunc{ .token = token_operand.* };
                    try token_fnc.pushBackPayload(InstructionSequence.resolveReference);
                    this.consumeToken();
                    arg_count.* += 1;
                    return token_fnc;
                },

                //RANGE
                TokenType.range => {
                    const reference_list = try unwrapRange(&token_operand.token);

                    for (reference_list.items) |reference| {
                        var token_fnc = TokenOperatorFunc{};
                        token_fnc.token.token_type = TokenType.reference;
                        token_fnc.token.valid_token = true;
                        @memcpy(token_fnc.token.token[0..10], reference[0..]);
                        try token_fnc.pushBackPayload(InstructionSequence.resolveReference);
                        try this.instruction_sequence.triggerStackSequenceUnary(&token_fnc);
                        arg_count.* += 1;
                    }

                    this.consumeToken();
                    return null;
                },

                else => {
                    return Error.parser_token_type_not_supported;
                },
            }
        } else {
            return Error.parser_expected_operand_is_missing;
        }
    }

    fn dealWithPercentSign(this: *@This(), token_fnc: *TokenOperatorFunc) !void {
        while (this.current_token) |token_unwrapped| {
            if (token_unwrapped.token_type == TokenType.percent_sign) {
                try token_fnc.pushBackPayload(InstructionSequence.percentOf);
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
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.divide },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.multiply },
        Instruction{ .single_instruction = Instructions.add },
    };

    @memcpy(solution[0].stack_operation.token.token[0..3], "100");
    @memcpy(solution[1].stack_operation.token.token[0..2], "50");
    @memcpy(solution[3].stack_operation.token.token[0..2], "10");
    @memcpy(solution[4].stack_operation.token.token[0..2], "20");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "strings" {
    const instruction_sequence = try testingGetInstructionSequence("\"abc\"&\"def\"");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.string } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.string } } },
        Instruction{ .single_instruction = Instructions.concat_strings },
    };

    @memcpy(solution[0].stack_operation.token.token[0..3], "abc");
    @memcpy(solution[1].stack_operation.token.token[0..3], "def");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "negate/percent/power 1" {
    const instruction_sequence = try testingGetInstructionSequence("-10^300%");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.percent_of },
        Instruction{ .single_instruction = Instructions.to_the_power_of },
    };

    @memcpy(solution[0].stack_operation.token.token[0..2], "10");
    @memcpy(solution[2].stack_operation.token.token[0..3], "300");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "negate/percent/power 2" {
    const instruction_sequence = try testingGetInstructionSequence("10^-300%");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.percent_of },
        Instruction{ .single_instruction = Instructions.to_the_power_of },
    };

    @memcpy(solution[0].stack_operation.token.token[0..2], "10");
    @memcpy(solution[1].stack_operation.token.token[0..3], "300");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "brackets" {
    const instruction_sequence = try testingGetInstructionSequence("50*(7-3)");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.subtract },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.multiply },
    };

    @memcpy(solution[0].stack_operation.token.token[0..1], "7");
    @memcpy(solution[1].stack_operation.token.token[0..1], "3");
    @memcpy(solution[3].stack_operation.token.token[0..2], "50");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "reference" {
    const instruction_sequence = try testingGetInstructionSequence("100+F7*20");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.reference } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.multiply },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.add },
    };

    @memcpy(solution[0].stack_operation.token.token[0..2], "F7");
    @memcpy(solution[2].stack_operation.token.token[0..2], "20");
    @memcpy(solution[4].stack_operation.token.token[0..3], "100");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "unroll range" {
    const instruction_sequence = try testingGetInstructionSequence("A100:B102");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.reference } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.reference } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.reference } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.reference } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.reference } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.reference } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
    };

    @memcpy(solution[0].stack_operation.token.token[0..4], "A100");
    @memcpy(solution[2].stack_operation.token.token[0..4], "A101");
    @memcpy(solution[4].stack_operation.token.token[0..4], "A102");
    @memcpy(solution[6].stack_operation.token.token[0..4], "B100");
    @memcpy(solution[8].stack_operation.token.token[0..4], "B101");
    @memcpy(solution[10].stack_operation.token.token[0..4], "B102");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "formula 1" {
    const instruction_sequence = try testingGetInstructionSequence("SUM(A1:B2,R5)");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.reference } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.reference } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.reference } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.reference } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },

        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.reference } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },

        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.f_sum },
    };

    @memcpy(solution[0].stack_operation.token.token[0..2], "A1");
    @memcpy(solution[2].stack_operation.token.token[0..2], "A2");
    @memcpy(solution[4].stack_operation.token.token[0..2], "B1");
    @memcpy(solution[6].stack_operation.token.token[0..2], "B2");
    @memcpy(solution[8].stack_operation.token.token[0..2], "R5");
    @memcpy(solution[10].stack_operation.token.token[0..1], "5");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "formula 2" {
    const instruction_sequence = try testingGetInstructionSequence("SUM(A1,Z51,2024,SUM(B1,B2))");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.reference } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.reference } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },

        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },

        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.reference } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.reference } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },

        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.f_sum },

        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.f_sum },
    };

    @memcpy(solution[0].stack_operation.token.token[0..2], "A1");
    @memcpy(solution[2].stack_operation.token.token[0..3], "Z51");
    @memcpy(solution[4].stack_operation.token.token[0..4], "2024");
    @memcpy(solution[5].stack_operation.token.token[0..2], "B1");
    @memcpy(solution[7].stack_operation.token.token[0..2], "B2");
    @memcpy(solution[9].stack_operation.token.token[0..1], "2");
    @memcpy(solution[11].stack_operation.token.token[0..1], "4");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "negation sequence" {
    const instruction_sequence = try testingGetInstructionSequence("1+-----5");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.add },
    };

    @memcpy(solution[0].stack_operation.token.token[0..1], "1");
    @memcpy(solution[1].stack_operation.token.token[0..1], "5");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "addition and negation" {
    const instruction_sequence = try testingGetInstructionSequence("5+-9%");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.percent_of },
        Instruction{ .single_instruction = Instructions.add },
    };

    @memcpy(solution[0].stack_operation.token.token[0..1], "5");
    @memcpy(solution[1].stack_operation.token.token[0..1], "9");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "division 1" {
    const instruction_sequence = try testingGetInstructionSequence("10/5");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.divide },
    };

    @memcpy(solution[0].stack_operation.token.token[0..2], "10");
    @memcpy(solution[1].stack_operation.token.token[0..1], "5");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "division 2" {
    const instruction_sequence = try testingGetInstructionSequence("10/-5");
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.divide },
    };

    @memcpy(solution[0].stack_operation.token.token[0..2], "10");
    @memcpy(solution[1].stack_operation.token.token[0..1], "5");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);

}

test "division 3" {
    const instruction_sequence = try testingGetInstructionSequence("91%/-8");
    defer instruction_sequence.instruction_list.deinit();
   
       var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.percent_of },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.constant } } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.divide },
    };

    @memcpy(solution[0].stack_operation.token.token[0..2], "91");
    @memcpy(solution[2].stack_operation.token.token[0..1], "8");

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
                try std.testing.expect(std.mem.eql(u8, sol.stack_operation.token.token[0..], itm.stack_operation.token.token[0..]));
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
                std.debug.print("{s} {s}\n", .{ @tagName(value.stack_operation.instruction), extractToken(&value.stack_operation.token.token) });
            },
        }
    }
}
