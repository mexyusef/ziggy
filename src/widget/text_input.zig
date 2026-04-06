const std = @import("std");
const parser = @import("../terminal/parser.zig");
const editor_mod = @import("editor.zig");
const input = @import("input.zig");
const autocomplete_popup = @import("autocomplete_popup.zig");
const completion = @import("completion.zig");
const node_mod = @import("node.zig");
const style_mod = @import("../style/style.zig");

pub const State = struct {
    editor: editor_mod.Editor,
    prompt: []const u8 = "> ",
    placeholder: ?[]const u8 = null,
    focused: bool = true,
    style: style_mod.Style = .{},
    suggestions: []const completion.Item = &.{},
    completion_state: completion.State = .{},

    pub fn init(allocator: std.mem.Allocator, initial: []const u8) !State {
        return .{ .editor = try editor_mod.Editor.init(allocator, initial) };
    }

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        self.editor.deinit(allocator);
        self.completion_state.deinit(allocator);
    }

    pub fn setSuggestions(self: *State, items: []const completion.Item) void {
        self.suggestions = items;
    }

    pub fn handleKey(self: *State, allocator: std.mem.Allocator, key: parser.Key) !void {
        switch (key) {
            .char => |c| try self.editor.insertChar(allocator, c),
            .backspace => try self.editor.backspace(allocator),
            .delete => try self.editor.deleteForward(allocator),
            .left => self.editor.moveLeft(),
            .right => self.editor.moveRight(),
            .word_left => self.editor.moveWordLeft(),
            .word_right => self.editor.moveWordRight(),
            .home, .ctrl_a => self.editor.moveHome(),
            .end, .ctrl_e => self.editor.moveEnd(),
            .ctrl_u => try self.editor.deleteToStart(allocator),
            .ctrl_k => try self.editor.deleteToEnd(allocator),
            .ctrl_w => try self.editor.deletePreviousWord(allocator),
            .ctrl_space => try completion.update(allocator, &self.completion_state, &self.editor, self.suggestions),
            .tab => {
                if (self.completion_state.visible) {
                    _ = try self.completion_state.applyCurrent(allocator, &self.editor);
                }
            },
            .up, .ctrl_p => self.completion_state.selectPrevious(),
            .down, .ctrl_n => self.completion_state.selectNext(),
            .escape => self.completion_state.visible = false,
            else => {},
        }
    }

    pub fn buildNode(self: *const State, allocator: std.mem.Allocator) !*const node_mod.Node {
        const input_node = try input.build(allocator, self.prompt, try allocator.dupe(u8, self.editor.value), self.editor.cursor, self.focused, self.style);
        const popup = try autocomplete_popup.build(allocator, &self.completion_state, .{ .hint = "Tab accepts" });
        if (popup) |overlay| return try node_mod.allocNode(allocator, .{ .overlay = .{ .base = input_node, .overlay = overlay } });
        return input_node;
    }
};

test "text input reacts to editing keys" {
    var state = try State.init(std.testing.allocator, "");
    defer state.deinit(std.testing.allocator);
    try state.handleKey(std.testing.allocator, .{ .char = 'a' });
    try state.handleKey(std.testing.allocator, .{ .char = 'b' });
    try std.testing.expectEqualStrings("ab", state.editor.value);
}
