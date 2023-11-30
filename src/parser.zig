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

    pub fn parse(lexer: *lex.Lexer) void {
        _ = lexer;
        Parser.consumeToken();
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
                this.triggerStackSequenceBinary(StackSequence.equal(), &result_lhs, &result_rhs);
                return null;
            }

            while (token_operator.*.token == TokenType.greater_than_sign) {
                this.consumeToken();
                result_rhs = this.stage01();
                this.triggerStackSequenceBinary(StackSequence.greaterThan(), &result_lhs, &result_rhs);
                return null;
            }
            while (token_operator.*.token == TokenType.less_than_sign) {
                this.consumeToken();
                result_rhs = this.stage01();
                this.triggerStackSequenceBinary(StackSequence.lessThan(), &result_lhs, &result_rhs);
                return null;
            }
            while (token_operator.*.token == TokenType.greater_equal_to_sign) {
                this.consumeToken();
                result_rhs = this.stage01();
                this.triggerStackSequenceBinary(StackSequence.greaterEqualThan(), &result_lhs, &result_rhs);
                return null;
            }
            while (token_operator.*.token == TokenType.less_equal_to_sign) {
                this.consumeToken();
                result_rhs = this.stage01();
                this.triggerStackSequenceBinary(StackSequence.lessEqualThan(), &result_lhs, &result_rhs);
                return null;
            }
            while (token_operator.*.token == TokenType.not_equal_to_sign) {
                this.consumeToken();
                result_rhs = this.stage01();
                this.triggerStackSequenceBinary(StackSequence.notEqualTo(), &result_lhs, &result_rhs);
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
                this.triggerStackSequenceBinary(StackSequence.concatenate(), &result_lhs, &result_rhs);
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
                this.triggerStackSequenceBinary(StackSequence.add(), &result_lhs, &result_rhs);
                return null;
            }

            while (token_operator.*.token_type == TokenType.minus) {
                this.consumeToken();
                result_rhs = this.stage03();
                this.triggerStackSequenceBinary(StackSequence.subtract(), &result_lhs, &result_lhs);
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
                this.triggerStackSequenceBinary(StackSequence.multipy(), &result_lhs, result_rhs);
                return null;
            }

            while (token_operator.*.token_type == TokenType.forward_slash) {
                this.consumeToken();
                result_rhs = this.stage04();
                this.triggerStackSequenceBinary(StackSequence.divide(), &result_lhs, &result_rhs);
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

    fn triggerStackSequenceBinary(this: *@This(), operator_function: StackSequence.OperatorFunction, lhs: *Token, rhs: *Token) void {
        if (this.first_token) {
            StackSequence.pushConstant(lhs);
            StackSequence.pushConstant(rhs);
            this.first_token = false;
        } else {
            if (lhs.* != null) {
                StackSequence.pushConstant(lhs);
            }

            if (rhs.* != null) {
                StackSequence.pushConstant(rhs);
            }
        }

        operator_function();

        lhs.* = null;
        rhs.* = null;
    }

    fn triggerStackSequenceUnary(this: *@This(), operator_function: StackSequence.OperatorFunction, token: *Token) void {
        _ = operator_function;

        if (token.* != null) {
            StackSequence.pushConstant(token);
        }
        if (this.first_token) {
            this.first_token = false;
        }
    }
};

// const Instructions = enum {
//     equal,
//     greaterThan,
//     lessThan,
//     greaterEqualThan,
//     lessEqualThan,
//     notEqualTo,
// };

const StackSequence = struct {
    


    const OperatorFunction = *const fn () void;

    fn pushConstant(token: *Token) void {
        _ = token;
    }
    fn equal() void {}
    fn greaterThan() void {}
    fn lessThan() void {}
    fn greaterEqualThan() void {}
    fn lessEqualThan() void {}
    fn notEqualTo() void {}

    fn concatenate() void {}

    fn add() void {}
    fn subtract() void {}

    fn multipy() void {}
    fn divide() void {}
};


test "parser"{

    var lexer = lex.Lexer{};
    lexer.init();

    const source = "10*20";
    try lexer.lex(source);

}