const std = @import("std");

const token_list_type = @import("lexer_token.zig").token_list_type;
const TokenType = @import("lexer_token.zig").TokenType;
const extractToken = @import("lexer_token.zig").extractToken;
const makeTokenListIterator = @import("lexer_token.zig").TokenListIterator.makeTokenListIterator;
const LexerToken = @import("lexer_token.zig").LexerToken;

const getNextToken = @import("tokenizer.zig").getNextToken;

const ReferenceList = @import("range_unwrap.zig").ReferenceList;
const unwrapRange = @import("range_unwrap.zig").unwrapRange;
const REFERENCE_SIZE = @import("range_unwrap.zig").REFERENCE_SIZE;

const Errors = error{
    lexer_source_size_equals_null,
};

pub fn lex(source: [*:0]const u8) !token_list_type {
    var token_list = token_list_type.init(std.heap.page_allocator);

    var current_position: ?usize = 0;
    const source_size = std.mem.len(source);
    if (source_size == 0) {
        return Errors.lexer_source_size_equals_null;
    }

    while (current_position) |pos| {
        const next_token_result = try getNextToken(source, pos, source_size);
        const referece_list = try dealWithRange(&next_token_result.token);
        if (referece_list) |list| {
            for (list.items) |reference| {
                var token = LexerToken{ .token_type = TokenType.reference };
                @memcpy(token.token[0..REFERENCE_SIZE], reference[0..]);
                try token_list.append(token);
            }
            list.deinit();
        } else {
            try token_list.append(next_token_result.token);
        }

        current_position = next_token_result.new_current;
    }
    invalidateUnessecaryTokens(&token_list);

    return token_list;
}

fn dealWithRange(lexer_token: *const LexerToken) !?ReferenceList {
    if (lexer_token.token_type == TokenType.range) {
        return try unwrapRange(&lexer_token.token);
    }
    return null;
}

fn invalidateUnessecaryTokens(token_list: *token_list_type) void {
    for (token_list.items, 0..) |*reference, index| {
        if (reference.*.token_type == TokenType.space) {
            if (index == 0 or index == token_list.items.len - 1) {
                reference.*.valid_token = false;
                continue;
            }

            if (!(token_list.items[index - 1].token_type == TokenType.reference and token_list.items[index + 1].token_type == TokenType.reference)) {
                reference.*.valid_token = false;
            }
        }
    }
}

test "30*20" {
    const token_list = try lex("30*20");
    defer token_list.deinit();

    try std.testing.expect(std.mem.eql(u8, extractToken(&token_list.items[0].token), "30"[0..]));
    try std.testing.expect(std.mem.eql(u8, extractToken(&token_list.items[1].token), "*"[0..]));
    try std.testing.expect(std.mem.eql(u8, extractToken(&token_list.items[2].token), "20"[0..]));
}

test "(50 * 40 )-20" {
    const source = "(50 * 40 )-20";

    const token_list = try lex(source);
    var token_list_iterator = makeTokenListIterator(token_list);
    defer token_list_iterator.drop();

    var token = token_list_iterator.getNext().?;
    var token_slice = extractToken(&token.token);
    var result = std.mem.eql(u8, token_slice, "("[0..]);
    try std.testing.expect(result);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "50"[0..]);
    try std.testing.expect(result);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "*"[0..]);
    try std.testing.expect(result);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "40"[0..]);
    try std.testing.expect(result);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, ")"[0..]);
    try std.testing.expect(result);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "-"[0..]);
    try std.testing.expect(result);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "20"[0..]);
    try std.testing.expect(result);
}

test "string" {
    const source = "\"wurst\"+";
    const token_list = try lex(source);
    var token_list_iterator = makeTokenListIterator(token_list);
    defer token_list_iterator.drop();

    var token = token_list_iterator.getNext().?;
    var token_slice = extractToken(&token.token);
    var result = std.mem.eql(u8, token_slice, "wurst"[0..]);
    try std.testing.expect(result);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "+"[0..]);
    try std.testing.expect(result);
}

test "reference" {
    const source = "A1,BB23,A100:B101";
    const token_list = try lex(source);
    var token_list_iterator = makeTokenListIterator(token_list);
    defer token_list_iterator.drop();

    var token = token_list_iterator.getNext().?;
    var token_slice = extractToken(&token.token);
    var result = std.mem.eql(u8, token_slice, "A1"[0..]);
    try std.testing.expect(result);
    try std.testing.expect(token.token_type == TokenType.reference);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, ","[0..]);
    try std.testing.expect(result);
    try std.testing.expect(token.token_type == TokenType.argument_deliminiter);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "BB23"[0..]);
    try std.testing.expect(result);
    try std.testing.expect(token.token_type == TokenType.reference);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, ","[0..]);
    try std.testing.expect(result);
    try std.testing.expect(token.token_type == TokenType.argument_deliminiter);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "A100"[0..]);
    try std.testing.expect(result);
    try std.testing.expect(token.token_type == TokenType.reference);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "A101"[0..]);
    try std.testing.expect(result);
    try std.testing.expect(token.token_type == TokenType.reference);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "B100"[0..]);
    try std.testing.expect(result);
    try std.testing.expect(token.token_type == TokenType.reference);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    result = std.mem.eql(u8, token_slice, "B101"[0..]);
    try std.testing.expect(result);
    try std.testing.expect(token.token_type == TokenType.reference);
}

test "formula" {
    const source = "SUM(A1,B2)";
    const token_list = try lex(source);
    var token_list_iterator = makeTokenListIterator(token_list);
    defer token_list_iterator.drop();

    var token = token_list_iterator.getNext().?;
    var token_slice = extractToken(&token.token);
    try std.testing.expect(std.mem.eql(u8, token_slice, "SUM"[0..]));
    try std.testing.expect(token.token_type == TokenType.function);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    try std.testing.expect(std.mem.eql(u8, token_slice, "("[0..]));
    try std.testing.expect(token.token_type == TokenType.bracket_open);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    try std.testing.expect(std.mem.eql(u8, token_slice, "A1"[0..]));
    try std.testing.expect(token.token_type == TokenType.reference);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    try std.testing.expect(std.mem.eql(u8, token_slice, ","[0..]));
    try std.testing.expect(token.token_type == TokenType.argument_deliminiter);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    try std.testing.expect(std.mem.eql(u8, token_slice, "B2"[0..]));
    try std.testing.expect(token.token_type == TokenType.reference);

    token = token_list_iterator.getNext().?;
    token_slice = extractToken(&token.token);
    try std.testing.expect(std.mem.eql(u8, token_slice, ")"[0..]));
    try std.testing.expect(token.token_type == TokenType.bracket_close);
}
