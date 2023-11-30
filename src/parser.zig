const std = @import("std");
const lex = @import("lexer.zig");
const tok = @import("token.zig");
const TokenType = tok.TokenType;
const Token = tok.Token;

const Error = error{
    expected_operand_is_missing,
};

const Parser = struct {
    lexer: *lex.Lexer,
    current_token: ?*Token = null,
    first_token: bool = true,
    instruction_sequene:InstructionSequence = undefined,

    pub fn init(this:*@This(), lexer: *lex.Lexer)void{
        this.instruction_sequene = InstructionSequence{};
        this.instruction_sequene.init();
        this.lexer = lexer;
    }

    pub fn parse(this:*@This()) InstructionSequence {
        this.consumeToken();
        return this.instruction_sequene;
    }

    fn consumeToken(this: *@This()) void {
        this.current_token = this.lexer.getNext();
    }
    //test monday
    //comparison =, >, <, >=, <=, <>
    fn stage00(this: *@This()) void {
        var result_lhs = this.stage01();

        if (this.current_token) |token_operator| {
            var result_rhs: ?Token = null;

            while (token_operator.*.token == TokenType.equal_sign) {
                this.consumeToken();
                result_rhs = this.stage01();
                this.triggerStackSequenceBinary(InstructionSequence.equal, &result_lhs, &result_rhs);
                return null;
            }

            while (token_operator.*.token == TokenType.greater_than_sign) {
                this.consumeToken();
                result_rhs = this.stage01();
                this.triggerStackSequenceBinary(InstructionSequence.greaterThan, &result_lhs, &result_rhs);
                return null;
            }
            while (token_operator.*.token == TokenType.less_than_sign) {
                this.consumeToken();
                result_rhs = this.stage01();
                this.triggerStackSequenceBinary(InstructionSequence.lessThan, &result_lhs, &result_rhs);
                return null;
            }
            while (token_operator.*.token == TokenType.greater_equal_to_sign) {
                this.consumeToken();
                result_rhs = this.stage01();
                this.triggerStackSequenceBinary(InstructionSequence.greaterEqualThan, &result_lhs, &result_rhs);
                return null;
            }
            while (token_operator.*.token == TokenType.less_equal_to_sign) {
                this.consumeToken();
                result_rhs = this.stage01();
                this.triggerStackSequenceBinary(InstructionSequence.lessEqualThan, &result_lhs, &result_rhs);
                return null;
            }
            while (token_operator.*.token == TokenType.not_equal_to_sign) {
                this.consumeToken();
                result_rhs = this.stage01();
                this.triggerStackSequenceBinary(InstructionSequence.notEqualTo, &result_lhs, &result_rhs);
                return null;
            }
        }

        return result_lhs;
    }

    //concatenation &
    fn stage01(this: *@This()) ?Token {
        var result_lhs = this.stage02();
        if (this.current_token) |token_operator| {
            var result_rhs: ?Token = null;

            while (token_operator.*.token_type == TokenType.ampersand) {
                this.consumeToken();
                result_rhs = this.stage02();
                this.triggerStackSequenceBinary(InstructionSequence.concatenate, &result_lhs, &result_rhs);
                return null;
            }
        }
        return result_lhs;
    }

    //addition and subtraction +,-
    fn stage02(this: *@This()) ?Token {
        var result_lhs = this.stage03();
        if (this.current_token) |token_operator| {
            var result_rhs: ?Token = null;

            while (token_operator.*.token_type == TokenType.plus) {
                this.consumeToken();
                result_rhs = this.stage03();
                this.triggerStackSequenceBinary(InstructionSequence.add, &result_lhs, &result_rhs);
                return null;
            }

            while (token_operator.*.token_type == TokenType.minus) {
                this.consumeToken();
                result_rhs = this.stage03();
                this.triggerStackSequenceBinary(InstructionSequence.subtract, &result_lhs, &result_lhs);
                return null;
            }
        }
        return result_lhs;
    }

    //multiplication and division *,/
    fn stage03(this: *@This()) ?Token {
        var result_lhs = this.stage04();
        if (this.current_token) |token_operator| {
            var result_rhs: ?Token = null;

            while (token_operator.*.token_type == TokenType.asterisk) {
                this.consumeToken();
                result_rhs = this.stage04();
                this.triggerStackSequenceBinary(InstructionSequence.multipy, &result_lhs, result_rhs);
                return null;
            }

            while (token_operator.*.token_type == TokenType.forward_slash) {
                this.consumeToken();
                result_rhs = this.stage04();
                this.triggerStackSequenceBinary(InstructionSequence.divide, &result_lhs, &result_rhs);
                return null;
            }
        }
        return result_lhs;
    }

    //exponentiation ^
    fn stage04(this: *@This()) ?Token {
        var result_lhs = this.stage05();
        if (this.current_token) |token_operator| {
            _ = token_operator;
            var result_rhs: ?Token = null;
            _ = result_rhs;
        }
        return result_lhs;
    }

    //percent %
    fn stage05(this: *@This()) ?Token {
        var result_lhs = this.stage06();
        if (this.current_token) |token_operator| {
            _ = token_operator;
            var result_rhs: ?Token = null;
            _ = result_rhs;
        }
        return result_lhs;
    }

    //negation -
    fn stage06(this: *@This()) ?Token {
        var result_lhs = this.stage07();
        if (this.current_token) |token_operator| {
            _ = token_operator;
            var result_rhs: ?Token = null;
            _ = result_rhs;
        }
        return result_lhs;
    }

    //reference operators :,' ',,
    fn stage07(this: *@This()) ?Token {
        var result_lhs = this.stage08();
        if (this.current_token) |token_operator| {
            _ = token_operator;
            var result_rhs: ?Token = null;
            _ = result_rhs;
        }
        return result_lhs;
    }

    //constant, sub section, formula
    fn stage08(this: *@This()) ?Token {
        if (this.current_token) |token_operand| {
            switch (token_operand.token_type) {
                TokenType.constant or TokenType.string => {
                    const token = token_operand.*;
                    this.consumeToken();
                    return token;
                },
            }
        } else {
            return Error.expected_operand_is_missing;
        }
    }

    fn triggerStackSequenceBinary(this: *@This(), operator_function: InstructionSequence.OperatorFunction, lhs: *Token, rhs: *Token) void {
        if (this.first_token) {
            InstructionSequence.pushConstant(lhs);
            InstructionSequence.pushConstant(rhs);
            this.first_token = false;
        } else {
            if (lhs.* != null) {
                InstructionSequence.pushConstant(&this.instruction_sequene, lhs);
            }

            if (rhs.* != null) {
                InstructionSequence.pushConstant(&this.instruction_sequence, rhs);
            }
        }

        operator_function();

        lhs.* = null;
        rhs.* = null;
    }

    fn triggerStackSequenceUnary(this: *@This(), operator_function: InstructionSequence.OperatorFunction, token: *Token) void {
        _ = operator_function;

        if (token.* != null) {
            InstructionSequence.pushConstant(&this.instruction_sequence, token);
        }
        if (this.first_token) {
            this.first_token = false;
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

    push,
};

const InstructionType = enum {
    single_instruction,
    stack_operation,
};

const Instruction = union(InstructionType) {
    single_instruction: Instruction,
    stack_operation: struct {
        instruction: Instruction,
        token: Token,
    },
};

const InstructionSequence = struct {
    const array_list_type = std.ArrayList(Instruction);
    instruction_list: array_list_type = undefined,

    pub fn init(this: *@This()) void {
        this.instruction_list.init(std.heap.page_allocator);
    }

    pub fn drop(this: *@This()) void {
        this.instruction_list.deinit();
    }

    const OperatorFunction = *const fn (this:*@This()) void;

    fn pushConstant(token: *Token) void {
        _ = token;
    }
    fn equal(this:*@This()) void {
        _ = this;}
    fn greaterThan(this:*@This()) void {
        _ = this;}
    fn lessThan(this:*@This()) void {
        _ = this;}
    fn greaterEqualThan(this:*@This()) void {
        _ = this;}
    fn lessEqualThan(this:*@This()) void {
        _ = this;}
    fn notEqualTo(this:*@This()) void {
        _ = this;}

    fn concatenate(this:*@This()) void {
        _ = this;}

    fn add(this:*@This()) void {
        _ = this;}
    fn subtract(this:*@This()) void {
        _ = this;}

    fn multipy(this:*@This()) void {
        _ = this;}
    fn divide(this:*@This()) void {
        _ = this;}
};

test "parser" {
    var lexer = lex.Lexer{};
    lexer.init();

    const source = "10*20";
    try lexer.lex(source);
}
