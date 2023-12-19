const std = @import("std");

const Error = error{
    rangeunwrapper_range_colon_divisor_na,
};

const ReferenceList = std.ArrayList([10]u8);

const RangeUnwrapper = struct {
    const DelimPositions = struct {
        left_col_start: usize,
        left_col_end: usize,
        left_row_start: usize,
        left_row_end: usize,
        right_col_start: usize,
        right_col_end: usize,
        right_row_start: usize,
        right_row_end: usize,
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

        const left_col_start: usize = 0;
        const left_col_end: usize = idx_left - 1;
        const left_row_start: usize = idx_left;
        const left_row_end: usize = range_delim_idx - 1;
        const right_col_start: usize = range_delim_idx + 1;
        const right_col_end: usize = range_delim_idx + idx_right;
        const right_row_start: usize = range_delim_idx + idx_right + 1;
        const right_row_end: usize = range.len - 1;

        //ABC12345:DEFG678

        const delimiters = DelimPositions{
            .left_col_start = left_col_start,
            .left_col_end = left_col_end,
            .left_row_start = left_row_start,
            .left_row_end = left_row_end,
            .right_col_start = right_col_start,
            .right_col_end = right_col_end,
            .right_row_start = right_row_start,
            .right_row_end = right_row_end,
        };

        return delimiters;
    }

    fn extractLeftCol(range: []const u8, range_delimiters: *const DelimPositions) [3]u8 {
        var column = [_]u8{0} ** 3;

        for (range[range_delimiters.left_col_idx .. range_delimiters.left_col_end + 1], 0..) |value, i| {
            column[i] = value;
        }

        return column;
    }

    fn extractLeftRow(range: []const u8, range_delimiters: *const DelimPositions) !usize {
        return try std.fmt.parseInt(usize, range[range_delimiters.left_row_start..range_delimiters.left_row_end + 1], 0);
    }

    fn extractRightCol(range: []const u8, range_delimiters: *const DelimPositions) [3]u8 {
        var column = [_]u8{0} ** 3;

        for (range[range_delimiters.right_col_start..range_delimiters.right_col_end + 1], 0..) |value, i| {
            column[i] = value;
        }

        return column;
    }

    fn extractRightRow(range: []const u8, range_delimiters: *const DelimPositions) !usize {
        return try std.fmt.parseInt(usize, range[range_delimiters.right_row_start..range_delimiters.right_row_end + 1], 0);
    }
};

test "delimiter calculation" {
    const result = try RangeUnwrapper.calcDelimiters("ABC12345:DEFG678"[0..]);
    try std.testing.expect(result.left_col_start == 0);
    try std.testing.expect(result.left_col_end == 2);

    try std.testing.expect(result.left_row_start == 3);
    try std.testing.expect(result.left_row_end == 7);

    try std.testing.expect(result.right_col_start == 9);
    try std.testing.expect(result.right_col_end == 12);

    try std.testing.expect(result.right_row_start == 13);
    try std.testing.expect(result.right_row_end == 15);
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
    try std.testing.expect(result[1] == 'E');
    try std.testing.expect(result[2] == 'F');
}

test "extract right row" {
    const range = "ABC12345:DEFG678"[0..];
    const delimiter = try RangeUnwrapper.calcDelimiters(range);
    const result = try RangeUnwrapper.extractRightRow(range, &delimiter);
    try std.testing.expect(result == 678);
}
