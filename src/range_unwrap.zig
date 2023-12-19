const std = @import("std");

const Error = error{
    rangeunwrapper_range_colon_divisor_na,
};

const ReferenceList = std.ArrayList([10]u8);

const RangeUnwrapper = struct {
    const DelimPositions = struct {
        left_col_idx: usize,
        left_col_len: usize,
        left_row_idx: usize,
        left_row_len: usize,
        right_col_len: usize,
        right_col_idx: usize,
        right_row_idx: usize,
        right_row_len: usize,
    };

    const IndividualParts = struct {
        left_col: [3]u8,
        left_row: usize,
        right_col: [3]u8,
        right_row: usize,
    };

    pub fn unwrapRange(this: *@This(), range: []const u8) !std.ArrayList([10]u8) {
        _ = this;

        var reference_list = ReferenceList.init(std.heap.page_allocator);

        const range_delimiters = RangeUnwrapper.calcDelimiters(range);

        const indiv_parts = IndividualParts{
            .left_col = RangeUnwrapper.extractLeftCol(range, &range_delimiters),
            .left_row = RangeUnwrapper.extractLeftRow(range, &range_delimiters),
            .right_col = RangeUnwrapper.extractRightCol(range, &range_delimiters),
            .right_row = RangeUnwrapper.extractRightRow(range, &range_delimiters),
        };

        _ = indiv_parts;

        return reference_list;
    }

    fn rangeToReferences(indiv_parts: *IndividualParts, reference_list: *ReferenceList) void {
        _ = reference_list;

        _ = indiv_parts;
    }

    fn calcDelimiters(range: []const u8) !DelimPositions {
        var idx_left: usize = 0;

        while (range[idx_left] >= 'A' and range[idx_left] <= 'Z') : (idx_left += 1) {}

        const range_delim_idx = std.mem.indexOf(u8, range, ":"[0..]) orelse return Error.rangeunwrapper_range_colon_divisor_na;

        var idx_right: usize = 0;

        while (range[(range_delim_idx + 1)..][idx_right] >= 'A' and range[(range_delim_idx + 1)..][idx_right] <= 'Z') : (idx_right += 1) {}

        const left_col_len: usize = idx_left;
        const left_row_idx: usize = idx_left;
        const left_row_len: usize = range_delim_idx - left_col_len;
        const right_col_idx: usize = range_delim_idx + 1;
        const right_col_len: usize = idx_right;
        const right_row_idx: usize = idx_right + range_delim_idx + 1;
        const right_row_len: usize = range.len - right_row_idx;

        const delimiters = DelimPositions{
            .left_col_idx = 0,
            .left_col_len = left_col_len,
            .left_row_idx = left_row_idx,
            .left_row_len = left_row_len,
            .right_col_idx = right_col_idx,
            .right_col_len = right_col_len,
            .right_row_idx = right_row_idx,
            .right_row_len = right_row_len,
        };

        return delimiters;
    }

    fn extractLeftCol(range: []const u8, range_delimiters: *const DelimPositions) [3]u8 {
        var column = [_]u8{0} ** 3;

        for (range[range_delimiters.left_col_idx..range_delimiters.left_col_len], 0..) |value, i| {
            column[i] = value;
        }

        return column;
    }

    fn extractLeftRow(range: []const u8, range_delimiters: *const DelimPositions) !usize {
        const debug = range[range_delimiters.left_row_idx..range_delimiters.left_row_len];
        _ = debug;
    
        return try std.fmt.parseInt(usize, range[range_delimiters.left_row_idx..range_delimiters.left_row_len], 0);
        
    }

    fn extractRightRow(range: []const u8, range_delimiters: *const DelimPositions) usize {
        return try std.fmt.parseInt(usize, range[range_delimiters.right_row_idx..range_delimiters.right_row_len], 0);
    }

    fn extractRightCol(range: []const u8, range_delimiters: *const DelimPositions) [3]u8 {
        var column = [_]u8{0} ** 3;

        for (range[range_delimiters.right_col_idx..range_delimiters.right_col_len], 0..) |value, i| {
            column[i] = value;
        }

        return column;
    }
};

test "delimiter calculation" {
    const result = try RangeUnwrapper.calcDelimiters("ABC12345:DEFG678"[0..]);
    try std.testing.expect(result.left_col_idx == 0);
    try std.testing.expect(result.left_col_len == 3);
    try std.testing.expect(result.left_row_idx == 3);
    try std.testing.expect(result.left_row_len == 5);
    try std.testing.expect(result.right_col_idx == 9);
    try std.testing.expect(result.right_col_len == 4);
    try std.testing.expect(result.right_row_idx == 13);
    try std.testing.expect(result.right_row_len == 3);
}

test "extract left col" {
    const range = "ABC12345:DEF678"[0..];
    const delimiter = try RangeUnwrapper.calcDelimiters(range);
    const result = RangeUnwrapper.extractLeftCol(range, &delimiter);
    try std.testing.expect(result[0] == 'A');
    try std.testing.expect(result[1] == 'B');
    try std.testing.expect(result[2] == 'C');
}

test "extract left row" {
    const range = "ABC12345:DEF678"[0..];
    const delimiter = try RangeUnwrapper.calcDelimiters(range);
    const result = try RangeUnwrapper.extractLeftRow(range, &delimiter);
    try std.testing.expect(result == 12345);
}

test "extract right col" {
    const range = "ABC12345:DEF678"[0..];
    const delimiter = try RangeUnwrapper.calcDelimiters(range);
    const result = RangeUnwrapper.extractRightCol(range, &delimiter);
    try std.testing.expect(result[0] == 'D');
    try std.testing.expect(result[0] == 'E');
    try std.testing.expect(result[0] == 'F');
    
}

test "extract right row" {
    const range = "ABC12345:DEFG678"[0..];
    const delimiter = try RangeUnwrapper.calcDelimiters(range);
    const result = try RangeUnwrapper.extractLeftRow(range, &delimiter);
    try std.testing.expect(result == 678);
}
