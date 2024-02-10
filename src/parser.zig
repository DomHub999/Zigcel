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
const DataType = @import("lexer_token.zig").DataType;
const DataTypes = @import("lexer_token.zig").DataTypes;

const lex = @import("lexer.zig").lex;

const InstructionSequence = @import("instruction_sequence.zig").InstructionSequence;
const Instruction = @import("instruction_sequence.zig").Instruction;
const Instructions = @import("instruction_sequence.zig").Instructions;
const InstructionType = @import("instruction_sequence.zig").InstructionType;
const execInstruction = @import("instruction_sequence.zig").execInstruction;

const ParserToken = @import("parser_token.zig").ParserToken;

const Function = @import("functions.zig").Function;

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
    instr_seq_data_type_for_stack_op_null,
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
        try this.outerLayer(&arg_count);
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
    fn outerLayer(this: *@This(), arg_count: *usize) !void {
        var result_lhs = try this.layer04(arg_count);

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.equal_sign) {
                try this.callToUnderlLayer(Instructions.equal, &result_lhs, Parser.layer04, arg_count);
            }
            while (token_operator.token_type == TokenType.greater_than_sign) {
                try this.callToUnderlLayer(Instructions.greaterThan, &result_lhs, Parser.layer04, arg_count);
            }
            while (token_operator.token_type == TokenType.less_than_sign) {
                try this.callToUnderlLayer(Instructions.lessThan, &result_lhs, Parser.layer04, arg_count);
            }
            while (token_operator.token_type == TokenType.greater_equal_to_sign) {
                try this.callToUnderlLayer(Instructions.greaterEqualThan, &result_lhs, Parser.layer04, arg_count);
            }
            while (token_operator.token_type == TokenType.less_equal_to_sign) {
                try this.callToUnderlLayer(Instructions.lessEqualThan, &result_lhs, Parser.layer04, arg_count);
            }
            while (token_operator.token_type == TokenType.not_equal_to_sign) {
                try this.callToUnderlLayer(Instructions.notEqualTo, &result_lhs, Parser.layer04, arg_count);
            }
        }

        //necessary for a single number, negated numer etc.
        if (result_lhs) |lhs| {
            try this.instruction_sequence.triggerStackSequenceUnary(&lhs);
        }
    }

    //concatenation &
    fn layer04(this: *@This(), arg_count: *usize) Error!?ParserToken {
        var result_lhs = try this.layer03(arg_count);

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.ampersand) {
                try this.callToUnderlLayer(Instructions.concat_strings, &result_lhs, Parser.layer03, arg_count);
                return null;
            }
        }

        return result_lhs;
    }

    //addition and subtraction +,-
    fn layer03(this: *@This(), arg_count: *usize) Error!?ParserToken {
        var result_lhs = try this.layer02(arg_count);

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.plus) {
                try this.callToUnderlLayer(Instructions.add, &result_lhs, Parser.layer02, arg_count);
                return null;
            }
            while (token_operator.token_type == TokenType.minus) {
                try this.callToUnderlLayer(Instructions.subtract, &result_lhs, Parser.layer02, arg_count);
                return null;
            }
        }

        return result_lhs;
    }

    //multiplication and division *,/
    fn layer02(this: *@This(), arg_count: *usize) Error!?ParserToken {
        var result_lhs = try this.layer01(arg_count);

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.asterisk) {
                try this.callToUnderlLayer(Instructions.multiply, &result_lhs, Parser.layer01, arg_count);
                return null;
            }
            while (token_operator.token_type == TokenType.forward_slash) {
                try this.callToUnderlLayer(Instructions.divide, &result_lhs, Parser.layer01, arg_count);
                return null;
            }
        }

        return result_lhs;
    }

    //exponentiation ^
    fn layer01(this: *@This(), arg_count: *usize) Error!?ParserToken {
        var result_lhs = try this.layer00(arg_count);

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.caret) {
                try this.callToUnderlLayer(Instructions.to_the_power_of, &result_lhs, Parser.layer00, arg_count);
                return null;
            }
        }

        return result_lhs;
    }

    //constant, string, negation, opening bracket, function, reference, range
    fn layer00(this: *@This(), arg_count: *usize) Error!?ParserToken {
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
                    try this.outerLayer(arg_count);
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
                    const function = token_operand.*;

                    this.consumeToken(); //function
                    this.consumeToken(); //opening bracket

                    var this_arg_count: usize = 0;

                    while (this.current_token != null and this.current_token.?.token_type != TokenType.bracket_close) {
                        if (this.current_token.?.token_type == TokenType.argument_deliminiter) {
                            this.consumeToken();
                        } else {
                            try this.outerLayer(&this_arg_count);
                        }
                    }

                    if (this.current_token != null and this.current_token.?.token_type == TokenType.bracket_close) {
                        this.consumeToken(); //closing bracket
                    } else {
                        return Error.parser_closing_bracket_expected;
                    }

                    //push number of arguments on the stack
                    var parser_token_args = ParserToken.create_number_int(this_arg_count);
                    try this.instruction_sequence.triggerStackSequenceUnary(&parser_token_args);

                    //push the function on the stack
                    const parser_token_func = createParserTokenFromLexTok(&function);
                    try this.instruction_sequence.triggerStackSequenceUnary(&parser_token_func);

                    //call the function
                    try this.instruction_sequence.execInstruction(Instructions.call_function);

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

                TokenType.boolean => {
                    const parser_token = createParserTokenFromLexTok(token_operand);
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
    var string_pool = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();
    const instruction_sequence = try testingGetInstructionSequence("100/50+10*20", &string_pool);
    defer instruction_sequence.instruction_list.deinit();

    const solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 100 } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 50 } } },
        Instruction{ .single_instruction = Instructions.divide },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 10 } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 20 } } },
        Instruction{ .single_instruction = Instructions.multiply },
        Instruction{ .single_instruction = Instructions.add },
    };

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "strings" {
    var string_pool = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();
    const instruction_sequence = try testingGetInstructionSequence("\"abc\"&\"def\"", &string_pool);
    defer instruction_sequence.instruction_list.deinit();

    const solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.string, .data_type = DataType{ .string = "abc"[0..] } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.string, .data_type = DataType{ .string = "def"[0..] } } },
        Instruction{ .single_instruction = Instructions.concat_strings },
    };

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "negate/percent/power 1" {
    var string_pool = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();
    const instruction_sequence = try testingGetInstructionSequence("-10^300%", &string_pool);
    defer instruction_sequence.instruction_list.deinit();

    const solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 10 } } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 300 } } },
        Instruction{ .single_instruction = Instructions.percent_of },
        Instruction{ .single_instruction = Instructions.to_the_power_of },
    };

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "negate/percent/power 2" {
    var string_pool = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();
    const instruction_sequence = try testingGetInstructionSequence("10^-300%", &string_pool);
    defer instruction_sequence.instruction_list.deinit();

    const solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 10 } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 300 } } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.percent_of },
        Instruction{ .single_instruction = Instructions.to_the_power_of },
    };

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "brackets" {
    var string_pool = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();
    const instruction_sequence = try testingGetInstructionSequence("50*(7-3)", &string_pool);
    defer instruction_sequence.instruction_list.deinit();

    const solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 7 } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 3 } } },
        Instruction{ .single_instruction = Instructions.subtract },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 50 } } },
        Instruction{ .single_instruction = Instructions.multiply },
    };

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "references" {
    var string_pool = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();
    const instruction_sequence = try testingGetInstructionSequence("100+F7*20", &string_pool);
    defer instruction_sequence.instruction_list.deinit();

    const solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference, .data_type = DataType{ .reference = .{ .column = 6, .row = 7 } } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 20 } } },
        Instruction{ .single_instruction = Instructions.multiply },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 100 } } },
        Instruction{ .single_instruction = Instructions.add },
    };

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "function 1" {
    var string_pool = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();
    const instruction_sequence = try testingGetInstructionSequence("SUM(A1:B2,R5)", &string_pool);
    defer instruction_sequence.instruction_list.deinit();

    const solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference, .data_type = DataType{ .reference = .{ .column = 1, .row = 1 } } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference, .data_type = DataType{ .reference = .{ .column = 1, .row = 2 } } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference, .data_type = DataType{ .reference = .{ .column = 2, .row = 1 } } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference, .data_type = DataType{ .reference = .{ .column = 2, .row = 2 } } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },

        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference, .data_type = DataType{ .reference = .{ .column = 18, .row = 5 } } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .u_int = 5 } } }, //number of arguments
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .function = Function.sum } } }, //the function itself
        Instruction{ .single_instruction = Instructions.call_function },
    };

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "function 2" {
    var string_pool = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();
    const instruction_sequence = try testingGetInstructionSequence("SUM(A1,Z51,2024,SUM(B1,B2))", &string_pool);
    defer instruction_sequence.instruction_list.deinit();

    const solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference, .data_type = DataType{ .reference = .{ .column = 1, .row = 1 } } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference, .data_type = DataType{ .reference = .{ .column = 26, .row = 51 } } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },

        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 2024 } } },

        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference, .data_type = DataType{ .reference = .{ .column = 2, .row = 1 } } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.reference, .data_type = DataType{ .reference = .{ .column = 2, .row = 2 } } } },
        Instruction{ .single_instruction = Instructions.resolve_reference },

        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .u_int = 2 } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.function, .data_type = DataType{ .function = Function.sum } } },
        Instruction{ .single_instruction = Instructions.call_function },

        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .u_int = 4 } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.function, .data_type = DataType{ .function = Function.sum } } },
        Instruction{ .single_instruction = Instructions.call_function },
    };

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "negation sequence" {
    var string_pool = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();
    const instruction_sequence = try testingGetInstructionSequence("1+-----5", &string_pool);
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 1 } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 5 } } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.add },
    };

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "addition and negation" {
    var string_pool = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();
    const instruction_sequence = try testingGetInstructionSequence("5+-9%", &string_pool);
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 5 } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 9 } } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.percent_of },
        Instruction{ .single_instruction = Instructions.add },
    };

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "division 1" {
    var string_pool = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();
    const instruction_sequence = try testingGetInstructionSequence("10/5", &string_pool);
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 10 } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 5 } } },
        Instruction{ .single_instruction = Instructions.divide },
    };

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "division 2" {
    var string_pool = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();
    const instruction_sequence = try testingGetInstructionSequence("10/-5", &string_pool);
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 10 } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 5 } } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.divide },
    };

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "division 3" {
    var string_pool = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();
    const instruction_sequence = try testingGetInstructionSequence("91%/-8", &string_pool);
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 91 } } },
        Instruction{ .single_instruction = Instructions.percent_of },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 8 } } },
        Instruction{ .single_instruction = Instructions.negate },
        Instruction{ .single_instruction = Instructions.divide },
    };

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "floating point num" {
    var string_pool = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();
    const instruction_sequence = try testingGetInstructionSequence("20.5+3.141", &string_pool);
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 20.5 } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .number = 3.141 } } },
        Instruction{ .single_instruction = Instructions.add },
    };

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "boolean equal" {
    var string_pool = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();
    const instruction_sequence = try testingGetInstructionSequence("AND(TRUE,FALSE)", &string_pool);
    defer instruction_sequence.instruction_list.deinit();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .boolean = true } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .boolean = false } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.constant, .data_type = DataType{ .u_int = 2 } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token_type = TokenType.function, .data_type = DataType{ .function = Function.bool_and } } },
        Instruction{ .single_instruction = Instructions.call_function },
    };

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

fn testingGetInstructionSequence(source: [*:0]const u8, string_pool: *std.heap.ArenaAllocator) !InstructionSequence {
    const token_list = try lex(source, string_pool);
    var token_list_iterator = makeTokenListIterator(token_list);
    defer token_list_iterator.drop();

    var parser = Parser{};
    parser.init(&token_list_iterator);
    return try parser.parse();
}

fn compareSolutionToinstrSeq(solution: []const Instruction, instruction_sequence: *const InstructionSequence) !void {
    for (solution, instruction_sequence.*.instruction_list.items) |sol, itm| {
        switch (sol) {
            InstructionType.single_instruction => {
                try std.testing.expect(sol.single_instruction == itm.single_instruction);
            },
            InstructionType.stack_operation => {
                try std.testing.expect(sol.stack_operation.instruction == itm.stack_operation.instruction);

                const sol_dt = sol.stack_operation.data_type;
                const itm_dt = itm.stack_operation.data_type;

                switch (sol.stack_operation.data_type) {
                    DataTypes.boolean => {
                        try std.testing.expect(sol_dt.boolean == itm_dt.boolean);
                    },
                    DataTypes.function => {
                        try std.testing.expect(sol_dt.function == itm_dt.function);
                    },
                    DataTypes.number => {
                        try std.testing.expect(sol_dt.number == itm_dt.number);
                    },
                    DataTypes.reference => {
                        try std.testing.expect(sol_dt.reference.column == itm_dt.reference.column and sol_dt.reference.row == itm_dt.reference.row);
                    },
                    DataTypes.string => {
                        try std.testing.expect(std.mem.eql(u8, sol_dt.string, itm_dt.string));
                    },
                    DataTypes.u_int => {
                        try std.testing.expect(sol_dt.u_int == itm_dt.u_int);
                    },
                }
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
                std.debug.print("{s} ", .{@tagName(value.stack_operation.instruction)});

                switch (value.stack_operation.data_type) {
                    DataTypes.boolean => {
                        std.debug.print("{}", .{value.stack_operation.data_type.boolean});
                    },
                    DataTypes.function => {
                        std.debug.print("{s}", .{@tagName(value.stack_operation.data_type.function)});
                    },
                    DataTypes.number => {
                        std.debug.print("{d}", .{value.stack_operation.data_type.number});
                    },
                    DataTypes.reference => {
                        std.debug.print("column: {} / row: {}", .{ value.stack_operation.data_type.reference.column, value.stack_operation.data_type.reference.row });
                    },
                    DataTypes.string => {
                        std.debug.print("{s}", .{value.stack_operation.data_type.string});
                    },
                    DataTypes.u_int => {
                        std.debug.print("{}", .{value.stack_operation.data_type.u_int});
                    },
                }

                std.debug.print("{c}\n", .{' '});
            },
        }
    }
}
