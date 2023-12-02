const std = @import("std");
const lex = @import("lexer.zig");
const tok = @import("token.zig");
const TokenType = tok.TokenType;
const Token = tok.Token;

const Error = error{
    expected_operand_is_missing,
    token_type_not_supported,
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
        try this.stage00();
        return this.instruction_sequence;
    }

    fn consumeToken(this: *@This()) void {
        this.current_token = this.lexer.getNext();
    }
    //test monday
    //comparison =, >, <, >=, <=, <>
    fn stage00(this: *@This()) !void {
        var result_lhs = try this.stage01();

        if (this.current_token) |token_operator| {
            var result_rhs: ?Token = null;

            while (token_operator.*.token_type == TokenType.equal_sign) {
                this.consumeToken();
                result_rhs = try this.stage01();
                try this.triggerStackSequenceBinary(InstructionSequence.equal, &result_lhs, &result_rhs);
            }

            while (token_operator.*.token_type == TokenType.greater_than_sign) {
                this.consumeToken();
                result_rhs = try this.stage01();
                try this.triggerStackSequenceBinary(InstructionSequence.greaterThan, &result_lhs, &result_rhs);
            }
            while (token_operator.*.token_type == TokenType.less_than_sign) {
                this.consumeToken();
                result_rhs = try this.stage01();
                try this.triggerStackSequenceBinary(InstructionSequence.lessThan, &result_lhs, &result_rhs);
            }
            while (token_operator.*.token_type == TokenType.greater_equal_to_sign) {
                this.consumeToken();
                result_rhs = try this.stage01();
                try this.triggerStackSequenceBinary(InstructionSequence.greaterEqualThan, &result_lhs, &result_rhs);
            }
            while (token_operator.*.token_type == TokenType.less_equal_to_sign) {
                this.consumeToken();
                result_rhs = try this.stage01();
                try this.triggerStackSequenceBinary(InstructionSequence.lessEqualThan, &result_lhs, &result_rhs);
            }
            while (token_operator.*.token_type == TokenType.not_equal_to_sign) {
                this.consumeToken();
                result_rhs = try this.stage01();
                try this.triggerStackSequenceBinary(InstructionSequence.notEqualTo, &result_lhs, &result_rhs);
            }
        }
    }

    //concatenation &
    fn stage01(this: *@This()) !?Token {
        var result_lhs = try this.stage02();
        if (this.current_token) |token_operator| {
            var result_rhs: ?Token = null;

            while (token_operator.*.token_type == TokenType.ampersand) {
                this.consumeToken();
                result_rhs = try this.stage02();
                try this.triggerStackSequenceBinary(InstructionSequence.concatenate, &result_lhs, &result_rhs);
                return null;
            }
        }
        return result_lhs;
    }

    //addition and subtraction +,-
    fn stage02(this: *@This()) !?Token {
        var result_lhs = try this.stage03();
        if (this.current_token) |token_operator| {
            var result_rhs: ?Token = null;

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
    fn stage03(this: *@This()) !?Token {
        var result_lhs = try this.stage04();
        if (this.current_token) |token_operator| {
            var result_rhs: ?Token = null;

            while (token_operator.*.token_type == TokenType.asterisk) {
                this.consumeToken();
                result_rhs = try this.stage04();
                try this.triggerStackSequenceBinary(InstructionSequence.multipy, &result_lhs, &result_rhs);
                return null;
            }

            while (token_operator.*.token_type == TokenType.forward_slash) {
                this.consumeToken();
                result_rhs = try this.stage04();
                try this.triggerStackSequenceBinary(InstructionSequence.divide, &result_lhs, &result_rhs);
                return null;
            }
        }
        return result_lhs;
    }

    //exponentiation ^
    fn stage04(this: *@This()) !?Token {
        var result_lhs = try this.stage05();
        if (this.current_token) |token_operator| {
            var result_rhs: ?Token = null;

            while (token_operator.*.token_type == TokenType.caret) {
                this.consumeToken();
                result_rhs = try this.stage05();
                try this.triggerStackSequenceBinary(InstructionSequence.toThePowerOf, &result_lhs, &result_rhs);
                return null;
            }
        }
        return result_lhs;
    }

    //percent %
    fn stage05(this: *@This()) !?Token {
        var result_lhs = try this.stage06();
        if (this.current_token) |token_operator| {
            // var result_rhs: ?Token = null;

            while (token_operator.*.token_type == TokenType.percent_sign) {
                this.consumeToken();
                //result_rhs = try this.stage06();
                try this.triggerStackSequenceUnary(InstructionSequence.percentOf, &result_lhs);
                return null;
            }
        }
        return result_lhs;
    }

    //negation -
    fn stage06(this: *@This()) !?Token {
        // var result_lhs = try this.stage07();
        if (this.current_token) |token_operator| {
            var result_rhs: ?Token = null;

            while (token_operator.*.token_type == TokenType.minus) {
                this.consumeToken();
                result_rhs = try this.stage07();
                try this.triggerStackSequenceUnary(InstructionSequence.negate, &result_rhs);
                return null;
            }
        }
        var result_lhs = try this.stage07();
        return result_lhs;
    }

    //reference operators :,' ',,
    fn stage07(this: *@This()) !?Token {
        var result_lhs = try this.stage08();
        if (this.current_token) |token_operator| {
            _ = token_operator;
            var result_rhs: ?Token = null;
            _ = result_rhs;
        }
        return result_lhs;
    }

    //constant, sub section, formula, string
    fn stage08(this: *@This()) !?Token {
        if (this.current_token) |token_operand| {
            switch (token_operand.token_type) {
                TokenType.constant => {
                    const token = token_operand.*;
                    this.consumeToken();
                    return token;
                },

                TokenType.string => {
                    const token = token_operand.*;
                    this.consumeToken();
                    return token;
                },
                else => {
                    return Error.token_type_not_supported;
                },
            }
        } else {
            return Error.expected_operand_is_missing;
        }
    }

    fn triggerStackSequenceBinary(this: *@This(), operator_function: InstructionSequence.OperatorFunction, lhs: *?Token, rhs: *?Token) !void {
        if (this.first_token) {
            if (lhs.* != null) {
                try this.instruction_sequence.pushConstant(&(lhs.*.?));
            }
            if (rhs.* != null) {
                try this.instruction_sequence.pushConstant(&(rhs.*.?));
            }
            this.first_token = false;
        } else {
            if (lhs.* != null) {
                try InstructionSequence.pushConstant(&this.instruction_sequence, &(lhs.*.?));
            }

            if (rhs.* != null) {
                try InstructionSequence.pushConstant(&this.instruction_sequence, &(rhs.*.?));
            }
        }

        try operator_function(&this.instruction_sequence);

        lhs.* = null;
        rhs.* = null;
    }

    fn triggerStackSequenceUnary(this: *@This(), operator_function: InstructionSequence.OperatorFunction, token: *?Token) !void {

        if (token.* != null) {
            try InstructionSequence.pushConstant(&this.instruction_sequence, &(token.*.?));
        }
        if (this.first_token) {
            this.first_token = false;
        }

        try operator_function(&this.instruction_sequence);
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

    concat_stringss,

    to_the_power_of,

    percent_of,

    negate,
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
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.concat_stringss });
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
        Instruction{ .single_instruction = Instructions.concat_stringss },
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
        Instruction{ .single_instruction = Instructions.concat_stringss },
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
