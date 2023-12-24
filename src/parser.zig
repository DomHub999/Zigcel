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
    parser_max_operator_prefix_exceeded,
    parser_max_operator_suffix_exceeded,
};

const N_PRE_SUFF_OPERATORS: usize = 5;
const TokenOperatorFunc = struct {
    token: tok.Token = undefined,
    prefix_operators: [N_PRE_SUFF_OPERATORS]?InstructionSequence.OperatorFunction = [_]?InstructionSequence.OperatorFunction{null} ** N_PRE_SUFF_OPERATORS,
    suffix_operators: [N_PRE_SUFF_OPERATORS]?InstructionSequence.OperatorFunction = [_]?InstructionSequence.OperatorFunction{null} ** N_PRE_SUFF_OPERATORS,
    idx_prefix_op: usize = 0,
    idx_suffix_op: usize = 0,
    fn pushBackPrefix(this: *@This(), func: InstructionSequence.OperatorFunction) !void {
        if (this.idx_prefix_op >= N_PRE_SUFF_OPERATORS) {
            return Error.parser_max_operator_prefix_exceeded;
        }
        this.prefix_operators[this.idx_prefix_op] = func;
        this.idx_prefix_op += 1;
    }
    fn pushBackSuffix(this: *@This(), func: InstructionSequence.OperatorFunction) !void {
        if (this.idx_prefix_op >= N_PRE_SUFF_OPERATORS) {
            return Error.parser_max_operator_suffix_exceeded;
        }
        this.suffix_operators[this.idx_suffix_op] = func;
        this.idx_suffix_op += 1;
    }
};

pub const Parser = struct {
    lexer: *lex.Lexer = undefined,
    current_token: ?*Token = null,
    first_token: bool = true,
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

    //comparison =, >, <, >=, <=, <>
    fn stage06(this: *@This()) !void {
        var result_lhs = try this.stage05();

        if (this.current_token) |token_operator| {
            var result_rhs: ?TokenOperatorFunc = null;

            while (token_operator.*.token_type == TokenType.equal_sign) {
                this.consumeToken();
                result_rhs = try this.stage05();
                try this.triggerStackSequenceBinary(InstructionSequence.equal, &result_lhs, &result_rhs);
            }

            while (token_operator.*.token_type == TokenType.greater_than_sign) {
                this.consumeToken();
                result_rhs = try this.stage05();
                try this.triggerStackSequenceBinary(InstructionSequence.greaterThan, &result_lhs, &result_rhs);
            }
            while (token_operator.*.token_type == TokenType.less_than_sign) {
                this.consumeToken();
                result_rhs = try this.stage05();
                try this.triggerStackSequenceBinary(InstructionSequence.lessThan, &result_lhs, &result_rhs);
            }
            while (token_operator.*.token_type == TokenType.greater_equal_to_sign) {
                this.consumeToken();
                result_rhs = try this.stage05();
                try this.triggerStackSequenceBinary(InstructionSequence.greaterEqualThan, &result_lhs, &result_rhs);
            }
            while (token_operator.*.token_type == TokenType.less_equal_to_sign) {
                this.consumeToken();
                result_rhs = try this.stage05();
                try this.triggerStackSequenceBinary(InstructionSequence.lessEqualThan, &result_lhs, &result_rhs);
            }
            while (token_operator.*.token_type == TokenType.not_equal_to_sign) {
                this.consumeToken();
                result_rhs = try this.stage05();
                try this.triggerStackSequenceBinary(InstructionSequence.notEqualTo, &result_lhs, &result_rhs);
            }
        }

        //necessary for a single number, negated numer etc.
        if (result_lhs) |*lhs| {
            try this.triggerStackSequenceUnary(lhs);
        }
    }

    //concatenation &
    fn stage05(this: *@This()) !?TokenOperatorFunc {
        var result_lhs = try this.stage04();
        if (this.current_token) |token_operator| {
            var result_rhs: ?TokenOperatorFunc = null;

            while (token_operator.*.token_type == TokenType.ampersand) {
                this.consumeToken();
                result_rhs = try this.stage04();
                try this.triggerStackSequenceBinary(InstructionSequence.concatenate, &result_lhs, &result_rhs);
                return null;
            }
        }
        return result_lhs;
    }

    //addition and subtraction +,-
    fn stage04(this: *@This()) !?TokenOperatorFunc {
        var result_lhs = try this.stage03();
        if (this.current_token) |token_operator| {
            var result_rhs: ?TokenOperatorFunc = null;

            while (token_operator.*.token_type == TokenType.plus) {
                this.consumeToken();
                result_rhs = try this.stage03();
                try this.triggerStackSequenceBinary(InstructionSequence.add, &result_lhs, &result_rhs);
                return null;
            }

            while (token_operator.*.token_type == TokenType.minus) {
                this.consumeToken();
                result_rhs = try this.stage03();
                try this.triggerStackSequenceBinary(InstructionSequence.subtract, &result_lhs, &result_lhs);
                return null;
            }
        }
        return result_lhs;
    }

    //multiplication and division *,/
    fn stage03(this: *@This()) !?TokenOperatorFunc {
        var result_lhs = try this.stage02();
        if (this.current_token) |token_operator| {
            var result_rhs: ?TokenOperatorFunc = null;

            while (token_operator.*.token_type == TokenType.asterisk) {
                this.consumeToken();
                result_rhs = try this.stage02();
                try this.triggerStackSequenceBinary(InstructionSequence.multipy, &result_lhs, &result_rhs);
                return null;
            }

            while (token_operator.*.token_type == TokenType.forward_slash) {
                this.consumeToken();
                result_rhs = try this.stage02();
                try this.triggerStackSequenceBinary(InstructionSequence.divide, &result_lhs, &result_rhs);
                return null;
            }
        }
        return result_lhs;
    }

    //exponentiation ^
    fn stage02(this: *@This()) !?TokenOperatorFunc {
        var result_lhs = try this.stage01();
        if (this.current_token) |token_operator| {
            var result_rhs: ?TokenOperatorFunc = null;

            while (token_operator.*.token_type == TokenType.caret) {
                this.consumeToken();
                result_rhs = try this.stage01();
                try this.triggerStackSequenceBinary(InstructionSequence.toThePowerOf, &result_lhs, &result_rhs);
                return null;
            }
        }
        return result_lhs;
    }

    //reference operators :,' ',, (colon, single space)
    fn stage01(this: *@This()) !?TokenOperatorFunc {
        const result_lhs = try this.stage00();
        if (this.current_token) |token_operator| {
            var result_rhs: ?TokenOperatorFunc = null;

            while (token_operator.*.token_type == TokenType.colon) {
                this.consumeToken();
                result_rhs = try this.stage00();
                // try this.triggerStackSequenceBinary(InstructionSequence.toThePowerOf, &result_lhs, &result_rhs);
                return null;
            }
        }
        return result_lhs;
    }

    //constant, sub section, formula, string
    fn stage00(this: *@This()) !?TokenOperatorFunc {
        if (this.current_token) |token_operand| {
            switch (token_operand.token_type) {
                TokenType.constant => {
                    var token_fnc = TokenOperatorFunc{ .token = token_operand.* };
                    this.consumeToken();

                    try this.dealWithPercentSign(&token_fnc);

                    return token_fnc;
                },

                TokenType.string => {
                    const token_fnc = TokenOperatorFunc{ .token = token_operand.* };
                    this.consumeToken();
                    return token_fnc;
                },

                TokenType.minus => {
                    var token_fnc = TokenOperatorFunc{};
                    try token_fnc.pushBackPrefix(InstructionSequence.negate);
                    this.consumeToken();

                    while (this.current_token) |token_unwrapped| {
                        if (token_unwrapped.token_type == TokenType.minus) {
                            try token_fnc.pushBackPrefix(InstructionSequence.negate);
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
                try token_fnc.pushBackSuffix(InstructionSequence.percentOf);
                this.consumeToken();
            } else {
                break;
            }
        }
    }

    fn triggerStackSequenceBinary(this: *@This(), operator_function: InstructionSequence.OperatorFunction, lhs: *?TokenOperatorFunc, rhs: *?TokenOperatorFunc) !void {
        if (this.first_token) {
            if (lhs.* != null) {
                try this.instruction_sequence.pushConstant(&(lhs.*.?.token));

                var idx: usize = 0;
                while (idx < lhs.*.?.idx_prefix_op) : (idx += 1) {
                    try lhs.*.?.prefix_operators[idx].?(&this.instruction_sequence);
                }
                idx = 0;
                while (idx < lhs.*.?.idx_suffix_op) : (idx += 1) {
                    try lhs.*.?.suffix_operators[idx].?(&this.instruction_sequence);
                }
            }
            if (rhs.* != null) {
                try this.instruction_sequence.pushConstant(&(rhs.*.?.token));

                var idx: usize = 0;
                while (idx < rhs.*.?.idx_prefix_op) : (idx += 1) {
                    try rhs.*.?.prefix_operators[idx].?(&this.instruction_sequence);
                }
                idx = 0;
                while (idx < rhs.*.?.idx_suffix_op) : (idx += 1) {
                    try rhs.*.?.suffix_operators[idx].?(&this.instruction_sequence);
                }
            }
            this.first_token = false;
        } else {
            if (lhs.* != null) {
                try InstructionSequence.pushConstant(&this.instruction_sequence, &(lhs.*.?.token));

                var idx: usize = 0;
                while (idx < lhs.*.?.idx_prefix_op) : (idx += 1) {
                    try lhs.*.?.prefix_operators[idx].?(&this.instruction_sequence);
                }
                idx = 0;
                while (idx < lhs.*.?.idx_suffix_op) : (idx += 1) {
                    try lhs.*.?.suffix_operators[idx].?(&this.instruction_sequence);
                }
            }

            if (rhs.* != null) {
                try InstructionSequence.pushConstant(&this.instruction_sequence, &(rhs.*.?.token));

                var idx: usize = 0;
                while (idx < rhs.*.?.idx_prefix_op) : (idx += 1) {
                    try rhs.*.?.prefix_operators[idx].?(&this.instruction_sequence);
                }
                idx = 0;
                while (idx < rhs.*.?.idx_suffix_op) : (idx += 1) {
                    try rhs.*.?.suffix_operators[idx].?(&this.instruction_sequence);
                }
            }
        }

        try operator_function(&this.instruction_sequence);

        lhs.* = null;
        rhs.* = null;
    }

    fn triggerStackSequenceUnary(this: *@This(), lhs: *TokenOperatorFunc) !void {
        try InstructionSequence.pushConstant(&this.instruction_sequence, &lhs.token);
        var idx: usize = 0;
        while (idx < lhs.idx_prefix_op) : (idx += 1) {
            try lhs.prefix_operators[idx].?(&this.instruction_sequence);
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

    fn pushConstant(this: *@This(), token: *Token) std.mem.Allocator.Error!void {
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

    const source = "-10^300%";
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
