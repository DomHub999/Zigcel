const std = @import("std");
const tok = @import("token.zig");
const Token = tok.Token;
const MAX_TOKEN_SIZE = tok.MAX_TOKEN_SIZE;
const TokenType = tok.TokenType;


const Errors = error{
    character_nod_defined,
    token_type_cannot_be_determined,
    source_size_equals_null,
    unexpected_character,
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
            return Errors.source_size_equals_null;
        }

        while (current_position) |pos| {
            const next_token_result = try TokenExtraction.getNextToken(source, pos, source_size);
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



pub const TokenExtraction = struct {
    fn getNextToken(source: [*:0]const u8, current: usize, source_size: usize) !struct { token: Token, new_current: ?usize } {
        var this_current = current;
        var current_character = source[this_current];
        const rule = TokenExtraction.getRule(current_character);
        var token = Token{};

        switch (rule) {
            RuleType.single_character => {
                try token.insertCharacterAndTokenType(current_character, rule.single_character.token_type);
            },

            RuleType.multiple_characters => {
                while (this_current < source_size) : (this_current += 1) {
                    current_character = source[this_current];

                    if (rule.multiple_characters.eoseq_det) |end_of_sequence_det| {
                        const end_of_sequence = end_of_sequence_det(source, current, this_current, source_size);
                        if (end_of_sequence) {
                            break;
                        }
                    }

                    const in_chara_range = characterInCharaRange(rule.multiple_characters.subs_characters, current_character);
                    if (!in_chara_range) {
                        this_current -= 1;
                        break;
                    }

                    if (rule.multiple_characters.chara_trans_det) |chara_transfer_determinator| {
                        const transfer_character = chara_transfer_determinator(source, current, this_current, source_size);
                        if (transfer_character) {
                            try token.insertCharacter(current_character);
                        }
                    } else {
                        try token.insertCharacter(current_character);
                    }
                }
                const token_type = try rule.multiple_characters.token_type_det(source, current, this_current, source_size);

                token.insertTokenType(token_type);
            },

            RuleType.not_defined => {
                return Errors.character_nod_defined;
            },
        }

        var new_current: ?usize = null;
        if ((this_current + 1) < source_size) {
            new_current = this_current + 1;
        }
        return .{ .token = token, .new_current = new_current };
    }

    const TokenTypeDet = *const fn (source: [*:0]const u8, start: usize, current: usize, source_size: usize) Errors!TokenType;
    const EndOfSeqDet = *const fn (source: [*:0]const u8, start: usize, current: usize, source_size: usize) bool;
    const CharacterTransferDet = *const fn (source: [*:0]const u8, start: usize, current: usize, source_size: usize) bool;

    const RuleType = enum {
        single_character,
        multiple_characters,
        not_defined,
    };
    const Rule = union(RuleType) {
        single_character: struct {
            token_type: TokenType,
        },
        multiple_characters: struct {
            subs_characters: []const CharaRange,
            token_type_det: TokenTypeDet,
            eoseq_det: ?EndOfSeqDet = null,
            chara_trans_det: ?CharacterTransferDet = null,
        },
        not_defined: bool,
    };

    const Option = enum { single, range };
    const CharaRange = union(Option) {
        single: struct {
            low: u8,
        },
        range: struct {
            low: u8,
            high: u8,
        },
    };

    const rule_table = makeRuleTable();

    fn makeRuleTable() [255]Rule {
        var tmp_rule_table = [_]Rule{Rule{ .not_defined = true }} ** 255;
        tmp_rule_table['+'] = Rule{ .single_character = .{ .token_type = TokenType.plus } };
        tmp_rule_table['-'] = Rule{ .single_character = .{ .token_type = TokenType.minus } };
        tmp_rule_table['*'] = Rule{ .single_character = .{ .token_type = TokenType.asterisk } };
        tmp_rule_table['/'] = Rule{ .single_character = .{ .token_type = TokenType.forward_slash } };
        tmp_rule_table['%'] = Rule{ .single_character = .{ .token_type = TokenType.percent_sign } };
        tmp_rule_table['^'] = Rule{ .single_character = .{ .token_type = TokenType.caret } };
        tmp_rule_table['('] = Rule{ .single_character = .{ .token_type = TokenType.bracket_open } };
        tmp_rule_table[')'] = Rule{ .single_character = .{ .token_type = TokenType.bracket_close } };
        tmp_rule_table['='] = Rule{ .single_character = .{ .token_type = TokenType.equal_sign } };
        tmp_rule_table['&'] = Rule{ .single_character = .{ .token_type = TokenType.ampersand } };
        tmp_rule_table[':'] = Rule{ .single_character = .{ .token_type = TokenType.colon } };
        tmp_rule_table[':'] = Rule{ .single_character = .{ .token_type = TokenType.comma } };

        tmp_rule_table['>'] = Rule{ .multiple_characters = .{ .subs_characters = &greater_than_r, .token_type_det = greater_than_f } };
        tmp_rule_table['<'] = Rule{ .multiple_characters = .{ .subs_characters = &smaller_than_r, .token_type_det = smaller_than_f } };
        tmp_rule_table[' '] = Rule{ .multiple_characters = .{ .subs_characters = &space_r, .token_type_det = space_f } };
        tmp_rule_table['"'] = Rule{ .multiple_characters = .{ .subs_characters = &double_quotes_r, .token_type_det = double_quotes_f, .eoseq_det = double_quotes_e, .chara_trans_det = double_quotes_t } };

        inline for ('0'..'9') |value| {
            tmp_rule_table[value] = Rule{ .multiple_characters = .{ .subs_characters = &zero_to_nine_r, .token_type_det = zero_to_nine_f } };
        }

        inline for ('A'..'Z') |value| {
            tmp_rule_table[value] = Rule{ .multiple_characters = .{ .subs_characters = &alphabet_r, .token_type_det = alphabet_f } };
        }
        return tmp_rule_table;
    }

    fn getRule(character: u8) Rule {
        return rule_table[character];
    }

    fn characterInCharaRange(subs_characters: []const CharaRange, character: u8) bool {
        for (subs_characters) |value| {
            switch (value) {
                Option.single => {
                    if (character == value.single.low) {
                        return true;
                    }
                },

                Option.range => {
                    if (character >= value.range.low and character <= value.range.high) {
                        return true;
                    }
                },
            }
        }
        return false;
    }

    //token type determinators
    fn zero_to_nine_f(source: [*:0]const u8, start: usize, current: usize, source_size: usize) Errors!TokenType {
        _ = source_size;
        _ = current;
        _ = start;
        _ = source;

        return TokenType.constant;
    }

    fn greater_than_f(source: [*:0]const u8, start: usize, current: usize, source_size: usize) Errors!TokenType {
        _ = source_size;
        _ = start;

        switch (source[current]) {
            '>' => return TokenType.greater_than_sign,
            '=' => return TokenType.greater_equal_to_sign,
            else => return Errors.unexpected_character,
        }
    }

    fn smaller_than_f(source: [*:0]const u8, start: usize, current: usize, source_size: usize) Errors!TokenType {
        _ = source_size;
        _ = start;

        switch (source[current]) {
            '<' => return TokenType.less_than_sign,
            '=' => return TokenType.less_equal_to_sign,
            '>' => return TokenType.not_equal_to_sign,
            else => return Errors.unexpected_character,
        }
    }

    fn space_f(source: [*:0]const u8, start: usize, current: usize, source_size: usize) Errors!TokenType {
        _ = source_size;
        _ = current;
        _ = start;
        _ = source;

        return TokenType.space;
    }

    fn alphabet_f(source: [*:0]const u8, start: usize, current: usize, source_size: usize) Errors!TokenType {
        _ = start;

        switch (source[current]) {
            '0'...'9' => {
                if ((current + 1) < source_size) {
                    if (source[current + 1] == '(') {
                        return TokenType.formula;
                    }
                }
                return TokenType.reference;
            },
            'A'...'Z' => {
                if ((current + 1) < source_size) {
                    if (source[current + 1] == '(') {
                        return TokenType.formula;
                    }
                }
            },

            else => {
                return Errors.token_type_cannot_be_determined;
            },
        }
        return Errors.token_type_cannot_be_determined;
    }

    fn double_quotes_f(source: [*:0]const u8, start: usize, current: usize, source_size: usize) Errors!TokenType {
        _ = source_size;
        _ = current;
        _ = start;
        _ = source;

        return TokenType.string;
    }

    //end of sequence determinators
    fn double_quotes_e(source: [*:0]const u8, start: usize, current: usize, source_size: usize) bool {
        _ = source_size;
        if (source[current] == '"' and current > start) {
            return true;
        }
        return false;
    }

    //character transfer determinators
    fn double_quotes_t(source: [*:0]const u8, start: usize, current: usize, source_size: usize) bool {
        _ = source_size;
        _ = start;
        if (source[current] == '"') {
            return false;
        }
        return true;
    }

    //character ranges
    const zero_to_nine_r = [_]CharaRange{
        CharaRange{ .range = .{ .low = '0', .high = '9' } },
        CharaRange{ .single = .{ .low = '.' } },
    };

    const greater_than_r = [_]CharaRange{
        CharaRange{ .single = .{ .low = '=' } },
    };

    const smaller_than_r = [_]CharaRange{
        CharaRange{ .single = .{ .low = '=' } },
        CharaRange{ .single = .{ .low = '>' } },
    };

    const space_r = [_]CharaRange{
        CharaRange{ .single = .{ .low = ' ' } },
    };

    const alphabet_r = [_]CharaRange{
        CharaRange{ .range = .{ .low = 'A', .high = 'Z' } },
        CharaRange{ .range = .{ .low = '0', .high = '9' } },
    };

    const double_quotes_r = [_]CharaRange{
        CharaRange{ .range = .{ .low = '!', .high = '~' } },
    };
};

test "30*20" {
    var lexer = Lexer{};
    lexer.init();

    const source = "30*20";
    try lexer.lex(source);

    var token = lexer.getNext().?;
    var token_slice = Lexer.extractToken(&token.token);
    var result_1 = std.mem.eql(u8, token_slice, "30"[0..]);
    try std.testing.expect(result_1);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    var result_2 = std.mem.eql(u8, token_slice, "*"[0..]);
    try std.testing.expect(result_2);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    var result_3 = std.mem.eql(u8, token_slice, "20"[0..]);
    try std.testing.expect(result_3);
}

test "(50 * 40 )-20" {
    var lexer = Lexer{};
    lexer.init();

    const source = "(50 * 40 )-20";
    try lexer.lex(source);

    var token = lexer.getNext().?;
    var token_slice = Lexer.extractToken(&token.token);
    var result_1 = std.mem.eql(u8, token_slice, "("[0..]);
    try std.testing.expect(result_1);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    var result_2 = std.mem.eql(u8, token_slice, "50"[0..]);
    try std.testing.expect(result_2);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    var result_3 = std.mem.eql(u8, token_slice, "*"[0..]);
    try std.testing.expect(result_3);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    var result_4 = std.mem.eql(u8, token_slice, "40"[0..]);
    try std.testing.expect(result_4);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    var result_5 = std.mem.eql(u8, token_slice, ")"[0..]);
    try std.testing.expect(result_5);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    var result_6 = std.mem.eql(u8, token_slice, "-"[0..]);
    try std.testing.expect(result_6);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    var result_7 = std.mem.eql(u8, token_slice, "20"[0..]);
    try std.testing.expect(result_7);
}

test "string" {
    var lexer = Lexer{};
    lexer.init();

    const source = "\"wurst\"+";
    try lexer.lex(source);

    var token = lexer.getNext().?;
    var token_slice = Lexer.extractToken(&token.token);
    var result_1 = std.mem.eql(u8, token_slice, "wurst"[0..]);
    try std.testing.expect(result_1);

    token = lexer.getNext().?;
    token_slice = Lexer.extractToken(&token.token);
    var result_2 = std.mem.eql(u8, token_slice, "+"[0..]);
    try std.testing.expect(result_2);
}
