const std = @import("std");
const lex = @import("lexer.zig");

const Error = error{
    token_type_not_impl_for_stage08,
};

const Parser = struct {
    lexer: *lex.Lexer,
    current_token: ?*lex.Token = null,
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
            while (token_operator.*.token == lex.TokenType.equal_sign) {
                this.consumeToken();
                var result_rhs = this.stage01();
                this.triggerStackSequenceBinary(StackSequence.equal(), &result_lhs, &result_rhs);
            }
            while (token_operator.*.token == lex.TokenType.greater_than_sign) {}
            while (token_operator.*.token == lex.TokenType.less_than_sign) {}
            while (token_operator.*.token == lex.TokenType.greater_equal_to_sign) {}
            while (token_operator.*.token == lex.TokenType.less_equal_to_sign) {}
            while (token_operator.*.token == lex.TokenType.not_equal_to_sign) {}
        }
    }

    //concatenation &
    fn stage01(this: *@This()) ?lex.Token {
        _ = this;
    }

    //addition and subtraction +,-
    fn stage02(this: *@This()) ?lex.Token {
        _ = this;
    }

    //multiplication and division *,/
    fn stage03(this: *@This()) ?lex.Token {
        _ = this;
    }

    //exponentiation ^
    fn stage04(this: *@This()) ?lex.Token {
        _ = this;
    }

    //percent %
    fn stage05(this: *@This()) ?lex.Token {
        _ = this;
    }

    //negation -
    fn stage06(this: *@This()) ?lex.Token {
        _ = this;
    }

    //reference operators :,' ',,
    fn stage07(this: *@This()) ?lex.Token {
        _ = this;
    }

    //constant, sub section, formula
    fn stage08(this: *@This()) ?lex.Token {
        _ = this;
    }

    fn triggerStackSequenceBinary(this: *@This(), operator_function: StackSequence.OperatorFunction, lhs: *lex.Token, rhs: *lex.Token) void {
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

    fn triggerStackSequenceUnary(this: *@This(), operator_function: StackSequence.OperatorFunction, token: *lex.Token) void {
        _ = operator_function;

        if (token.* != null) {
            StackSequence.pushConstant(token);
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
};

const StackSequence = struct {
    const OperatorFunction = *const fn () void;

    fn pushConstant(token: *lex.Token) void {
        _ = token;
    }
    fn equal() void {}
    fn greaterThan() void {}
    fn lessThan() void {}
    fn greaterEqualThan() void {}
    fn lessEqualThan() void {}
    fn notEqualTo() void {}
};
