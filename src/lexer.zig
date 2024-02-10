const std = @import("std");

const token_list_type = @import("lexer_token.zig").token_list_type;
const TokenType = @import("lexer_token.zig").TokenType;
const extractToken = @import("lexer_token.zig").extractToken;
const makeTokenListIterator = @import("lexer_token.zig").TokenListIterator.makeTokenListIterator;
const LexerToken = @import("lexer_token.zig").LexerToken;
const getCurrentTokenBuffer = @import("lexer_token.zig").getCurrentTokenBuffer;

const getNextToken = @import("tokenizer.zig").getNextToken;

const ReferenceList = @import("range_unwrap.zig").ReferenceList;
const unwrapRange = @import("range_unwrap.zig").unwrapRange;
const REFERENCE_SIZE = @import("range_unwrap.zig").REFERENCE_SIZE;

const Function = @import("functions.zig").Function;

const Errors = error{
    lexer_source_size_equals_null,
};

pub fn lex(source: [*:0]const u8, string_pool: *std.heap.ArenaAllocator) !token_list_type {
    var token_list = token_list_type.init(std.heap.page_allocator);

    var current_position: ?usize = 0;
    const source_size = std.mem.len(source);
    if (source_size == 0) {
        return Errors.lexer_source_size_equals_null;
    }

    while (current_position) |pos| {
        
        var next_token_result = try getNextToken(source, pos, source_size);
        const token_buffer = getCurrentTokenBuffer();
        
        const referece_list = try dealWithRange(&next_token_result.token, token_buffer);
        
        if (referece_list) |list| {
            for (list.items) |reference| {
                var token = LexerToken{ .token_type = TokenType.reference };
                try token.insertCharacterString(reference[0..]);
                try token.extractDataType(string_pool);
                try token_list.append(token);
            }
            list.deinit();
        } else {
            try next_token_result.token.extractDataType(string_pool);
            try token_list.append(next_token_result.token);
        }

        current_position = next_token_result.new_current;
    }
    invalidateUnessecaryTokens(&token_list);

    return token_list;
}

fn dealWithRange(lexer_token: *const LexerToken, token_buffer:[]const u8) !?ReferenceList {
    if (lexer_token.token_type == TokenType.range) {
        return try unwrapRange(token_buffer);
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
var string_pool =  std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();

    const token_list = try lex("30*20", &string_pool);
    defer token_list.deinit();

    try std.testing.expect(token_list.items[0].data_type.?.number == 30);
    try std.testing.expect(token_list.items[1].token_type == TokenType.asterisk);
    try std.testing.expect(token_list.items[2].data_type.?.number == 20);

}

test "(50 * 40 )-20" {
    const source = "(50 * 40 )-20";
    
    var string_pool =  std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();
    
    const token_list = try lex(source, &string_pool);
    var token_list_iterator = makeTokenListIterator(token_list);
    defer token_list_iterator.drop();

    var token = token_list_iterator.getNext().?;
    try std.testing.expect(token.token_type == TokenType.bracket_open);

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.data_type.?.number == 50);

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.token_type == TokenType.asterisk);

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.data_type.?.number == 40);

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.token_type == TokenType.bracket_close);

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.token_type == TokenType.minus);

        token = token_list_iterator.getNext().?;
    try std.testing.expect(token.data_type.?.number == 20);
}

test "string" {
    const source = "\"wurst\"+";

    var string_pool =  std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();

    const token_list = try lex(source, &string_pool);
    var token_list_iterator = makeTokenListIterator(token_list);
    defer token_list_iterator.drop();

    var token = token_list_iterator.getNext().?;
    try std.testing.expect(std.mem.eql(u8, token.data_type.?.string, "wurst"[0..]));

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.token_type == TokenType.plus);
}

test "reference" {
    const source = "A1,BB23,A100:B101";

    var string_pool =  std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();

    const token_list = try lex(source, &string_pool);
    var token_list_iterator = makeTokenListIterator(token_list);
    defer token_list_iterator.drop();

    var token = token_list_iterator.getNext().?;
    try std.testing.expect(token.data_type.?.reference.column == 1);
    try std.testing.expect(token.data_type.?.reference.row == 1);

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.token_type == TokenType.argument_deliminiter);

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.data_type.?.reference.column == 54);
    try std.testing.expect(token.data_type.?.reference.row == 23);

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.token_type == TokenType.argument_deliminiter);

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.data_type.?.reference.column == 1);
    try std.testing.expect(token.data_type.?.reference.row == 100);

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.data_type.?.reference.column == 1);
    try std.testing.expect(token.data_type.?.reference.row == 101);

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.data_type.?.reference.column == 2);
    try std.testing.expect(token.data_type.?.reference.row == 100);

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.data_type.?.reference.column == 2);
    try std.testing.expect(token.data_type.?.reference.row == 101);
}

test "formula" {
    const source = "SUM(A1,B2)";

    var string_pool =  std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer string_pool.deinit();

    const token_list = try lex(source, &string_pool);
    var token_list_iterator = makeTokenListIterator(token_list);
    defer token_list_iterator.drop();

    var token = token_list_iterator.getNext().?;
    try std.testing.expect(token.data_type.?.function == Function.sum);

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.token_type == TokenType.bracket_open);

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.data_type.?.reference.column == 1);
    try std.testing.expect(token.data_type.?.reference.row == 1);

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.token_type == TokenType.argument_deliminiter);

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.data_type.?.reference.column == 2);
    try std.testing.expect(token.data_type.?.reference.row == 2);

    token = token_list_iterator.getNext().?;
    try std.testing.expect(token.token_type == TokenType.bracket_close);
}
