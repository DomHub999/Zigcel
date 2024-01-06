const std = @import("std");
const LexerToken = @import("lexer_token.zig").LexerToken;
const ParserToken = @import("parser_token.zig").ParserToken;
const MAX_TOKEN_SIZE = @import("lexer_token.zig").MAX_TOKEN_SIZE;
const TokenType = @import("lexer_token.zig").TokenType;

pub const Instructions = enum {
    equal,
    greaterThan,
    lessThan,
    greaterEqualThan,
    lessEqualThan,
    notEqualTo,

    add,
    subtract,
    multiply,
    divide,

    push,

    concat_strings,

    to_the_power_of,

    percent_of,

    negate,

    range,
    resolve_reference,

    f_sum,
};

pub const InstructionType = enum {
    single_instruction,
    stack_operation,
};

pub const Instruction = union(InstructionType) {
    single_instruction: Instructions,
    stack_operation: struct {
        instruction: Instructions,
        token: [MAX_TOKEN_SIZE]u8 = [_]u8{0} ** MAX_TOKEN_SIZE, //for debugging purposes
        token_type: TokenType = undefined,
    },

    fn createSingleInstruction(instruction:Instructions)@This(){
        return Instruction{.single_instruction = instruction};
    }
    fn createStackOperation(instruction:Instructions, parser_token:*const ParserToken)@This(){
        const stack_operation = Instruction{.stack_operation = .{.instruction = instruction, .token = parser_token.token, .token_type = parser_token.token_type } };
        return stack_operation;
    }
};

pub const InstructionSequence = struct {
    const array_list_type = std.ArrayList(Instruction);
    instruction_list: array_list_type = undefined,

    pub fn init(this: *@This()) void {
        this.instruction_list = array_list_type.init(std.heap.page_allocator);
    }

    pub fn drop(this: *@This()) void {
        this.instruction_list.deinit();
    }

    pub fn triggerStackSequenceBinary(this: *@This(), instruction:Instructions, lhs: *const ?ParserToken, rhs: *const ?ParserToken) !void {
        
        if (lhs.*) |l| {
            try this.pushConstant(&l);
            try this.unloadPayload(&l);
        }

        if (rhs.*) |r| {
            try this.pushConstant(&r);
            try this.unloadPayload(&r);
        }

        try this.execInstruction(instruction);
    }

    pub fn triggerStackSequenceUnary(this: *@This(), lhs: *const ParserToken) !void {
        try this.pushConstant(lhs);
        try this.unloadPayload(lhs);
    }

    pub fn unloadPayload(this: *@This(), parser_token: *const ParserToken) !void {
        var idx: usize = 0;
        while (idx < parser_token.idx_payload) : (idx += 1) {
            try this.execInstruction(parser_token.payload[idx].?);
        }
    }

    fn execInstruction(this: *@This(), instruction:Instructions)!void{
        try this.instruction_list.append(Instruction.createSingleInstruction(instruction));
    }

    fn pushConstant(this: *@This(), parser_token: *const ParserToken) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction.createStackOperation(Instructions.push, parser_token));
    }

};
