const std = @import("std");

fn parseNextCoord(line: []const u8, start_i: *usize) i32 {
    const i = std.mem.indexOfScalarPos(u8, line, start_i.*, '=').? + 1;
    start_i.* = std.mem.indexOfAnyPos(u8, line, i, ",:") orelse line.len;
    return std.fmt.parseInt(i32, line[i..start_i.*], 10) catch unreachable;
}
const parsed_input = blk: {
    @setEvalBranchQuota(100_000);
    const input = @embedFile("input");
    var sensor_count = 0;
    var line_it = std.mem.tokenize(u8, input, std.cstr.line_sep);
    while (line_it.next()) |_| sensor_count += 1;
    var sensors: [sensor_count]struct { sx: i32, sy: i32, bx: i32, by: i32 } = undefined;
    var p1_bxs_on_y = std.BoundedArray(i32, sensor_count).init(0) catch unreachable;
    line_it = std.mem.tokenize(u8, input, std.cstr.line_sep);
    for (sensors) |*info| {
        const line = line_it.next().?;
        var i: usize = 0;
        info.* = .{
            .sx = parseNextCoord(line, &i), // Sensor coords.
            .sy = parseNextCoord(line, &i),
            .bx = parseNextCoord(line, &i), // Nearest beacon coords.
            .by = parseNextCoord(line, &i),
        };
        if (info.by == 2_000_000) p1_bxs_on_y.append(info.bx) catch unreachable;
    }
    if (p1_bxs_on_y.len != 0) { // Sort and dedup bxs on line y.
        std.sort.sort(i32, p1_bxs_on_y.slice(), {}, std.sort.asc(i32));
        const slice = p1_bxs_on_y.slice();
        p1_bxs_on_y.len = 1;
        for (slice[1..]) |bx, prev_i| if (bx != slice[prev_i]) p1_bxs_on_y.append(bx) catch unreachable;
    }
    break :blk .{ .sensors = sensors, .p1_bxs_on_y = p1_bxs_on_y.slice() };
};

const Interval = struct { x0: i32, x1: i32 };
fn computeExclusions(y: i32, p2: bool) std.BoundedArray(Interval, parsed_input.sensors.len) {
    var intervals = std.BoundedArray(Interval, parsed_input.sensors.len).init(0) catch unreachable;
    for (parsed_input.sensors) |sensor| {
        const d = std.math.absCast(sensor.by - sensor.sy) + std.math.absCast(sensor.bx - sensor.sx); // Manhattan dist.
        if (std.math.absCast(sensor.sy - y) > d) continue; // Line further away than the beacon.
        // On the line y=2,000,000, all x where d>=|sy-y|+|sx-x| can't have other beacons.
        // To find the exclusion interval, solve for the two values of x where the rhs equals d.
        var xa = sensor.sx + (std.math.absInt(sensor.sy - y) catch unreachable) - @intCast(i32, d);
        var xb = sensor.sx - (std.math.absInt(sensor.sy - y) catch unreachable) + @intCast(i32, d);
        if (p2) {
            xa = std.math.clamp(xa, 0, 4_000_000);
            xb = std.math.clamp(xb, 0, 4_000_000);
        }
        intervals.append(.{ .x0 = @min(xa, xb), .x1 = @max(xa, xb) }) catch unreachable;
    }
    if (intervals.len < 2) return intervals;
    std.sort.sort(Interval, intervals.slice(), {}, struct { // Sort so interval merging is easy.
        fn lessThan(context: void, lhs: Interval, rhs: Interval) bool {
            _ = context;
            return lhs.x0 < rhs.x0; // Sorting x1 doesn't matter.
        }
    }.lessThan);
    const slice = intervals.slice();
    var interval_accum = intervals.get(0);
    intervals.len = 0;
    for (slice[1..]) |interval| { // Merge overlapping intervals in-place.
        if (interval_accum.x1 < interval.x0) { // Can't merge with previous.
            intervals.append(interval_accum) catch unreachable;
            interval_accum = interval;
        } else interval_accum.x1 = @max(interval_accum.x1, interval.x1);
    }
    intervals.append(interval_accum) catch unreachable;
    return intervals;
}
const p1 = blk: {
    @setEvalBranchQuota(100_000);
    var result = 0;
    for (computeExclusions(2_000_000, false).slice()) |interval| {
        result += 1 + interval.x1 - interval.x0;
        for (parsed_input.p1_bxs_on_y) |bx| { // Compensate for known beacons on the line.
            if (bx >= interval.x0 and bx <= interval.x1) result -= 1;
        }
    }
    break :blk result;
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Day15 (P1 at comptime): P1: {}", .{p1});
    var p2_x: i32 = 0;
    var p2_y: i32 = 0;
    while (p2_y <= 4_000_000) : (p2_y += 1) {
        const intervals = computeExclusions(p2_y, true);
        if (intervals.len == 1 and intervals.get(0).x0 > 0) p2_x = intervals.get(0).x0 - 1;
        if (intervals.len == 1 and intervals.get(0).x1 < 4_000_000) p2_x = intervals.get(0).x1 + 1;
        if (intervals.len == 2) p2_x = intervals.get(0).x1 + 1;
        if (p2_x != 0) break;
    }
    try stdout.print(", P2: {}\n", .{4_000_000 * @as(i64, p2_x) + p2_y});
}
