const std = @import("std");
const Function = @import("functions.zig").Function;

const ROW_CHARACTERS = @import("range_unwrap.zig").ROW_CHARACTERS;
const numberFromCol = @import("range_unwrap.zig").numberFromCol;

const getFunction = @import("functions.zig").getFunction;

const Errors = error{
    token_exceeds_max_buffer_size,
    lexer_token_corrupt_reference,
    lexer_token_data_type_cannot_be_created,
};

pub const MAX_TOKEN_SIZE: usize = 20;
const MAX_BUFFER_SIZE: usize = 1024;

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

    constant,
    function,
    reference,
    range,
    boolean,
    string,
};

pub const DataTypes = enum {
    number,
    string,
    boolean,
    reference,
    function,
    u_int,
};

pub const DataType = union(DataTypes) {
    number: f64,
    string: []const u8,
    boolean: bool,
    reference: struct { row: usize, column: usize }, //to be implemented
    function: Function,
    u_int: usize,
};

var buffer: [MAX_BUFFER_SIZE]u8 = [_]u8{0} ** MAX_BUFFER_SIZE;
fn initializeBuffer() void {
    buffer = [_]u8{0} ** MAX_BUFFER_SIZE;
}

pub const LexerToken = struct {
    current_chara_num: usize = 0,
    token: [MAX_TOKEN_SIZE]u8 = [_]u8{0} ** MAX_TOKEN_SIZE, //for debugging purposes
    token_type: TokenType = undefined,
    valid_token: bool = true,
    data_type: ?DataType = null,

    pub fn insertCharacterAndTokenType(this: *@This(), character: u8, ttype: TokenType) !void {
        this.insertTokenType(ttype);
        try this.insertCharacter(character);
    }

    pub fn insertCharacter(this: *@This(), character: u8) !void {
        if (this.current_chara_num + 1 == MAX_BUFFER_SIZE) {
            return Errors.token_exceeds_max_buffer_size;
        }

        if (this.current_chara_num == 0) {
            initializeBuffer();
        }

        if (this.current_chara_num <= MAX_TOKEN_SIZE) {
            this.token[this.current_chara_num] = character;
        }

        buffer[this.current_chara_num] = character;

        this.current_chara_num += 1;
    }

    pub fn insertCharacterString(this: *@This(), character_string: []const u8)!void{
        for (character_string) |character| {
            try this.insertCharacter(character);
        }
    }

    pub fn insertTokenType(this: *@This(), ttype: TokenType) void {
        this.token_type = ttype;
    }

    pub fn extractDataType(this: *@This(), string_pool: *std.heap.ArenaAllocator) !void {
        const data_type = getDataType(this.token_type);
        const slice_of_token = extractToken(&this.token);
        if (data_type) |d_type| {
            switch (d_type) {
                DataTypes.number => {
                    const number: f64 = try std.fmt.parseFloat(f64, slice_of_token);
                    this.data_type = DataType{ .number = number };
                },
                DataTypes.string => {
                        const string_size = this.current_chara_num;
                        var string = try string_pool.allocator().alloc(u8, string_size);
                        @memcpy(string[0..string_size], buffer[0..string_size]);
                        this.data_type = DataType{.string = string};
                },
                DataTypes.boolean => {
                    const bool_value = std.mem.eql(u8, slice_of_token, "TRUE"[0..]);
                    this.data_type = DataType{ .boolean = bool_value };
                },
                DataTypes.reference => {
                    const row_idx = std.mem.indexOfAny(u8, slice_of_token, ROW_CHARACTERS) orelse return Errors.lexer_token_corrupt_reference;
                    const row = try std.fmt.parseInt(usize, slice_of_token[row_idx..], 0);
                    const col = numberFromCol(slice_of_token[0..row_idx], row_idx);
                    this.data_type = DataType{ .reference = .{ .row = row, .column = col } };
                },
                DataTypes.function => {
                    const function = try getFunction(slice_of_token);
                    this.data_type = DataType{ .function = function };
                },
                DataTypes.u_int => {
                    //cannot be created on lexer level
                    return Errors.lexer_token_data_type_cannot_be_created;
                }
            }
        }
    }
};

const token_type_data_type_mapping = makeTokenTypeDataTypeMapping();

fn makeTokenTypeDataTypeMapping() [@typeInfo(TokenType).Enum.fields.len]?DataTypes {
    var mapping = [_]?DataTypes{null} ** @typeInfo(TokenType).Enum.fields.len;
    mapping[@intFromEnum(TokenType.constant)] = DataTypes.number;
    mapping[@intFromEnum(TokenType.string)] = DataTypes.string;
    mapping[@intFromEnum(TokenType.boolean)] = DataTypes.boolean;
    mapping[@intFromEnum(TokenType.reference)] = DataTypes.reference;
    mapping[@intFromEnum(TokenType.function)] = DataTypes.function;

    return mapping;
}
fn getDataType(token_type: TokenType) ?DataTypes {
    return token_type_data_type_mapping[@intFromEnum(token_type)];
}

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
