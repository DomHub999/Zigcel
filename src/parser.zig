const std = @import("std");
const lex = @import("lexer.zig");
const tok = @import("token.zig");
const TokenType = tok.TokenType;
const Token = tok.Token;
const TokenPair = tok.TokenPair;

const Error = error{
    parser_expected_operand_is_missing,
    parser_token_type_not_supported,
    parser_no_operand_to_negate_available,
    parser_no_payload_exceeded_max,
    OutOfMemory,
};

const NUMBER_OF_PAYLOADS: usize = 10;
const TokenOperatorFunc = struct {
    token: tok.Token = undefined,
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
    lexer: *lex.Lexer = undefined,
    current_token: ?*Token = null,
    instruction_sequence: InstructionSequence = undefined,

    pub fn init(this: *@This(), lexer: *lex.Lexer) void {
        this.instruction_sequence = InstructionSequence{};
        this.instruction_sequence.init();
        this.lexer = lexer;
    }

    pub fn parse(this: *@This()) !InstructionSequence {
        this.consumeToken();
        try this.stage06();
        return this.instruction_sequence;
    }

    fn consumeToken(this: *@This()) void {
        this.current_token = this.lexer.getNext();
    }

    const LayerFunction = *const fn(this: *@This())Error!?TokenOperatorFunc;
    fn callToUnderlLayer(this:*@This(), operator_function: InstructionSequence.OperatorFunction, lhs: *?TokenOperatorFunc, funToUnderlLayer: LayerFunction)!void{
        this.consumeToken();
        const result_rhs = try funToUnderlLayer(this);
        try this.triggerStackSequenceBinary(operator_function, lhs, &result_rhs);
    }

    //comparison =, >, <, >=, <=, <>
    fn stage06(this: *@This()) !void {

        var result_lhs = try this.stage05();

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.equal_sign) {
                try this.callToUnderlLayer(InstructionSequence.equal, &result_lhs, Parser.stage05);
            }
            while (token_operator.token_type == TokenType.greater_than_sign) {
                try this.callToUnderlLayer(InstructionSequence.greaterThan, &result_lhs, Parser.stage05);
            }
            while (token_operator.token_type == TokenType.less_than_sign) {
                try this.callToUnderlLayer(InstructionSequence.lessThan, &result_lhs, Parser.stage05);
            }
            while (token_operator.token_type == TokenType.greater_equal_to_sign) {
                try this.callToUnderlLayer(InstructionSequence.greaterEqualThan, &result_lhs, Parser.stage05);
            }
            while (token_operator.token_type == TokenType.less_equal_to_sign) {
                try this.callToUnderlLayer(InstructionSequence.lessEqualThan, &result_lhs, Parser.stage05);
            }
            while (token_operator.token_type == TokenType.not_equal_to_sign) {
                try this.callToUnderlLayer(InstructionSequence.notEqualTo, &result_lhs, Parser.stage05);
            }
        }

        //necessary for a single number, negated numer etc.
        if (result_lhs) |lhs| {
            try this.triggerStackSequenceUnary(&lhs);
        }
    }

    //concatenation &
    fn stage05(this: *@This()) Error!?TokenOperatorFunc {

        var result_lhs = try this.stage04();

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.ampersand) {
                try this.callToUnderlLayer(InstructionSequence.concatenate, &result_lhs, Parser.stage04);
                return null;
            }
        }

        return result_lhs;
    }

    //addition and subtraction +,-
    fn stage04(this: *@This()) Error!?TokenOperatorFunc {

        var result_lhs = try this.stage03();

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.plus) {
                try this.callToUnderlLayer(InstructionSequence.add, &result_lhs, Parser.stage03);
                return null;
            }
            while (token_operator.token_type == TokenType.minus) {
                try this.callToUnderlLayer(InstructionSequence.subtract, &result_lhs, Parser.stage03);
                return null;
            }
        }

        return result_lhs;
    }

    //multiplication and division *,/
    fn stage03(this: *@This()) Error!?TokenOperatorFunc {
        
        var result_lhs = try this.stage02();
        
        if (this.current_token) |token_operator| {
        
            while (token_operator.token_type == TokenType.asterisk) {
                try this.callToUnderlLayer(InstructionSequence.multipy, &result_lhs, Parser.stage02);
                return null;
            }
            while (token_operator.token_type == TokenType.forward_slash) {
                try this.callToUnderlLayer(InstructionSequence.divide, &result_lhs, Parser.stage02);
                return null;
            }
        }

        return result_lhs;
    }

    //exponentiation ^
    fn stage02(this: *@This()) Error!?TokenOperatorFunc {

        var result_lhs = try this.stage00();

        if (this.current_token) |token_operator| {
            while (token_operator.token_type == TokenType.caret) {
                try this.callToUnderlLayer(InstructionSequence.toThePowerOf, &result_lhs, Parser.stage00);
                return null;
            }
        }

        return result_lhs;
    }

    // //reference operators ' ' (single space)
    // fn stage01(this: *@This()) Error!?TokenOperatorFunc {
    //     const result_lhs = try this.stage00();
    //     if (this.current_token) |token_operator| {
    //         var result_rhs: ?TokenOperatorFunc = null;

    //         while (token_operator.*.token_type == TokenType.space) {
    //             this.consumeToken();
    //             result_rhs = try this.stage00();
    //             // try this.triggerStackSequenceBinary(InstructionSequence.toThePowerOf, &result_lhs, &result_rhs);
    //             return null;
    //         }
    //     }
    //     return result_lhs;
    // }

    //constant, string, negation, opening bracket, formula, reference, range
    fn stage00(this: *@This()) Error!?TokenOperatorFunc {

        //get rid of the comma/semicolon before the operand
        if (this.current_token) |symbol| {
            if (symbol.token_type == TokenType.argument_deliminiter) {
                this.consumeToken();
            }
        }

        if (this.current_token) |token_operand| {
            switch (token_operand.token_type) {

                //CONSTANT
                TokenType.constant => {
                    var token_fnc = TokenOperatorFunc{ .token = token_operand.* };
                    this.consumeToken();
                    try this.dealWithPercentSign(&token_fnc);
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

                // //OPENING BRACKET
                // TokenType.bracket_open => {},

                // //FORMULA
                // TokenType.formula => {
                //     this.consumeToken(); //formula
                //     this.consumeToken(); //opening bracket

                // },

                // //REFERENCE
                // TokenType.reference => {},

                // //RANGE
                // TokenType.range => {},

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

    fn triggerStackSequenceBinary(this: *@This(), operator_function: InstructionSequence.OperatorFunction, lhs: *const ?TokenOperatorFunc, rhs: *const ?TokenOperatorFunc) !void {

        if (lhs.*) |l| {
            try this.instruction_sequence.pushConstant(&l.token);
            try this.unloadPayload(&l);
        }
        if (rhs.*) |r| {
            try this.instruction_sequence.pushConstant(&r.token);
            try this.unloadPayload(&r);
        }

        try operator_function(&this.instruction_sequence);

    }

    fn triggerStackSequenceUnary(this: *@This(), lhs: *const TokenOperatorFunc) !void {
        try this.instruction_sequence.pushConstant(&lhs.token);
        try this.unloadPayload(lhs);
    }

    fn unloadPayload(this: *@This(), tok_op_fn: *const TokenOperatorFunc) !void {
        var idx: usize = 0;
        while (idx < tok_op_fn.idx_payload) : (idx += 1) {
            try tok_op_fn.payload[idx].?(&this.instruction_sequence);
        }
    }
};

const Instructions = enum {
    equal,
    greaterThan,
    lessThan,
    greaterEqualThan,
    lessEqualThan,
    notEqualTo,

    add,
    subtract,
    multiply,
    divide,

    push,

    concat_strings,

    to_the_power_of,

    percent_of,

    negate,

    range,
};

pub const InstructionType = enum {
    single_instruction,
    stack_operation,
};

pub const Instruction = union(InstructionType) {
    single_instruction: Instructions,
    stack_operation: struct {
        instruction: Instructions,
        token: Token,
    },
};

const InstructionSequence = struct {
    const array_list_type = std.ArrayList(Instruction);
    instruction_list: array_list_type = undefined,

    pub fn init(this: *@This()) void {
        this.instruction_list = array_list_type.init(std.heap.page_allocator);
    }

    pub fn drop(this: *@This()) void {
        this.instruction_list.deinit();
    }

    const OperatorFunction = *const fn (this: *@This()) std.mem.Allocator.Error!void;

    fn pushConstant(this: *@This(), token: *const Token) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = token.* } });
    }
    fn equal(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.equal });
    }
    fn greaterThan(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.greaterThan });
    }
    fn lessThan(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.lessThan });
    }
    fn greaterEqualThan(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.greaterEqualThan });
    }
    fn lessEqualThan(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.lessEqualThan });
    }
    fn notEqualTo(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.notEqualTo });
    }

    fn concatenate(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.concat_strings });
    }

    fn add(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.add });
    }
    fn subtract(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.subtract });
    }

    fn multipy(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.multiply });
    }
    fn divide(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.divide });
    }

    fn toThePowerOf(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.to_the_power_of });
    }
    fn percentOf(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.percent_of });
    }
    fn negate(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.negate });
    }
};

test "100/50+10*20" {
    var lexer = lex.Lexer{};
    lexer.init();
    defer lexer.drop();

    const source = "100/50+10*20";
    try lexer.lex(source);

    var parser = Parser{};
    parser.init(&lexer);
    const instruction_sequence = try parser.parse();

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
    var lexer = lex.Lexer{};
    lexer.init();
    defer lexer.drop();

    const source = "\"abc\"&\"def\"";
    try lexer.lex(source);

    var parser = Parser{};
    parser.init(&lexer);
    const instruction_sequence = try parser.parse();

    var solution = [_]Instruction{
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.string } } },
        Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = Token{ .token_type = TokenType.string } } },
        Instruction{ .single_instruction = Instructions.concat_strings },
    };

    @memcpy(solution[0].stack_operation.token.token[0..3], "abc");
    @memcpy(solution[1].stack_operation.token.token[0..3], "def");

    try compareSolutionToinstrSeq(&solution, &instruction_sequence);
}

test "negate/percent/power" {
    var lexer = lex.Lexer{};
    lexer.init();
    defer lexer.drop();

    const source = "-10^300%";
    try lexer.lex(source);

    var parser = Parser{};
    parser.init(&lexer);
    const instruction_sequence = try parser.parse();

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
                std.debug.print("{s} {s}\n", .{ @tagName(value.stack_operation.instruction), lex.Lexer.extractToken(&value.stack_operation.token.token) });
            },
        }
    }
}
