const std = @import("std");
const node_mod = @import("node.zig");
const screen_mod = @import("../terminal/screen.zig");
const rect_mod = @import("surface.zig");
const style_mod = @import("../style/style.zig");
const rich_text = @import("../format/rich_text.zig");
const border_mod = @import("../style/border.zig");
const transform = @import("../format/transform.zig");

const SelectionRange = struct {
    start: usize,
    end: usize,
};

pub fn renderNode(screen: *screen_mod.Screen, rect: rect_mod.Rect, node: *const node_mod.Node) void {
    switch (node.*) {
        .empty => {},
        .spacer => |data| fillRect(screen, rect, data.style),
        .divider => |data| renderDivider(screen, rect, data),
        .badge => |data| renderBadge(screen, rect, data),
        .progress_bar => |data| renderProgressBar(screen, rect, data),
        .key_hints => |data| renderKeyHints(screen, rect, data),
        .tab_bar => |data| renderTabBar(screen, rect, data),
        .scrollbar => |data| renderScrollbar(screen, rect, data),
        .text => |data| renderText(screen, rect, data.text, data.style, data.wrap, data.alignment),
        .transform_text => |data| renderTransformText(screen, rect, data),
        .box => |data| renderBox(screen, rect, data),
        .vstack => |data| renderVStack(screen, rect, data),
        .hstack => |data| renderHStack(screen, rect, data),
        .split => |data| renderSplit(screen, rect, data),
        .status_bar => |data| renderStatusBar(screen, rect, data),
        .input => |data| renderInput(screen, rect, data),
        .text_area => |data| renderTextArea(screen, rect, data),
        .list => |data| renderList(screen, rect, data),
        .scroll => |data| renderScroll(screen, rect, data),
        .rich_scroll => |data| renderRichScroll(screen, rect, data),
        .overlay => |data| {
            renderNode(screen, rect, data.base);
            renderNode(screen, rect, data.overlay);
        },
        .modal => |data| renderModal(screen, rect, data),
    }
}

fn fillRect(screen: *screen_mod.Screen, rect: rect_mod.Rect, style: style_mod.Style) void {
    var y: u16 = 0;
    while (y < rect.height) : (y += 1) {
        var x: u16 = 0;
        while (x < rect.width) : (x += 1) {
            screen.setCell(.{ .x = rect.x + x, .y = rect.y + y }, ' ', style);
        }
    }
}

fn renderText(
    screen: *screen_mod.Screen,
    rect: rect_mod.Rect,
    text: []const u8,
    style: style_mod.Style,
    wrap_mode: node_mod.Node.WrapMode,
    alignment: node_mod.Node.HorizontalAlign,
) void {
    fillRect(screen, rect, style);
    const max_width: usize = @intCast(rect.width);
    if (max_width == 0 or rect.height == 0) return;

    switch (wrap_mode) {
        .wrap, .word => {
            var lines = std.mem.splitScalar(u8, text, '\n');
            var row: u16 = 0;
            while (lines.next()) |line| {
                if (row >= rect.height) return;
                renderWrappedWords(screen, .{ .x = rect.x, .y = rect.y }, max_width, line, style, alignment, &row, rect.height);
            }
        },
        .char => {
            var lines = std.mem.splitScalar(u8, text, '\n');
            var row: u16 = 0;
            while (lines.next()) |line| {
                if (line.len == 0) {
                    if (row >= rect.height) break;
                    row += 1;
                    continue;
                }
                var start: usize = 0;
                while (start < line.len) {
                    if (row >= rect.height) return;
                    const end = @min(start + max_width, line.len);
                    const chunk = line[start..end];
                    const draw_x = alignedX(rect.x, rect.width, chunk.len, alignment);
                    screen.writeText(.{ .x = draw_x, .y = rect.y + row }, chunk, style);
                    row += 1;
                    start = end;
                }
            }
        },
        .none => {
            var parts = std.mem.splitScalar(u8, text, '\n');
            const first_line = parts.first();
            const clipped = first_line[0..@min(first_line.len, max_width)];
            screen.writeText(.{ .x = alignedX(rect.x, rect.width, clipped.len, alignment), .y = rect.y }, clipped, style);
        },
        else => {
            var parts = std.mem.splitScalar(u8, text, '\n');
            const first_line = parts.first();
            renderTruncatedLine(screen, .{ .x = rect.x, .y = rect.y }, rect.width, first_line, style, wrap_mode, alignment);
        },
    }
}

fn renderBox(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.BoxData) void {
    const outer_x = rect.x + data.margin_left;
    const outer_y = rect.y + data.margin_top;
    const outer_width = rect.width -| data.margin_left -| data.margin_right;
    const outer_height = rect.height -| data.margin_top -| data.margin_bottom;
    if (outer_width < 2 or outer_height < 2) return;

    if (rect.width < 2 or rect.height < 2) return;
    const style = data.style;
    const border = data.border_style.chars();
    const x0 = outer_x;
    const y0 = outer_y;
    const x1 = outer_x + outer_width - 1;
    const y1 = outer_y + outer_height - 1;

    // Paint the full panel area so box background colors produce real themed cards.
    fillRect(screen, .{
        .x = outer_x,
        .y = outer_y,
        .width = outer_width,
        .height = outer_height,
    }, style);

    screen.setGlyph(.{ .x = x0, .y = y0 }, border.top_left, style);
    screen.setGlyph(.{ .x = x1, .y = y0 }, border.top_right, style);
    screen.setGlyph(.{ .x = x0, .y = y1 }, border.bottom_left, style);
    screen.setGlyph(.{ .x = x1, .y = y1 }, border.bottom_right, style);
    var x = x0 + 1;
    while (x < x1) : (x += 1) {
        screen.setGlyph(.{ .x = x, .y = y0 }, border.horizontal, style);
        screen.setGlyph(.{ .x = x, .y = y1 }, border.horizontal, style);
    }
    var y = y0 + 1;
    while (y < y1) : (y += 1) {
        screen.setGlyph(.{ .x = x0, .y = y }, border.vertical, style);
        screen.setGlyph(.{ .x = x1, .y = y }, border.vertical, style);
    }

    if (data.title) |title| {
        const title_width: usize = @intCast(rect.width -| 4);
        const clipped = title[0..@min(title.len, title_width)];
        const title_x = alignedX(x0 + 2, outer_width -| 4, clipped.len, data.title_align);
        screen.writeText(.{ .x = title_x, .y = y0 }, clipped, style);
    }
    if (data.child) |child| {
        const inner_x = outer_x + 1 + data.padding_left;
        const inner_y = outer_y + 1 + data.padding_top;
        const inner_width = outer_width -| 2 -| data.padding_left -| data.padding_right;
        const inner_height = outer_height -| 2 -| data.padding_top -| data.padding_bottom;
        if (inner_width == 0 or inner_height == 0) return;
        renderNode(screen, .{
            .x = inner_x,
            .y = inner_y,
            .width = inner_width,
            .height = inner_height,
        }, child);
    }
}

fn renderTransformText(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.TransformTextData) void {
    const allocator = screen.allocator;
    const output = switch (data.mode) {
        .uppercase => transform.uppercase(allocator, data.text) catch return,
        .lowercase => transform.lowercase(allocator, data.text) catch return,
        .hanging_indent => |indent| transform.hangingIndent(allocator, data.text, indent) catch return,
    };
    defer allocator.free(output);
    renderText(screen, rect, output, data.style, data.wrap, data.alignment);
}

fn renderVStack(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.VStackData) void {
    if (data.children.len == 0) return;
    const gap_total: u16 = if (data.children.len <= 1) 0 else @intCast(@min((data.children.len - 1) * data.gap, std.math.maxInt(u16)));
    const usable_height: u16 = rect.height -| gap_total;
    const total_weight = sumWeights(data.weights, data.children.len);
    var y = rect.y;
    var used_height: u16 = 0;
    for (data.children, 0..) |child, index| {
        const h: u16 = if (index + 1 == data.children.len)
            usable_height -| used_height
        else if (data.weights) |_|
            @intCast((@as(usize, usable_height) * childWeight(data.weights, index)) / total_weight)
        else
            @intCast(@as(usize, usable_height) / data.children.len);
        renderNode(screen, .{ .x = rect.x, .y = y, .width = rect.width, .height = h }, child);
        y +|= h +| data.gap;
        used_height += h;
        if (y >= rect.y + rect.height) break;
    }
}

fn renderHStack(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.HStackData) void {
    if (data.children.len == 0) return;
    const gap_total: u16 = if (data.children.len <= 1) 0 else @intCast(@min((data.children.len - 1) * data.gap, std.math.maxInt(u16)));
    const usable_width: u16 = rect.width -| gap_total;
    const total_weight = sumWeights(data.weights, data.children.len);
    var x = rect.x;
    var used_width: u16 = 0;
    for (data.children, 0..) |child, index| {
        const w: u16 = if (index + 1 == data.children.len)
            usable_width -| used_width
        else if (data.weights) |_|
            @intCast((@as(usize, usable_width) * childWeight(data.weights, index)) / total_weight)
        else
            @intCast(@as(usize, usable_width) / data.children.len);
        renderNode(screen, .{ .x = x, .y = rect.y, .width = w, .height = rect.height }, child);
        x +|= w +| data.gap;
        used_width += w;
        if (x >= rect.x + rect.width) break;
    }
}

fn renderSplit(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.SplitData) void {
    switch (data.axis) {
        .horizontal => {
            const left_width: u16 = @intCast((@as(u32, rect.width) * data.ratio_percent) / 100);
            const right_width: u16 = rect.width -| left_width -| 1;
            renderNode(screen, .{ .x = rect.x, .y = rect.y, .width = left_width, .height = rect.height }, data.left);
            if (left_width < rect.width) {
                var y = rect.y;
                while (y < rect.y + rect.height) : (y += 1) {
                    screen.setGlyph(.{ .x = rect.x + left_width, .y = y }, "│", .{});
                }
            }
            if (left_width + 1 < rect.width) {
                renderNode(screen, .{
                    .x = rect.x + left_width + 1,
                    .y = rect.y,
                    .width = right_width,
                    .height = rect.height,
                }, data.right);
            }
        },
        .vertical => {
            const top_height: u16 = @intCast((@as(u32, rect.height) * data.ratio_percent) / 100);
            const bottom_height: u16 = rect.height -| top_height -| 1;
            renderNode(screen, .{ .x = rect.x, .y = rect.y, .width = rect.width, .height = top_height }, data.left);
            if (top_height < rect.height) {
                var x = rect.x;
                while (x < rect.x + rect.width) : (x += 1) {
                    screen.setGlyph(.{ .x = x, .y = rect.y + top_height }, "─", .{});
                }
            }
            if (top_height + 1 < rect.height) {
                renderNode(screen, .{
                    .x = rect.x,
                    .y = rect.y + top_height + 1,
                    .width = rect.width,
                    .height = bottom_height,
                }, data.right);
            }
        },
    }
}

fn renderStatusBar(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.StatusBarData) void {
    if (rect.height == 0) return;
    var x: u16 = rect.x;
    while (x < rect.x + rect.width) : (x += 1) {
        screen.setCell(.{ .x = x, .y = rect.y }, ' ', data.style);
    }
    const width: usize = @intCast(rect.width);
    const left_style = data.left_style orelse data.style;
    const center_style = data.center_style orelse data.style;
    const right_style = data.right_style orelse data.style;

    screen.writeText(.{ .x = rect.x, .y = rect.y }, data.left[0..@min(data.left.len, width)], left_style);
    if (data.center) |center| {
        const center_len: usize = @min(center.len, width);
        const start_x = rect.x + @as(u16, @intCast((width - center_len) / 2));
        screen.writeText(.{ .x = start_x, .y = rect.y }, center[0..center_len], center_style);
    }
    const right_len: usize = @min(data.right.len, width);
    if (right_len < rect.width) {
        const start_x: u16 = rect.x + rect.width - @as(u16, @intCast(right_len));
        screen.writeText(.{ .x = start_x, .y = rect.y }, data.right[data.right.len - right_len ..], right_style);
    }
}

fn renderInput(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.InputData) void {
    const cursor_style: style_mod.Style = .{
        .fg = .{ .rgb = .{ .r = 20, .g = 24, .b = 32 } },
        .bg = .{ .rgb = .{ .r = 250, .g = 204, .b = 21 } },
        .bold = true,
    };
    renderTextArea(screen, rect, .{
        .prompt = data.prompt,
        .value = data.value,
        .cursor = data.cursor,
        .focused = data.focused,
        .style = data.style,
        .selection_style = cursor_style,
        .focus = data.focus,
    });
}

fn renderTextArea(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.TextAreaData) void {
    if (rect.height == 0) return;
    const width: usize = @intCast(rect.width);
    const height: usize = @intCast(rect.height);
    if (width == 0 or height == 0) return;
    fillRect(screen, rect, data.style);

    if (data.wrap_lines) {
        renderWrappedTextArea(screen, rect, data, width, height);
        return;
    }

    const cursor = @min(data.cursor, data.value.len);
    const cursor_line = countLines(data.value[0..cursor]) - 1;

    var start_line: usize = data.offset_line;
    if (data.offset_line == 0 and cursor_line + 1 > height) {
        start_line = cursor_line + 1 - height;
    }

    var line_index: usize = 0;
    var draw_row: usize = 0;
    var lines = std.mem.splitScalar(u8, data.value, '\n');
    while (lines.next()) |line| : (line_index += 1) {
        if (line_index < start_line) continue;
        if (draw_row >= height) break;

        var line_buf: [1024]u8 = undefined;
        const prefix = if (line_index == 0) data.prompt else "  ";
        const visible_line = if (data.offset_column < line.len) line[data.offset_column..] else "";
        const prefix_len: usize = @min(prefix.len, line_buf.len);
        @memcpy(line_buf[0..prefix_len], prefix[0..prefix_len]);

        const cursor_on_line = findCursorOnLine(data.value, cursor, line_index);
        const line_style = if (data.current_line) |current_line|
            if (line_index == current_line and data.current_line_style != null) data.current_line_style.? else data.style
        else
            data.style;
        var total = prefix_len;

        if (cursor_on_line) |col| {
            const visible_col = col -| data.offset_column;
            const before_len: usize = @min(visible_col, line_buf.len - total);
            @memcpy(line_buf[total .. total + before_len], visible_line[0..before_len]);
            total += before_len;

            if (data.focused and col >= data.offset_column and total < line_buf.len) {
                const cursor_index = col - data.offset_column;
                line_buf[total] = if (cursor_index < visible_line.len) visible_line[cursor_index] else '_';
                total += 1;
            }

            if (col >= data.offset_column and total < line_buf.len) {
                const visible_cursor_col = col - data.offset_column;
                const unclamped_start_after = if (data.focused) visible_cursor_col + 1 else visible_cursor_col;
                const start_after = @min(unclamped_start_after, visible_line.len);
                const after_cap: usize = @min(visible_line.len -| start_after, line_buf.len - total);
                if (after_cap > 0) {
                    @memcpy(line_buf[total .. total + after_cap], visible_line[start_after .. start_after + after_cap]);
                    total += after_cap;
                }
            } else {
                const line_cap: usize = @min(visible_line.len, line_buf.len - total);
                @memcpy(line_buf[total .. total + line_cap], visible_line[0..line_cap]);
                total += line_cap;
            }
        } else {
            const line_cap: usize = @min(visible_line.len, line_buf.len - total);
            @memcpy(line_buf[total .. total + line_cap], visible_line[0..line_cap]);
            total += line_cap;
        }

        renderTextAreaLine(
            screen,
            .{ .x = rect.x, .y = rect.y + @as(u16, @intCast(draw_row)) },
            width,
            line_buf[0..@min(total, width)],
            line_style,
            data.selection_style,
            lineSelectionRange(data, line_index, prefix_len),
            if (cursor_on_line) |col|
                if (col >= data.offset_column and data.focused)
                    @min(prefix_len + (col - data.offset_column), @min(total, width) -| 1)
                else
                    null
            else
                null,
        );
        draw_row += 1;
    }

    if (data.value.len == 0) {
        var line_buf: [1024]u8 = undefined;
        const prefix_len: usize = @min(data.prompt.len, line_buf.len);
        @memcpy(line_buf[0..prefix_len], data.prompt[0..prefix_len]);
        var total = prefix_len;
        if (data.placeholder) |placeholder| {
            const remaining = line_buf.len - total;
            const cap: usize = @min(placeholder.len, remaining);
            @memcpy(line_buf[total .. total + cap], placeholder[0..cap]);
            total += cap;
        }
        if (data.focused and total < line_buf.len) {
            line_buf[total] = '_';
            total += 1;
        }
        renderTextAreaLine(screen, .{ .x = rect.x, .y = rect.y }, width, line_buf[0..@min(total, width)], data.style, data.selection_style, null, if (data.focused) total -| 1 else null);
    }
}

fn renderTextAreaLine(
    screen: *screen_mod.Screen,
    origin: screen_mod.Point,
    width: usize,
    text: []const u8,
    style: style_mod.Style,
    selection_style: style_mod.Style,
    selection: ?SelectionRange,
    cursor_index: ?usize,
) void {
    var fill_index: usize = 0;
    while (fill_index < width) : (fill_index += 1) {
        screen.setCell(.{ .x = origin.x + @as(u16, @intCast(fill_index)), .y = origin.y }, ' ', style);
    }
    var index: usize = 0;
    while (index < text.len) : (index += 1) {
        const active = if (selection) |range| index >= range.start and index < range.end else false;
        const cursor_active = cursor_index != null and index == cursor_index.?;
        screen.setCell(
            .{ .x = origin.x + @as(u16, @intCast(index)), .y = origin.y },
            text[index],
            if (active or cursor_active) selection_style else style,
        );
    }
}

fn renderWrappedTextArea(
    screen: *screen_mod.Screen,
    rect: rect_mod.Rect,
    data: node_mod.Node.TextAreaData,
    width: usize,
    height: usize,
) void {
    const cursor = @min(data.cursor, data.value.len);
    var line_index: usize = 0;
    var visual_row_index: usize = 0;
    var draw_row: usize = 0;
    var lines = std.mem.splitScalar(u8, data.value, '\n');
    while (lines.next()) |line| : (line_index += 1) {
        if (draw_row >= height) break;

        const line_style = if (data.current_line) |current_line|
            if (line_index == current_line and data.current_line_style != null) data.current_line_style.? else data.style
        else
            data.style;
        const cursor_on_line = findCursorOnLine(data.value, cursor, line_index);
        const prefix = if (line_index == 0) data.prompt else "";
        var start: usize = 0;
        var first_chunk = true;

        while (true) {
            if (draw_row >= height) break;

            var line_buf: [1024]u8 = undefined;
            const active_prefix = if (first_chunk) prefix else "";
            const active_prefix_len = @min(active_prefix.len, @min(width, line_buf.len));
            if (active_prefix_len > 0) @memcpy(line_buf[0..active_prefix_len], active_prefix[0..active_prefix_len]);
            var total: usize = active_prefix_len;

            const chunk_width = width -| active_prefix_len;
            const chunk_end = if (chunk_width == 0) start else @min(start + chunk_width, line.len);
            if (chunk_end > start) {
                const cap = @min(chunk_end - start, line_buf.len - total);
                @memcpy(line_buf[total .. total + cap], line[start .. start + cap]);
                total += cap;
            }

            if (cursor_on_line) |col| {
                if (col >= start and col <= chunk_end) {
                    const cursor_slot = active_prefix_len + (col - start);
                    if (cursor_slot < @min(width, line_buf.len)) {
                        if (cursor_slot >= total) {
                            var pad_index = total;
                            while (pad_index < cursor_slot and pad_index < line_buf.len) : (pad_index += 1) line_buf[pad_index] = ' ';
                            total = cursor_slot;
                        }
                        line_buf[cursor_slot] = if (col < line.len) line[col] else '_';
                        total = @max(total, cursor_slot + 1);
                    }
                }
            }

            if (visual_row_index >= data.offset_line) {
                renderTextAreaLine(
                    screen,
                    .{ .x = rect.x, .y = rect.y + @as(u16, @intCast(draw_row)) },
                    width,
                    line_buf[0..@min(total, width)],
                    line_style,
                    data.selection_style,
                    null,
                    if (cursor_on_line) |col|
                        if (col >= start and col <= chunk_end and data.focused)
                            @min(active_prefix_len + (col - start), @min(total, width) -| 1)
                        else
                            null
                    else
                        null,
                );
                draw_row += 1;
            }
            visual_row_index += 1;

            if (chunk_end >= line.len) break;
            start = chunk_end;
            first_chunk = false;
        }
    }

    if (data.value.len == 0) {
        var line_buf: [1024]u8 = undefined;
        var total: usize = 0;
        if (data.placeholder) |placeholder| {
            const cap = @min(placeholder.len, @min(width, line_buf.len));
            @memcpy(line_buf[0..cap], placeholder[0..cap]);
            total = cap;
        }
        if (data.focused and total < @min(width, line_buf.len)) {
            line_buf[total] = '_';
            total += 1;
        }
        renderTextAreaLine(screen, .{ .x = rect.x, .y = rect.y }, width, line_buf[0..@min(total, width)], data.style, data.selection_style, null, if (data.focused) total -| 1 else null);
    }
}

fn lineSelectionRange(data: node_mod.Node.TextAreaData, line_index: usize, prefix_len: usize) ?SelectionRange {
    if (data.selection_start == null or data.selection_end == null) return null;
    const line_start = lineStartForIndex(data.value, line_index);
    const line_end = std.mem.indexOfScalarPos(u8, data.value, line_start, '\n') orelse data.value.len;
    const visible_start = line_start + @min(data.offset_column, line_end - line_start);
    const start = @max(data.selection_start.?, visible_start);
    const end = @min(data.selection_end.?, line_end);
    if (start >= end) return null;
    return .{
        .start = prefix_len + (start - visible_start),
        .end = prefix_len + (end - visible_start),
    };
}

fn lineStartForIndex(value: []const u8, target_line: usize) usize {
    var current_line: usize = 0;
    var start: usize = 0;
    var index: usize = 0;
    while (index < value.len and current_line < target_line) : (index += 1) {
        if (value[index] == '\n') {
            current_line += 1;
            start = index + 1;
        }
    }
    return start;
}

fn countLines(text: []const u8) usize {
    if (text.len == 0) return 1;
    var count: usize = 1;
    for (text) |byte| {
        if (byte == '\n') count += 1;
    }
    return count;
}

fn findCursorOnLine(value: []const u8, cursor: usize, target_line: usize) ?usize {
    var current_line: usize = 0;
    var line_start: usize = 0;
    var index: usize = 0;
    while (index <= value.len) : (index += 1) {
        if (current_line == target_line) {
            const line_end = std.mem.indexOfScalarPos(u8, value, line_start, '\n') orelse value.len;
            if (cursor >= line_start and cursor <= line_end) {
                return cursor - line_start;
            }
            return null;
        }

        if (index == value.len or value[index] == '\n') {
            current_line += 1;
            line_start = index + 1;
        }
    }
    return null;
}

fn renderList(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.ListData) void {
    fillRect(screen, rect, data.style);
    const visible: usize = @min(@as(usize, rect.height), data.items.len -| data.offset);
    for (0..visible) |row| {
        const idx: usize = data.offset + row;
        const prefix = if (idx == data.selected) data.marker else data.unselected_marker;
        var buf: [1024]u8 = undefined;
        const line = std.fmt.bufPrint(&buf, "{s}{s}", .{ prefix, data.items[idx] }) catch prefix;
        renderText(screen, .{ .x = rect.x, .y = rect.y + @as(u16, @intCast(row)), .width = rect.width, .height = 1 }, line, if (idx == data.selected) data.selected_style else data.style, .truncate_end, .left);
    }
}

fn renderScroll(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.ScrollData) void {
    fillRect(screen, rect, data.style);
    var row: u16 = 0;
    var idx = data.offset;
    while (row < rect.height and idx < data.lines.len) : ({
        row += 1;
        idx += 1;
    }) {
        renderText(screen, .{ .x = rect.x, .y = rect.y + row, .width = rect.width, .height = 1 }, data.lines[idx], data.style, .truncate_end, .left);
    }
}

fn renderRichScroll(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.RichScrollData) void {
    fillRect(screen, rect, data.style);
    var row: u16 = 0;
    var idx = data.offset;
    while (row < rect.height and idx < data.lines.len) : ({
        row += 1;
        idx += 1;
    }) {
        renderRichLine(screen, .{ .x = rect.x, .y = rect.y + row }, rect.width, data.lines[idx], data.style, data.alignment);
    }
}

fn renderRichLine(
    screen: *screen_mod.Screen,
    point: screen_mod.Point,
    width: u16,
    line: rich_text.Line,
    fallback_style: style_mod.Style,
    alignment: node_mod.Node.HorizontalAlign,
) void {
    const total_width = richLineWidth(line);
    var x = alignedX(point.x, width, total_width, alignment);
    const x_end = point.x + width;
    for (line.spans) |span| {
        const style = if (style_mod.Style.eql(span.style, .{})) fallback_style else span.style;
        if (x >= x_end or x >= screen.size.width) return;
        screen.writeLinkedText(.{ .x = x, .y = point.y }, span.text, style, span.link_target);
        x += @as(u16, @intCast(textDisplayWidth(span.text)));
    }
}

fn renderTruncatedLine(
    screen: *screen_mod.Screen,
    point: screen_mod.Point,
    width: u16,
    text: []const u8,
    style: style_mod.Style,
    mode: node_mod.Node.WrapMode,
    alignment: node_mod.Node.HorizontalAlign,
) void {
    const width_usize: usize = @intCast(width);
    if (width_usize == 0) return;
    if (text.len <= width_usize) {
        screen.writeText(.{ .x = alignedX(point.x, width, text.len, alignment), .y = point.y }, text, style);
        return;
    }
    if (width_usize == 1) {
        screen.writeText(.{ .x = point.x, .y = point.y }, ".", style);
        return;
    }

    const ellipsis = "...";
    if (width_usize <= ellipsis.len) {
        screen.writeText(.{ .x = point.x, .y = point.y }, ellipsis[0..width_usize], style);
        return;
    }
    const keep = width_usize - ellipsis.len;
    var buf: [1024]u8 = undefined;
    const out = switch (mode) {
        .truncate, .truncate_end => blk: {
            @memcpy(buf[0..keep], text[0..keep]);
            @memcpy(buf[keep .. keep + ellipsis.len], ellipsis);
            break :blk buf[0 .. keep + ellipsis.len];
        },
        .truncate_start => blk: {
            @memcpy(buf[0..ellipsis.len], ellipsis);
            @memcpy(buf[ellipsis.len .. ellipsis.len + keep], text[text.len - keep ..]);
            break :blk buf[0 .. ellipsis.len + keep];
        },
        .truncate_middle => blk: {
            const left_keep = keep / 2;
            const right_keep = keep - left_keep;
            @memcpy(buf[0..left_keep], text[0..left_keep]);
            @memcpy(buf[left_keep .. left_keep + ellipsis.len], ellipsis);
            @memcpy(buf[left_keep + ellipsis.len .. left_keep + ellipsis.len + right_keep], text[text.len - right_keep ..]);
            break :blk buf[0 .. left_keep + ellipsis.len + right_keep];
        },
        .wrap, .word, .char, .none => text,
    };
    screen.writeText(.{ .x = alignedX(point.x, width, out.len, alignment), .y = point.y }, out, style);
}

fn renderModal(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.ModalData) void {
    if (rect.width < 12 or rect.height < 8) return;

    const max_width = @max(rect.width -| 6, @as(u16, 8));
    const max_height = @max(rect.height -| 4, @as(u16, 6));
    const desired_width: u16 = @intCast((@as(u32, rect.width) * 3) / 4);
    const desired_height: u16 = @intCast((@as(u32, rect.height) * 3) / 4);
    const width: u16 = @min(max_width, @max(@min(max_width, @as(u16, 56)), desired_width));
    const height: u16 = @min(max_height, @max(@min(max_height, @as(u16, 14)), desired_height));
    const x: u16 = rect.x + (rect.width -| width) / 2;
    const y_space = rect.height -| height;
    const y: u16 = rect.y + @max(y_space / 3, 1);
    const body = if (data.child) |child|
        child
    else if (data.body) |text|
        node_mod.allocNode(screen.allocator, .{
            .text = .{ .text = text, .style = data.style, .wrap = .wrap },
        }) catch return
    else
        return;
    defer if (data.child == null) screen.allocator.destroy(body);
    const box = node_mod.allocNode(screen.allocator, .{
        .box = .{
            .title = data.title,
            .style = data.style,
            .border_style = data.border_style,
            .padding_top = data.padding,
            .padding_bottom = data.padding,
            .padding_left = data.padding,
            .padding_right = data.padding,
            .child = body,
        },
    }) catch return;
    defer screen.allocator.destroy(box);
    renderNode(screen, .{ .x = x, .y = y, .width = width, .height = height }, box);
}

fn renderDivider(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.DividerData) void {
    fillRect(screen, rect, data.style);
    const glyph = data.glyph orelse switch (data.axis) {
        .horizontal => "─",
        .vertical => "│",
    };
    switch (data.axis) {
        .horizontal => {
            var x: u16 = 0;
            while (x < rect.width) : (x += 1) {
                screen.setGlyph(.{ .x = rect.x + x, .y = rect.y }, glyph, data.style);
            }
        },
        .vertical => {
            var y: u16 = 0;
            while (y < rect.height) : (y += 1) {
                screen.setGlyph(.{ .x = rect.x, .y = rect.y + y }, glyph, data.style);
            }
        },
    }
}

fn renderBadge(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.BadgeData) void {
    fillRect(screen, rect, data.style);
    if (rect.width == 0 or rect.height == 0) return;
    var writer = std.ArrayList(u8).empty;
    defer writer.deinit(screen.allocator);
    var i: u16 = 0;
    while (i < data.padding_left) : (i += 1) writer.append(screen.allocator, ' ') catch return;
    writer.appendSlice(screen.allocator, data.text) catch return;
    i = 0;
    while (i < data.padding_right) : (i += 1) writer.append(screen.allocator, ' ') catch return;
    const draw_x = alignedX(rect.x, rect.width, writer.items.len, data.alignment);
    screen.writeText(.{ .x = draw_x, .y = rect.y }, writer.items[0..@min(writer.items.len, rect.width)], data.style);
}

fn renderProgressBar(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.ProgressBarData) void {
    fillRect(screen, rect, data.style);
    if (rect.width == 0 or rect.height == 0) return;
    const width: usize = rect.width;
    const label = if (data.show_label)
        std.fmt.allocPrint(screen.allocator, " {d}%", .{percentValue(data.current, data.total)}) catch ""
    else
        "";
    defer if (label.len > 0) screen.allocator.free(label);

    const bar_width = width -| label.len;
    const filled = if (data.total == 0) 0 else @min(bar_width, (bar_width * @min(data.current, data.total)) / data.total);

    var x: usize = 0;
    while (x < bar_width) : (x += 1) {
        const style = if (x < filled) data.fill_style else data.style;
        const glyph = if (x < filled) data.full_glyph else data.empty_glyph;
        screen.setGlyph(.{ .x = rect.x + @as(u16, @intCast(x)), .y = rect.y }, glyph, style);
    }
    if (label.len > 0 and bar_width < width) {
        screen.writeText(.{ .x = rect.x + @as(u16, @intCast(bar_width)), .y = rect.y }, label, data.style);
    }
}

fn renderKeyHints(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.KeyHintsData) void {
    fillRect(screen, rect, data.style);
    if (rect.height == 0 or rect.width == 0) return;
    const content_width = joinedWidth(data.items, data.separator);
    var x = alignedX(rect.x, rect.width, content_width, data.alignment);
    const x_end = rect.x + rect.width;
    for (data.items, 0..) |item, index| {
        if (index > 0) {
            for (data.separator) |byte| {
                if (x >= x_end) return;
                screen.setCell(.{ .x = x, .y = rect.y }, byte, data.style);
                x += 1;
            }
        }
        for (item) |byte| {
            if (x >= x_end) return;
            screen.setCell(.{ .x = x, .y = rect.y }, byte, data.style);
            x += 1;
        }
    }
}

fn renderTabBar(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.TabBarData) void {
    fillRect(screen, rect, data.style);
    if (rect.height == 0 or rect.width == 0) return;
    const content_width = tabBarWidth(data.items, data.separator);
    var x = alignedX(rect.x, rect.width, content_width, data.alignment);
    const x_end = rect.x + rect.width;
    for (data.items, 0..) |item, index| {
        if (index > 0) {
            for (data.separator) |byte| {
                if (x >= x_end) return;
                screen.setCell(.{ .x = x, .y = rect.y }, byte, data.style);
                x += 1;
            }
        }
        const style = if (index == data.selected) data.selected_style else data.style;
        const prefix = if (index == data.selected) "[" else " ";
        const suffix = if (index == data.selected) "]" else " ";
        for (prefix) |byte| {
            if (x >= x_end) return;
            screen.setCell(.{ .x = x, .y = rect.y }, byte, style);
            x += 1;
        }
        for (item) |byte| {
            if (x >= x_end) return;
            screen.setCell(.{ .x = x, .y = rect.y }, byte, style);
            x += 1;
        }
        for (suffix) |byte| {
            if (x >= x_end) return;
            screen.setCell(.{ .x = x, .y = rect.y }, byte, style);
            x += 1;
        }
    }
}

fn renderScrollbar(screen: *screen_mod.Screen, rect: rect_mod.Rect, data: node_mod.Node.ScrollbarData) void {
    fillRect(screen, rect, data.style);
    if (rect.width == 0 or rect.height == 0) return;
    const axis_len: usize = switch (data.axis) {
        .vertical => rect.height,
        .horizontal => rect.width,
    };
    if (axis_len == 0) return;

    var thumb_start: usize = 0;
    var thumb_len: usize = axis_len;
    if (data.total > 0 and data.viewport > 0 and data.total > data.viewport) {
        thumb_len = @max(1, (axis_len * data.viewport) / data.total);
        const max_start = axis_len -| thumb_len;
        const max_offset = data.total -| data.viewport;
        thumb_start = if (max_offset == 0) 0 else (max_start * @min(data.offset, max_offset)) / max_offset;
    }

    switch (data.axis) {
        .vertical => {
            var y: usize = 0;
            while (y < axis_len) : (y += 1) {
                const style = if (y >= thumb_start and y < thumb_start + thumb_len) data.thumb_style else data.style;
                const glyph = if (y >= thumb_start and y < thumb_start + thumb_len) data.thumb_glyph else data.track_glyph;
                screen.setGlyph(.{ .x = rect.x, .y = rect.y + @as(u16, @intCast(y)) }, glyph, style);
            }
        },
        .horizontal => {
            var x: usize = 0;
            while (x < axis_len) : (x += 1) {
                const style = if (x >= thumb_start and x < thumb_start + thumb_len) data.thumb_style else data.style;
                const glyph = if (x >= thumb_start and x < thumb_start + thumb_len) data.thumb_glyph else data.track_glyph;
                screen.setGlyph(.{ .x = rect.x + @as(u16, @intCast(x)), .y = rect.y }, glyph, style);
            }
        },
    }
}

fn renderWrappedWords(
    screen: *screen_mod.Screen,
    point: screen_mod.Point,
    width: usize,
    line: []const u8,
    style: style_mod.Style,
    alignment: node_mod.Node.HorizontalAlign,
    row: *u16,
    max_height: u16,
) void {
    if (line.len == 0) {
        row.* += 1;
        return;
    }

    var current = std.ArrayList(u8).initCapacity(screen.allocator, width) catch return;
    defer current.deinit(screen.allocator);
    const indent_len = std.mem.indexOfNone(u8, line, " ") orelse line.len;
    if (indent_len > 0) {
        current.appendSlice(screen.allocator, line[0..@min(indent_len, width)]) catch return;
    }
    var words = std.mem.tokenizeAny(u8, line, " \t");
    while (words.next()) |word| {
        const has_non_space = std.mem.indexOfNone(u8, current.items, " ") != null;
        const needed = if (current.items.len == 0)
            word.len
        else if (has_non_space)
            current.items.len + 1 + word.len
        else
            current.items.len + word.len;
        if (needed > width and current.items.len > 0) {
            if (row.* >= max_height) return;
            screen.writeText(.{ .x = alignedX(point.x, @intCast(width), current.items.len, alignment), .y = point.y + row.* }, current.items, style);
            row.* += 1;
            current.clearRetainingCapacity();
        }
        if (current.items.len > 0 and std.mem.indexOfNone(u8, current.items, " ") != null) {
            current.append(screen.allocator, ' ') catch return;
        }
        current.appendSlice(screen.allocator, word[0..@min(word.len, width)]) catch return;
    }
    if (current.items.len > 0 and row.* < max_height) {
        screen.writeText(.{ .x = alignedX(point.x, @intCast(width), current.items.len, alignment), .y = point.y + row.* }, current.items, style);
        row.* += 1;
    }
}

fn alignedX(base_x: u16, available_width: u16, content_width: usize, alignment: node_mod.Node.HorizontalAlign) u16 {
    const available: usize = available_width;
    const used = @min(content_width, available);
    const padding = available - used;
    return switch (alignment) {
        .left => base_x,
        .center => base_x + @as(u16, @intCast(padding / 2)),
        .right => base_x + @as(u16, @intCast(padding)),
    };
}

fn sumWeights(weights: ?[]const u16, child_count: usize) u16 {
    if (weights) |provided| {
        var total: u16 = 0;
        for (provided) |weight| total +|= @max(weight, 1);
        return @max(total, 1);
    }
    return @intCast(@max(child_count, 1));
}

fn childWeight(weights: ?[]const u16, index: usize) u16 {
    if (weights) |provided| {
        if (index < provided.len) return @max(provided[index], 1);
    }
    return 1;
}

fn joinedWidth(items: []const []const u8, separator: []const u8) usize {
    var total: usize = 0;
    for (items, 0..) |item, index| {
        if (index > 0) total += textDisplayWidth(separator);
        total += textDisplayWidth(item);
    }
    return total;
}

fn tabBarWidth(items: []const []const u8, separator: []const u8) usize {
    var total: usize = 0;
    for (items, 0..) |item, index| {
        if (index > 0) total += textDisplayWidth(separator);
        total += textDisplayWidth(item) + 2;
    }
    return total;
}

fn richLineWidth(line: rich_text.Line) usize {
    var total: usize = 0;
    for (line.spans) |span| total += textDisplayWidth(span.text);
    return total;
}

fn textDisplayWidth(text: []const u8) usize {
    var total: usize = 0;
    var utf8 = std.unicode.Utf8View.init(text) catch return text.len;
    var iter = utf8.iterator();
    while (iter.nextCodepoint()) |codepoint| {
        total += codepointDisplayWidth(codepoint);
    }
    return total;
}

fn codepointDisplayWidth(codepoint: u21) usize {
    if ((codepoint >= 0x1100 and codepoint <= 0x115F) or
        (codepoint >= 0x2329 and codepoint <= 0x232A) or
        (codepoint >= 0x2E80 and codepoint <= 0xA4CF) or
        (codepoint >= 0xAC00 and codepoint <= 0xD7A3) or
        (codepoint >= 0xF900 and codepoint <= 0xFAFF) or
        (codepoint >= 0xFE10 and codepoint <= 0xFE19) or
        (codepoint >= 0xFE30 and codepoint <= 0xFE6F) or
        (codepoint >= 0xFF00 and codepoint <= 0xFF60) or
        (codepoint >= 0xFFE0 and codepoint <= 0xFFE6))
    {
        return 2;
    }
    return 1;
}

fn percentValue(current: usize, total: usize) usize {
    if (total == 0) return 0;
    return (@min(current, total) * 100) / total;
}

test "render box and text" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 20, .height = 6 });
    defer screen.deinit();
    const child = try node_mod.allocNode(std.testing.allocator, .{ .text = .{ .text = "hello" } });
    defer std.testing.allocator.destroy(child);
    const root = try node_mod.allocNode(std.testing.allocator, .{ .box = .{ .title = "t", .child = child } });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 10, .height = 4 }, root);
    const border = screen.getCell(.{ .x = 0, .y = 0 });
    try std.testing.expectEqualStrings("┌", border.glyph_bytes[0..border.glyph_len]);
    try std.testing.expectEqual(@as(u8, 'h'), screen.getCell(.{ .x = 1, .y = 1 }).byte);
}

test "render status bar keeps right-aligned content" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 20, .height = 2 });
    defer screen.deinit();
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .status_bar = .{ .left = "left", .right = "R", .style = .{} },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 10, .height = 1 }, root);
    try std.testing.expectEqual(@as(u8, 'l'), screen.getCell(.{ .x = 0, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, 'R'), screen.getCell(.{ .x = 9, .y = 0 }).byte);
}

test "render status bar centers middle content" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 20, .height = 2 });
    defer screen.deinit();
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .status_bar = .{ .left = "L", .center = "MID", .right = "R", .style = .{} },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 11, .height = 1 }, root);
    try std.testing.expectEqual(@as(u8, 'M'), screen.getCell(.{ .x = 4, .y = 0 }).byte);
}

test "render rich scroll uses span styles" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 12, .height = 2 });
    defer screen.deinit();
    const spans = try std.testing.allocator.alloc(rich_text.Span, 2);
    defer {
        std.testing.allocator.free(spans[0].text);
        std.testing.allocator.free(spans[1].text);
        std.testing.allocator.free(spans);
    }
    spans[0] = .{ .text = try std.testing.allocator.dupe(u8, "> "), .style = .{ .fg = .{ .ansi = 11 }, .bold = true } };
    spans[1] = .{ .text = try std.testing.allocator.dupe(u8, "hello"), .style = .{ .fg = .{ .ansi = 14 } } };
    const lines = try std.testing.allocator.alloc(rich_text.Line, 1);
    defer std.testing.allocator.free(lines);
    lines[0] = .{ .spans = spans };

    const root = try node_mod.allocNode(std.testing.allocator, .{
        .rich_scroll = .{ .lines = lines, .offset = 0, .style = .{} },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 10, .height = 1 }, root);
    try std.testing.expectEqual(@as(u8, '>'), screen.getCell(.{ .x = 0, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, 'h'), screen.getCell(.{ .x = 2, .y = 0 }).byte);
}

test "richLineWidth counts wide glyph width" {
    const spans = try std.testing.allocator.alloc(rich_text.Span, 1);
    defer {
        std.testing.allocator.free(spans[0].text);
        std.testing.allocator.free(spans);
    }
    spans[0] = .{ .text = try std.testing.allocator.dupe(u8, "表x"), .style = .{} };
    const line = rich_text.Line{ .spans = spans };
    try std.testing.expectEqual(@as(usize, 3), richLineWidth(line));
}

test "render vertical split draws separator row" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 10, .height = 6 });
    defer screen.deinit();
    const top = try node_mod.allocNode(std.testing.allocator, .{ .text = .{ .text = "top" } });
    defer std.testing.allocator.destroy(top);
    const bottom = try node_mod.allocNode(std.testing.allocator, .{ .text = .{ .text = "bottom" } });
    defer std.testing.allocator.destroy(bottom);
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .split = .{ .left = top, .right = bottom, .ratio_percent = 50, .axis = .vertical },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 10, .height = 6 }, root);
    const separator = screen.getCell(.{ .x = 0, .y = 3 });
    try std.testing.expectEqualStrings("─", separator.glyph_bytes[0..separator.glyph_len]);
    try std.testing.expectEqual(@as(u8, 'b'), screen.getCell(.{ .x = 0, .y = 4 }).byte);
}

test "render divider draws unicode rule" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 6, .height = 2 });
    defer screen.deinit();
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .divider = .{ .axis = .horizontal, .style = .{}, .glyph = null },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 4, .height = 1 }, root);
    const glyph = screen.getCell(.{ .x = 0, .y = 0 });
    try std.testing.expectEqualStrings("─", glyph.glyph_bytes[0..glyph.glyph_len]);
}

test "render badge applies padding" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 12, .height = 2 });
    defer screen.deinit();
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .badge = .{ .text = "RUN", .padding_left = 1, .padding_right = 1 },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 8, .height = 1 }, root);
    try std.testing.expectEqual(@as(u8, 'R'), screen.getCell(.{ .x = 1, .y = 0 }).byte);
}

test "render progress bar fills proportionally" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 16, .height = 2 });
    defer screen.deinit();
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .progress_bar = .{ .current = 50, .total = 100, .show_label = false },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 10, .height = 1 }, root);
    const filled = screen.getCell(.{ .x = 0, .y = 0 });
    const empty = screen.getCell(.{ .x = 9, .y = 0 });
    try std.testing.expectEqualStrings("█", filled.glyph_bytes[0..filled.glyph_len]);
    try std.testing.expectEqualStrings("░", empty.glyph_bytes[0..empty.glyph_len]);
}

test "render key hints joins items on one row" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 24, .height = 2 });
    defer screen.deinit();
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .key_hints = .{ .items = &.{ "Tab", "Ctrl+D" }, .style = .{}, .separator = "  " },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 20, .height = 1 }, root);
    try std.testing.expectEqual(@as(u8, 'T'), screen.getCell(.{ .x = 0, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, 'C'), screen.getCell(.{ .x = 5, .y = 0 }).byte);
}

test "render box respects padding" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 16, .height = 8 });
    defer screen.deinit();
    const child = try node_mod.allocNode(std.testing.allocator, .{ .text = .{ .text = "x" } });
    defer std.testing.allocator.destroy(child);
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .box = .{
            .title = "pad",
            .style = .{},
            .border_style = .classic,
            .padding_top = 1,
            .padding_left = 2,
            .child = child,
        },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 10, .height = 6 }, root);
    try std.testing.expectEqual(@as(u8, 'x'), screen.getCell(.{ .x = 3, .y = 2 }).byte);
}

test "render box respects margin" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 16, .height = 8 });
    defer screen.deinit();
    const child = try node_mod.allocNode(std.testing.allocator, .{ .text = .{ .text = "x" } });
    defer std.testing.allocator.destroy(child);
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .box = .{
            .title = "m",
            .style = .{},
            .border_style = .classic,
            .margin_top = 1,
            .margin_left = 2,
            .child = child,
        },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 12, .height = 6 }, root);
    try std.testing.expectEqual(@as(u8, '+'), screen.getCell(.{ .x = 2, .y = 1 }).byte);
}

test "render box fills interior background" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 12, .height = 6 });
    defer screen.deinit();
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .box = .{
            .style = .{
                .fg = .{ .ansi = 15 },
                .bg = .{ .rgb = .{ .r = 18, .g = 52, .b = 86 } },
            },
        },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 8, .height = 4 }, root);
    try std.testing.expectEqual(root.box.style.bg.rgb.r, screen.getCell(.{ .x = 3, .y = 2 }).style.bg.rgb.r);
}

test "render text supports center alignment" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 12, .height = 2 });
    defer screen.deinit();
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .text = .{ .text = "abc", .wrap = .none, .alignment = .center },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 9, .height = 1 }, root);
    try std.testing.expectEqual(@as(u8, 'a'), screen.getCell(.{ .x = 3, .y = 0 }).byte);
}

test "render tab bar highlights selected item" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 24, .height = 2 });
    defer screen.deinit();
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .tab_bar = .{ .items = &.{ "one", "two" }, .selected = 1 },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 20, .height = 1 }, root);
    try std.testing.expectEqual(@as(u8, '['), screen.getCell(.{ .x = 7, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, 't'), screen.getCell(.{ .x = 8, .y = 0 }).byte);
}

test "render scrollbar shows thumb" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 4, .height = 8 });
    defer screen.deinit();
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .scrollbar = .{ .offset = 4, .viewport = 4, .total = 12 },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 1, .height = 8 }, root);
    const thumb = screen.getCell(.{ .x = 0, .y = 3 });
    try std.testing.expectEqualStrings("█", thumb.glyph_bytes[0..thumb.glyph_len]);
}

test "render hstack supports weights" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 16, .height = 2 });
    defer screen.deinit();
    const left = try node_mod.allocNode(std.testing.allocator, .{ .text = .{ .text = "L" } });
    defer std.testing.allocator.destroy(left);
    const right = try node_mod.allocNode(std.testing.allocator, .{ .text = .{ .text = "R" } });
    defer std.testing.allocator.destroy(right);
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .hstack = .{ .children = &.{ left, right }, .gap = 1, .weights = &.{ 3, 1 } },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 9, .height = 1 }, root);
    try std.testing.expectEqual(@as(u8, 'L'), screen.getCell(.{ .x = 0, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, 'R'), screen.getCell(.{ .x = 7, .y = 0 }).byte);
}

test "render text supports truncate modes" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 12, .height = 4 });
    defer screen.deinit();

    const end_node = try node_mod.allocNode(std.testing.allocator, .{
        .text = .{ .text = "HelloWorld", .wrap = .truncate_end },
    });
    defer std.testing.allocator.destroy(end_node);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 6, .height = 1 }, end_node);
    try std.testing.expectEqual(@as(u8, '.'), screen.getCell(.{ .x = 5, .y = 0 }).byte);

    const start_node = try node_mod.allocNode(std.testing.allocator, .{
        .text = .{ .text = "HelloWorld", .wrap = .truncate_start },
    });
    defer std.testing.allocator.destroy(start_node);
    renderNode(&screen, .{ .x = 0, .y = 1, .width = 6, .height = 1 }, start_node);
    try std.testing.expectEqual(@as(u8, '.'), screen.getCell(.{ .x = 0, .y = 1 }).byte);

    const mid_node = try node_mod.allocNode(std.testing.allocator, .{
        .text = .{ .text = "HelloWorld", .wrap = .truncate_middle },
    });
    defer std.testing.allocator.destroy(mid_node);
    renderNode(&screen, .{ .x = 0, .y = 2, .width = 6, .height = 1 }, mid_node);
    try std.testing.expectEqual(@as(u8, '.'), screen.getCell(.{ .x = 2, .y = 2 }).byte);
}

test "render text supports word wrap and none modes" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 16, .height = 4 });
    defer screen.deinit();

    const word_node = try node_mod.allocNode(std.testing.allocator, .{
        .text = .{ .text = "alpha beta gamma", .wrap = .word },
    });
    defer std.testing.allocator.destroy(word_node);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 8, .height = 3 }, word_node);
    try std.testing.expectEqual(@as(u8, 'a'), screen.getCell(.{ .x = 0, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, 'b'), screen.getCell(.{ .x = 0, .y = 1 }).byte);

    const none_node = try node_mod.allocNode(std.testing.allocator, .{
        .text = .{ .text = "abcdefghij", .wrap = .none },
    });
    defer std.testing.allocator.destroy(none_node);
    renderNode(&screen, .{ .x = 0, .y = 3, .width = 4, .height = 1 }, none_node);
    try std.testing.expectEqual(@as(u8, 'd'), screen.getCell(.{ .x = 3, .y = 3 }).byte);
}

test "render transform text supports hanging indent" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 12, .height = 4 });
    defer screen.deinit();
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .transform_text = .{
            .text = "A\nB",
            .mode = .{ .hanging_indent = 2 },
        },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 8, .height = 3 }, root);
    try std.testing.expectEqual(@as(u8, 'A'), screen.getCell(.{ .x = 0, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, ' '), screen.getCell(.{ .x = 0, .y = 1 }).byte);
    try std.testing.expectEqual(@as(u8, 'B'), screen.getCell(.{ .x = 2, .y = 1 }).byte);
}

test "render input supports multiline content" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 20, .height = 4 });
    defer screen.deinit();
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .input = .{ .prompt = "> ", .value = "one\ntwo", .cursor = 5, .focused = true },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 12, .height = 3 }, root);
    try std.testing.expectEqual(@as(u8, '>'), screen.getCell(.{ .x = 0, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, 'o'), screen.getCell(.{ .x = 2, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, ' '), screen.getCell(.{ .x = 0, .y = 1 }).byte);
    try std.testing.expectEqual(@as(u8, 't'), screen.getCell(.{ .x = 2, .y = 1 }).byte);
}

test "render input highlights mid-line cursor position" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 12, .height = 1 });
    defer screen.deinit();

    const node = node_mod.Node{
        .input = .{
            .prompt = "> ",
            .value = "abcdef",
            .cursor = 3,
            .focused = true,
            .style = .{},
        },
    };
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 12, .height = 1 }, &node);

    const cursor_cell = screen.getCell(.{ .x = 5, .y = 0 });
    try std.testing.expectEqual(@as(u8, 'd'), cursor_cell.glyph_bytes[0]);
    try std.testing.expect(cursor_cell.style.bold);
    try std.testing.expectEqual(@as(u8, 250), cursor_cell.style.bg.rgb.r);
    try std.testing.expectEqual(@as(u8, 204), cursor_cell.style.bg.rgb.g);
    try std.testing.expectEqual(@as(u8, 21), cursor_cell.style.bg.rgb.b);
}

test "render text area shows placeholder when empty" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 20, .height = 2 });
    defer screen.deinit();
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .text_area = .{
            .prompt = "> ",
            .value = "",
            .cursor = 0,
            .focused = false,
            .placeholder = "type here",
        },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 14, .height = 1 }, root);
    try std.testing.expectEqual(@as(u8, '>'), screen.getCell(.{ .x = 0, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, 't'), screen.getCell(.{ .x = 2, .y = 0 }).byte);
}

test "render hstack places children side by side" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 20, .height = 4 });
    defer screen.deinit();
    const left = try node_mod.allocNode(std.testing.allocator, .{ .text = .{ .text = "L" } });
    defer std.testing.allocator.destroy(left);
    const right = try node_mod.allocNode(std.testing.allocator, .{ .text = .{ .text = "R" } });
    defer std.testing.allocator.destroy(right);
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .hstack = .{ .children = &.{ left, right }, .gap = 1 },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 6, .height = 1 }, root);
    try std.testing.expectEqual(@as(u8, 'L'), screen.getCell(.{ .x = 0, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, 'R'), screen.getCell(.{ .x = 3, .y = 0 }).byte);
}

test "render list respects offset and markers" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 16, .height = 4 });
    defer screen.deinit();
    const root = try node_mod.allocNode(std.testing.allocator, .{
        .list = .{
            .items = &.{ "one", "two", "three" },
            .selected = 2,
            .offset = 1,
            .marker = "* ",
            .unselected_marker = "- ",
        },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 10, .height = 2 }, root);
    try std.testing.expectEqual(@as(u8, '-'), screen.getCell(.{ .x = 0, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, 't'), screen.getCell(.{ .x = 2, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, '*'), screen.getCell(.{ .x = 0, .y = 1 }).byte);
    try std.testing.expectEqual(@as(u8, 't'), screen.getCell(.{ .x = 2, .y = 1 }).byte);
}

test "render text clears trailing cells in rect" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 12, .height = 2 });
    defer screen.deinit();
    screen.writeText(.{ .x = 0, .y = 0 }, "XXXXXXXXXXXX", .{});

    const root = try node_mod.allocNode(std.testing.allocator, .{
        .text = .{ .text = "abc", .style = .{} },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 8, .height = 1 }, root);

    try std.testing.expectEqual(@as(u8, 'a'), screen.getCell(.{ .x = 0, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, 'c'), screen.getCell(.{ .x = 2, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, ' '), screen.getCell(.{ .x = 6, .y = 0 }).byte);
}

test "render text area clears stale cells before drawing placeholder" {
    var screen = try screen_mod.Screen.init(std.testing.allocator, .{ .width = 20, .height = 2 });
    defer screen.deinit();
    screen.writeText(.{ .x = 0, .y = 0 }, "XXXXXXXXXXXXXXXXXXXX", .{});

    const root = try node_mod.allocNode(std.testing.allocator, .{
        .text_area = .{
            .prompt = "> ",
            .value = "",
            .cursor = 0,
            .focused = false,
            .placeholder = "type",
        },
    });
    defer std.testing.allocator.destroy(root);
    renderNode(&screen, .{ .x = 0, .y = 0, .width = 10, .height = 1 }, root);

    try std.testing.expectEqual(@as(u8, '>'), screen.getCell(.{ .x = 0, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, 't'), screen.getCell(.{ .x = 2, .y = 0 }).byte);
    try std.testing.expectEqual(@as(u8, ' '), screen.getCell(.{ .x = 9, .y = 0 }).byte);
}
