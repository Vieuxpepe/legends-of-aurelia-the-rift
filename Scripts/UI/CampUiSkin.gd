## Shared camp visual tokens + style helpers for hub UI (camp menu, dragon ranch, etc.).
extends RefCounted

const CAMP_PANEL_BG := Color(0.13, 0.097, 0.068, 0.88)
const CAMP_PANEL_BG_ALT := Color(0.17, 0.126, 0.083, 0.94)
const CAMP_PANEL_BG_SOFT := Color(0.08, 0.061, 0.043, 0.82)
const CAMP_BORDER := Color(0.82, 0.66, 0.24, 0.96)
const CAMP_BORDER_SOFT := Color(0.47, 0.38, 0.17, 0.94)
const CAMP_TEXT := Color(0.94, 0.91, 0.84, 1.0)
const CAMP_MUTED := Color(0.73, 0.68, 0.60, 1.0)
const CAMP_ACCENT_CYAN := Color(0.48, 0.87, 1.0, 1.0)
const CAMP_ACCENT_GREEN := Color(0.40, 0.94, 0.54, 1.0)
const CAMP_ACTION_PRIMARY := Color(0.76, 0.58, 0.19, 0.96)
const CAMP_ACTION_SECONDARY := Color(0.28, 0.21, 0.13, 0.94)

## Default width for custom tooltip panels (word-wrapped Label inside camp panel).
const RANCH_TOOLTIP_MAX_WIDTH := 320.0

## Unit dossier / dragon mini-dossier stat bars (matches camp_menu unit info cap & tiers).
const UNIT_DOSSIER_STAT_BAR_CAP := 50.0
const UNIT_DOSSIER_STAT_TIER_CYAN := Color(0.28, 0.88, 1.0, 1.0)
const UNIT_DOSSIER_STAT_TIER_PURPLE := Color(0.76, 0.48, 1.0, 1.0)
const UNIT_DOSSIER_STAT_TIER_ORANGE := Color(1.0, 0.64, 0.22, 1.0)
const UNIT_DOSSIER_STAT_TIER_WHITE := Color(0.96, 0.96, 0.98, 1.0)


static func make_panel_style(
	bg: Color = CAMP_PANEL_BG,
	border: Color = CAMP_BORDER,
	radius: int = 24,
	shadow_size: int = 12
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 6)
	return style


## Break long plain tooltip strings into lines (helps default engine tooltips that do not wrap).
static func plain_tooltip_word_wrap(text: String, max_chars_per_line: int = 52) -> String:
	var t := str(text).strip_edges()
	if t.is_empty():
		return ""

	var words: PackedStringArray = t.split(" ", false)
	if words.is_empty():
		return t

	var lines: PackedStringArray = PackedStringArray()
	var line: String = ""

	for w in words:
		var wstr := str(w)
		var try_line: String = (line + " " + wstr).strip_edges() if line != "" else wstr
		if try_line.length() <= max_chars_per_line:
			line = try_line
		else:
			if line != "":
				lines.append(line)
			line = wstr

	if line != "":
		lines.append(line)

	return "\n".join(lines)


## Rich panel tooltip used by _make_custom_tooltip on ranch controls (wraps + camp styling).
static func make_wrapped_tooltip_panel(for_text: String, max_width: float = RANCH_TOOLTIP_MAX_WIDTH) -> Control:
	var stripped := str(for_text).strip_edges()
	if stripped.is_empty():
		return Control.new()

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		make_panel_style(CAMP_PANEL_BG_ALT, CAMP_BORDER_SOFT, 14, 6)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var label := Label.new()
	label.text = stripped
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(max_width, 0.0)
	label.add_theme_color_override("font_color", CAMP_TEXT)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.01, 0.92))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_font_size_override("font_size", 14)
	margin.add_child(label)

	return panel


static func make_button_style(
	fill: Color,
	border: Color,
	radius: int = 18,
	shadow_size: int = 6,
	content_margin_h: int = 0,
	content_margin_v: int = 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 4)
	if content_margin_h > 0:
		style.content_margin_left = content_margin_h
		style.content_margin_right = content_margin_h
	if content_margin_v > 0:
		style.content_margin_top = content_margin_v
		style.content_margin_bottom = content_margin_v
	return style


static func style_button(
	button: Button,
	primary: bool = false,
	font_size: int = 22,
	min_height: float = 52.0,
	content_margin_h: int = 18,
	content_margin_v: int = 12
) -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size.y = min_height
	button.add_theme_font_size_override("font_size", font_size)
	var base_font_color := Color(0.12, 0.09, 0.04, 1.0) if primary else CAMP_TEXT
	button.add_theme_color_override("font_color", base_font_color)
	button.add_theme_color_override("font_hover_color", Color(0.08, 0.06, 0.03, 1.0) if primary else Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(0.08, 0.06, 0.03, 1.0) if primary else CAMP_TEXT)
	button.add_theme_color_override("font_focus_color", base_font_color)
	var base_fill := CAMP_ACTION_PRIMARY if primary else CAMP_ACTION_SECONDARY
	var base_border := CAMP_ACCENT_CYAN if primary else CAMP_BORDER_SOFT
	var mh: int = content_margin_h
	var mv: int = content_margin_v
	button.add_theme_stylebox_override("normal", make_button_style(base_fill, base_border, 18, 6, mh, mv))
	button.add_theme_stylebox_override(
		"hover",
		make_button_style(base_fill.lightened(0.08) if primary else base_fill.lightened(0.12), CAMP_BORDER, 18, 6, mh, mv)
	)
	button.add_theme_stylebox_override(
		"pressed",
		make_button_style(base_fill.darkened(0.08), CAMP_ACCENT_CYAN if primary else CAMP_BORDER, 18, 6, mh, mv)
	)
	button.add_theme_stylebox_override("focus", make_button_style(base_fill, CAMP_ACCENT_CYAN, 18, 6, mh, mv))
	button.add_theme_stylebox_override(
		"disabled",
		make_button_style(base_fill.darkened(0.10), base_border.darkened(0.12), 18, 0, mh, mv)
	)


static func style_rich_label(
	label: Control,
	font_size: int = 18,
	panel_bg: Color = CAMP_PANEL_BG_SOFT,
	border: Color = CAMP_BORDER_SOFT,
	scrollable: bool = false
) -> void:
	if label == null:
		return
	if label is RichTextLabel:
		var rtl: RichTextLabel = label as RichTextLabel
		rtl.fit_content = false
		rtl.scroll_active = scrollable
		rtl.scroll_following = false
		rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtl.mouse_filter = Control.MOUSE_FILTER_STOP if scrollable else Control.MOUSE_FILTER_IGNORE
		rtl.add_theme_font_size_override("normal_font_size", font_size)
		rtl.add_theme_color_override("default_color", CAMP_TEXT)
		rtl.add_theme_stylebox_override("normal", make_panel_style(panel_bg, border, 18, 0))
		return
	if label is Label:
		var plain: Label = label as Label
		plain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		plain.add_theme_font_size_override("font_size", font_size)
		plain.add_theme_color_override("font_color", CAMP_TEXT)
		plain.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.01, 0.96))
		plain.add_theme_constant_override("outline_size", 2)
		plain.add_theme_stylebox_override("normal", make_panel_style(panel_bg, border, 18, 0))


## Body text without an inset panel (avoids stacked boxes in narrow rails).
static func style_rich_label_flat(label: Control, font_size: int = 16, scrollable: bool = false) -> void:
	if label == null or not label is RichTextLabel:
		return
	var rtl := label as RichTextLabel
	rtl.fit_content = true
	rtl.scroll_active = scrollable
	rtl.scroll_following = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.mouse_filter = Control.MOUSE_FILTER_STOP if scrollable else Control.MOUSE_FILTER_IGNORE
	rtl.add_theme_font_size_override("normal_font_size", font_size)
	rtl.add_theme_color_override("default_color", CAMP_TEXT)
	rtl.add_theme_stylebox_override("normal", StyleBoxEmpty.new())


static func style_label(label: Label, color: Color = CAMP_TEXT, font_size: int = 18, outline_size: int = 2) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.01, 0.96))
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_font_size_override("font_size", font_size)


static func style_panel(panel: Panel, bg: Color = CAMP_PANEL_BG_SOFT, border: Color = CAMP_BORDER_SOFT, radius: int = 18, shadow_size: int = 8) -> void:
	style_panel_surface(panel, bg, border, radius, shadow_size)


## Panel + PanelContainer both use the "panel" stylebox; use from code-built UI that must size in containers.
static func style_panel_surface(surface: Control, bg: Color = CAMP_PANEL_BG_SOFT, border: Color = CAMP_BORDER_SOFT, radius: int = 18, shadow_size: int = 8) -> void:
	if surface == null:
		return
	var style := make_panel_style(bg, border, radius, shadow_size)
	if surface is Panel:
		(surface as Panel).add_theme_stylebox_override("panel", style)
	elif surface is PanelContainer:
		(surface as PanelContainer).add_theme_stylebox_override("panel", style)


static func style_option_button(option: OptionButton, font_size: int = 16, min_height: float = 40.0) -> void:
	if option == null:
		return
	option.focus_mode = Control.FOCUS_ALL
	option.mouse_filter = Control.MOUSE_FILTER_STOP
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	option.custom_minimum_size.y = min_height
	option.add_theme_font_size_override("font_size", font_size)
	option.add_theme_color_override("font_color", CAMP_TEXT)
	option.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	option.add_theme_color_override("font_pressed_color", CAMP_TEXT)
	option.add_theme_color_override("font_focus_color", CAMP_TEXT)
	var normal_style := make_button_style(Color(0.20, 0.15, 0.09, 0.96), CAMP_BORDER_SOFT, 14, 4)
	var hover_style := make_button_style(Color(0.24, 0.18, 0.10, 0.98), CAMP_BORDER, 14, 4)
	var pressed_style := make_button_style(Color(0.16, 0.12, 0.08, 0.98), CAMP_ACCENT_CYAN, 14, 4)
	option.add_theme_stylebox_override("normal", normal_style)
	option.add_theme_stylebox_override("hover", hover_style)
	option.add_theme_stylebox_override("pressed", pressed_style)
	option.add_theme_stylebox_override("focus", pressed_style)
	option.add_theme_stylebox_override("disabled", normal_style)


## stop_mouse: when true, uses MOUSE_FILTER_STOP (Godot may swallow clicks meant for child controls).
## Use stop_mouse = false for scroll areas that contain buttons/menus (see ranch info card).
static func style_scroll(scroll: ScrollContainer, stop_mouse: bool = true) -> void:
	if scroll == null:
		return
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP if stop_mouse else Control.MOUSE_FILTER_PASS
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var vbar := scroll.get_v_scroll_bar()
	if vbar != null:
		vbar.custom_minimum_size.x = 10.0
		vbar.add_theme_stylebox_override("scroll", make_button_style(Color(0.09, 0.07, 0.05, 0.72), Color(0, 0, 0, 0), 8, 0))
		vbar.add_theme_stylebox_override("grabber", make_button_style(CAMP_BORDER_SOFT, CAMP_BORDER_SOFT, 8, 0))
		vbar.add_theme_stylebox_override("grabber_highlight", make_button_style(CAMP_BORDER, CAMP_BORDER, 8, 0))
		vbar.add_theme_stylebox_override("grabber_pressed", make_button_style(CAMP_ACCENT_CYAN, CAMP_ACCENT_CYAN, 8, 0))


static func style_line_edit(le: LineEdit, font_size: int = 18, min_height: float = 44.0) -> void:
	if le == null:
		return
	le.custom_minimum_size.y = maxf(le.custom_minimum_size.y, min_height)
	le.add_theme_font_size_override("font_size", font_size)
	le.add_theme_color_override("font_color", CAMP_TEXT)
	le.add_theme_color_override("font_placeholder_color", CAMP_MUTED)
	le.add_theme_color_override("font_selected_color", Color(0.12, 0.09, 0.04, 1.0))
	le.add_theme_color_override("caret_color", CAMP_BORDER)
	le.add_theme_color_override("selection_color", Color(CAMP_ACCENT_CYAN.r, CAMP_ACCENT_CYAN.g, CAMP_ACCENT_CYAN.b, 0.35))
	var box := make_button_style(Color(0.10, 0.08, 0.055, 0.98), CAMP_BORDER_SOFT, 12, 0)
	box.content_margin_left = 10.0
	box.content_margin_top = 8.0
	box.content_margin_right = 10.0
	box.content_margin_bottom = 8.0
	var box_focus := make_button_style(Color(0.12, 0.09, 0.06, 0.99), CAMP_BORDER, 12, 0)
	box_focus.content_margin_left = 10.0
	box_focus.content_margin_top = 8.0
	box_focus.content_margin_right = 10.0
	box_focus.content_margin_bottom = 8.0
	le.add_theme_stylebox_override("normal", box)
	le.add_theme_stylebox_override("focus", box_focus)
	le.add_theme_stylebox_override("read_only", box)


static func progress_bar_background() -> StyleBoxFlat:
	return make_button_style(Color(0.06, 0.045, 0.03, 0.96), CAMP_BORDER_SOFT, 10, 0)


static func progress_bar_fill(fill_color: Color, border_color: Color = CAMP_BORDER) -> StyleBoxFlat:
	return make_button_style(fill_color, border_color, 8, 0)


static func style_progress_bar(bar: ProgressBar, min_height: float = 20.0) -> void:
	if bar == null:
		return
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.clip_contents = true
	bar.custom_minimum_size = Vector2(0, min_height)
	bar.add_theme_stylebox_override("background", progress_bar_background())
	bar.add_theme_stylebox_override("fill", progress_bar_fill(CAMP_BORDER.darkened(0.08), CAMP_BORDER))


static func set_progress_bar_fill_color(bar: ProgressBar, fill_color: Color) -> void:
	if bar == null:
		return
	bar.add_theme_stylebox_override("fill", progress_bar_fill(fill_color, CAMP_BORDER_SOFT))


static func dossier_stat_bar_display_value(raw_value: int) -> float:
	if raw_value <= 0:
		return 0.0
	var cap_int := int(UNIT_DOSSIER_STAT_BAR_CAP)
	if raw_value < cap_int:
		return float(raw_value)
	var wrapped := raw_value % cap_int
	if wrapped == 0:
		return UNIT_DOSSIER_STAT_BAR_CAP
	return float(wrapped)


static func dossier_stat_fill_color(stat_key: String, stat_value: int) -> Color:
	if stat_value >= 200:
		return UNIT_DOSSIER_STAT_TIER_WHITE
	if stat_value >= 150:
		return UNIT_DOSSIER_STAT_TIER_ORANGE
	if stat_value >= 100:
		return UNIT_DOSSIER_STAT_TIER_PURPLE
	if stat_value >= 50:
		return UNIT_DOSSIER_STAT_TIER_CYAN
	match stat_key:
		"max_hp":
			return Color(0.92, 0.42, 0.38, 1.0)
		"strength":
			return Color(0.94, 0.48, 0.36, 1.0)
		"magic":
			return Color(0.78, 0.48, 0.96, 1.0)
		"defense":
			return Color(0.50, 0.88, 0.50, 1.0)
		"resistance":
			return Color(0.38, 0.90, 0.82, 1.0)
		"speed":
			return Color(0.46, 0.76, 1.0, 1.0)
		"agility":
			return Color(0.96, 0.82, 0.44, 1.0)
		"move_range":
			return Color(0.82, 0.72, 0.48, 1.0)
		_:
			return CAMP_BORDER


## Rounded stat bar matching camp unit dossier (compact for dragon card).
static func style_dossier_stat_bar(bar: ProgressBar, fill: Color, overcap: bool) -> void:
	if bar == null:
		return
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.clip_contents = true
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.06, 0.05, 0.98)
	bg_style.border_color = fill if overcap else Color(0.24, 0.22, 0.18, 1.0)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(5)
	bg_style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	bg_style.shadow_size = 1
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.border_color = fill.lightened(0.18)
	fill_style.set_border_width_all(1)
	fill_style.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)


static func style_dossier_value_chip(surface: Control, accent: Color) -> void:
	if surface == null:
		return
	style_panel_surface(surface, Color(0.10, 0.09, 0.07, 0.98), accent.lightened(0.10), 6, 2)


static func style_dossier_row_panel(surface: Control, accent: Color, overcap: bool = false) -> void:
	if surface == null:
		return
	var border := accent if overcap else accent.darkened(0.08)
	var tinted := Color(
		lerpf(0.10, accent.r, 0.14),
		lerpf(0.09, accent.g, 0.14),
		lerpf(0.07, accent.b, 0.14),
		0.92
	)
	style_panel_surface(surface, tinted, border, 8, 2)
