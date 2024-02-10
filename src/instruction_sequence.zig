const std = @import("std");
const LexerToken = @import("lexer_token.zig").LexerToken;
const ParserToken = @import("parser_token.zig").ParserToken;
const TokenType = @import("lexer_token.zig").TokenType;
const DataType = @import("lexer_token.zig").DataType;
const Function = @import("functions.zig").Function;

const Errors = error{
    instr_seq_data_type_for_stack_op_null,
};

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

    call_function,
};

pub const InstructionType = enum {
    single_instruction,
    stack_operation,
};

pub const Instruction = union(InstructionType) {
    single_instruction: Instructions,

    stack_operation: struct {
        instruction: Instructions,
        token_type: TokenType = undefined,
        data_type: DataType,
    },

    fn createSingleInstruction(instruction: Instructions) @This() {
        return Instruction{ .single_instruction = instruction };
    }
    fn createStackOperation(instruction: Instructions, parser_token: *const ParserToken) !@This() {
        const data_type = parser_token.data_type orelse return Errors.instr_seq_data_type_for_stack_op_null;
        const stack_operation = Instruction{ .stack_operation = .{ .instruction = instruction, .token_type = parser_token.token_type, .data_type = data_type } };
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

    pub fn triggerStackSequenceBinary(this: *@This(), instruction: Instructions, lhs: *const ?ParserToken, rhs: *const ?ParserToken) !void {
        if (lhs.*) |l| {
            try this.pushToken(&l);
            try this.unloadPayload(&l);
        }

        if (rhs.*) |r| {
            try this.pushToken(&r);
            try this.unloadPayload(&r);
        }

        try this.execInstruction(instruction);
    }

    pub fn triggerStackSequenceUnary(this: *@This(), lhs: *const ParserToken) !void {
        try this.pushToken(lhs);
        try this.unloadPayload(lhs);
    }

    

    pub fn unloadPayload(this: *@This(), parser_token: *const ParserToken) !void {
        var idx: usize = 0;
        while (idx < parser_token.idx_payload) : (idx += 1) {
            try this.execInstruction(parser_token.payload[idx].?);
        }
    }

    pub fn execInstruction(this: *@This(), instruction: Instructions) !void {
        try this.instruction_list.append(Instruction.createSingleInstruction(instruction));
    }

    fn pushToken(this: *@This(), parser_token: *const ParserToken) !void {
        const stack_operation = try Instruction.createStackOperation(Instructions.push, parser_token);
        try this.instruction_list.append(stack_operation);
    }

};
