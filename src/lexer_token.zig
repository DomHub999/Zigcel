const std = @import("std");

const Errors = error{
    token_exceeds_max_token_size,
};

pub const MAX_TOKEN_SIZE: usize = 20;

pub const token_list_type = std.ArrayList(LexerToken);

pub const ARGUMENT_DELIMINITER: u8 = ',';

pub const TokenType = enum {
    plus,
    minus,
    asterisk,
    forward_slash,
    percent_sign,
    caret,
    bracket_open,
    bracket_close,
    constant,

    equal_sign,
    greater_than_sign,
    less_than_sign,
    greater_equal_to_sign,
    less_equal_to_sign,
    not_equal_to_sign,

    ampersand,
    colon, //may be deleted if only present in ranges
    argument_deliminiter,
    space,
    pound,
    at,

    formula,
    reference,
    range,

    string,
};

pub const LexerToken = struct {
    current_chara_num: usize = 0,
    token: [MAX_TOKEN_SIZE]u8 = [_]u8{0} ** MAX_TOKEN_SIZE, //for debugging purposes
    token_type: TokenType = undefined,
    valid_token: bool = true,

    pub fn insertCharacterAndTokenType(this: *@This(), character: u8, ttype: TokenType) !void {
        this.insertTokenType(ttype);
        try this.insertCharacter(character);
    }

    pub fn insertCharacter(this: *@This(), character: u8) !void {
        if (this.current_chara_num + 1 == MAX_TOKEN_SIZE) {
            return Errors.token_exceeds_max_token_size;
        }
        this.token[this.current_chara_num] = character;
        this.current_chara_num += 1;
    }

    pub fn insertTokenType(this: *@This(), ttype: TokenType) void {
        this.token_type = ttype;
    }
};

pub fn extractToken(token: *const [MAX_TOKEN_SIZE]u8) []const u8 {
    var index: usize = 0;

    while (token.*[index] != 0) : (index += 1) {}
    return token.*[0..index];
}

pub const TokenListIterator = struct {
    token_list: token_list_type,
    current_token: usize = 0,

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

    pub fn getNext(this: *@This()) ?*LexerToken {
        if (!this.hasNext()) {
            return null;
        }

        const token = &this.token_list.items[this.current_token];
        this.current_token += 1;
        return token;
    }

    pub fn peek(this: *@This()) ?*LexerToken {
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

    pub fn makeTokenListIterator(token_list: token_list_type) @This() {
        return @This(){ .token_list = token_list };
    }
};
