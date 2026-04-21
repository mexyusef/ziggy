const std = @import("std");
const style_mod = @import("../style/style.zig");
const focus_mod = @import("focus.zig");
const rich_text = @import("../format/rich_text.zig");
const border_mod = @import("../style/border.zig");

pub const Node = union(enum) {
    empty,
    spacer: SpacerData,
    divider: DividerData,
    badge: BadgeData,
    progress_bar: ProgressBarData,
    key_hints: KeyHintsData,
    tab_bar: TabBarData,
    scrollbar: ScrollbarData,
    text: TextData,
    transform_text: TransformTextData,
    box: BoxData,
    vstack: VStackData,
    hstack: HStackData,
    split: SplitData,
    status_bar: StatusBarData,
    input: InputData,
    text_area: TextAreaData,
    list: ListData,
    scroll: ScrollData,
    rich_scroll: RichScrollData,
    overlay: OverlayData,
    modal: ModalData,

    pub const TextData = struct {
        text: []const u8,
        style: style_mod.Style = .{},
        wrap: WrapMode = .wrap,
        alignment: HorizontalAlign = .left,
    };

    pub const TransformMode = union(enum) {
        uppercase,
        lowercase,
        hanging_indent: u16,
    };

    pub const TransformTextData = struct {
        text: []const u8,
        style: style_mod.Style = .{},
        wrap: WrapMode = .wrap,
        alignment: HorizontalAlign = .left,
        mode: TransformMode = .uppercase,
    };

    pub const SpacerData = struct {
        style: style_mod.Style = .{},
    };

    pub const DividerData = struct {
        axis: SplitAxis = .horizontal,
        style: style_mod.Style = .{},
        glyph: ?[]const u8 = null,
    };

    pub const BadgeData = struct {
        text: []const u8,
        style: style_mod.Style = .{ .bold = true },
        padding_left: u16 = 1,
        padding_right: u16 = 1,
        alignment: HorizontalAlign = .left,
    };

    pub const ProgressBarData = struct {
        current: usize = 0,
        total: usize = 100,
        style: style_mod.Style = .{},
        fill_style: style_mod.Style = .{ .bold = true },
        empty_glyph: []const u8 = "░",
        full_glyph: []const u8 = "█",
        show_label: bool = true,
    };

    pub const KeyHintsData = struct {
        items: []const []const u8,
        style: style_mod.Style = .{},
        separator: []const u8 = "  ",
        alignment: HorizontalAlign = .left,
    };

    pub const TabBarData = struct {
        items: []const []const u8,
        selected: usize = 0,
        style: style_mod.Style = .{},
        selected_style: style_mod.Style = .{ .bold = true },
        separator: []const u8 = "  ",
        alignment: HorizontalAlign = .left,
    };

    pub const ScrollbarAxis = enum {
        vertical,
        horizontal,
    };

    pub const ScrollbarData = struct {
        axis: ScrollbarAxis = .vertical,
        offset: usize = 0,
        viewport: usize = 0,
        total: usize = 0,
        style: style_mod.Style = .{},
        thumb_style: style_mod.Style = .{ .bold = true },
        track_glyph: []const u8 = "│",
        thumb_glyph: []const u8 = "█",
    };

    pub const WrapMode = enum {
        wrap,
        word,
        char,
        none,
        truncate,
        truncate_start,
        truncate_middle,
        truncate_end,
    };

    pub const BoxData = struct {
        title: ?[]const u8 = null,
        title_align: HorizontalAlign = .left,
        style: style_mod.Style = .{},
        border_style: border_mod.BorderStyle = .single,
        margin_top: u16 = 0,
        margin_bottom: u16 = 0,
        margin_left: u16 = 0,
        margin_right: u16 = 0,
        padding_top: u16 = 0,
        padding_bottom: u16 = 0,
        padding_left: u16 = 0,
        padding_right: u16 = 0,
        child: ?*const Node = null,
        focus: focus_mod.FocusState = .{},
    };

    pub const VStackData = struct {
        children: []const *const Node,
        gap: u16 = 0,
        weights: ?[]const u16 = null,
    };

    pub const HStackData = struct {
        children: []const *const Node,
        gap: u16 = 0,
        weights: ?[]const u16 = null,
    };

    pub const SplitData = struct {
        left: *const Node,
        right: *const Node,
        ratio_percent: u8 = 50,
        axis: SplitAxis = .horizontal,
    };

    pub const SplitAxis = enum {
        horizontal,
        vertical,
    };

    pub const StatusBarData = struct {
        left: []const u8,
        right: []const u8,
        center: ?[]const u8 = null,
        style: style_mod.Style = .{},
        left_style: ?style_mod.Style = null,
        center_style: ?style_mod.Style = null,
        right_style: ?style_mod.Style = null,
    };

    pub const InputData = struct {
        prompt: []const u8 = "> ",
        value: []const u8,
        cursor: usize = 0,
        focused: bool = true,
        style: style_mod.Style = .{},
        focus: focus_mod.FocusState = .{},
    };

    pub const TextAreaData = struct {
        prompt: []const u8 = "> ",
        value: []const u8,
        cursor: usize = 0,
        selection_start: ?usize = null,
        selection_end: ?usize = null,
        current_line: ?usize = null,
        wrap_lines: bool = false,
        offset_line: usize = 0,
        offset_column: usize = 0,
        scroll_margin: usize = 1,
        focused: bool = true,
        placeholder: ?[]const u8 = null,
        style: style_mod.Style = .{},
        current_line_style: ?style_mod.Style = null,
        selection_style: style_mod.Style = .{ .fg = .{ .ansi = 15 }, .bg = .{ .ansi = 4 }, .bold = true },
        focus: focus_mod.FocusState = .{},
    };

    pub const ListData = struct {
        items: []const []const u8,
        selected: usize = 0,
        offset: usize = 0,
        marker: []const u8 = "> ",
        unselected_marker: []const u8 = "  ",
        style: style_mod.Style = .{},
        selected_style: style_mod.Style = .{ .bold = true },
        focus: focus_mod.FocusState = .{},
    };

    pub const ScrollData = struct {
        lines: []const []const u8,
        offset: usize = 0,
        style: style_mod.Style = .{},
    };

    pub const RichScrollData = struct {
        lines: []const rich_text.Line,
        offset: usize = 0,
        style: style_mod.Style = .{},
        alignment: HorizontalAlign = .left,
    };

    pub const OverlayData = struct {
        base: *const Node,
        overlay: *const Node,
    };

    pub const ModalData = struct {
        title: []const u8,
        body: ?[]const u8 = null,
        child: ?*const Node = null,
        style: style_mod.Style = .{},
        border_style: border_mod.BorderStyle = .double,
    };

    pub const HorizontalAlign = enum {
        left,
        center,
        right,
    };
};

pub fn allocNode(allocator: std.mem.Allocator, node: Node) !*const Node {
    const ptr = try allocator.create(Node);
    ptr.* = node;
    return ptr;
}
