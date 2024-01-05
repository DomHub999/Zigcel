const LexerToken = @import("lexer_token.zig").LexerToken;
const TokenType = @import("lexer_token.zig").TokenType;
const ARGUMENT_DELIMINITER = @import("lexer_token.zig").ARGUMENT_DELIMINITER;

const Errors = error{
    tokenizer_character_not_defined,
    tokenizer_unexpected_character,
    tokenizer_token_type_cannot_be_determined,
};

pub fn getNextToken(source: [*:0]const u8, current: usize, source_size: usize) !struct { token: LexerToken, new_current: ?usize } {
    var this_current = current;
    var current_character = source[this_current];
    const rule = getRule(current_character);
    var token = LexerToken{};

    switch (rule) {
        RuleType.single_character => {
            try token.insertCharacterAndTokenType(current_character, rule.single_character.token_type);
        },

        RuleType.multiple_characters => {
            while (this_current < source_size) : (this_current += 1) {
                current_character = source[this_current];

                //there are two rules to break a sequence
                //the end of sequence rule, which may check for a specific logic...
                if (rule.multiple_characters.eoseq_det) |end_of_sequence_det| {
                    const end_of_sequence = end_of_sequence_det(source, current, this_current, source_size);
                    //after this switch, the this_current cursor must point to the last character of a token (sub)string, this may also be a terminating character like "
                    if (end_of_sequence) {
                        break;
                    }
                }

                //...or if the subsequent character is not part of a defined range which belongs to a token type
                const in_chara_range = characterInCharaRange(rule.multiple_characters.subs_characters, current_character);
                //after this switch, the this_current cursor must point to the last character of a token (sub)string
                //because whe have advanced one character before realising that the token string has ended, we need to decrement the cursor by one
                if (!in_chara_range) {
                    this_current -= 1;
                    break;
                }

                //filters out characters which are there for syntactical reasons but do not actually belong to a token
                if (rule.multiple_characters.chara_trans_det) |chara_transfer_determinator| {
                    const transfer_character = chara_transfer_determinator(source, current, this_current, source_size);
                    if (transfer_character) {
                        try token.insertCharacter(current_character);
                    }
                } else {
                    try token.insertCharacter(current_character);
                }
            }

            const last_character = if (this_current >= source_size) this_current - 1 else this_current;
            const token_type = try rule.multiple_characters.token_type_det(source, current, last_character, source_size);

            token.insertTokenType(token_type);
        },

        RuleType.not_defined => {
            return Errors.tokenizer_character_not_defined;
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
    tmp_rule_table[ARGUMENT_DELIMINITER] = Rule{ .single_character = .{ .token_type = TokenType.argument_deliminiter } };

    tmp_rule_table['>'] = Rule{ .multiple_characters = .{ .subs_characters = &greater_than_r, .token_type_det = greater_than_f } };
    tmp_rule_table['<'] = Rule{ .multiple_characters = .{ .subs_characters = &smaller_than_r, .token_type_det = smaller_than_f } };
    tmp_rule_table[' '] = Rule{ .multiple_characters = .{ .subs_characters = &space_r, .token_type_det = space_f } };
    tmp_rule_table['"'] = Rule{ .multiple_characters = .{ .subs_characters = &double_quotes_r, .token_type_det = double_quotes_f, .eoseq_det = double_quotes_e, .chara_trans_det = double_quotes_t } };

    var num_chara: u8 = '0';
    inline while (num_chara <= '9') : (num_chara += 1) {
        tmp_rule_table[num_chara] = Rule{ .multiple_characters = .{ .subs_characters = &zero_to_nine_r, .token_type_det = zero_to_nine_f } };
    }

    var capital_letter: u8 = 'A';
    inline while (capital_letter <= 'Z') : (capital_letter += 1) {
        tmp_rule_table[capital_letter] = Rule{ .multiple_characters = .{ .subs_characters = &alphabet_r, .token_type_det = alphabet_f } };
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
        else => return Errors.tokenizer_unexpected_character,
    }
}

fn smaller_than_f(source: [*:0]const u8, start: usize, current: usize, source_size: usize) Errors!TokenType {
    _ = source_size;
    _ = start;

    const last_character_index = current - 1;

    switch (source[last_character_index]) {
        '<' => return TokenType.less_than_sign,
        '=' => return TokenType.less_equal_to_sign,
        '>' => return TokenType.not_equal_to_sign,
        else => return Errors.tokenizer_unexpected_character,
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
    const debug = source[current];
    _ = debug;

    switch (source[current]) {
        '0'...'9' => {
            if ((current + 1) < source_size) {
                if (source[current + 1] == '(') {
                    return TokenType.formula;
                }
            }
            var idx: usize = start;
            while (idx <= current) : (idx += 1) {
                if (source[idx] == ':') {
                    return TokenType.range;
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
            return Errors.tokenizer_token_type_cannot_be_determined;
        },
    }
    return Errors.tokenizer_token_type_cannot_be_determined;
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
    CharaRange{ .single = .{ .low = ':' } },
    CharaRange{ .range = .{ .low = 'A', .high = 'Z' } },
    CharaRange{ .range = .{ .low = '0', .high = '9' } },
};

const double_quotes_r = [_]CharaRange{
    CharaRange{ .range = .{ .low = '!', .high = '~' } },
};
