const std = @import("std");
const pow = std.math.pow;

const Error = error{
    rangeunwrapper_range_colon_divisor_na,
    rangeunwrapper_no_row_part_in_range,
};

const ReferenceList = std.ArrayList([10]u8);

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
    left_col_len: usize,
    left_row: usize,
    right_col_len: usize,
    right_col: [3]u8,
    right_row: usize,
};

pub fn unwrapRange(range: []const u8) !std.ArrayList([10]u8) {
    var reference_list = ReferenceList.init(std.heap.page_allocator);

    const range_delimiters = try calcDelimiters(range);

    const left_col = extractLeftCol(range, &range_delimiters);
    const right_col = extractRightCol(range, &range_delimiters);

    const indiv_parts = IndividualParts{
        .left_col = left_col.column,
        .left_col_len = left_col.column_len,
        .left_row = try extractLeftRow(range, &range_delimiters),
        .right_col = right_col.column,
        .right_col_len = right_col.column_len,
        .right_row = try extractRightRow(range, &range_delimiters),
    };

    try rangeToReferences(&indiv_parts, &reference_list);

    return reference_list;
}

fn rangeToReferences(indiv_parts: *const IndividualParts, reference_list: *ReferenceList) !void {
    const left_col_numeric = numberFromCol(&indiv_parts.left_col, indiv_parts.left_col_len);
    const right_col_numeric = numberFromCol(&indiv_parts.right_col, indiv_parts.right_col_len);

    for (left_col_numeric..right_col_numeric + 1) |col_num| {
        for (indiv_parts.left_row..indiv_parts.right_row + 1) |row_num| {
            var reference = [_]u8{0} ** 10;

            const column = colFromNumber(col_num);
            const row = rowFromNumber(row_num);

            var idx: usize = 0;
            for (column) |value| {
                if (value == 0) {
                    break;
                } else {
                    reference[idx] = value;
                    idx += 1;
                }
            }
            for (row) |value| {
                if (value == 0) {
                    break;
                } else {
                    reference[idx] = value;
                    idx += 1;
                }
            }

            try reference_list.append(reference);
        }
    }
}

fn calcDelimiters(range: []const u8) !DelimPositions {
    const row_characters = "0123456789";

    const range_delim_idx = std.mem.indexOf(u8, range, ":"[0..]) orelse return Error.rangeunwrapper_range_colon_divisor_na;
    const idx_left = std.mem.indexOfAny(u8, range[0..range_delim_idx], row_characters[0..]) orelse return Error.rangeunwrapper_no_row_part_in_range;
    const idx_right = std.mem.indexOfAny(u8, range[range_delim_idx + 1 ..], row_characters[0..]) orelse return Error.rangeunwrapper_no_row_part_in_range;

    const delimiters = DelimPositions{
        .left_col_start = 0,
        .left_col_end = idx_left - 1,
        .left_row_start = idx_left,
        .left_row_end = range_delim_idx - 1,
        .right_col_start = range_delim_idx + 1,
        .right_col_end = range_delim_idx + idx_right,
        .right_row_start = range_delim_idx + idx_right + 1,
        .right_row_end = range.len - 1,
    };

    return delimiters;
}

fn extractLeftCol(range: []const u8, range_delimiters: *const DelimPositions) struct { column: [3]u8, column_len: usize } {
    var column = [_]u8{0} ** 3;
    var column_len: usize = 0;

    for (range[range_delimiters.left_col_start .. range_delimiters.left_col_end + 1], 0..) |value, i| {
        column[i] = value;
        column_len = i;
    }

    return .{ .column = column, .column_len = column_len + 1 };
}

fn extractLeftRow(range: []const u8, range_delimiters: *const DelimPositions) !usize {
    return try std.fmt.parseInt(usize, range[range_delimiters.left_row_start .. range_delimiters.left_row_end + 1], 0);
}

fn extractRightCol(range: []const u8, range_delimiters: *const DelimPositions) struct { column: [3]u8, column_len: usize } {
    var column = [_]u8{0} ** 3;
    var column_len: usize = 0;

    for (range[range_delimiters.right_col_start .. range_delimiters.right_col_end + 1], 0..) |value, i| {
        column[i] = value;
        column_len = i;
    }

    return .{ .column = column, .column_len = column_len + 1 };
    
}

fn extractRightRow(range: []const u8, range_delimiters: *const DelimPositions) !usize {
    return try std.fmt.parseInt(usize, range[range_delimiters.right_row_start .. range_delimiters.right_row_end + 1], 0);
}

fn upperCharacterToNum(chara: u8) usize {
    return chara - '@';
}

const alphabet_num_chara: usize = 26;
fn numberFromCol(col: *const [3]u8, len: usize) usize {
    var this_length = len;
    var result: usize = 0;
    var iteration: usize = 0;

    while (this_length > 0) : (this_length -= 1) {
        const numFromChara = upperCharacterToNum(col[this_length - 1]);
        const multiplicator = pow(usize, alphabet_num_chara, iteration);
        result += numFromChara * multiplicator;
        iteration += 1;
    }
    return result;
}

fn numToUpperChara(num: usize) u8 {
    const num_as_u8: u8 = @intCast(num);
    return num_as_u8 + '@';
}

fn colFromNumber(num: usize) [3]u8 {
    var iteration: usize = 3;
    var result = [_]u8{0} ** 3;
    var idx: usize = 0;
    var remainder: usize = num;

    while (iteration > 0) : (iteration -= 1) {
        const divisor = pow(usize, alphabet_num_chara, iteration - 1);
        const chara_num = remainder / divisor;

        if (chara_num > 0) {
            result[idx] = numToUpperChara(chara_num);
            remainder -= chara_num * divisor;
            idx += 1;    
        }
    }

    return result;
}

fn rowFromNumber(num: usize) [7]u8 {
    var row = [_]u8{0} ** 7;

    const limb = [1]std.math.big.Limb{num};
    const cons = std.math.big.int.Const{ .limbs = &limb, .positive = true };
    var limb_buf: [10]std.math.big.Limb = undefined;
    _ = std.math.big.int.Const.toString(cons, &row, 10, std.fmt.Case.lower, &limb_buf);

    return row;
}

test "delimiter calculation" {
    const result = try calcDelimiters("ABC12345:DEFG678"[0..]);
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
    const delimiter = try calcDelimiters(range);
    const result = extractLeftCol(range, &delimiter);
    try std.testing.expect(result.column[0] == 'A');
    try std.testing.expect(result.column[1] == 'B');
    try std.testing.expect(result.column[2] == 'C');
    try std.testing.expect(result.column_len == 3);
}

test "extract left row" {
    const range = "ABC12345:DEF678"[0..];
    const delimiter = try calcDelimiters(range);
    const result = try extractLeftRow(range, &delimiter);
    try std.testing.expect(result == 12345);
}

test "extract right col" {
    const range = "ABC12345:DEF678"[0..];
    const delimiter = try calcDelimiters(range);
    const result = extractRightCol(range, &delimiter);
    try std.testing.expect(result.column[0] == 'D');
    try std.testing.expect(result.column[1] == 'E');
    try std.testing.expect(result.column[2] == 'F');
    try std.testing.expect(result.column_len == 3);
}

test "extract right row" {
    const range = "ABC12345:DEFG678"[0..];
    const delimiter = try calcDelimiters(range);
    const result = try extractRightRow(range, &delimiter);
    try std.testing.expect(result == 678);
}

test "col to num" {
    const col = [3]u8{ 'X', 'F', 'D' };
    const result = numberFromCol(&col, 3);
    try std.testing.expect(result == 16384);
}

test "num to chara" {
    const result = colFromNumber(16384);
    try std.testing.expect(result[0] == 'X');
    try std.testing.expect(result[1] == 'F');
    try std.testing.expect(result[2] == 'D');
}

test "row from number" {
    const result = rowFromNumber(1234);
    try std.testing.expect(result[0] == '1');
    try std.testing.expect(result[1] == '2');
    try std.testing.expect(result[2] == '3');
    try std.testing.expect(result[3] == '4');
    try std.testing.expect(result[4] == 0);
}

test "unwrap" {
    const result = try unwrapRange("A1:B2"[0..]);
    defer result.deinit();
    try std.testing.expect(std.mem.eql(u8, result.items[0][0..2] , "A1"[0..]));
    try std.testing.expect(std.mem.eql(u8, result.items[1][0..2] , "A2"[0..]));
    try std.testing.expect(std.mem.eql(u8, result.items[2][0..2] , "B1"[0..]));
    try std.testing.expect(std.mem.eql(u8, result.items[3][0..2] , "B2"[0..]));
}
