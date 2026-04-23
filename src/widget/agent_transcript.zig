const std = @import("std");
const transcript = @import("transcript.zig");
const box = @import("box.zig");
const rich_markdown = @import("../format/rich_markdown.zig");
const style_mod = @import("../style/style.zig");
const node_mod = @import("node.zig");

pub const Role = enum {
    system,
    user,
    assistant,
    tool,
    failure,
};

pub const Message = struct {
    role: Role,
    body: []const u8,
    title: ?[]const u8 = null,
    selected: bool = false,
    meta: ?[]const u8 = null,
    badge: ?[]const u8 = null,
};

pub const Theme = struct {
    style: style_mod.Style = .{},
    selected_title_style: style_mod.Style = .{ .bold = true },
    system_style: style_mod.Style = .{ .fg = .{ .ansi = 14 }, .bold = true },
    user_style: style_mod.Style = .{ .fg = .{ .ansi = 11 }, .bold = true },
    assistant_style: style_mod.Style = .{ .fg = .{ .ansi = 10 }, .bold = true },
    tool_style: style_mod.Style = .{ .fg = .{ .ansi = 13 }, .bold = true },
    error_style: style_mod.Style = .{ .fg = .{ .ansi = 9 }, .bold = true },
    meta_style: style_mod.Style = .{ .dim = true },
    badge_style: style_mod.Style = .{ .bold = true },
    separator_style: style_mod.Style = .{ .dim = true },
    markdown_theme: rich_markdown.Theme = .{},
};

pub const Options = struct {
    title: ?[]const u8 = "Transcript",
    width: usize = 80,
    offset: usize = 0,
    viewport_height: usize = 0,
    follow_end: bool = true,
    theme: Theme = .{},
};

pub fn build(
    allocator: std.mem.Allocator,
    messages: []const Message,
    options: Options,
) !struct {
    node: *const node_mod.Node,
    entry_starts: []const usize,
    offset: usize,
} {
    const entries = try toEntries(allocator, messages, options.theme);
    defer allocator.free(entries);

    const resolved_offset = if (options.follow_end)
        try transcript.followOffset(allocator, entries, options.width, options.viewport_height)
    else
        options.offset;
    const rendered = try transcript.renderLines(allocator, entries, options.width);
    defer richDeinit(allocator, rendered.lines, rendered.entry_starts);

    const doc = try transcript.build(allocator, entries, resolved_offset, options.width, options.theme.style);
    const wrapped = try box.buildWithOptions(allocator, options.title, doc, .{
        .style = options.theme.style,
        .padding_top = 0,
        .padding_bottom = 0,
        .padding_left = 0,
        .padding_right = 0,
    });
    return .{
        .node = wrapped,
        .entry_starts = try allocator.dupe(usize, rendered.entry_starts),
        .offset = resolved_offset,
    };
}

fn toEntries(
    allocator: std.mem.Allocator,
    messages: []const Message,
    theme: Theme,
) ![]transcript.Entry {
    const entries = try allocator.alloc(transcript.Entry, messages.len);
    for (messages, 0..) |message, index| {
        entries[index] = .{
            .title = message.title orelse roleTitle(message.role),
            .body = message.body,
            .selected = message.selected,
            .badge = message.badge orelse roleBadge(message.role),
            .meta = message.meta,
            .title_style = roleStyle(theme, message.role),
            .selected_title_style = theme.selected_title_style,
            .badge_style = theme.badge_style,
            .meta_style = theme.meta_style,
            .separator_style = theme.separator_style,
            .body_theme = theme.markdown_theme,
        };
    }
    return entries;
}

fn roleTitle(role: Role) []const u8 {
    return switch (role) {
        .system => "System",
        .user => "User",
        .assistant => "Assistant",
        .tool => "Tool",
        .failure => "Error",
    };
}

fn roleBadge(role: Role) []const u8 {
    return switch (role) {
        .system => "SYS",
        .user => "USER",
        .assistant => "AI",
        .tool => "TOOL",
        .failure => "ERR",
    };
}

fn roleStyle(theme: Theme, role: Role) style_mod.Style {
    return switch (role) {
        .system => theme.system_style,
        .user => theme.user_style,
        .assistant => theme.assistant_style,
        .tool => theme.tool_style,
        .failure => theme.error_style,
    };
}

fn richDeinit(allocator: std.mem.Allocator, lines: []const @import("../format/rich_text.zig").Line, entry_starts: []const usize) void {
    @import("../format/rich_text.zig").freeLines(allocator, lines);
    allocator.free(entry_starts);
}

test "agent transcript maps roles into transcript entries" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const messages = [_]Message{
        .{ .role = .system, .body = "system note" },
        .{ .role = .assistant, .body = "reply", .selected = true, .meta = "step 2/3" },
    };
    const built = try build(alloc, &messages, .{ .width = 48, .viewport_height = 8 });
    try std.testing.expect(built.node.* == .box);
    try std.testing.expectEqual(@as(usize, 2), built.entry_starts.len);
}
