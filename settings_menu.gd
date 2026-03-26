# ==============================================================================
# SCRIPT: SettingsMenu.gd
# PURPOSE: Manages global settings + feedback submission.
# NOTE: Settings are stored globally in user://settings.cfg via CampaignManager.
# ==============================================================================

extends Control

const SETTINGS_BG := Color(0.12, 0.11, 0.09, 0.97)
const SETTINGS_BG_ALT := Color(0.16, 0.14, 0.11, 0.96)
const SETTINGS_BORDER := Color(0.80, 0.66, 0.33, 0.95)
const SETTINGS_BORDER_MUTED := Color(0.48, 0.41, 0.24, 0.72)
const SETTINGS_TEXT := Color(0.94, 0.92, 0.84, 1.0)
const SETTINGS_TEXT_MUTED := Color(0.74, 0.71, 0.62, 1.0)
const SETTINGS_ACCENT := Color(0.98, 0.82, 0.26, 1.0)
const SETTINGS_ACCENT_SOFT := Color(0.62, 0.92, 1.0, 1.0)
const SETTINGS_CARD_ELEVATED := Color(0.18, 0.15, 0.12, 0.97)
const SETTINGS_CARD_ACTION := Color(0.19, 0.14, 0.10, 0.98)
const SETTINGS_CARD_REPORT := Color(0.13, 0.12, 0.10, 0.98)
const SETTINGS_SUCCESS := Color(0.58, 1.0, 0.68, 1.0)
const SETTINGS_WARNING := Color(1.0, 0.68, 0.42, 1.0)
const SETTINGS_ERROR := Color(1.0, 0.42, 0.42, 1.0)
const FEEDBACK_CATEGORY_ORDER := ["ALL", "BUGS", "UI", "BALANCE", "SUGGESTIONS"]

var _is_syncing_ui: bool = false
var _menu_tween: Tween = null
var _feedback_entries_cache: Array[Dictionary] = []
var _feedback_submit_category: String = "ALL"
var _feedback_board_filter: String = "ALL"
var _feedback_submit_category_buttons: Dictionary = {}
var _feedback_filter_buttons: Dictionary = {}

func _find_ui(node_name: String) -> Node:
	return find_child(node_name, true, false)

@onready var canvas_layer: CanvasLayer = _find_ui("CanvasLayer") as CanvasLayer
@onready var backdrop: ColorRect = _find_ui("Backdrop") as ColorRect
@onready var modal_panel: Panel = _find_ui("ModalPanel") as Panel
@onready var header_controls: Control = _find_ui("HeaderControls") as Control
@onready var title_label: Label = _find_ui("TitleLabel") as Label
@onready var subtitle_label: Label = _find_ui("SubtitleLabel") as Label
@onready var settings_scroll: ScrollContainer = _find_ui("SettingsScroll") as ScrollContainer
@onready var settings_vbox: VBoxContainer = _find_ui("SettingsVBox") as VBoxContainer
@onready var close_button: Button = _find_ui("CloseButton") as Button
@onready var quit_button: Button = _find_ui("QuitToTitleButton") as Button

# --- EXISTING SETTINGS ---
@onready var volume_slider: HSlider = _find_ui("VolumeSlider") as HSlider
@onready var camera_slider: HSlider = _find_ui("CameraSlider") as HSlider
@onready var move_speed_slider: HSlider = _find_ui("MoveSpeedSlider") as HSlider
@onready var follow_enemy_toggle: CheckBox = _find_ui("FollowEnemyToggle") as CheckBox

# --- NEW SETTINGS ---
@onready var danger_zone_toggle: CheckBox = _find_ui("DangerZoneToggle") as CheckBox
@onready var minimap_toggle: CheckBox = _find_ui("MinimapToggle") as CheckBox
@onready var minimap_opacity_slider: HSlider = _find_ui("MinimapOpacitySlider") as HSlider

@onready var zoom_step_slider: HSlider = _find_ui("ZoomStepSlider") as HSlider
@onready var min_zoom_slider: HSlider = _find_ui("MinZoomSlider") as HSlider
@onready var max_zoom_slider: HSlider = _find_ui("MaxZoomSlider") as HSlider
@onready var zoom_to_cursor_toggle: CheckBox = _find_ui("ZoomToCursorToggle") as CheckBox
@onready var edge_margin_slider: HSlider = _find_ui("EdgeMarginSlider") as HSlider

@onready var show_grid_toggle: CheckBox = _find_ui("ShowGridToggle") as CheckBox
@onready var show_enemy_threat_toggle: CheckBox = _find_ui("ShowEnemyThreatToggle") as CheckBox
@onready var show_faction_tiles_toggle: CheckBox = _find_ui("ShowFactionTilesToggle") as CheckBox
@onready var show_path_toggle: CheckBox = _find_ui("ShowPathToggle") as CheckBox
@onready var path_pulse_toggle: CheckBox = _find_ui("PathPulseToggle") as CheckBox
@onready var show_battle_log_toggle: CheckBox = _find_ui("ShowBattleLogToggle") as CheckBox
@onready var allow_fog_toggle: CheckBox = _find_ui("AllowFogToggle") as CheckBox

@onready var reset_defaults_btn: Button = _find_ui("ResetDefaultsButton") as Button

# --- VALUE LABELS ---
@onready var volume_value_label: Label = _find_ui("VolumeValue") as Label
@onready var camera_value_label: Label = _find_ui("CameraValue") as Label
@onready var move_speed_value_label: Label = _find_ui("MoveSpeedValue") as Label
@onready var minimap_opacity_value_label: Label = _find_ui("MinimapOpacityValue") as Label
@onready var zoom_step_value_label: Label = _find_ui("ZoomStepValue") as Label
@onready var min_zoom_value_label: Label = _find_ui("MinZoomValue") as Label
@onready var max_zoom_value_label: Label = _find_ui("MaxZoomValue") as Label
@onready var edge_margin_value_label: Label = _find_ui("EdgeMarginValue") as Label

# --- FEEDBACK UI ---
@onready var feedback_title: LineEdit = _find_ui("FeedbackTitle") as LineEdit
@onready var feedback_body: TextEdit = _find_ui("FeedbackBody") as TextEdit
@onready var feedback_category_label: Label = _find_ui("FeedbackCategoryLabel") as Label
@onready var feedback_category_row: HBoxContainer = _find_ui("FeedbackCategoryRow") as HBoxContainer
@onready var feedback_status_label: Label = _find_ui("FeedbackStatusLabel") as Label
@onready var submit_feedback_btn: Button = _find_ui("SubmitFeedbackButton") as Button
@onready var view_feedback_btn: Button = _find_ui("ViewFeedbackButton") as Button

# --- BULLETIN BOARD ---
@onready var feedback_board: Control = _find_ui("FeedbackBoard") as Control
@onready var feedback_modal: Panel = _find_ui("FeedbackModal") as Panel
@onready var feedback_filter_label: Label = _find_ui("FeedbackFilterLabel") as Label
@onready var feedback_filter_row: HBoxContainer = _find_ui("FeedbackFilterRow") as HBoxContainer
@onready var feedback_list: VBoxContainer = _find_ui("FeedbackList") as VBoxContainer
@onready var refresh_board_button: Button = _find_ui("RefreshBoardButton") as Button
@onready var close_board_button: Button = _find_ui("CloseBoardButton") as Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_layout_menu):
		vp.size_changed.connect(_layout_menu)

	CampaignManager.load_global_settings()
	_build_feedback_category_rows()
	_apply_theme()
	_layout_menu()
	_connect_all_signals()
	_sync_ui_from_settings()
	_apply_settings_to_runtime()
	hide_menu()

func _make_panel_style(fill: Color, border: Color, border_width: int = 2, radius: int = 12, shadow_alpha: float = 0.42, shadow_size: int = 8, shadow_y: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, shadow_alpha)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, shadow_y)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	return style

func _style_panel(panel: Control, fill: Color = SETTINGS_BG, border: Color = SETTINGS_BORDER, border_width: int = 2, radius: int = 12) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", _make_panel_style(fill, border, border_width, radius))

func _style_rule(rule: ColorRect, color: Color, height: int = 3, width: int = 0) -> void:
	if rule == null:
		return
	rule.color = color
	rule.custom_minimum_size = Vector2(width, height)

func _make_feedback_chip(text_value: String, font_color: Color, fill: Color, border: Color, min_width: int = 0) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(min_width, 0)
	chip.add_theme_stylebox_override("panel", _make_panel_style(fill, border, 1, 8, 0.18, 2, 1))
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(label, font_color, 13, 1)
	chip.add_child(label)
	return chip

func _infer_feedback_category(subject: String, body: String) -> String:
	var haystack := (subject + " " + body).to_lower()
	if "crash" in haystack or "bug" in haystack or "error" in haystack or "freeze" in haystack:
		return "BUGS"
	if "ui" in haystack or "menu" in haystack or "readability" in haystack or "font" in haystack:
		return "UI"
	if "balance" in haystack or "damage" in haystack or "weapon" in haystack or "skill" in haystack:
		return "BALANCE"
	if "idea" in haystack or "feature" in haystack or "suggestion" in haystack or "should" in haystack:
		return "SUGGESTIONS"
	return "ALL"

func _resolve_feedback_category(info: Dictionary) -> String:
	var explicit_category := _normalize_feedback_category(str(info.get("category", "")))
	if explicit_category != "ALL":
		return explicit_category
	return _infer_feedback_category(str(info.get("subject", "")), str(info.get("message", "")))

func _get_feedback_report_profile(category: String) -> Dictionary:
	match category:
		"BUGS":
			return {
				"label": "BUG REPORT",
				"accent": SETTINGS_ERROR,
				"fill": Color(0.22, 0.10, 0.10, 0.96)
			}
		"UI":
			return {
				"label": "UI FEEDBACK",
				"accent": SETTINGS_ACCENT_SOFT,
				"fill": Color(0.10, 0.16, 0.18, 0.96)
			}
		"BALANCE":
			return {
				"label": "BALANCE NOTE",
				"accent": SETTINGS_WARNING,
				"fill": Color(0.20, 0.14, 0.08, 0.96)
			}
		"SUGGESTIONS":
			return {
				"label": "SUGGESTION",
				"accent": SETTINGS_SUCCESS,
				"fill": Color(0.10, 0.18, 0.11, 0.96)
			}
		_:
			return {
				"label": "FIELD REPORT",
				"accent": SETTINGS_ACCENT,
				"fill": Color(0.18, 0.14, 0.10, 0.96)
			}

func _format_feedback_timestamp(raw_time: String) -> String:
	if raw_time.strip_edges() == "":
		return "Unknown Date"
	return raw_time.replace("T", " ")

func _extract_feedback_data(entry: Dictionary) -> Dictionary:
	var raw_metadata: Variant = entry.get("metadata", "{}")
	var data: Variant = {}
	if raw_metadata is String:
		data = JSON.parse_string(raw_metadata)
	else:
		data = raw_metadata
	if data == null or not (data is Dictionary):
		return {"subject": "Legacy Report", "message": str(raw_metadata)}
	return data as Dictionary

func _make_scrollbar_style(fill: Color, border: Color, radius: int = 9) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func _style_scrollbars(scroll: ScrollContainer, accent: Color) -> void:
	if scroll == null:
		return
	for bar in [scroll.get_v_scroll_bar(), scroll.get_h_scroll_bar()]:
		if bar == null:
			continue
		bar.custom_minimum_size = Vector2(18, 18)
		bar.add_theme_stylebox_override("scroll", _make_scrollbar_style(Color(0.10, 0.09, 0.07, 0.92), SETTINGS_BORDER_MUTED, 10))
		bar.add_theme_stylebox_override("grabber", _make_scrollbar_style(accent.darkened(0.18), accent.lerp(Color.WHITE, 0.18), 10))
		bar.add_theme_stylebox_override("grabber_highlight", _make_scrollbar_style(accent, accent.lerp(Color.WHITE, 0.28), 10))
		bar.add_theme_stylebox_override("grabber_pressed", _make_scrollbar_style(accent.darkened(0.08), accent.lerp(Color.WHITE, 0.34), 10))
		bar.add_theme_stylebox_override("focus", _make_scrollbar_style(Color(0.12, 0.11, 0.09, 0.98), SETTINGS_ACCENT, 10))

func _style_label(label: Label, color: Color = SETTINGS_TEXT, font_size: int = 20, outline_size: int = 3) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.92))
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_font_size_override("font_size", font_size)

func _style_richtext(text_box: RichTextLabel, font_size: int = 18) -> void:
	if text_box == null:
		return
	text_box.add_theme_color_override("default_color", SETTINGS_TEXT)
	text_box.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.88))
	text_box.add_theme_constant_override("outline_size", 2)
	text_box.add_theme_font_size_override("normal_font_size", font_size)
	text_box.add_theme_font_size_override("bold_font_size", font_size)
	var normal_font: Font = text_box.get_theme_font("normal_font")
	if normal_font != null:
		text_box.add_theme_font_override("bold_font", normal_font)

func _style_button(btn: Button, label_text: String, primary: bool = false, font_size: int = 22) -> void:
	if btn == null:
		return
	var normal_fill: Color = Color(0.64, 0.48, 0.18, 0.96) if primary else Color(0.24, 0.20, 0.14, 0.96)
	var hover_fill: Color = Color(0.74, 0.56, 0.22, 0.98) if primary else Color(0.32, 0.27, 0.18, 0.98)
	var press_fill: Color = Color(0.52, 0.39, 0.16, 0.98) if primary else Color(0.19, 0.16, 0.10, 0.98)
	var font_color: Color = Color(0.12, 0.08, 0.04, 1.0) if primary else SETTINGS_TEXT
	var regular_font: Font = btn.get_theme_font("font", "Label")
	btn.text = label_text
	btn.add_theme_font_size_override("font_size", font_size)
	if regular_font != null:
		btn.add_theme_font_override("font", regular_font)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_color_override("font_focus_color", font_color)
	btn.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.92))
	btn.add_theme_constant_override("outline_size", 3)
	btn.add_theme_stylebox_override("normal", _make_panel_style(normal_fill, SETTINGS_BORDER, 2, 10))
	btn.add_theme_stylebox_override("hover", _make_panel_style(hover_fill, SETTINGS_BORDER, 2, 10))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(press_fill, SETTINGS_BORDER, 2, 10))
	btn.add_theme_stylebox_override("focus", _make_panel_style(hover_fill, SETTINGS_ACCENT, 2, 10))

func _style_secondary_action_button(btn: Button, label_text: String, font_size: int = 20) -> void:
	if btn == null:
		return
	btn.text = label_text
	var regular_font: Font = btn.get_theme_font("font", "Label")
	if regular_font != null:
		btn.add_theme_font_override("font", regular_font)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", SETTINGS_TEXT)
	btn.add_theme_color_override("font_hover_color", SETTINGS_TEXT)
	btn.add_theme_color_override("font_pressed_color", SETTINGS_TEXT)
	btn.add_theme_color_override("font_focus_color", SETTINGS_TEXT)
	btn.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.92))
	btn.add_theme_constant_override("outline_size", 2)
	btn.add_theme_stylebox_override("normal", _make_panel_style(Color(0.23, 0.18, 0.12, 0.98), SETTINGS_WARNING.lerp(SETTINGS_BORDER, 0.55), 2, 10))
	btn.add_theme_stylebox_override("hover", _make_panel_style(Color(0.29, 0.22, 0.14, 0.98), SETTINGS_WARNING, 2, 10))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.18, 0.14, 0.09, 0.98), SETTINGS_WARNING, 2, 10))
	btn.add_theme_stylebox_override("focus", _make_panel_style(Color(0.29, 0.22, 0.14, 0.98), SETTINGS_ACCENT, 2, 10))

func _get_feedback_category_accent(category: String) -> Color:
	match category:
		"BUGS":
			return SETTINGS_ERROR
		"UI":
			return SETTINGS_ACCENT_SOFT
		"BALANCE":
			return SETTINGS_WARNING
		"SUGGESTIONS":
			return SETTINGS_SUCCESS
		_:
			return SETTINGS_ACCENT

func _style_feedback_mode_button(btn: Button, category: String, active: bool) -> void:
	if btn == null:
		return
	var accent := _get_feedback_category_accent(category)
	var regular_font: Font = btn.get_theme_font("font", "Label")
	if regular_font != null:
		btn.add_theme_font_override("font", regular_font)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.90))
	btn.add_theme_constant_override("outline_size", 2)
	var active_font := Color(0.13, 0.09, 0.04, 1.0)
	btn.add_theme_color_override("font_color", SETTINGS_TEXT if not active else active_font)
	btn.add_theme_color_override("font_hover_color", SETTINGS_TEXT if not active else active_font)
	btn.add_theme_color_override("font_pressed_color", SETTINGS_TEXT if not active else active_font)
	btn.add_theme_color_override("font_focus_color", SETTINGS_TEXT if not active else active_font)

	var inactive_fill := Color(0.15, 0.12, 0.09, 0.98)
	var inactive_hover := Color(0.20, 0.16, 0.11, 0.98)
	var inactive_pressed := Color(0.17, 0.14, 0.10, 0.98)
	var active_fill := accent.lerp(Color(0.14, 0.10, 0.05, 1.0), 0.34)
	var active_hover := accent.lerp(Color.WHITE, 0.16)
	var active_pressed := accent.darkened(0.04)
	var active_border := accent.lerp(Color.WHITE, 0.20)

	if active:
		btn.add_theme_stylebox_override("normal", _make_panel_style(active_fill, active_border, 2, 9, 0.44, 13, 2))
		btn.add_theme_stylebox_override("hover", _make_panel_style(active_hover, accent.lerp(Color.WHITE, 0.30), 2, 9, 0.52, 14, 2))
		btn.add_theme_stylebox_override("pressed", _make_panel_style(active_pressed, active_border, 2, 9, 0.38, 10, 1))
		btn.add_theme_stylebox_override("focus", _make_panel_style(active_hover, SETTINGS_ACCENT, 2, 9, 0.52, 14, 2))
	else:
		var border := accent.lerp(SETTINGS_BORDER_MUTED, 0.56)
		btn.add_theme_stylebox_override("normal", _make_panel_style(inactive_fill, border, 1, 9, 0.14, 2, 1))
		btn.add_theme_stylebox_override("hover", _make_panel_style(inactive_hover, accent, 1, 9, 0.22, 4, 1))
		btn.add_theme_stylebox_override("pressed", _make_panel_style(inactive_pressed, accent, 1, 9, 0.20, 2, 0))
		btn.add_theme_stylebox_override("focus", _make_panel_style(inactive_hover, SETTINGS_ACCENT, 1, 9, 0.24, 4, 1))

func _get_feedback_category_label(category: String) -> String:
	match category:
		"BUGS":
			return "BUGS"
		"UI":
			return "UI"
		"BALANCE":
			return "BALANCE"
		"SUGGESTIONS":
			return "SUGGESTIONS"
		_:
			return "ALL"

func _normalize_feedback_category(category_raw: String) -> String:
	var category := category_raw.strip_edges().to_upper()
	match category:
		"BUG", "BUGS", "BUG REPORT":
			return "BUGS"
		"UI", "UI FEEDBACK":
			return "UI"
		"BALANCE", "BALANCE NOTE":
			return "BALANCE"
		"SUGGESTION", "SUGGESTIONS":
			return "SUGGESTIONS"
		_:
			return "ALL"

func _build_feedback_category_buttons(row: HBoxContainer, for_submit: bool) -> void:
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()
	var target_dict := _feedback_submit_category_buttons if for_submit else _feedback_filter_buttons
	target_dict.clear()
	for category in FEEDBACK_CATEGORY_ORDER:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 32)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = _get_feedback_category_label(category)
		row.add_child(btn)
		target_dict[category] = btn
		if for_submit:
			if not btn.pressed.is_connected(_on_feedback_submit_category_pressed.bind(category)):
				btn.pressed.connect(_on_feedback_submit_category_pressed.bind(category))
		else:
			if not btn.pressed.is_connected(_on_feedback_filter_pressed.bind(category)):
				btn.pressed.connect(_on_feedback_filter_pressed.bind(category))

func _build_feedback_category_rows() -> void:
	_build_feedback_category_buttons(feedback_category_row, true)
	_build_feedback_category_buttons(feedback_filter_row, false)
	_sync_feedback_category_buttons()

func _sync_feedback_category_buttons() -> void:
	for category in FEEDBACK_CATEGORY_ORDER:
		var submit_btn := _feedback_submit_category_buttons.get(category) as Button
		if submit_btn != null:
			submit_btn.button_pressed = category == _feedback_submit_category
			_style_feedback_mode_button(submit_btn, category, category == _feedback_submit_category)
		var filter_btn := _feedback_filter_buttons.get(category) as Button
		if filter_btn != null:
			filter_btn.button_pressed = category == _feedback_board_filter
			_style_feedback_mode_button(filter_btn, category, category == _feedback_board_filter)

func _on_feedback_submit_category_pressed(category: String) -> void:
	_feedback_submit_category = category
	_sync_feedback_category_buttons()

func _on_feedback_filter_pressed(category: String) -> void:
	_feedback_board_filter = category
	_sync_feedback_category_buttons()
	_render_feedback_entries()

func _style_slider(slider: HSlider, accent: Color) -> void:
	if slider == null:
		return
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color(0.10, 0.09, 0.07, 0.96)
	track_style.border_color = SETTINGS_BORDER_MUTED
	track_style.set_border_width_all(1)
	track_style.set_corner_radius_all(8)
	track_style.content_margin_left = 8
	track_style.content_margin_right = 8
	track_style.content_margin_top = 8
	track_style.content_margin_bottom = 8
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = accent
	fill_style.border_color = accent.lerp(Color.WHITE, 0.25)
	fill_style.set_border_width_all(1)
	fill_style.set_corner_radius_all(8)
	fill_style.content_margin_left = 8
	fill_style.content_margin_right = 8
	fill_style.content_margin_top = 8
	fill_style.content_margin_bottom = 8
	slider.add_theme_stylebox_override("grabber_area", track_style)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_style)

func _style_checkbox(box: CheckBox) -> void:
	if box == null:
		return
	var regular_font: Font = box.get_theme_font("font", "Label")
	if regular_font != null:
		box.add_theme_font_override("font", regular_font)
	box.add_theme_font_size_override("font_size", 19)
	box.add_theme_color_override("font_color", SETTINGS_TEXT)
	box.add_theme_color_override("font_hover_color", SETTINGS_ACCENT)
	box.add_theme_color_override("font_pressed_color", SETTINGS_TEXT)
	box.add_theme_color_override("font_hover_pressed_color", SETTINGS_ACCENT)
	box.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.92))
	box.add_theme_constant_override("outline_size", 2)
	box.add_theme_constant_override("h_separation", 10)

func _style_input_field(control: Control, multi_line: bool = false) -> void:
	if control == null:
		return
	var fill: Color = Color(0.10, 0.09, 0.07, 0.98)
	var border: Color = SETTINGS_BORDER_MUTED
	control.add_theme_stylebox_override("normal", _make_panel_style(fill, border, 1, 8))
	control.add_theme_stylebox_override("focus", _make_panel_style(fill, SETTINGS_ACCENT, 2, 8))
	if control is LineEdit:
		var line := control as LineEdit
		var regular_font: Font = line.get_theme_font("font", "Label")
		if regular_font != null:
			line.add_theme_font_override("font", regular_font)
		line.add_theme_font_size_override("font_size", 19)
		line.add_theme_color_override("font_color", SETTINGS_TEXT)
		line.add_theme_color_override("font_placeholder_color", SETTINGS_TEXT_MUTED)
		line.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.92))
		line.add_theme_constant_override("outline_size", 2)
	elif control is TextEdit:
		var text_edit := control as TextEdit
		text_edit.add_theme_font_size_override("font_size", 18)
		text_edit.add_theme_color_override("font_readonly_color", SETTINGS_TEXT)
		text_edit.add_theme_color_override("font_color", SETTINGS_TEXT)
		text_edit.add_theme_color_override("font_placeholder_color", SETTINGS_TEXT_MUTED)
		text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		if multi_line:
			text_edit.scroll_fit_content_height = false

func _apply_theme() -> void:
	_style_panel(modal_panel, SETTINGS_BG, SETTINGS_BORDER, 2, 20)
	if modal_panel != null:
		modal_panel.add_theme_stylebox_override("panel", _make_panel_style(SETTINGS_BG, SETTINGS_BORDER, 2, 20, 0.56, 18, 8))
	if backdrop != null:
		backdrop.color = Color(0.0, 0.0, 0.0, 0.72)

	_style_label(title_label, SETTINGS_ACCENT, 42, 4)
	_style_label(subtitle_label, SETTINGS_TEXT_MUTED, 19, 2)
	var header_accent_row := _find_ui("HeaderAccentRow") as Control
	if header_accent_row != null:
		header_accent_row.visible = false

	_style_button(close_button, "RESUME", true, 22)
	_style_button(quit_button, "QUIT TO TITLE", false, 20)
	_style_secondary_action_button(reset_defaults_btn, "RESTORE FIELD DEFAULTS", 20)
	_style_button(submit_feedback_btn, "SUBMIT REPORT", true, 20)
	_style_button(view_feedback_btn, "VIEW COMMUNITY REPORTS", false, 18)
	_style_button(refresh_board_button, "REFRESH", false, 18)
	_style_button(close_board_button, "CLOSE", true, 18)

	_style_panel(_find_ui("AudioCameraCard") as Control, SETTINGS_CARD_ELEVATED, SETTINGS_BORDER_MUTED, 1, 16)
	_style_panel(_find_ui("MapViewCard") as Control, SETTINGS_CARD_ELEVATED, SETTINGS_BORDER_MUTED, 1, 16)
	_style_panel(_find_ui("ZoomCard") as Control, SETTINGS_CARD_ELEVATED, SETTINGS_BORDER_MUTED, 1, 16)
	_style_panel(_find_ui("QuickActionsCard") as Control, SETTINGS_CARD_ACTION, SETTINGS_WARNING.lerp(SETTINGS_BORDER, 0.55), 1, 16)
	_style_panel(_find_ui("FeedbackCard") as Control, SETTINGS_CARD_REPORT, SETTINGS_BORDER_MUTED, 1, 16)

	for section_title_name in ["AudioCameraTitle", "MapViewTitle", "ZoomTitle", "QuickActionsTitle", "FeedbackTitleLabel"]:
		_style_label(_find_ui(section_title_name) as Label, SETTINGS_ACCENT, 26, 3)
	for subtitle_name in ["AudioCameraSubtitle", "MapViewSubtitle", "ZoomSubtitle", "QuickActionsSubtitle", "FeedbackSubtitleLabel"]:
		_style_label(_find_ui(subtitle_name) as Label, SETTINGS_TEXT_MUTED, 16, 1)
	var subtle_rule := SETTINGS_BORDER_MUTED.lerp(SETTINGS_ACCENT, 0.18)
	for rule_name in ["AudioCameraRule", "MapViewRule", "ZoomRule", "QuickActionsRule", "FeedbackRule", "FeedbackBoardRule"]:
		_style_rule(_find_ui(rule_name) as ColorRect, subtle_rule, 2)

	for label_name in ["VolumeLabel", "CameraLabel", "MoveSpeedLabel", "MinimapOpacityLabel", "ZoomStepLabel", "MinZoomLabel", "MaxZoomLabel", "EdgeMarginLabel"]:
		_style_label(_find_ui(label_name) as Label, SETTINGS_TEXT, 19, 2)

	for value_label in [volume_value_label, camera_value_label, move_speed_value_label, minimap_opacity_value_label, zoom_step_value_label, min_zoom_value_label, max_zoom_value_label, edge_margin_value_label]:
		_style_label(value_label, SETTINGS_ACCENT_SOFT, 19, 2)

	_style_checkbox(follow_enemy_toggle)
	_style_checkbox(danger_zone_toggle)
	_style_checkbox(minimap_toggle)
	_style_checkbox(zoom_to_cursor_toggle)
	_style_checkbox(show_grid_toggle)
	_style_checkbox(show_enemy_threat_toggle)
	_style_checkbox(show_faction_tiles_toggle)
	_style_checkbox(show_path_toggle)
	_style_checkbox(path_pulse_toggle)
	_style_checkbox(show_battle_log_toggle)
	_style_checkbox(allow_fog_toggle)

	_style_slider(volume_slider, SETTINGS_ACCENT)
	_style_slider(camera_slider, SETTINGS_ACCENT_SOFT)
	_style_slider(move_speed_slider, Color(0.92, 0.72, 0.36, 1.0))
	_style_slider(minimap_opacity_slider, Color(0.64, 0.90, 1.0, 1.0))
	_style_slider(zoom_step_slider, SETTINGS_ACCENT)
	_style_slider(min_zoom_slider, SETTINGS_ACCENT_SOFT)
	_style_slider(max_zoom_slider, SETTINGS_WARNING)
	_style_slider(edge_margin_slider, Color(0.64, 1.0, 0.78, 1.0))

	_style_input_field(feedback_title, false)
	_style_input_field(feedback_body, true)
	_style_label(feedback_category_label, SETTINGS_TEXT_MUTED, 15, 1)
	_style_label(feedback_filter_label, SETTINGS_TEXT_MUTED, 15, 1)
	_style_label(feedback_status_label, SETTINGS_TEXT_MUTED, 15, 1)
	_sync_feedback_category_buttons()

	_style_scrollbars(settings_scroll, SETTINGS_ACCENT)
	_style_scrollbars(_find_ui("SideScroll") as ScrollContainer, SETTINGS_WARNING)
	_style_scrollbars(_find_ui("FeedbackScroll") as ScrollContainer, SETTINGS_ACCENT_SOFT)

	if feedback_board != null:
		feedback_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel(feedback_modal, SETTINGS_BG, SETTINGS_BORDER, 2, 18)
	_style_label(_find_ui("FeedbackBoardTitle") as Label, SETTINGS_ACCENT, 28, 3)
	_style_label(_find_ui("FeedbackBoardSubtitle") as Label, SETTINGS_TEXT_MUTED, 15, 1)

func _layout_menu() -> void:
	var vp_size := get_viewport_rect().size
	if modal_panel != null:
		var panel_size := Vector2(
			clampf(vp_size.x - 80.0, 1280.0, 1700.0),
			clampf(vp_size.y - 100.0, 760.0, 940.0)
		)
		modal_panel.size = panel_size
		modal_panel.position = (vp_size - panel_size) * 0.5
		if header_controls != null:
			header_controls.position = Vector2(28, 24)
			header_controls.size = Vector2(panel_size.x - 56.0, 82.0)
		var content_margin := _find_ui("ContentMargin") as MarginContainer
		if content_margin != null:
			content_margin.position = Vector2(24, 118)
			content_margin.size = Vector2(panel_size.x - 48.0, panel_size.y - 142.0)
	if feedback_modal != null:
		var board_size := Vector2(
			clampf(vp_size.x - 220.0, 920.0, 1120.0),
			clampf(vp_size.y - 160.0, 620.0, 760.0)
		)
		feedback_modal.size = board_size
		feedback_modal.position = (vp_size - board_size) * 0.5

func _queue_modal_layout_refresh() -> void:
	if not visible or canvas_layer == null or not canvas_layer.visible:
		return
	var content_margin := _find_ui("ContentMargin") as MarginContainer
	var main_hbox := _find_ui("MainHBox") as HBoxContainer
	var title_block := _find_ui("TitleBlock") as VBoxContainer
	var side_column := _find_ui("SideColumn") as VBoxContainer
	if title_block != null:
		title_block.queue_sort()
	if header_controls is Container:
		(header_controls as Container).queue_sort()
	if content_margin != null:
		content_margin.queue_sort()
	if main_hbox != null:
		main_hbox.queue_sort()
	if settings_vbox != null:
		settings_vbox.queue_sort()
	if side_column != null:
		side_column.queue_sort()
	if settings_scroll != null:
		settings_scroll.scroll_horizontal = 0
		settings_scroll.scroll_vertical = 0
	var side_scroll := _find_ui("SideScroll") as ScrollContainer
	if side_scroll != null:
		side_scroll.scroll_horizontal = 0
		side_scroll.scroll_vertical = 0
	if feedback_board != null and feedback_board.visible:
		var feedback_scroll := _find_ui("FeedbackScroll") as ScrollContainer
		if feedback_scroll != null:
			feedback_scroll.scroll_horizontal = 0
			feedback_scroll.scroll_vertical = 0

func _finalize_show_layout() -> void:
	if not visible or canvas_layer == null or not canvas_layer.visible:
		return
	_layout_menu()
	_queue_modal_layout_refresh()
	await get_tree().process_frame
	if not visible or canvas_layer == null or not canvas_layer.visible:
		return
	_layout_menu()
	_queue_modal_layout_refresh()
	if modal_panel != null:
		modal_panel.queue_redraw()

func _connect_value_signal(slider: HSlider, callable_target: Callable) -> void:
	if slider != null and not slider.value_changed.is_connected(callable_target):
		slider.value_changed.connect(callable_target)

func _connect_toggle_signal(toggle: BaseButton, callable_target: Callable) -> void:
	if toggle != null and not toggle.toggled.is_connected(callable_target):
		toggle.toggled.connect(callable_target)

func _connect_all_signals() -> void:
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if quit_button and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)
	if submit_feedback_btn and not submit_feedback_btn.pressed.is_connected(_on_submit_feedback_pressed):
		submit_feedback_btn.pressed.connect(_on_submit_feedback_pressed)
	if view_feedback_btn and not view_feedback_btn.pressed.is_connected(_open_feedback_board):
		view_feedback_btn.pressed.connect(_open_feedback_board)
	if close_board_button and not close_board_button.pressed.is_connected(_close_feedback_board):
		close_board_button.pressed.connect(_close_feedback_board)
	if refresh_board_button and not refresh_board_button.pressed.is_connected(_fetch_all_feedback):
		refresh_board_button.pressed.connect(_fetch_all_feedback)
	if reset_defaults_btn and not reset_defaults_btn.pressed.is_connected(_on_reset_defaults_pressed):
		reset_defaults_btn.pressed.connect(_on_reset_defaults_pressed)

	_connect_value_signal(volume_slider, _on_volume_changed)
	_connect_value_signal(camera_slider, _on_camera_speed_changed)
	_connect_value_signal(move_speed_slider, _on_move_speed_changed)
	_connect_toggle_signal(follow_enemy_toggle, _on_follow_enemy_toggled)
	_connect_toggle_signal(danger_zone_toggle, _on_danger_zone_toggled)
	_connect_toggle_signal(minimap_toggle, _on_minimap_toggled)
	_connect_value_signal(minimap_opacity_slider, _on_minimap_opacity_changed)
	_connect_value_signal(zoom_step_slider, _on_zoom_step_changed)
	_connect_value_signal(min_zoom_slider, _on_min_zoom_changed)
	_connect_value_signal(max_zoom_slider, _on_max_zoom_changed)
	_connect_toggle_signal(zoom_to_cursor_toggle, _on_zoom_to_cursor_toggled)
	_connect_value_signal(edge_margin_slider, _on_edge_margin_changed)
	_connect_toggle_signal(show_grid_toggle, _on_show_grid_toggled)
	_connect_toggle_signal(show_enemy_threat_toggle, _on_show_enemy_threat_toggled)
	_connect_toggle_signal(show_faction_tiles_toggle, _on_show_faction_tiles_toggled)
	_connect_toggle_signal(show_path_toggle, _on_show_path_toggled)
	_connect_toggle_signal(path_pulse_toggle, _on_path_pulse_toggled)
	_connect_toggle_signal(show_battle_log_toggle, _on_show_battle_log_toggled)
	_connect_toggle_signal(allow_fog_toggle, _on_allow_fog_toggled)

func _sync_ui_from_settings() -> void:
	_is_syncing_ui = true

	if volume_slider:
		volume_slider.value = CampaignManager.audio_master_volume
	if camera_slider:
		camera_slider.value = CampaignManager.camera_pan_speed
	if move_speed_slider:
		move_speed_slider.value = CampaignManager.unit_move_speed
	if follow_enemy_toggle:
		follow_enemy_toggle.button_pressed = CampaignManager.battle_follow_enemy_camera

	if danger_zone_toggle:
		danger_zone_toggle.button_pressed = CampaignManager.battle_show_danger_zone_default
	if minimap_toggle:
		minimap_toggle.button_pressed = CampaignManager.battle_show_minimap_default
	if minimap_opacity_slider:
		minimap_opacity_slider.value = CampaignManager.battle_minimap_opacity

	if zoom_step_slider:
		zoom_step_slider.value = CampaignManager.battle_zoom_step
	if min_zoom_slider:
		min_zoom_slider.value = CampaignManager.battle_min_zoom
	if max_zoom_slider:
		max_zoom_slider.value = CampaignManager.battle_max_zoom
	if zoom_to_cursor_toggle:
		zoom_to_cursor_toggle.button_pressed = CampaignManager.battle_zoom_to_cursor
	if edge_margin_slider:
		edge_margin_slider.value = CampaignManager.battle_edge_margin

	if show_grid_toggle:
		show_grid_toggle.button_pressed = CampaignManager.battle_show_grid
	if show_enemy_threat_toggle:
		show_enemy_threat_toggle.button_pressed = CampaignManager.battle_show_enemy_threat
	if show_faction_tiles_toggle:
		show_faction_tiles_toggle.button_pressed = CampaignManager.battle_show_faction_tiles
	if show_path_toggle:
		show_path_toggle.button_pressed = CampaignManager.battle_show_path_preview
	if path_pulse_toggle:
		path_pulse_toggle.button_pressed = CampaignManager.battle_path_preview_pulse
	if show_battle_log_toggle:
		show_battle_log_toggle.button_pressed = CampaignManager.battle_show_log
	if allow_fog_toggle:
		allow_fog_toggle.button_pressed = CampaignManager.battle_allow_fog_of_war

	_refresh_value_labels()
	_set_feedback_status("", SETTINGS_TEXT_MUTED)
	_is_syncing_ui = false

func _refresh_value_labels() -> void:
	if volume_value_label:
		volume_value_label.text = "%d%%" % int(round(CampaignManager.audio_master_volume * 100.0))
	if camera_value_label:
		camera_value_label.text = "%d" % int(round(CampaignManager.camera_pan_speed))
	if move_speed_value_label:
		move_speed_value_label.text = "%.2fs" % CampaignManager.unit_move_speed
	if minimap_opacity_value_label:
		minimap_opacity_value_label.text = "%d%%" % int(round(CampaignManager.battle_minimap_opacity * 100.0))
	if zoom_step_value_label:
		zoom_step_value_label.text = "%.2fx" % CampaignManager.battle_zoom_step
	if min_zoom_value_label:
		min_zoom_value_label.text = "%.2fx" % CampaignManager.battle_min_zoom
	if max_zoom_value_label:
		max_zoom_value_label.text = "%.2fx" % CampaignManager.battle_max_zoom
	if edge_margin_value_label:
		edge_margin_value_label.text = "%d px" % CampaignManager.battle_edge_margin

func _persist_and_apply() -> void:
	if _is_syncing_ui:
		return

	if CampaignManager.battle_max_zoom <= CampaignManager.battle_min_zoom:
		CampaignManager.battle_max_zoom = CampaignManager.battle_min_zoom + 0.10
		_sync_ui_from_settings()

	_refresh_value_labels()
	CampaignManager.save_global_settings()
	CampaignManager.apply_audio_settings()
	_apply_settings_to_runtime()

func _apply_settings_to_runtime() -> void:
	var current = get_tree().current_scene
	if current != null and current.has_method("apply_campaign_settings"):
		current.apply_campaign_settings()

# ==============================================================================
# SETTINGS HANDLERS
# ==============================================================================

func _on_volume_changed(value: float) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.audio_master_volume = clampf(value, 0.0, 1.0)
	_persist_and_apply()

func _on_camera_speed_changed(value: float) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.camera_pan_speed = value
	_persist_and_apply()

func _on_move_speed_changed(value: float) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.unit_move_speed = value
	_persist_and_apply()

func _on_follow_enemy_toggled(toggled_on: bool) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.battle_follow_enemy_camera = toggled_on
	_persist_and_apply()

func _on_danger_zone_toggled(toggled_on: bool) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.battle_show_danger_zone_default = toggled_on
	_persist_and_apply()

func _on_minimap_toggled(toggled_on: bool) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.battle_show_minimap_default = toggled_on
	_persist_and_apply()

func _on_minimap_opacity_changed(value: float) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.battle_minimap_opacity = clampf(value, 0.15, 1.0)
	_persist_and_apply()

func _on_zoom_step_changed(value: float) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.battle_zoom_step = clampf(value, 0.02, 0.50)
	_persist_and_apply()

func _on_min_zoom_changed(value: float) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.battle_min_zoom = clampf(value, 0.20, 3.00)
	_persist_and_apply()

func _on_max_zoom_changed(value: float) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.battle_max_zoom = clampf(value, 0.20, 4.00)
	_persist_and_apply()

func _on_zoom_to_cursor_toggled(toggled_on: bool) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.battle_zoom_to_cursor = toggled_on
	_persist_and_apply()

func _on_edge_margin_changed(value: float) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.battle_edge_margin = clampi(int(value), 4, 300)
	_persist_and_apply()

func _on_show_grid_toggled(toggled_on: bool) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.battle_show_grid = toggled_on
	_persist_and_apply()

func _on_show_enemy_threat_toggled(toggled_on: bool) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.battle_show_enemy_threat = toggled_on
	_persist_and_apply()

func _on_show_faction_tiles_toggled(toggled_on: bool) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.battle_show_faction_tiles = toggled_on
	_persist_and_apply()

func _on_show_path_toggled(toggled_on: bool) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.battle_show_path_preview = toggled_on
	_persist_and_apply()

func _on_path_pulse_toggled(toggled_on: bool) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.battle_path_preview_pulse = toggled_on
	_persist_and_apply()

func _on_show_battle_log_toggled(toggled_on: bool) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.battle_show_log = toggled_on
	_persist_and_apply()

func _on_allow_fog_toggled(toggled_on: bool) -> void:
	if _is_syncing_ui:
		return
	CampaignManager.battle_allow_fog_of_war = toggled_on
	_persist_and_apply()

func _on_reset_defaults_pressed() -> void:
	CampaignManager.audio_master_volume = 1.0
	CampaignManager.camera_pan_speed = 600.0
	CampaignManager.unit_move_speed = 0.15

	CampaignManager.battle_follow_enemy_camera = true
	CampaignManager.battle_show_danger_zone_default = false
	CampaignManager.battle_show_minimap_default = false
	CampaignManager.battle_minimap_opacity = 0.90

	CampaignManager.battle_zoom_step = 0.10
	CampaignManager.battle_min_zoom = 0.60
	CampaignManager.battle_max_zoom = 2.20
	CampaignManager.battle_zoom_to_cursor = true
	CampaignManager.battle_edge_margin = 50

	CampaignManager.battle_show_grid = true
	CampaignManager.battle_show_enemy_threat = true
	CampaignManager.battle_show_faction_tiles = true
	CampaignManager.battle_show_path_preview = true
	CampaignManager.battle_path_preview_pulse = true
	CampaignManager.battle_show_log = true
	CampaignManager.battle_allow_fog_of_war = true

	_sync_ui_from_settings()
	_persist_and_apply()
	_set_feedback_status("Field defaults restored.", SETTINGS_SUCCESS)

# ==============================================================================
# FEEDBACK BOARD
# ==============================================================================

func _open_feedback_board() -> void:
	if feedback_board:
		feedback_board.show()
		_fetch_all_feedback()

func _close_feedback_board() -> void:
	if feedback_board:
		feedback_board.hide()

func _fetch_all_feedback() -> void:
	if feedback_list == null:
		_set_feedback_status("Community board is unavailable right now.", SETTINGS_ERROR)
		return

	var _sw_result = await SilentWolf.Scores.get_scores(50, "player_feedback").sw_get_scores_complete
	var scores = SilentWolf.Scores.scores
	_feedback_entries_cache.clear()
	for entry in scores:
		if entry is Dictionary:
			_feedback_entries_cache.append(entry)
	_render_feedback_entries()

func _render_feedback_entries() -> void:
	if feedback_list == null:
		return
	for child in feedback_list.get_children():
		child.queue_free()

	var filtered_entries: Array[Dictionary] = []
	for entry in _feedback_entries_cache:
		var info := _extract_feedback_data(entry)
		var category := _resolve_feedback_category(info)
		if _feedback_board_filter == "ALL" or category == _feedback_board_filter:
			filtered_entries.append(entry)

	if filtered_entries.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No %s reports found in the capital archive." % _get_feedback_category_label(_feedback_board_filter).to_lower()
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_label(empty_lbl, SETTINGS_TEXT_MUTED, 17, 2)
		feedback_list.add_child(empty_lbl)
		return

	for i in range(filtered_entries.size()):
		_create_feedback_row(filtered_entries[i], i)

func _create_feedback_row(entry: Dictionary, populate_index: int = 0) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _make_panel_style(Color(0.15, 0.12, 0.09, 0.98), SETTINGS_BORDER_MUTED.lerp(SETTINGS_ACCENT, 0.18), 1, 14, 0.28, 8, 3))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	row.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var info := _extract_feedback_data(entry)
	var subject: String = str(info.get("subject", "Legacy Report"))
	var message: String = str(info.get("message", "..."))
	var sender: String = str(entry.get("player_name", "Anonymous"))
	var version_text: String = str(info.get("version", "1.0.4"))
	var timestamp_text: String = _format_feedback_timestamp(str(info.get("timestamp", "Unknown Date")))
	var category_key := _resolve_feedback_category(info)
	var report_profile := _get_feedback_report_profile(category_key)
	var accent: Color = report_profile["accent"] as Color
	var chip_fill: Color = report_profile["fill"] as Color

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	vbox.add_child(header_row)

	var header_left := VBoxContainer.new()
	header_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_left.add_theme_constant_override("separation", 6)
	header_row.add_child(header_left)

	header_left.add_child(_make_feedback_chip(str(report_profile["label"]), accent, chip_fill, accent.lerp(Color.WHITE, 0.20), 140))

	var header := Label.new()
	header.text = subject.to_upper()
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(header, SETTINGS_ACCENT, 22, 2)
	header_left.add_child(header)

	var meta_column := VBoxContainer.new()
	meta_column.add_theme_constant_override("separation", 6)
	header_row.add_child(meta_column)
	meta_column.add_child(_make_feedback_chip("VER " + version_text, SETTINGS_TEXT_MUTED, Color(0.11, 0.10, 0.08, 0.98), SETTINGS_BORDER_MUTED, 92))
	meta_column.add_child(_make_feedback_chip(timestamp_text, SETTINGS_TEXT_MUTED, Color(0.11, 0.10, 0.08, 0.98), SETTINGS_BORDER_MUTED, 180))

	var rule := ColorRect.new()
	_style_rule(rule, accent.lerp(SETTINGS_BORDER_MUTED, 0.45), 2)
	vbox.add_child(rule)

	var summary := Label.new()
	summary.text = "Filed by %s" % sender
	_style_label(summary, SETTINGS_TEXT_MUTED, 14, 1)
	vbox.add_child(summary)

	var body_shell := PanelContainer.new()
	body_shell.add_theme_stylebox_override("panel", _make_panel_style(Color(0.11, 0.10, 0.08, 0.95), accent.lerp(SETTINGS_BORDER_MUTED, 0.35), 1, 10, 0.10, 2, 1))
	vbox.add_child(body_shell)

	var body_margin := MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 14)
	body_margin.add_theme_constant_override("margin_top", 12)
	body_margin.add_theme_constant_override("margin_right", 14)
	body_margin.add_theme_constant_override("margin_bottom", 12)
	body_shell.add_child(body_margin)

	var body := Label.new()
	body.text = message
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(body, SETTINGS_TEXT, 16, 1)
	body_margin.add_child(body)

	var footer_row := HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", 8)
	vbox.add_child(footer_row)

	footer_row.add_child(_make_feedback_chip("REPORTER: " + sender.to_upper(), SETTINGS_TEXT, Color(0.14, 0.12, 0.10, 0.98), SETTINGS_BORDER_MUTED, 180))
	var mmr_value: int = int(info.get("mmr", 0))
	if mmr_value > 0:
		footer_row.add_child(_make_feedback_chip("MMR %d" % mmr_value, SETTINGS_ACCENT_SOFT, Color(0.10, 0.14, 0.16, 0.98), SETTINGS_ACCENT_SOFT.lerp(SETTINGS_BORDER_MUTED, 0.35), 92))
	var archive_chip := _make_feedback_chip("CAPITAL ARCHIVE", SETTINGS_TEXT_MUTED, Color(0.10, 0.09, 0.07, 0.96), SETTINGS_BORDER_MUTED, 140)
	archive_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_row.add_child(archive_chip)

	feedback_list.add_child(row)
	row.modulate = Color(1.0, 1.0, 1.0, 0.0)
	row.scale = Vector2(0.985, 0.985)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if populate_index > 0:
		tween.tween_interval(0.035 * float(populate_index))
	tween.parallel().tween_property(row, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(row, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ==============================================================================
# FEEDBACK SUBMISSION
# ==============================================================================

func _on_submit_feedback_pressed() -> void:
	var title: String = feedback_title.text.strip_edges()
	var body: String = feedback_body.text.strip_edges()

	if title == "" or body == "":
		_set_feedback_status("Please fill in both the subject and the report body.", SETTINGS_WARNING)
		return

	submit_feedback_btn.disabled = true
	_style_button(submit_feedback_btn, "SYNCING...", true, 20)
	_set_feedback_status("Sending your report to the capital board...", SETTINGS_TEXT_MUTED)

	var metadata := {
		"category": _feedback_submit_category,
		"subject": title,
		"message": body,
		"version": "1.0.4",
		"mmr": CampaignManager.arena_mmr,
		"timestamp": Time.get_datetime_string_from_system()
	}

	var player_name: String = str(CampaignManager.custom_avatar.get("name", "Unknown Player"))
	var dummy_score: int = int(Time.get_unix_time_from_system())

	var sw_result = await SilentWolf.Scores.save_score(
		player_name,
		dummy_score,
		"player_feedback",
		metadata
	).sw_save_score_complete

	if sw_result:
		_clear_feedback_fields()
		submit_feedback_btn.disabled = false
		_style_button(submit_feedback_btn, "REPORT SENT", true, 20)
		_set_feedback_status("Report delivered. Thank you for helping shape the game.", SETTINGS_SUCCESS)
		await get_tree().create_timer(2.0).timeout
		_style_button(submit_feedback_btn, "SUBMIT REPORT", true, 20)
	else:
		submit_feedback_btn.disabled = false
		_style_button(submit_feedback_btn, "SUBMIT REPORT", true, 20)
		_set_feedback_status("Network error. Please try again in a moment.", SETTINGS_ERROR)

func _clear_feedback_fields() -> void:
	if feedback_title:
		feedback_title.text = ""
	if feedback_body:
		feedback_body.text = ""
	_feedback_submit_category = "ALL"
	_sync_feedback_category_buttons()

func _set_feedback_status(msg: String, color: Color) -> void:
	if feedback_status_label == null:
		return
	feedback_status_label.text = msg
	feedback_status_label.visible = msg != ""
	_style_label(feedback_status_label, color, 14, 1)

func _show_status_message(msg: String, color: Color) -> void:
	_set_feedback_status(msg, color)

# ==============================================================================
# MENU FLOW
# ==============================================================================

func _input(event: InputEvent) -> void:
	if not (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_menuESC")):
		return
	if canvas_layer == null:
		return
	if not canvas_layer.visible:
		show_menu()
	elif feedback_board != null and feedback_board.visible:
		_close_feedback_board()
	else:
		hide_menu()

func show_menu() -> void:
	get_tree().paused = true
	visible = true
	if canvas_layer:
		canvas_layer.visible = true
		canvas_layer.layer = 128
	_layout_menu()
	_sync_ui_from_settings()
	_close_feedback_board()
	if _menu_tween != null:
		_menu_tween.kill()
	if backdrop != null:
		backdrop.modulate.a = 0.0
	if modal_panel != null:
		modal_panel.scale = Vector2(0.97, 0.97)
		modal_panel.modulate.a = 0.0
	_menu_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	if backdrop != null:
		_menu_tween.tween_property(backdrop, "modulate:a", 1.0, 0.18)
	if modal_panel != null:
		_menu_tween.tween_property(modal_panel, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_menu_tween.tween_property(modal_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	call_deferred("_finalize_show_layout")

func hide_menu() -> void:
	if feedback_board:
		feedback_board.hide()
	visible = false
	if canvas_layer:
		canvas_layer.visible = false
	get_tree().paused = false

func _on_close_pressed() -> void:
	hide_menu()

func _on_quit_pressed() -> void:
	hide_menu()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
