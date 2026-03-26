extends Control

const MENU_BG := Color(0.12, 0.10, 0.07, 0.96)
const MENU_BG_ALT := Color(0.17, 0.13, 0.09, 0.96)
const MENU_BORDER := Color(0.82, 0.67, 0.29, 0.96)
const MENU_BORDER_MUTED := Color(0.52, 0.43, 0.22, 0.80)
const MENU_TEXT := Color(0.96, 0.93, 0.86, 1.0)
const MENU_TEXT_MUTED := Color(0.73, 0.69, 0.60, 0.96)
const MENU_ACCENT := Color(0.95, 0.79, 0.28, 1.0)
const MENU_ACCENT_SOFT := Color(0.58, 0.87, 1.0, 1.0)
const MENU_SUCCESS := Color(0.52, 0.92, 0.60, 1.0)
const MENU_WARNING := Color(0.96, 0.67, 0.34, 1.0)
const MENU_ERROR := Color(0.97, 0.42, 0.38, 1.0)
const DISPATCH_LEADERBOARD := "main_menu_dispatch"
const DISPATCH_CATEGORIES := ["NEWS", "MODIFICATIONS", "OTHER"]
const DISPATCH_APPROVED_STEAM_IDS: Array[String] = []
const DISPATCH_ALLOW_DEBUG_EDITOR := true

@onready var backdrop_art: TextureRect = $BackdropArt
@onready var backdrop_shade: ColorRect = $BackdropShade
@onready var backdrop_warmth: ColorRect = $BackdropWarmth
@onready var header_panel: Control = $HeaderPanel
@onready var header_card: PanelContainer = $HeaderPanel/HeaderCard
@onready var intel_panel: Control = $IntelPanel
@onready var intel_card: PanelContainer = $IntelPanel/IntelCard
@onready var dispatch_panel: Control = $DispatchPanel
@onready var dispatch_card: PanelContainer = $DispatchPanel/DispatchCard
@onready var main_vbox: Control = $CenterStage/MainPanel
@onready var campaign_vbox: Control = $CenterStage/CampaignMenu

@onready var start_button: Button = $CenterStage/MainPanel/Margin/VBox/StartButton
@onready var settings_button: Button = $CenterStage/MainPanel/Margin/VBox/SettingsButton
@onready var quit_button: Button = $CenterStage/MainPanel/Margin/VBox/QuitButton

@onready var continue_button: Button = $CenterStage/CampaignMenu/Margin/VBox/ContinueButton
@onready var new_game_button: Button = $CenterStage/CampaignMenu/Margin/VBox/NewGameButton
@onready var load_game_button: Button = $CenterStage/CampaignMenu/Margin/VBox/LoadGameButton
@onready var back_button: Button = $CenterStage/CampaignMenu/Margin/VBox/BackButton
@onready var slots_container: VBoxContainer = $CenterStage/CampaignMenu/Margin/VBox/SlotsContainer

@onready var auto_slot_1_btn: Button = $CenterStage/CampaignMenu/Margin/VBox/SlotsContainer/SlotRow1/AutoSlot1Button
@onready var auto_slot_2_btn: Button = $CenterStage/CampaignMenu/Margin/VBox/SlotsContainer/SlotRow2/AutoSlot2Button
@onready var auto_slot_3_btn: Button = $CenterStage/CampaignMenu/Margin/VBox/SlotsContainer/SlotRow3/AutoSlot3Button

@onready var slot_1_btn: Button = $CenterStage/CampaignMenu/Margin/VBox/SlotsContainer/SlotRow1/Slot1Button
@onready var slot_2_btn: Button = $CenterStage/CampaignMenu/Margin/VBox/SlotsContainer/SlotRow2/Slot2Button
@onready var slot_3_btn: Button = $CenterStage/CampaignMenu/Margin/VBox/SlotsContainer/SlotRow3/Slot3Button

@onready var del_slot_1_btn: Button = $CenterStage/CampaignMenu/Margin/VBox/SlotsContainer/SlotRow1/DeleteSlot1
@onready var del_slot_2_btn: Button = $CenterStage/CampaignMenu/Margin/VBox/SlotsContainer/SlotRow2/DeleteSlot2
@onready var del_slot_3_btn: Button = $CenterStage/CampaignMenu/Margin/VBox/SlotsContainer/SlotRow3/DeleteSlot3
@onready var delete_dialog: ConfirmationDialog = $DeleteConfirmation
@onready var overwrite_dialog: ConfirmationDialog = $OverwriteConfirmation
@onready var dispatch_editor_dialog: ConfirmationDialog = $DispatchEditorDialog

@onready var intel_rule: ColorRect = $IntelPanel/IntelCard/Margin/VBox/IntelRule
@onready var dispatch_rule: ColorRect = $DispatchPanel/DispatchCard/Margin/VBox/DispatchRule
@onready var dispatch_meta_label: Label = $DispatchPanel/DispatchCard/Margin/VBox/DispatchMeta
@onready var dispatch_scroll: ScrollContainer = $DispatchPanel/DispatchCard/Margin/VBox/DispatchScroll
@onready var dispatch_body_label: RichTextLabel = $DispatchPanel/DispatchCard/Margin/VBox/DispatchScroll/DispatchBody
@onready var dispatch_category_label: Label = $DispatchPanel/DispatchCard/Margin/VBox/Footer/DispatchInfoRow/DispatchCategory
@onready var dispatch_status_label: Label = $DispatchPanel/DispatchCard/Margin/VBox/Footer/DispatchInfoRow/DispatchStatus
@onready var edit_dispatch_button: Button = $DispatchPanel/DispatchCard/Margin/VBox/Footer/DispatchActionsRow/EditDispatchButton
@onready var dispatch_category_option: OptionButton = $DispatchEditorDialog/Margin/VBox/DispatchCategoryOption
@onready var dispatch_headline_edit: LineEdit = $DispatchEditorDialog/Margin/VBox/DispatchHeadlineEdit
@onready var dispatch_body_edit: TextEdit = $DispatchEditorDialog/Margin/VBox/DispatchBodyEdit

var pending_delete_slot: int = 0
var _dispatch_payload: Dictionary = {}

var SFX_HOVER: AudioStream = preload("res://audio/menu_hover.wav")
var SFX_CLICK: AudioStream = preload("res://audio/menu_click.wav")
var MENU_MUSIC: AudioStream = preload("res://audio/Menu Music (Remastered).wav")

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer


func _make_panel_style(fill: Color, border: Color, border_width: int = 2, radius: int = 16, shadow_alpha: float = 0.40, shadow_size: int = 10, shadow_y: int = 4) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0.0, 0.0, 0.0, shadow_alpha)
	box.shadow_size = shadow_size
	box.shadow_offset = Vector2(0, shadow_y)
	return box


func _style_panel(panel: Control, fill: Color, border: Color, border_width: int = 2, radius: int = 16, shadow_alpha: float = 0.36) -> void:
	if panel == null:
		return
	var style := _make_panel_style(fill, border, border_width, radius, shadow_alpha, 10, 4)
	if panel is PanelContainer:
		(panel as PanelContainer).add_theme_stylebox_override("panel", style)
	elif panel is Panel:
		(panel as Panel).add_theme_stylebox_override("panel", style)


func _style_label(label: Label, color: Color, font_size: int, outline_size: int = 2, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if label == null:
		return
	var regular_font: Font = label.get_theme_font("font", "Label")
	if regular_font != null:
		label.add_theme_font_override("font", regular_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.94))
	label.add_theme_constant_override("outline_size", outline_size)
	label.horizontal_alignment = alignment as HorizontalAlignment


func _style_rule(rule: ColorRect, color: Color, height: int = 2) -> void:
	if rule == null:
		return
	rule.color = color
	rule.custom_minimum_size = Vector2(0, height)


func _style_line_edit(input: LineEdit) -> void:
	if input == null:
		return
	var regular_font: Font = input.get_theme_font("font", "LineEdit")
	if regular_font != null:
		input.add_theme_font_override("font", regular_font)
	input.add_theme_font_size_override("font_size", 18)
	input.add_theme_color_override("font_color", MENU_TEXT)
	input.add_theme_color_override("font_placeholder_color", MENU_TEXT_MUTED)
	input.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.92))
	input.add_theme_constant_override("outline_size", 1)
	input.add_theme_stylebox_override("normal", _make_panel_style(Color(0.12, 0.10, 0.08, 0.98), MENU_BORDER_MUTED, 1, 10, 0.18, 5, 1))
	input.add_theme_stylebox_override("focus", _make_panel_style(Color(0.16, 0.13, 0.10, 0.98), MENU_ACCENT_SOFT, 2, 10, 0.24, 6, 2))


func _style_option_button(btn: OptionButton) -> void:
	if btn == null:
		return
	_style_button(btn, btn.text, false, 18, 46)
	btn.text = ""


func _style_text_edit(input: TextEdit) -> void:
	if input == null:
		return
	var regular_font: Font = input.get_theme_font("font", "TextEdit")
	if regular_font != null:
		input.add_theme_font_override("font", regular_font)
	input.add_theme_font_size_override("font_size", 18)
	input.add_theme_color_override("font_color", MENU_TEXT)
	input.add_theme_color_override("font_selected_color", MENU_TEXT)
	input.add_theme_color_override("selection_color", Color(0.43, 0.31, 0.11, 0.90))
	input.add_theme_color_override("background_color", Color(0.12, 0.10, 0.08, 0.98))
	input.add_theme_stylebox_override("normal", _make_panel_style(Color(0.12, 0.10, 0.08, 0.98), MENU_BORDER_MUTED, 1, 10, 0.18, 5, 1))
	input.add_theme_stylebox_override("focus", _make_panel_style(Color(0.16, 0.13, 0.10, 0.98), MENU_ACCENT_SOFT, 2, 10, 0.24, 6, 2))


func _style_button(btn: Button, label_text: String, primary: bool, font_size: int = 22, min_height: int = 62) -> void:
	if btn == null:
		return
	var regular_font: Font = btn.get_theme_font("font", "Label")
	if regular_font != null:
		btn.add_theme_font_override("font", regular_font)
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, min_height)
	btn.add_theme_font_size_override("font_size", font_size)
	var font_color := Color(0.13, 0.09, 0.04, 1.0) if primary else MENU_TEXT
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_color_override("font_focus_color", font_color)
	btn.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.94))
	btn.add_theme_constant_override("outline_size", 2)
	var normal_fill := Color(0.66, 0.50, 0.17, 0.98) if primary else Color(0.20, 0.16, 0.11, 0.98)
	var hover_fill := Color(0.76, 0.58, 0.20, 0.98) if primary else Color(0.28, 0.22, 0.14, 0.98)
	var press_fill := Color(0.54, 0.40, 0.14, 0.98) if primary else Color(0.16, 0.13, 0.09, 0.98)
	var border := MENU_BORDER if primary else MENU_BORDER_MUTED.lerp(MENU_BORDER, 0.35)
	btn.add_theme_stylebox_override("normal", _make_panel_style(normal_fill, border, 2, 12, 0.34, 9, 3))
	btn.add_theme_stylebox_override("hover", _make_panel_style(hover_fill, MENU_BORDER, 2, 12, 0.40, 11, 3))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(press_fill, MENU_BORDER, 2, 12, 0.30, 7, 1))
	btn.add_theme_stylebox_override("focus", _make_panel_style(hover_fill, MENU_ACCENT_SOFT, 2, 12, 0.40, 11, 3))


func _set_control_rect(control: Control, pos: Vector2, rect_size: Vector2) -> void:
	if control == null:
		return
	control.position = pos
	control.size = rect_size
	control.offset_left = pos.x
	control.offset_top = pos.y
	control.offset_right = pos.x + rect_size.x
	control.offset_bottom = pos.y + rect_size.y


func _style_slot_button(btn: Button) -> void:
	if btn == null:
		return
	var regular_font: Font = btn.get_theme_font("font", "Label")
	if regular_font != null:
		btn.add_theme_font_override("font", regular_font)
	btn.text = ""
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_stylebox_override("normal", _make_panel_style(Color(0.17, 0.13, 0.09, 0.98), MENU_BORDER_MUTED, 1, 14, 0.28, 8, 3))
	btn.add_theme_stylebox_override("hover", _make_panel_style(Color(0.23, 0.18, 0.12, 0.98), MENU_BORDER, 2, 14, 0.34, 10, 3))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.13, 0.10, 0.07, 0.98), MENU_BORDER, 2, 14, 0.24, 6, 1))
	btn.add_theme_stylebox_override("focus", _make_panel_style(Color(0.23, 0.18, 0.12, 0.98), MENU_ACCENT_SOFT, 2, 14, 0.34, 10, 3))


func _style_auto_slot_button(btn: Button, slot_num: int) -> void:
	if btn == null:
		return
	var regular_font: Font = btn.get_theme_font("font", "Label")
	if regular_font != null:
		btn.add_theme_font_override("font", regular_font)
	btn.text = "AUTO\n%d" % slot_num
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color(0.10, 0.08, 0.04, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.10, 0.08, 0.04, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.10, 0.08, 0.04, 1.0))
	btn.add_theme_color_override("font_focus_color", Color(0.10, 0.08, 0.04, 1.0))
	btn.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.85))
	btn.add_theme_constant_override("outline_size", 2)
	btn.add_theme_stylebox_override("normal", _make_panel_style(Color(0.75, 0.61, 0.22, 0.98), MENU_BORDER, 2, 12, 0.26, 7, 2))
	btn.add_theme_stylebox_override("hover", _make_panel_style(Color(0.83, 0.68, 0.26, 0.98), MENU_BORDER, 2, 12, 0.30, 8, 2))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.59, 0.47, 0.17, 0.98), MENU_BORDER, 2, 12, 0.24, 5, 1))
	btn.add_theme_stylebox_override("focus", _make_panel_style(Color(0.83, 0.68, 0.26, 0.98), MENU_ACCENT_SOFT, 2, 12, 0.30, 8, 2))


func _style_delete_button(btn: Button) -> void:
	if btn == null:
		return
	var regular_font: Font = btn.get_theme_font("font", "Label")
	if regular_font != null:
		btn.add_theme_font_override("font", regular_font)
	btn.text = "X"
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", MENU_TEXT)
	btn.add_theme_color_override("font_hover_color", MENU_TEXT)
	btn.add_theme_color_override("font_pressed_color", MENU_TEXT)
	btn.add_theme_color_override("font_focus_color", MENU_TEXT)
	btn.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.94))
	btn.add_theme_constant_override("outline_size", 2)
	btn.add_theme_stylebox_override("normal", _make_panel_style(Color(0.21, 0.09, 0.08, 0.98), MENU_ERROR.lerp(MENU_BORDER_MUTED, 0.45), 1, 12, 0.22, 6, 2))
	btn.add_theme_stylebox_override("hover", _make_panel_style(Color(0.31, 0.11, 0.10, 0.98), MENU_ERROR, 2, 12, 0.28, 8, 2))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.17, 0.07, 0.06, 0.98), MENU_ERROR, 2, 12, 0.20, 4, 1))
	btn.add_theme_stylebox_override("focus", _make_panel_style(Color(0.31, 0.11, 0.10, 0.98), MENU_ACCENT_SOFT, 2, 12, 0.28, 8, 2))


func _style_dialog(dialog: ConfirmationDialog) -> void:
	if dialog == null:
		return
	var regular_font: Font = dialog.get_theme_font("font", "Label")
	if regular_font != null:
		dialog.add_theme_font_override("font", regular_font)
	dialog.add_theme_font_size_override("title_font_size", 20)
	dialog.add_theme_font_size_override("font_size", 18)
	dialog.add_theme_color_override("title_color", MENU_ACCENT)
	dialog.add_theme_color_override("font_color", MENU_TEXT)
	dialog.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.94))
	dialog.add_theme_constant_override("outline_size", 2)
	dialog.add_theme_stylebox_override("panel", _make_panel_style(MENU_BG, MENU_BORDER, 2, 18, 0.44, 14, 6))


func _style_slot_contents(slot_button: Button) -> void:
	var accent_bar = slot_button.get_node_or_null("MarginContainer/HBox/AccentBar") as ColorRect
	var portrait_rect = slot_button.get_node_or_null("MarginContainer/HBox/Portrait") as TextureRect
	var name_label = slot_button.get_node_or_null("MarginContainer/HBox/TextVBox/NameLabel") as Label
	var loc_label = slot_button.get_node_or_null("MarginContainer/HBox/TextVBox/LocationLabel") as Label
	var meta_label = slot_button.get_node_or_null("MarginContainer/HBox/TextVBox/MetaLabel") as Label
	var gold_label = slot_button.get_node_or_null("MarginContainer/HBox/GoldLabel") as Label
	if accent_bar != null:
		accent_bar.color = MENU_ACCENT_SOFT.lerp(MENU_ACCENT, 0.55)
		accent_bar.custom_minimum_size = Vector2(6, 0)
	if portrait_rect != null:
		portrait_rect.custom_minimum_size = Vector2(92, 92)
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if name_label != null:
		_style_label(name_label, MENU_ACCENT, 22, 2)
	if loc_label != null:
		_style_label(loc_label, MENU_TEXT, 16, 1)
	if meta_label != null:
		_style_label(meta_label, MENU_ACCENT_SOFT.lerp(MENU_TEXT, 0.42), 15, 1)
	if gold_label != null:
		_style_label(gold_label, MENU_ACCENT_SOFT, 20, 2, HORIZONTAL_ALIGNMENT_RIGHT)


func _get_dispatch_category_color(category: String) -> Color:
	match category.to_upper():
		"MODIFICATIONS":
			return MENU_WARNING
		"OTHER":
			return MENU_ACCENT_SOFT
		_:
			return MENU_ACCENT


func _default_dispatch_payload() -> Dictionary:
	return {
		"title": "WAR TABLE UPDATES",
		"category": "NEWS",
		"body": "The dispatch channel is live. Use this space for news, modifications, event notes, maintenance warnings, or community-facing updates once the bulletin is approved and published.",
		"author": "WAR TABLE",
		"updated_at": int(Time.get_unix_time_from_system())
	}


func _get_steam_singleton() -> Object:
	if Engine.has_singleton("Steam"):
		return Engine.get_singleton("Steam")
	return null


func _can_edit_dispatch() -> bool:
	var steam_singleton := _get_steam_singleton()
	if steam_singleton != null and steam_singleton.has_method("getSteamID"):
		var steam_id := str(steam_singleton.call("getSteamID"))
		return DISPATCH_APPROVED_STEAM_IDS.has(steam_id)
	return OS.is_debug_build() and DISPATCH_ALLOW_DEBUG_EDITOR


func _get_dispatch_editor_name() -> String:
	var steam_singleton := _get_steam_singleton()
	if steam_singleton != null and steam_singleton.has_method("getPersonaName"):
		return str(steam_singleton.call("getPersonaName"))
	return "LOCAL DEBUG"


func _format_dispatch_stamp(unix_time: int, author: String) -> String:
	var author_name := author.strip_edges()
	if unix_time <= 0:
		return "LIVE BULLETIN // %s" % (author_name if author_name != "" else "WAR TABLE")
	var date_info: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return "LIVE BULLETIN // %02d/%02d/%04d %02d:%02d // %s" % [
		int(date_info.get("day", 1)),
		int(date_info.get("month", 1)),
		int(date_info.get("year", 2000)),
		int(date_info.get("hour", 0)),
		int(date_info.get("minute", 0)),
		author_name if author_name != "" else "WAR TABLE"
	]


func _apply_dispatch_payload(payload: Dictionary, status_text: String = "Awaiting dispatch confirmation.") -> void:
	_dispatch_payload = payload.duplicate(true)
	var category := str(payload.get("category", "NEWS")).to_upper()
	var category_color := _get_dispatch_category_color(category)
	var headline := str(payload.get("title", "WAR TABLE UPDATES")).strip_edges()
	var body := str(payload.get("body", "")).strip_edges()
	var author := str(payload.get("author", "WAR TABLE"))
	var updated_at := int(payload.get("updated_at", 0))
	if headline == "":
		headline = "WAR TABLE UPDATES"
	if body == "":
		body = "No live dispatch is posted yet."
	dispatch_category_label.text = category
	dispatch_category_label.add_theme_color_override("font_color", category_color)
	dispatch_meta_label.text = _format_dispatch_stamp(updated_at, author)
	dispatch_meta_label.add_theme_color_override("font_color", MENU_TEXT_MUTED)
	dispatch_status_label.text = status_text
	dispatch_status_label.add_theme_color_override("font_color", MENU_TEXT_MUTED)
	dispatch_body_label.text = "[color=#f1d07a]%s[/color]\n\n[color=#efe7d5]%s[/color]" % [headline, body]
	call_deferred("_refresh_dispatch_body_layout")


func _refresh_dispatch_body_layout() -> void:
	if dispatch_body_label == null or dispatch_scroll == null:
		return
	var body_width: float = maxf(dispatch_scroll.size.x - 18.0, 280.0)
	dispatch_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dispatch_body_label.custom_minimum_size = Vector2(body_width, 0.0)
	dispatch_body_label.size = Vector2(body_width, dispatch_body_label.size.y)
	call_deferred("_finish_dispatch_body_layout", body_width)


func _finish_dispatch_body_layout(body_width: float) -> void:
	if dispatch_body_label == null or dispatch_scroll == null:
		return
	var content_height: float = maxf(dispatch_body_label.get_content_height() + 12.0, dispatch_scroll.size.y)
	dispatch_body_label.custom_minimum_size = Vector2(body_width, content_height)
	dispatch_body_label.size = Vector2(body_width, content_height)


func _fetch_dispatch_feed() -> void:
	_apply_dispatch_payload(_default_dispatch_payload(), "SYNCING DISPATCH FEED...")
	if not has_node("/root/SilentWolf"):
		_apply_dispatch_payload(_default_dispatch_payload(), "LOCAL FALLBACK // SILENTWOLF OFFLINE")
		return
	_fetch_dispatch_feed_async()


func _fetch_dispatch_feed_async() -> void:
	var sw_result = await SilentWolf.Scores.get_scores(1, DISPATCH_LEADERBOARD).sw_get_scores_complete
	var scores: Array = []
	if sw_result is Dictionary:
		scores = sw_result.get("scores", [])
	if scores.is_empty():
		scores = SilentWolf.Scores.scores
	if scores.is_empty():
		_apply_dispatch_payload(_default_dispatch_payload(), "LOCAL FALLBACK // NO LIVE DISPATCH")
		return
	var top_entry: Dictionary = scores[0]
	var metadata: Dictionary = top_entry.get("metadata", {})
	var payload := {
		"title": str(metadata.get("title", "WAR TABLE UPDATES")),
		"category": str(metadata.get("category", "NEWS")),
		"body": str(metadata.get("body", metadata.get("message", ""))),
		"author": str(metadata.get("author", top_entry.get("player_name", "WAR TABLE"))),
		"updated_at": int(metadata.get("updated_at", int(top_entry.get("score", 0))))
	}
	_apply_dispatch_payload(payload, "LIVE DISPATCH // VERIFIED")


func _open_dispatch_editor() -> void:
	if not _can_edit_dispatch():
		return
	if dispatch_editor_dialog == null:
		return
	dispatch_editor_dialog.get_ok_button().text = "PUBLISH DISPATCH"
	dispatch_category_option.select(max(DISPATCH_CATEGORIES.find(str(_dispatch_payload.get("category", "NEWS")).to_upper()), 0))
	dispatch_headline_edit.text = str(_dispatch_payload.get("title", "WAR TABLE UPDATES"))
	dispatch_body_edit.text = str(_dispatch_payload.get("body", ""))
	dispatch_editor_dialog.exclusive = true
	dispatch_editor_dialog.min_size = Vector2i(860, 560)
	dispatch_editor_dialog.popup_centered(Vector2i(860, 560))
	dispatch_editor_dialog.move_to_foreground()
	dispatch_headline_edit.call_deferred("grab_focus")


func _on_dispatch_editor_confirmed() -> void:
	var category: String = DISPATCH_CATEGORIES[dispatch_category_option.selected]
	var title := dispatch_headline_edit.text.strip_edges()
	var body := dispatch_body_edit.text.strip_edges()
	if title == "" or body == "":
		_apply_dispatch_payload(_dispatch_payload if not _dispatch_payload.is_empty() else _default_dispatch_payload(), "DISPATCH REJECTED // HEADLINE OR MESSAGE MISSING")
		return
	var payload := {
		"title": title,
		"category": category,
		"body": body,
		"author": _get_dispatch_editor_name(),
		"updated_at": int(Time.get_unix_time_from_system())
	}
	_apply_dispatch_payload(payload, "PUBLISHING DISPATCH...")
	_publish_dispatch_async(payload)


func _publish_dispatch_async(payload: Dictionary) -> void:
	if not has_node("/root/SilentWolf"):
		_apply_dispatch_payload(payload, "LOCAL DEBUG // NO CLOUD SYNC")
		return
	var fresh_score := int(Time.get_unix_time_from_system())
	var sw_result = await SilentWolf.Scores.save_score("SYSTEM", fresh_score, DISPATCH_LEADERBOARD, payload).sw_save_score_complete
	var success := false
	if sw_result is Dictionary:
		success = bool(sw_result.get("success", false))
	if success:
		_apply_dispatch_payload(payload, "LIVE DISPATCH // PUBLISHED")
		return
	_apply_dispatch_payload(payload, "LOCAL DISPLAY // CLOUD PUBLISH NOT CONFIRMED")


func _apply_theme() -> void:
	_style_panel(header_panel, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 0, 0.0)
	_style_panel(intel_panel, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 0, 0.0)
	_style_panel(dispatch_panel, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 0, 0.0)
	_style_panel(header_card, MENU_BG, MENU_BORDER, 2, 22, 0.46)
	_style_panel(intel_card, Color(0.14, 0.11, 0.08, 0.94), MENU_BORDER_MUTED, 1, 20, 0.34)
	_style_panel(dispatch_card, Color(0.14, 0.11, 0.08, 0.94), MENU_BORDER_MUTED, 1, 20, 0.34)
	_style_panel(main_vbox, MENU_BG_ALT, MENU_BORDER, 2, 22, 0.50)
	_style_panel(campaign_vbox, MENU_BG, MENU_BORDER, 2, 22, 0.50)

	_style_label($HeaderPanel/HeaderCard/Margin/VBox/Overline, MENU_TEXT_MUTED, 16, 1)
	_style_label($HeaderPanel/HeaderCard/Margin/VBox/HeaderTitle, MENU_ACCENT, 40, 4)
	_style_label($HeaderPanel/HeaderCard/Margin/VBox/HeaderSubtitle, MENU_TEXT, 28, 3)
	_style_label($HeaderPanel/HeaderCard/Margin/VBox/HeaderBody, MENU_TEXT_MUTED, 17, 1)

	_style_label($IntelPanel/IntelCard/Margin/VBox/IntelTitle, MENU_ACCENT, 28, 3)
	_style_rule(intel_rule, MENU_BORDER_MUTED.lerp(MENU_ACCENT_SOFT, 0.35), 2)
	_style_label($IntelPanel/IntelCard/Margin/VBox/IntelCopy, MENU_TEXT_MUTED, 15, 1)
	for path in [
		"IntelPanel/IntelCard/Margin/VBox/IntelItem1",
		"IntelPanel/IntelCard/Margin/VBox/IntelItem2",
		"IntelPanel/IntelCard/Margin/VBox/IntelItem3",
		"IntelPanel/IntelCard/Margin/VBox/IntelItem4",
		"IntelPanel/IntelCard/Margin/VBox/IntelItem5"
	]:
		_style_label(get_node(path) as Label, MENU_TEXT, 15, 1)
	_style_label($DispatchPanel/DispatchCard/Margin/VBox/DispatchTitle, MENU_ACCENT, 26, 3)
	_style_rule(dispatch_rule, MENU_BORDER_MUTED.lerp(MENU_ACCENT_SOFT, 0.35), 2)
	_style_label(dispatch_meta_label, MENU_TEXT_MUTED, 14, 1)
	_style_label(dispatch_category_label, MENU_ACCENT, 15, 2)
	_style_label(dispatch_status_label, MENU_TEXT_MUTED, 14, 1)
	dispatch_status_label.clip_text = true
	dispatch_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	dispatch_body_label.add_theme_font_size_override("normal_font_size", 16)
	dispatch_body_label.add_theme_font_override("normal_font", dispatch_body_label.get_theme_font("normal_font", "RichTextLabel"))
	dispatch_body_label.add_theme_color_override("default_color", MENU_TEXT)
	dispatch_body_label.scroll_active = false
	dispatch_body_label.fit_content = false

	_style_label($CenterStage/MainPanel/Margin/VBox/MainKicker, MENU_TEXT_MUTED, 16, 1)
	_style_label($CenterStage/MainPanel/Margin/VBox/MainTitle, MENU_ACCENT, 30, 3)
	_style_label($CenterStage/MainPanel/Margin/VBox/MainBody, MENU_TEXT_MUTED, 17, 1)
	_style_label($CenterStage/MainPanel/Margin/VBox/MainHint, MENU_ACCENT_SOFT.lerp(MENU_TEXT, 0.35), 15, 1)

	_style_label($CenterStage/CampaignMenu/Margin/VBox/CampaignKicker, MENU_TEXT_MUTED, 16, 1)
	_style_label($CenterStage/CampaignMenu/Margin/VBox/CampaignTitle, MENU_ACCENT, 30, 3)
	_style_label($CenterStage/CampaignMenu/Margin/VBox/CampaignBody, MENU_TEXT_MUTED, 17, 1)
	_style_label($CenterStage/CampaignMenu/Margin/VBox/SlotsHeader, MENU_WARNING, 18, 2)

	_style_button(start_button, "CAMPAIGN COMMAND", true, 24, 64)
	_style_button(settings_button, "FIELD SETTINGS", false, 22, 58)
	_style_button(quit_button, "QUIT TO DESKTOP", false, 22, 58)
	_style_button(continue_button, "CONTINUE CAMPAIGN", true, 22, 66)
	_style_button(new_game_button, "NEW CAMPAIGN", false, 22, 62)
	_style_button(load_game_button, "ARCHIVE SLOTS", false, 22, 62)
	_style_button(back_button, "RETURN TO ENTRY", false, 20, 54)
	_style_button(edit_dispatch_button, "EDIT", false, 18, 46)

	for auto_btn in [auto_slot_1_btn, auto_slot_2_btn, auto_slot_3_btn]:
		var slot_num := 1 if auto_btn == auto_slot_1_btn else 2 if auto_btn == auto_slot_2_btn else 3
		_style_auto_slot_button(auto_btn, slot_num)

	for delete_btn in [del_slot_1_btn, del_slot_2_btn, del_slot_3_btn]:
		_style_delete_button(delete_btn)

	for slot_btn in [slot_1_btn, slot_2_btn, slot_3_btn]:
		_style_slot_button(slot_btn)
		_style_slot_contents(slot_btn)

	_style_dialog(delete_dialog)
	_style_dialog(overwrite_dialog)
	_style_dialog(dispatch_editor_dialog)
	_style_label($DispatchEditorDialog/Margin/VBox/DispatchCategoryLabel, MENU_ACCENT, 18, 2)
	_style_label($DispatchEditorDialog/Margin/VBox/DispatchHeadlineLabel, MENU_ACCENT, 18, 2)
	_style_label($DispatchEditorDialog/Margin/VBox/DispatchBodyLabel, MENU_ACCENT, 18, 2)
	_style_label($DispatchEditorDialog/Margin/VBox/DispatchEditorHint, MENU_TEXT_MUTED, 15, 1)
	_style_option_button(dispatch_category_option)
	_style_line_edit(dispatch_headline_edit)
	_style_text_edit(dispatch_body_edit)


func _init_audio() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = MENU_MUSIC
	_music_player.autoplay = true
	_music_player.volume_db = -6.0
	add_child(_music_player)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)


func _play_hover_sfx() -> void:
	if _sfx_player == null:
		return
	_sfx_player.stream = SFX_HOVER
	_sfx_player.pitch_scale = randf_range(0.95, 1.05)
	_sfx_player.play()


func _play_click_sfx() -> void:
	if _sfx_player == null:
		return
	_sfx_player.stream = SFX_CLICK
	_sfx_player.pitch_scale = randf_range(0.92, 1.08)
	_sfx_player.play()


func _button_press_feedback(control: Control) -> void:
	if control == null:
		return
	var t := create_tween()
	t.tween_property(control, "scale", Vector2(0.97, 0.97), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(control, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _button_hover_entered(control: Control) -> void:
	if control == null:
		return
	var t := create_tween()
	t.tween_property(control, "scale", Vector2(1.02, 1.02), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _button_hover_exited(control: Control) -> void:
	if control == null:
		return
	var t := create_tween()
	t.tween_property(control, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _wire_button_feedback(buttons: Array) -> void:
	for raw_button in buttons:
		var btn := raw_button as BaseButton
		if btn == null:
			continue
		var ctrl := btn as Control
		btn.mouse_entered.connect(func():
			_play_hover_sfx()
			_button_hover_entered(ctrl)
		)
		btn.mouse_exited.connect(func(): _button_hover_exited(ctrl))
		btn.pressed.connect(func():
			_play_click_sfx()
			_button_press_feedback(ctrl)
		)


func _connect_signals() -> void:
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_layout_menu):
		vp.size_changed.connect(_layout_menu)

	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	back_button.pressed.connect(_on_back_pressed)

	slot_1_btn.pressed.connect(func(): _on_slot_pressed(1))
	slot_2_btn.pressed.connect(func(): _on_slot_pressed(2))
	slot_3_btn.pressed.connect(func(): _on_slot_pressed(3))

	auto_slot_1_btn.pressed.connect(func(): _on_slot_pressed(1, true))
	auto_slot_2_btn.pressed.connect(func(): _on_slot_pressed(2, true))
	auto_slot_3_btn.pressed.connect(func(): _on_slot_pressed(3, true))

	del_slot_1_btn.pressed.connect(func(): _on_delete_pressed(1))
	del_slot_2_btn.pressed.connect(func(): _on_delete_pressed(2))
	del_slot_3_btn.pressed.connect(func(): _on_delete_pressed(3))

	if delete_dialog != null:
		delete_dialog.confirmed.connect(_on_delete_confirmed)
	if dispatch_editor_dialog != null:
		dispatch_editor_dialog.confirmed.connect(_on_dispatch_editor_confirmed)
	if edit_dispatch_button != null:
		edit_dispatch_button.pressed.connect(_open_dispatch_editor)

	_wire_button_feedback([
		start_button,
		settings_button,
		quit_button,
		continue_button,
		new_game_button,
		load_game_button,
		back_button,
		slot_1_btn,
		slot_2_btn,
		slot_3_btn,
		auto_slot_1_btn,
		auto_slot_2_btn,
		auto_slot_3_btn,
		del_slot_1_btn,
		del_slot_2_btn,
		del_slot_3_btn,
		edit_dispatch_button
	])


func _prepare_intro_state() -> void:
	_layout_menu()
	main_vbox.visible = true
	campaign_vbox.visible = false
	slots_container.visible = false
	main_vbox.modulate.a = 0.0
	main_vbox.scale = Vector2(0.97, 0.97)
	campaign_vbox.modulate.a = 0.0
	campaign_vbox.scale = Vector2(0.97, 0.97)
	if header_panel != null:
		header_panel.modulate.a = 0.0
		header_panel.position.y -= 18.0
	if intel_panel != null:
		intel_panel.modulate.a = 0.0
		intel_panel.position.y += 18.0
	if dispatch_panel != null:
		dispatch_panel.modulate.a = 0.0
		dispatch_panel.position.y += 18.0
	var intro := create_tween()
	intro.set_parallel(true)
	intro.tween_property(main_vbox, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro.tween_property(main_vbox, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if header_panel != null:
		intro.tween_property(header_panel, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		intro.tween_property(header_panel, "position:y", header_panel.position.y + 18.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if intel_panel != null:
		intro.tween_property(intel_panel, "modulate:a", 1.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		intro.tween_property(intel_panel, "position:y", intel_panel.position.y - 18.0, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if dispatch_panel != null:
		intro.tween_property(dispatch_panel, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		intro.tween_property(dispatch_panel, "position:y", dispatch_panel.position.y - 18.0, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _ready() -> void:
	if SettingsMenu != null and SettingsMenu.has_method("hide_menu"):
		SettingsMenu.hide_menu()
	_apply_theme()
	_connect_signals()
	_layout_menu()
	_refresh_save_ui()
	dispatch_category_option.clear()
	for category in DISPATCH_CATEGORIES:
		dispatch_category_option.add_item(category)
	edit_dispatch_button.visible = _can_edit_dispatch()
	_init_audio()
	_prepare_intro_state()
	_start_atmosphere_pass()
	_fetch_dispatch_feed()
	start_button.grab_focus()


func _layout_menu() -> void:
	var vp_size := get_viewport_rect().size
	if backdrop_art != null:
		backdrop_art.pivot_offset = vp_size * 0.5
	if header_panel != null:
		var header_size := Vector2(clampf(vp_size.x * 0.42, 700.0, 850.0), clampf(vp_size.y * 0.165, 154.0, 188.0))
		_set_control_rect(header_panel, Vector2(32.0, 28.0), header_size)
		if header_card != null:
			_set_control_rect(header_card, Vector2.ZERO, header_size)
	if intel_panel != null:
		var right_width := clampf(vp_size.x * 0.23, 360.0, 430.0)
		var right_x := vp_size.x - right_width - 32.0
		var right_top := 34.0
		var right_gap := 24.0
		var intel_size := Vector2(right_width, clampf(vp_size.y * 0.305, 300.0, 360.0))
		_set_control_rect(intel_panel, Vector2(right_x, right_top), intel_size)
		if intel_card != null:
			_set_control_rect(intel_card, Vector2.ZERO, intel_size)
		if dispatch_panel != null:
			var available_dispatch_height: float = maxf(vp_size.y - (right_top + intel_size.y + right_gap) - 44.0, 230.0)
			var dispatch_size := Vector2(right_width, clampf(minf(available_dispatch_height, vp_size.y * 0.29), 250.0, 330.0))
			var dispatch_pos := Vector2(right_x, right_top + intel_size.y + right_gap)
			_set_control_rect(dispatch_panel, dispatch_pos, dispatch_size)
			if dispatch_card != null:
				_set_control_rect(dispatch_card, Vector2.ZERO, dispatch_size)
	if main_vbox != null:
		var main_size := Vector2(clampf(vp_size.x * 0.41, 740.0, 900.0), clampf(vp_size.y * 0.24, 286.0, 350.0))
		_set_control_rect(main_vbox, Vector2((vp_size.x - main_size.x) * 0.5, clampf(vp_size.y * 0.34, 278.0, 356.0)), main_size)
	if campaign_vbox != null:
		var campaign_size := Vector2(clampf(vp_size.x * 0.66, 1120.0, 1320.0), clampf(vp_size.y * 0.56, 520.0, 640.0))
		_set_control_rect(campaign_vbox, Vector2((vp_size.x - campaign_size.x) * 0.5, clampf(vp_size.y * 0.22, 196.0, 252.0)), campaign_size)
	_refresh_dispatch_body_layout()


func _format_record_timestamp(unix_time: int) -> String:
	if unix_time <= 0:
		return "UPDATED: ARCHIVE DATE UNKNOWN"
	var date_info: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	var day := int(date_info.get("day", 1))
	var month := int(date_info.get("month", 1))
	var year := int(date_info.get("year", 2000))
	var hour := int(date_info.get("hour", 0))
	var minute := int(date_info.get("minute", 0))
	return "UPDATED: %02d/%02d/%04d  %02d:%02d" % [day, month, year, hour, minute]


func _start_atmosphere_pass() -> void:
	if backdrop_art != null:
		backdrop_art.scale = Vector2(1.02, 1.02)
		backdrop_art.position = Vector2(-18.0, -10.0)
		var drift := create_tween()
		drift.set_loops()
		drift.set_parallel(true)
		drift.tween_property(backdrop_art, "scale", Vector2(1.05, 1.05), 10.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(backdrop_art, "position", Vector2(-34.0, -18.0), 10.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.chain().set_parallel(true)
		drift.tween_property(backdrop_art, "scale", Vector2(1.03, 1.03), 12.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(backdrop_art, "position", Vector2(12.0, -6.0), 12.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if backdrop_warmth != null:
		backdrop_warmth.modulate.a = 0.72
		var warmth := create_tween()
		warmth.set_loops()
		warmth.tween_property(backdrop_warmth, "modulate:a", 0.92, 6.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		warmth.tween_property(backdrop_warmth, "modulate:a", 0.68, 8.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if backdrop_shade != null:
		backdrop_shade.modulate.a = 1.0
		var shade := create_tween()
		shade.set_loops()
		shade.tween_property(backdrop_shade, "modulate:a", 0.96, 7.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		shade.tween_property(backdrop_shade, "modulate:a", 1.0, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _animate_archive_rows() -> void:
	if slots_container == null or not slots_container.visible:
		return
	var delay := 0.0
	for raw_row in slots_container.get_children():
		var row := raw_row as Control
		if row == null:
			continue
		row.modulate.a = 0.0
		row.scale = Vector2(0.985, 0.985)
		var row_tween := create_tween()
		row_tween.tween_property(row, "modulate:a", 1.0, 0.18).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		row_tween.parallel().tween_property(row, "scale", Vector2.ONE, 0.24).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		delay += 0.045


func _get_slot_button(slot_num: int, is_auto: bool) -> Button:
	match slot_num:
		1:
			return auto_slot_1_btn if is_auto else slot_1_btn
		2:
			return auto_slot_2_btn if is_auto else slot_2_btn
		3:
			return auto_slot_3_btn if is_auto else slot_3_btn
	return null


func _refresh_save_ui() -> void:
	var has_slot1 := FileAccess.file_exists(CampaignManager.get_save_path(1, false))
	var has_slot2 := FileAccess.file_exists(CampaignManager.get_save_path(2, false))
	var has_slot3 := FileAccess.file_exists(CampaignManager.get_save_path(3, false))
	var has_auto1 := FileAccess.file_exists(CampaignManager.get_save_path(1, true))
	var has_auto2 := FileAccess.file_exists(CampaignManager.get_save_path(2, true))
	var has_auto3 := FileAccess.file_exists(CampaignManager.get_save_path(3, true))

	var slot1_active := has_slot1 or has_auto1
	var slot2_active := has_slot2 or has_auto2
	var slot3_active := has_slot3 or has_auto3

	slot_1_btn.visible = slot1_active
	slot_2_btn.visible = slot2_active
	slot_3_btn.visible = slot3_active

	if slot1_active:
		_update_save_slot_ui(slot_1_btn, 1, false)
	if slot2_active:
		_update_save_slot_ui(slot_2_btn, 2, false)
	if slot3_active:
		_update_save_slot_ui(slot_3_btn, 3, false)

	auto_slot_1_btn.visible = has_auto1
	auto_slot_2_btn.visible = has_auto2
	auto_slot_3_btn.visible = has_auto3
	if auto_slot_1_btn.visible:
		auto_slot_1_btn.text = "AUTO\n1"
	if auto_slot_2_btn.visible:
		auto_slot_2_btn.text = "AUTO\n2"
	if auto_slot_3_btn.visible:
		auto_slot_3_btn.text = "AUTO\n3"

	del_slot_1_btn.visible = slot1_active
	del_slot_2_btn.visible = slot2_active
	del_slot_3_btn.visible = slot3_active

	var has_any_saves := slot1_active or slot2_active or slot3_active
	continue_button.visible = has_any_saves
	load_game_button.visible = has_any_saves
	if not has_any_saves:
		slots_container.visible = false


func _update_save_slot_ui(slot_button: Button, slot_num: int, is_auto: bool) -> void:
	var path := CampaignManager.get_save_path(slot_num, is_auto)
	var portrait_rect := slot_button.get_node_or_null("MarginContainer/HBox/Portrait") as TextureRect
	var name_label := slot_button.get_node_or_null("MarginContainer/HBox/TextVBox/NameLabel") as Label
	var loc_label := slot_button.get_node_or_null("MarginContainer/HBox/TextVBox/LocationLabel") as Label
	var meta_label := slot_button.get_node_or_null("MarginContainer/HBox/TextVBox/MetaLabel") as Label
	var gold_label := slot_button.get_node_or_null("MarginContainer/HBox/GoldLabel") as Label
	if name_label == null:
		return

	var prefix := "AUTO %d" % slot_num if is_auto else "SLOT %d" % slot_num
	if not FileAccess.file_exists(path):
		name_label.text = "%s - EMPTY" % prefix
		name_label.add_theme_color_override("font_color", MENU_TEXT_MUTED)
		if loc_label != null:
			loc_label.text = "No active field record."
		if meta_label != null:
			meta_label.text = "Awaiting a new war-table entry."
		if gold_label != null:
			gold_label.text = ""
		if portrait_rect != null:
			portrait_rect.texture = null
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var save_data = file.get_var()
	file.close()

	if typeof(save_data) != TYPE_DICTIONARY:
		name_label.text = "%s - CORRUPTED" % prefix
		name_label.add_theme_color_override("font_color", MENU_ERROR)
		if loc_label != null:
			loc_label.text = "Archive could not be decoded."
		if meta_label != null:
			meta_label.text = "Field record integrity check failed."
		if gold_label != null:
			gold_label.text = ""
		return

	var roster: Array = save_data.get("player_roster", [])
	var leader_name := "Unknown"
	var leader_lvl := 1
	var portrait_value: Variant = ""
	if roster.size() > 0:
		leader_name = roster[0].get("unit_name", "Hero")
		leader_lvl = roster[0].get("level", 1)
		portrait_value = roster[0].get("portrait", "")

	var gold: int = int(save_data.get("global_gold", 0))
	var map_idx := int(save_data.get("current_level_index", 0)) + 1
	var modified_time := int(FileAccess.get_modified_time(path))
	name_label.text = "%s // %s  LV %d" % [prefix, leader_name.to_upper(), leader_lvl]
	name_label.add_theme_color_override("font_color", MENU_ACCENT)
	if loc_label != null:
		loc_label.text = "FIELD RECORD: MAP %d  |  ACTIVE COMMANDER FILE" % map_idx
		loc_label.add_theme_color_override("font_color", MENU_TEXT_MUTED)
	if meta_label != null:
		meta_label.text = _format_record_timestamp(modified_time)
		meta_label.add_theme_color_override("font_color", MENU_ACCENT_SOFT.lerp(MENU_TEXT, 0.35))
	if gold_label != null:
		gold_label.text = "GOLD %d" % gold
		gold_label.add_theme_color_override("font_color", MENU_ACCENT_SOFT)
	if portrait_rect != null:
		if portrait_value is String and ResourceLoader.exists(str(portrait_value)):
			portrait_rect.texture = load(str(portrait_value))
		elif portrait_value is Texture2D:
			portrait_rect.texture = portrait_value as Texture2D


func _on_start_pressed() -> void:
	var t := create_tween()
	t.tween_property(main_vbox, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(main_vbox, "scale", Vector2(0.97, 0.97), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		main_vbox.visible = false
		campaign_vbox.visible = true
		campaign_vbox.modulate.a = 0.0
		campaign_vbox.scale = Vector2(0.97, 0.97)
		slots_container.visible = false
	)
	t.tween_property(campaign_vbox, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(campaign_vbox, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		if continue_button.visible:
			continue_button.grab_focus()
		else:
			new_game_button.grab_focus()
	)


func _on_back_pressed() -> void:
	var t := create_tween()
	t.tween_property(campaign_vbox, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(campaign_vbox, "scale", Vector2(0.97, 0.97), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		campaign_vbox.visible = false
		slots_container.visible = false
		main_vbox.visible = true
		main_vbox.modulate.a = 0.0
		main_vbox.scale = Vector2(0.97, 0.97)
	)
	t.tween_property(main_vbox, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(main_vbox, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): start_button.grab_focus())


func _on_settings_pressed() -> void:
	if SettingsMenu != null and SettingsMenu.has_method("show_menu"):
		SettingsMenu.show_menu()


func _on_new_game_pressed() -> void:
	if CampaignManager.has_method("reset_campaign_data"):
		CampaignManager.reset_campaign_data()
	CampaignManager.current_level_index = 0
	CampaignManager.active_save_slot = 1
	for i in range(1, 4):
		if not FileAccess.file_exists(CampaignManager.get_save_path(i, false)) and not FileAccess.file_exists(CampaignManager.get_save_path(i, true)):
			CampaignManager.active_save_slot = i
			break
	SceneTransition.change_scene_to_file("res://Scenes/character_creation.tscn")


func _on_continue_pressed() -> void:
	var newest_slot := -1
	var newest_is_auto := false
	var newest_time := 0
	for i in range(1, 4):
		var man_path := CampaignManager.get_save_path(i, false)
		if FileAccess.file_exists(man_path):
			var mod_time := FileAccess.get_modified_time(man_path)
			if mod_time > newest_time:
				newest_time = mod_time
				newest_slot = i
				newest_is_auto = false
		var auto_path := CampaignManager.get_save_path(i, true)
		if FileAccess.file_exists(auto_path):
			var auto_time := FileAccess.get_modified_time(auto_path)
			if auto_time > newest_time:
				newest_time = auto_time
				newest_slot = i
				newest_is_auto = true
	if newest_slot != -1:
		_on_slot_pressed(newest_slot, newest_is_auto)


func _on_load_game_pressed() -> void:
	var showing := not slots_container.visible
	if showing:
		slots_container.visible = true
		slots_container.modulate.a = 0.0
		slots_container.scale = Vector2(0.985, 0.985)
		var t := create_tween()
		t.tween_property(slots_container, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(slots_container, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_callback(_animate_archive_rows)
		if slot_1_btn.visible:
			slot_1_btn.grab_focus()
		elif slot_2_btn.visible:
			slot_2_btn.grab_focus()
		elif slot_3_btn.visible:
			slot_3_btn.grab_focus()
	else:
		var t := create_tween()
		t.tween_property(slots_container, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_callback(func(): slots_container.visible = false)
		load_game_button.grab_focus()


func _on_slot_pressed(slot_num: int, is_auto: bool = false) -> void:
	if CampaignManager.load_game(slot_num, is_auto):
		SceneTransition.change_scene_to_file("res://Scenes/camp_menu.tscn")
	else:
		var btn := _get_slot_button(slot_num, is_auto)
		if btn != null:
			_flash_slot_error(btn)
		print("Error: Failed to load save slot ", slot_num)


func _flash_slot_error(control: Control) -> void:
	if control == null:
		return
	var t := create_tween()
	t.tween_property(control, "modulate", Color(1.0, 0.35, 0.35), 0.08).set_trans(Tween.TRANS_SINE)
	t.tween_property(control, "modulate", Color.WHITE, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_delete_pressed(slot_num: int) -> void:
	pending_delete_slot = slot_num
	if delete_dialog != null:
		delete_dialog.dialog_text = "Are you sure you want to permanently delete save slot %d?" % slot_num
		delete_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	if CampaignManager.has_method("delete_game"):
		CampaignManager.delete_game(pending_delete_slot)
	await get_tree().create_timer(0.10).timeout
	_refresh_save_ui()
	if not continue_button.visible:
		new_game_button.grab_focus()
		slots_container.visible = false
