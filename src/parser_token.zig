const LexerToken = @import("lexer_token.zig").LexerToken;
const MAX_TOKEN_SIZE = @import("lexer_token.zig").MAX_TOKEN_SIZE;
const TokenType = @import("lexer_token.zig").TokenType;
const DataType = @import("lexer_token.zig").DataType;

const InstructionSequence = @import("instruction_sequence.zig").InstructionSequence;
const Instructions = @import("instruction_sequence.zig").Instructions;

const Errors = error{
    parser_token_no_payload_exceeded_max,
};

const NUMBER_OF_PAYLOADS: usize = 10;
pub const ParserToken = struct {
    token: [MAX_TOKEN_SIZE]u8 = [_]u8{0} ** MAX_TOKEN_SIZE, //for debugging purposes
    token_type: TokenType = undefined,
    payload: [NUMBER_OF_PAYLOADS]?Instructions = [_]?Instructions{null} ** NUMBER_OF_PAYLOADS,
    idx_payload: usize = 0,
    data_type: ?DataType = null,

    pub fn createParserTokenFromLexTok(lexer_token: *const LexerToken) @This() {
        const parser_token = ParserToken{ .token = lexer_token.token, .token_type = lexer_token.token_type, .data_type = lexer_token.data_type };
        return parser_token;
    }

    pub fn copyAttributesFromLexTok(this: *@This(), lexer_token: *LexerToken) void {
        this.token = lexer_token.token;
        this.token_type = lexer_token.token_type;
        this.data_type = lexer_token.data_type;
    }

    pub fn pushBackPayload(this: *@This(), inststruction: Instructions) !void {
        if (this.idx_payload >= NUMBER_OF_PAYLOADS) {
            return Errors.parser_token_no_payload_exceeded_max;
        }

        this.payload[this.idx_payload] = inststruction;
        this.idx_payload += 1;
    }
};
