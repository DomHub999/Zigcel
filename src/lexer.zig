const std = @import("std");
const tok = @import("token.zig");
const tokz = @import("tokenizer.zig");
const Token = tok.Token;
const getNextToken = tokz.getNextToken;
const MAX_TOKEN_SIZE = tok.MAX_TOKEN_SIZE;
const TokenType = tok.TokenType;

const Errors = error{
    lexer_source_size_equals_null,
};

pub const Lexer = struct {
    const token_list_type = std.ArrayList(Token);
    token_list: token_list_type = undefined,
    current_token: usize = 0,

    pub fn init(this: *@This()) void {
        this.token_list = token_list_type.init(std.heap.page_allocator);
    }

    pub fn lex(this: *@This(), source: [*:0]const u8) !void {
        var current_position: ?usize = 0;
        const source_size = std.mem.len(source);
        if (source_size == 0) {
            return Errors.lexer_source_size_equals_null;
        }

        while (current_position) |pos| {
            const next_token_result = try getNextToken(source, pos, source_size);
            try this.token_list.append(next_token_result.token);
            current_position = next_token_result.new_current;
        }
        this.invalidateUnessecaryTokens();
    }

    pub fn drop(this: *@This()) void {
        this.token_list.deinit();
    }

    pub fn hasNext(this: *@This()) bool {
        this.skipToNextValidToken();
        if (this.current_token < this.token_list.items.len) {
            return true;
        }
        return false;
    }
    pub fn getNext(this: *@This()) ?*Token {
        if (!this.hasNext()) {
            return null;
        }

        const token = &this.token_list.items[this.current_token];
        this.current_token += 1;
        return token;
    }

    pub fn peek(this: *@This()) ?*Token {
        if (!this.hasNext()) {
            return null;
        }

        const token = &this.token_list.items[this.current_token];
        return token;
    }

    fn skipToNextValidToken(this: *@This()) void {
        while (this.current_token < this.token_list.items.len and this.token_list.items[this.current_token].valid_token == false) {
            this.current_token += 1;
        }
    }

    pub fn extractToken(token: *const [MAX_TOKEN_SIZE]u8) []const u8 {
        var index: usize = 0;

        while (token.*[index] != 0) : (index += 1) {}
        return token.*[0..index];
    }

    fn invalidateUnessecaryTokens(this: *@This()) void {
        for (this.token_list.items, 0..) |*reference, index| {
            if (reference.*.token_type == TokenType.space) {
                if (index == 0 or index == this.token_list.items.len - 1) {
                    reference.*.valid_token = false;
                    continue;
                }

                if (!(this.token_list.items[index - 1].token_type == TokenType.reference and this.token_list.items[index + 1].token_type == TokenType.reference)) {
                    reference.*.valid_token = false;
                }
            }
        }
    }
};

test "30*20" {
    var lexer = Lexer{};
    lexer.init();
    defer lexer.drop();

    const source = "30*20";
    try lexer.lex(source);

    var token = lexer.getNext().?;
    var token_slice = Lexer.extractToken(&token.token);
    var result = std.mem.eql(u8, token_slice, "30"[0..]);
    try std.testing.expect(result);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "*"[0..]);
    try std.testing.expect(result);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "20"[0..]);
    try std.testing.expect(result);
}

test "(50 * 40 )-20" {
    var lexer = Lexer{};
    lexer.init();
    defer lexer.drop();

    const source = "(50 * 40 )-20";
    try lexer.lex(source);

    var token = lexer.getNext().?;
    var token_slice = Lexer.extractToken(&token.token);
    var result = std.mem.eql(u8, token_slice, "("[0..]);
    try std.testing.expect(result);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "50"[0..]);
    try std.testing.expect(result);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "*"[0..]);
    try std.testing.expect(result);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "40"[0..]);
    try std.testing.expect(result);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, ")"[0..]);

    try std.testing.expect(result);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "-"[0..]);
    try std.testing.expect(result);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "20"[0..]);
    try std.testing.expect(result);
}

test "string" {
    var lexer = Lexer{};
    lexer.init();
    defer lexer.drop();

    const source = "\"wurst\"+";
    try lexer.lex(source);

    var token = lexer.getNext().?;
    var token_slice = Lexer.extractToken(&token.token);
    var result = std.mem.eql(u8, token_slice, "wurst"[0..]);
    try std.testing.expect(result);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "+"[0..]);
    try std.testing.expect(result);
}

test "reference" {
    var lexer = Lexer{};
    lexer.init();
    defer lexer.drop();

    const source = "A1,BB23,D4:EF567";
    try lexer.lex(source);

    var token = lexer.getNext().?;
    var token_slice = Lexer.extractToken(&token.token);
    var result = std.mem.eql(u8, token_slice, "A1"[0..]);
    try std.testing.expect(result);
    try std.testing.expect(token.token_type == TokenType.reference);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, ","[0..]);
    try std.testing.expect(result);
    try std.testing.expect(token.token_type == TokenType.argument_deliminiter);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "BB23"[0..]);
    try std.testing.expect(result);
    try std.testing.expect(token.token_type == TokenType.reference);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, ","[0..]);
    try std.testing.expect(result);
    try std.testing.expect(token.token_type == TokenType.argument_deliminiter);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "D4:EF567"[0..]);
    try std.testing.expect(result);
    try std.testing.expect(token.token_type == TokenType.range);
}

test "formula" {
    var lexer = Lexer{};
    lexer.init();
    defer lexer.drop();

    const source = "SUM(A1,B2)";
    try lexer.lex(source);

    var token = lexer.getNext().?;
    var token_slice = Lexer.extractToken(&token.token);
    try std.testing.expect(std.mem.eql(u8, token_slice, "SUM"[0..]));
    try std.testing.expect(token.token_type == TokenType.formula);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    try std.testing.expect(std.mem.eql(u8, token_slice, "("[0..]));
    try std.testing.expect(token.token_type == TokenType.bracket_open);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    try std.testing.expect(std.mem.eql(u8, token_slice, "A1"[0..]));
    try std.testing.expect(token.token_type == TokenType.reference);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    try std.testing.expect(std.mem.eql(u8, token_slice, ","[0..]));
    try std.testing.expect(token.token_type == TokenType.argument_deliminiter);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    try std.testing.expect(std.mem.eql(u8, token_slice, "B2"[0..]));
    try std.testing.expect(token.token_type == TokenType.reference);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    try std.testing.expect(std.mem.eql(u8, token_slice, ")"[0..]));
    try std.testing.expect(token.token_type == TokenType.bracket_close);

}
