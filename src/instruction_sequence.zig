const std = @import("std");
const LexerToken = @import("lexer_token.zig").LexerToken;
const ParserToken = @import("parser_token.zig").ParserToken;

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
        token: LexerToken,
    },
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

    pub fn triggerStackSequenceBinary(this: *@This(), operator_function: InstructionSequence.OperatorFunction, lhs: *const ?ParserToken, rhs: *const ?ParserToken) !void {
        if (lhs.*) |l| {
            try this.pushConstant(&l.token);
            try this.unloadPayload(&l);
        }

        if (rhs.*) |r| {
            try this.pushConstant(&r.token);
            try this.unloadPayload(&r);
        }

        try operator_function(this);
    }

    pub fn triggerStackSequenceUnary(this: *@This(), lhs: *const ParserToken) !void {
        try this.pushConstant(&lhs.token);
        try this.unloadPayload(lhs);
    }

    pub fn unloadPayload(this: *@This(), tok_op_fn: *const ParserToken) !void {
        var idx: usize = 0;
        while (idx < tok_op_fn.idx_payload) : (idx += 1) {
            try tok_op_fn.payload[idx].?(this);
        }
    }

    

    pub const OperatorFunction = *const fn (this: *@This()) std.mem.Allocator.Error!void;

    pub fn pushConstant(this: *@This(), token: *const LexerToken) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .stack_operation = .{ .instruction = Instructions.push, .token = token.* } });
    }

    pub fn equal(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.equal });
    }
    pub fn greaterThan(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.greaterThan });
    }
    pub fn lessThan(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.lessThan });
    }
    pub fn greaterEqualThan(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.greaterEqualThan });
    }
    pub fn lessEqualThan(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.lessEqualThan });
    }
    pub fn notEqualTo(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.notEqualTo });
    }

    pub fn concatenate(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.concat_strings });
    }

    pub fn add(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.add });
    }
    pub fn subtract(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.subtract });
    }

    pub fn multipy(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.multiply });
    }
    pub fn divide(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.divide });
    }

    pub fn toThePowerOf(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.to_the_power_of });
    }
    pub fn percentOf(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.percent_of });
    }
    pub fn negate(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.negate });
    }
    pub fn resolveReference(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.resolve_reference });
    }
    pub fn f_sum(this: *@This()) std.mem.Allocator.Error!void {
        try this.instruction_list.append(Instruction{ .single_instruction = Instructions.f_sum });
    }
};
