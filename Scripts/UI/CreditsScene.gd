extends Control
const CREDITS_SECTION_DATA_SCRIPT: GDScript = preload("res://Scripts/UI/Credits/CreditsSectionData.gd")
const CREDITS_CONTRIBUTOR_DATA_SCRIPT: GDScript = preload("res://Scripts/UI/Credits/CreditsContributorData.gd")

const MENU_BG := Color(0.12, 0.10, 0.07, 0.96)
const MENU_BG_ALT := Color(0.17, 0.13, 0.09, 0.96)
const MENU_BORDER := Color(0.82, 0.67, 0.29, 0.96)
const MENU_BORDER_MUTED := Color(0.52, 0.43, 0.22, 0.80)
const MENU_TEXT := Color(0.96, 0.93, 0.86, 1.0)
const MENU_TEXT_MUTED := Color(0.73, 0.69, 0.60, 0.96)
const MENU_ACCENT := Color(0.95, 0.79, 0.28, 1.0)
const MENU_ACCENT_SOFT := Color(0.58, 0.87, 1.0, 1.0)

@export var scroll_speed: float = 28.0
@export var hold_seconds_at_end: float = 1.4
@export var section_gap: int = 22
@export var entry_gap: int = 8
@export var center_highlight_strength: float = 0.42
@export var center_highlight_scale: float = 1.08
@export var sparkles_count: int = 16
@export var edge_fade_band_px: float = 84.0
@export var edge_fade_floor: float = 0.0
@export var hover_pulse_scale_bonus: float = 0.05
@export var hover_pulse_alpha_bonus: float = 0.10
@export var hover_pulse_smoothing: float = 0.18
@export var opener_text: String = "Presented by Legends of Aurelia"
@export var opener_fade_in_seconds: float = 1.1
@export var opener_hold_seconds: float = 1.3
@export var opener_fade_out_seconds: float = 0.9
@export var content_fade_in_seconds: float = 0.65
@export var loop_fade_out_seconds: float = 0.42
@export var loop_fade_in_seconds: float = 0.52
@export_group("Finale Card")
@export var finale_enabled: bool = true
@export var finale_title_text: String = "THANK YOU FOR PLAYING"
@export var finale_subtitle_text: String = "Your command keeps Aurelia alive."
@export var finale_fade_in_seconds: float = 0.34
@export var finale_hold_seconds: float = 1.45
@export var finale_fade_out_seconds: float = 0.34
@export var hold_seconds_before_finale: float = 0.08
@export_group("Finale Logo")
@export var finale_logo_texture: Texture2D
@export var finale_logo_max_size: Vector2 = Vector2(560, 280)
@export var finale_logo_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var finale_logo_display_scale: float = 2.0
@export var finale_logo_pop_start_scale: float = 0.90
@export var finale_logo_pop_duration: float = 0.24
@export var finale_logo_glow_strength: float = 0.14
@export var finale_logo_glow_pulse_seconds: float = 0.60
@export var finale_center_y_ratio: float = 0.50
@export var finale_center_offset_y: float = -140.0
@export_group("Credits Data")
@export var use_default_sections_if_empty: bool = true
@export var credits_sections: Array[Resource] = []
@export_group("Studio Spotlight")
@export var show_studio_spotlight: bool = true
@export var studio_section_title: String = "Studio Spotlight"
@export var studio_name: String = "Rooktide Games"
@export_multiline var studio_section_details: String = "Independent tactical RPG studio focused on expressive combat systems, strong atmosphere, and player-driven stories."
@export_multiline var studio_name_details: String = "Founding studio behind Legends of Aurelia, leading worldbuilding, gameplay architecture, and long-term creative direction."

@onready var backdrop: ColorRect = $Backdrop
@onready var card: Control = $Center/Card
@onready var header_overline: Label = $Center/Card/Margin/Root/Header/Overline
@onready var header_title: Label = $Center/Card/Margin/Root/Header/Title
@onready var header_hint: Label = $Center/Card/Margin/Root/Header/Hint
@onready var content_root: VBoxContainer = $Center/Card/Margin/Root
@onready var scroll: ScrollContainer = $Center/Card/Margin/Root/CreditsScroll
@onready var credits_vbox: VBoxContainer = $Center/Card/Margin/Root/CreditsScroll/CreditsVBox
@onready var back_button: Button = $Center/Card/Margin/Root/ButtonRow/BackButton
@onready var credits_music_player: AudioStreamPlayer = $CreditsMusicPlayer
@onready var ambient_aura: ColorRect = $AmbientAura
@onready var top_fade: ColorRect = $Center/Card/TopFade
@onready var bottom_fade: ColorRect = $Center/Card/BottomFade
@onready var opener_overlay: ColorRect = $OpenerOverlay
@onready var opener_label: Label = $OpenerOverlay/OpenerLabel
@onready var transition_flash: ColorRect = $TransitionFlash

var _end_hold_timer: float = 0.0
var _top_spacer: Control = null
var _bottom_spacer: Control = null
var _scroll_pos: float = 0.0
var _sparkles: Array[ColorRect] = []
var _scroll_enabled: bool = false
var _time_accum: float = 0.0
var _loop_transitioning: bool = false
var _detail_panel: PanelContainer = null
var _detail_title_label: Label = null
var _detail_subtitle_label: Label = null
var _detail_body_label: RichTextLabel = null
var _detail_close_button: Button = null
var _detail_visible: bool = false
var _finale_card: PanelContainer = null
var _finale_logo_rect: TextureRect = null
var _finale_logo_pulse_tween: Tween = null
var _finale_logo_target_size: Vector2 = Vector2.ZERO
var _finale_title_label: Label = null
var _finale_subtitle_label: Label = null

func _ready() -> void:
	if credits_music_player != null:
		credits_music_player.bus = "Music"
	if credits_sections.is_empty() and use_default_sections_if_empty:
		credits_sections = _build_default_sections()
	_style_ui()
	_rebuild_credits()
	call_deferred("_finalize_credits_layout")
	if back_button != null:
		back_button.pressed.connect(_on_back_pressed)
	_play_credits_music()
	_start_theatrical_pass()
	_spawn_sparkles()
	call_deferred("_play_opener")

func _process(delta: float) -> void:
	_time_accum += delta
	if not _scroll_enabled:
		return
	if scroll == null:
		return
	var vbar := scroll.get_v_scroll_bar()
	if vbar == null:
		return
	var content_height: float = credits_vbox.get_combined_minimum_size().y if credits_vbox != null else 0.0
	var viewport_height: float = scroll.size.y
	var max_scroll: int = int(maxf(content_height - viewport_height, 0.0))
	if max_scroll <= 0:
		max_scroll = int(maxf(vbar.max_value, 0.0))
	if max_scroll <= 0:
		return
	if finale_enabled and _has_last_credit_content_exited_viewport():
		_end_hold_timer += delta
		if _end_hold_timer >= hold_seconds_before_finale:
			_restart_credits_cycle()
			_end_hold_timer = 0.0
		return
	if _scroll_pos >= float(max_scroll) - 0.5:
		_end_hold_timer += delta
		var end_hold_target: float = hold_seconds_at_end
		if finale_enabled:
			end_hold_target = minf(hold_seconds_at_end, hold_seconds_before_finale)
		if _end_hold_timer >= end_hold_target:
			_restart_credits_cycle()
			_end_hold_timer = 0.0
		return
	_scroll_pos = minf(float(max_scroll), _scroll_pos + scroll_speed * delta)
	scroll.scroll_vertical = int(_scroll_pos)
	_end_hold_timer = 0.0
	_update_entry_emphasis()

func _has_last_credit_content_exited_viewport() -> bool:
	if scroll == null or credits_vbox == null:
		return false
	var viewport_top: float = scroll.global_position.y
	var last_credit_control: Control = null
	for i in range(credits_vbox.get_child_count() - 1, -1, -1):
		var ctrl := credits_vbox.get_child(i) as Control
		if ctrl == null:
			continue
		if bool(ctrl.get_meta("credit_content", false)):
			last_credit_control = ctrl
			break
	if last_credit_control == null:
		return false
	var last_bottom: float = last_credit_control.global_position.y + last_credit_control.size.y
	return last_bottom <= viewport_top + 2.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		if _detail_visible:
			_close_detail_panel()
			return
		_on_back_pressed()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_update_scroll_spacers")
		call_deferred("_layout_detail_panel")
		call_deferred("_layout_finale_card")

func _on_back_pressed() -> void:
	if Engine.has_singleton("SceneTransition"):
		SceneTransition.change_scene_to_file("res://Scenes/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _reset_scroll_to_start() -> void:
	if scroll == null:
		return
	_scroll_pos = 0.0
	scroll.scroll_vertical = 0

func _finalize_credits_layout() -> void:
	if scroll == null:
		return
	await get_tree().process_frame
	_update_scroll_spacers()
	_layout_detail_panel()
	_reset_scroll_to_start()

func _style_ui() -> void:
	if backdrop != null:
		backdrop.color = Color(0.01, 0.01, 0.02, 0.96)
	if ambient_aura != null:
		ambient_aura.color = Color(0.42, 0.28, 0.10, 0.16)

	if card != null:
		card.modulate.a = 1.0

	_style_label(header_overline, MENU_TEXT_MUTED, 16, 1)
	_style_label(header_title, MENU_ACCENT, 46, 3)
	_style_label(header_hint, MENU_ACCENT_SOFT.lerp(MENU_TEXT_MUTED, 0.55), 18, 1)
	if content_root != null:
		content_root.modulate.a = 0.0

	if scroll != null:
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.mouse_filter = Control.MOUSE_FILTER_PASS
		var scroll_panel := StyleBoxFlat.new()
		scroll_panel.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		scroll_panel.border_color = Color(0.0, 0.0, 0.0, 0.0)
		scroll_panel.set_border_width_all(0)
		scroll_panel.set_corner_radius_all(0)
		scroll.add_theme_stylebox_override("panel", scroll_panel)
		var vbar: VScrollBar = scroll.get_v_scroll_bar()
		if vbar != null:
			vbar.visible = false
			vbar.modulate.a = 0.0
			vbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var transparent := StyleBoxFlat.new()
			transparent.bg_color = Color(0, 0, 0, 0)
			vbar.add_theme_stylebox_override("scroll", transparent)
			vbar.add_theme_stylebox_override("grabber", transparent)
			vbar.add_theme_stylebox_override("grabber_highlight", transparent)
			vbar.add_theme_stylebox_override("grabber_pressed", transparent)

	_style_button(back_button, "RETURN TO ENTRY")
	_setup_detail_panel()
	if top_fade != null:
		top_fade.visible = false
		top_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	if bottom_fade != null:
		bottom_fade.visible = false
		bottom_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	if opener_overlay != null:
		opener_overlay.color = Color(0.01, 0.01, 0.02, 0.88)
		opener_overlay.visible = true
		opener_overlay.modulate.a = 0.0
	if opener_label != null:
		opener_label.text = opener_text
		_style_label(opener_label, MENU_ACCENT_SOFT.lerp(MENU_ACCENT, 0.4), 56, 3)
		opener_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		opener_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		opener_label.modulate.a = 0.0
	if transition_flash != null:
		transition_flash.color = Color(0.95, 0.79, 0.28, 0.0)
		transition_flash.modulate.a = 0.0
		transition_flash.visible = false
	_setup_finale_card()

func _style_label(label: Label, color: Color, font_size: int, outline_size: int = 2) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.94))
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_font_size_override("font_size", font_size)

func _style_button(btn: Button, label_text: String) -> void:
	if btn == null:
		return
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 56)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", MENU_TEXT)
	btn.add_theme_color_override("font_hover_color", MENU_TEXT)
	btn.add_theme_color_override("font_pressed_color", MENU_TEXT)
	btn.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.94))
	btn.add_theme_constant_override("outline_size", 2)
	btn.add_theme_stylebox_override("normal", _button_style(Color(0.20, 0.16, 0.11, 0.98), MENU_BORDER_MUTED))
	btn.add_theme_stylebox_override("hover", _button_style(Color(0.28, 0.22, 0.14, 0.98), MENU_BORDER))
	btn.add_theme_stylebox_override("pressed", _button_style(Color(0.16, 0.13, 0.09, 0.98), MENU_BORDER))
	btn.add_theme_stylebox_override("focus", _button_style(Color(0.28, 0.22, 0.14, 0.98), MENU_ACCENT_SOFT))

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(12)
	box.shadow_color = Color(0, 0, 0, 0.30)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 3)
	return box

func _rebuild_credits() -> void:
	if credits_vbox == null:
		return
	for child in credits_vbox.get_children():
		credits_vbox.remove_child(child)
		child.queue_free()

	_top_spacer = Control.new()
	_top_spacer.custom_minimum_size = Vector2(0, 220)
	credits_vbox.add_child(_top_spacer)

	if show_studio_spotlight:
		var studio_title: String = studio_section_title.strip_edges()
		if studio_title == "":
			studio_title = "STUDIO SPOTLIGHT"
		var studio_details: String = studio_section_details.strip_edges()
		if studio_details == "":
			studio_details = "Studio overview."
		var studio_member_name: String = studio_name.strip_edges()
		if studio_member_name == "":
			studio_member_name = "STUDIO NAME"
		var studio_member_details: String = studio_name_details.strip_edges()
		if studio_member_details == "":
			studio_member_details = "Studio contributor details."
		_add_credit_section_block(studio_title, studio_details, [
			{
				"name": studio_member_name,
				"detail": studio_member_details
			}
		])

	var loose_members: Array[Resource] = []
	for section_res in credits_sections:
		var section: Resource = section_res
		if section == null:
			continue
		# Allow direct contributor entries in the list for convenience.
		# If the resource has no "members" field but has "display_name", we collect it
		# into a fallback "Special Mentions" section.
		var raw_members_field: Variant = section.get("members")
		if not (raw_members_field is Array):
			var direct_name: String = str(section.get("display_name")).strip_edges()
			if direct_name != "":
				loose_members.append(section)
			continue

		var section_title: String = str(section.get("title")).strip_edges()
		var section_details: String = str(section.get("details")).strip_edges()
		var members_variant: Variant = raw_members_field
		var members: Array = []
		if members_variant is Array:
			members = members_variant as Array
		if section_title == "":
			section_title = "UNNAMED SECTION"
		if section_details == "":
			section_details = "No additional details provided for this section."
		var section_members: Array[Dictionary] = []
		for member_res in members:
			var member: Resource = member_res
			if member == null:
				continue
			var entry: String = str(member.get("display_name")).strip_edges()
			if entry == "":
				continue
			var detail_text: String = str(member.get("details")).strip_edges()
			if detail_text == "":
				detail_text = "Detailed notes for this contributor have not been published yet."
			section_members.append({
				"name": entry,
				"detail": detail_text
			})
		_add_credit_section_block(section_title, section_details, section_members)

	if not loose_members.is_empty():
		var fallback_members: Array[Dictionary] = []
		for loose_member_res in loose_members:
			var loose_member: Resource = loose_member_res
			if loose_member == null:
				continue
			var loose_name: String = str(loose_member.get("display_name")).strip_edges()
			if loose_name == "":
				continue
			var loose_detail: String = str(loose_member.get("details")).strip_edges()
			if loose_detail == "":
				loose_detail = "Detailed notes for this contributor have not been published yet."
			fallback_members.append({
				"name": loose_name,
				"detail": loose_detail
			})
		_add_credit_section_block("Special Mentions", "Contributors added directly in the inspector list.", fallback_members)

	_bottom_spacer = Control.new()
	_bottom_spacer.custom_minimum_size = Vector2(0, 260)
	credits_vbox.add_child(_bottom_spacer)

func _add_credit_section_block(section_title: String, section_details: String, member_entries: Array[Dictionary]) -> void:
	var title_label := Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text = section_title.to_upper()
	_style_label(title_label, MENU_ACCENT_SOFT, 28, 2)
	title_label.set_meta("credit_phase", randf_range(0.0, TAU))
	title_label.set_meta("credit_content", true)
	title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	title_label.tooltip_text = "Click for section details"
	_wire_credit_hover(title_label)
	title_label.gui_input.connect(_on_credit_label_gui_input.bind(section_title, "Section Overview", section_details))
	credits_vbox.add_child(title_label)

	var rule_wrap := HBoxContainer.new()
	rule_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_wrap.set_meta("credit_phase", randf_range(0.0, TAU))
	rule_wrap.set_meta("credit_content", true)
	credits_vbox.add_child(rule_wrap)
	var left_pad := Control.new()
	left_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_wrap.add_child(left_pad)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(340, 2)
	rule.color = MENU_BORDER.lerp(MENU_ACCENT_SOFT, 0.25)
	rule_wrap.add_child(rule)
	var right_pad := Control.new()
	right_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_wrap.add_child(right_pad)

	for member_entry in member_entries:
		var entry_name: String = str(member_entry.get("name", "")).strip_edges()
		if entry_name == "":
			continue
		var entry_detail: String = str(member_entry.get("detail", "")).strip_edges()
		if entry_detail == "":
			entry_detail = "Detailed notes for this contributor have not been published yet."
		var name_label := Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.text = entry_name
		_style_label(name_label, MENU_TEXT, 34, 2)
		name_label.set_meta("credit_phase", randf_range(0.0, TAU))
		name_label.set_meta("credit_content", true)
		name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		name_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		name_label.tooltip_text = "Click for contributor details"
		_wire_credit_hover(name_label)
		name_label.gui_input.connect(_on_credit_label_gui_input.bind(entry_name, section_title, entry_detail))
		credits_vbox.add_child(name_label)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, section_gap)
	credits_vbox.add_child(gap)

func _wire_credit_hover(label: Label) -> void:
	if label == null:
		return
	label.set_meta("credit_hovered", false)
	label.set_meta("credit_hover_strength", 0.0)
	label.mouse_entered.connect(func() -> void:
		if label != null:
			label.set_meta("credit_hovered", true)
	)
	label.mouse_exited.connect(func() -> void:
		if label != null:
			label.set_meta("credit_hovered", false)
	)

func _build_default_sections() -> Array[Resource]:
	var sections: Array[Resource] = []

	var core: Resource = CREDITS_SECTION_DATA_SCRIPT.new()
	core.set("title", "Core Development")
	core.set("details", "Core architecture, systems direction, and release cadence for Legends of Aurelia.")
	core.set("members", [
		_make_credit_member("Cathaldus", "Creative direction, tactical loop design, and production orchestration across game modes."),
		_make_credit_member("Nyx", "Combat readability tuning, UX iteration loops, and encounter-feedback balancing."),
		_make_credit_member("Community Test Command", "Structured test sweeps, regression calls, and live usability feedback.")
	])
	sections.append(core)

	var design: Resource = CREDITS_SECTION_DATA_SCRIPT.new()
	design.set("title", "Design + Gameplay")
	design.set("details", "Ruleset clarity, progression rhythm, and battlefield decision quality.")
	design.set("members", [
		_make_credit_member("Tactical Systems Team", "Turn flow, stat ecosystem, and mode-to-mode balance pillars."),
		_make_credit_member("Encounter Design Cell", "Map pressure composition, reinforcement pacing, and objective drama."),
		_make_credit_member("UI Combat Readability", "Forecast hierarchy, icon language, and information timing under pressure.")
	])
	sections.append(design)

	var art: Resource = CREDITS_SECTION_DATA_SCRIPT.new()
	art.set("title", "Art + Atmosphere")
	art.set("details", "Visual identity, battlefield mood, and audio texture that define the world tone.")
	art.set("members", [
		_make_credit_member("Pixel Art Contributors", "Character portraits, tile readability passes, and world motif consistency."),
		_make_credit_member("VFX + Lighting", "Spell impact language, ambient depth, and scene mood continuity."),
		_make_credit_member("Audio + Music Pipeline", "Theme integration, dynamics mixing, and gameplay-state reactivity.")
	])
	sections.append(art)

	var thanks: Resource = CREDITS_SECTION_DATA_SCRIPT.new()
	thanks.set("title", "Special Thanks")
	thanks.set("details", "The players and test groups who challenged every system until it became stronger.")
	thanks.set("members", [
		_make_credit_member("Playtest Commanders", "Campaign progression notes, fail-case validation, and onboarding insights."),
		_make_credit_member("Co-op Expedition Crew", "Co-op pacing stress tests and role-composition observations."),
		_make_credit_member("Arena Rivals", "Competitive pressure tests for ranked integrity and skill expression.")
	])
	sections.append(thanks)

	return sections

func _make_credit_member(name_text: String, detail_text: String) -> Resource:
	var member: Resource = CREDITS_CONTRIBUTOR_DATA_SCRIPT.new()
	member.set("display_name", name_text)
	member.set("details", detail_text)
	return member

func _on_credit_label_gui_input(event: InputEvent, title_text: String, subtitle_text: String, body_text: String) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if not mouse_event.pressed:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	_open_detail_panel(title_text, subtitle_text, body_text)

func _setup_detail_panel() -> void:
	if card == null or is_instance_valid(_detail_panel):
		return
	_detail_panel = PanelContainer.new()
	_detail_panel.name = "DetailPanel"
	_detail_panel.z_index = 12
	_detail_panel.visible = false
	_detail_panel.modulate.a = 0.0
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.custom_minimum_size = Vector2(430, 0)
	_detail_panel.position = Vector2(card.size.x - 470.0, 120.0)
	_detail_panel.size = Vector2(430.0, maxf(card.size.y - 210.0, 260.0))
	card.add_child(_detail_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.08, 0.05, 0.93)
	panel_style.border_color = MENU_BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.shadow_color = Color(0, 0, 0, 0.35)
	panel_style.shadow_size = 14
	panel_style.shadow_offset = Vector2(0, 6)
	_detail_panel.add_theme_stylebox_override("panel", panel_style)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 16)
	panel_margin.add_theme_constant_override("margin_top", 14)
	panel_margin.add_theme_constant_override("margin_right", 16)
	panel_margin.add_theme_constant_override("margin_bottom", 14)
	_detail_panel.add_child(panel_margin)

	var panel_vbox := VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 10)
	panel_margin.add_child(panel_vbox)

	_detail_title_label = Label.new()
	_detail_title_label.text = "CONTRIBUTOR"
	_detail_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_label(_detail_title_label, MENU_ACCENT, 30, 2)
	panel_vbox.add_child(_detail_title_label)

	_detail_subtitle_label = Label.new()
	_detail_subtitle_label.text = "Section"
	_detail_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_label(_detail_subtitle_label, MENU_ACCENT_SOFT, 20, 1)
	panel_vbox.add_child(_detail_subtitle_label)

	var separator := ColorRect.new()
	separator.custom_minimum_size = Vector2(0, 2)
	separator.color = MENU_BORDER.lerp(MENU_ACCENT_SOFT, 0.25)
	panel_vbox.add_child(separator)

	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_vbox.add_child(body_scroll)

	_detail_body_label = RichTextLabel.new()
	_detail_body_label.bbcode_enabled = false
	_detail_body_label.fit_content = false
	_detail_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_body_label.custom_minimum_size = Vector2(0, 220)
	_detail_body_label.scroll_active = false
	_detail_body_label.selection_enabled = false
	_detail_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body_label.add_theme_font_size_override("normal_font_size", 18)
	_detail_body_label.add_theme_color_override("default_color", MENU_TEXT)
	_detail_body_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.94))
	_detail_body_label.add_theme_constant_override("outline_size", 1)
	body_scroll.add_child(_detail_body_label)

	_detail_close_button = Button.new()
	_style_button(_detail_close_button, "RESUME ROLL")
	_detail_close_button.custom_minimum_size = Vector2(0, 50)
	_detail_close_button.pressed.connect(_close_detail_panel)
	panel_vbox.add_child(_detail_close_button)
	_layout_detail_panel()

func _setup_finale_card() -> void:
	if card == null or is_instance_valid(_finale_card):
		return
	_finale_card = PanelContainer.new()
	_finale_card.name = "FinaleCard"
	_finale_card.z_index = 15
	_finale_card.visible = false
	_finale_card.modulate.a = 0.0
	_finale_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finale_card.custom_minimum_size = Vector2(760, 120)
	card.add_child(_finale_card)

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	box.border_color = Color(0.0, 0.0, 0.0, 0.0)
	box.set_border_width_all(0)
	box.set_corner_radius_all(0)
	box.shadow_color = Color(0, 0, 0, 0.0)
	box.shadow_size = 0
	box.shadow_offset = Vector2.ZERO
	_finale_card.add_theme_stylebox_override("panel", box)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_finale_card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_finale_logo_rect = TextureRect.new()
	_finale_logo_rect.name = "FinaleLogo"
	_finale_logo_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_finale_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_finale_logo_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_finale_logo_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_finale_logo_rect.custom_minimum_size = finale_logo_max_size
	_finale_logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finale_logo_rect.visible = false
	vbox.add_child(_finale_logo_rect)

	_finale_title_label = Label.new()
	_finale_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_finale_title_label, MENU_ACCENT, 44, 3)
	vbox.add_child(_finale_title_label)

	_finale_subtitle_label = Label.new()
	_finale_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_finale_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(_finale_subtitle_label, MENU_ACCENT_SOFT.lerp(MENU_TEXT, 0.38), 20, 1)
	vbox.add_child(_finale_subtitle_label)

	_layout_finale_card()

func _layout_finale_card() -> void:
	if _finale_card == null or card == null:
		return
	var width: float = minf(980.0, maxf(700.0, card.size.x * 0.72))
	var has_logo: bool = finale_logo_texture != null
	var logo_scale: float = clampf(finale_logo_display_scale, 0.5, 4.0)
	var logo_height: float = 0.0
	if has_logo:
		var texture_ratio: float = 0.52
		if finale_logo_texture != null:
			var tex_size: Vector2 = finale_logo_texture.get_size()
			if tex_size.x > 1.0:
				texture_ratio = clampf(tex_size.y / tex_size.x, 0.20, 2.40)
		var max_logo_width: float = minf(width * 0.98, finale_logo_max_size.x * logo_scale)
		var logo_width: float = clampf(width * 0.50 * logo_scale, 280.0, max_logo_width)
		logo_height = clampf(logo_width * texture_ratio, 110.0, finale_logo_max_size.y * logo_scale)
		_finale_logo_target_size = Vector2(logo_width, logo_height)
		if _finale_logo_rect != null:
			_finale_logo_rect.custom_minimum_size = _finale_logo_target_size
	else:
		_finale_logo_target_size = Vector2.ZERO
	var text_block_height: float = 128.0
	var height: float = text_block_height + logo_height + (16.0 if has_logo else 0.0)
	_finale_card.size = Vector2(width, height)
	# Keep the finale block centered, with optional upward nudge for tall logos.
	_finale_card.position = Vector2(
		(card.size.x - width) * 0.5,
		((card.size.y - height) * 0.5) + finale_center_offset_y
	)

func _layout_detail_panel() -> void:
	if _detail_panel == null or card == null:
		return
	var panel_width: float = minf(440.0, maxf(360.0, card.size.x * 0.34))
	var panel_top: float = 92.0
	var reserved_bottom: float = 96.0
	if back_button != null:
		var card_global_pos: Vector2 = card.get_global_rect().position
		var back_global_pos: Vector2 = back_button.get_global_rect().position
		var local_back_y: float = back_global_pos.y - card_global_pos.y
		reserved_bottom = maxf(reserved_bottom, (card.size.y - local_back_y) + 16.0)
	_detail_panel.position = Vector2(card.size.x - panel_width - 24.0, panel_top)
	_detail_panel.size = Vector2(panel_width, maxf(card.size.y - panel_top - reserved_bottom, 250.0))

func _open_detail_panel(title_text: String, subtitle_text: String, body_text: String) -> void:
	if _detail_panel == null:
		return
	if _detail_title_label != null:
		_detail_title_label.text = title_text.to_upper()
	if _detail_subtitle_label != null:
		_detail_subtitle_label.text = subtitle_text
	if _detail_body_label != null:
		_detail_body_label.text = body_text
		_detail_body_label.scroll_to_paragraph(0)
		_detail_body_label.scroll_to_line(0)
	_scroll_enabled = false
	_detail_visible = true
	_detail_panel.visible = true
	_detail_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_detail_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _close_detail_panel() -> void:
	if _detail_panel == null:
		return
	if not _detail_visible:
		return
	_detail_visible = false
	var tween := create_tween()
	tween.tween_property(_detail_panel, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if _detail_panel != null:
			_detail_panel.visible = false
		if not _loop_transitioning:
			_scroll_enabled = true
	)

func _update_scroll_spacers() -> void:
	if scroll == null:
		return
	var scroll_h: int = maxi(320, int(scroll.size.y))
	if _top_spacer != null:
		# Start credits offscreen below the viewport so they rise into view.
		_top_spacer.custom_minimum_size = Vector2(0, int(scroll_h * 1.00))
	if _bottom_spacer != null:
		# Keep a generous tail so the last lines can fully fade out before reset.
		_bottom_spacer.custom_minimum_size = Vector2(0, int(scroll_h * 1.18))

func _play_credits_music() -> void:
	if credits_music_player == null:
		return
	if credits_music_player.stream == null:
		return
	credits_music_player.play()

func _play_opener() -> void:
	if opener_overlay == null or opener_label == null:
		_start_credits_content_fade_in()
		return
	opener_overlay.visible = true
	opener_overlay.modulate.a = 0.0
	opener_label.modulate.a = 0.0
	var opener_tween := create_tween()
	opener_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	opener_tween.tween_property(opener_overlay, "modulate:a", 1.0, opener_fade_in_seconds)
	opener_tween.parallel().tween_property(opener_label, "modulate:a", 1.0, opener_fade_in_seconds)
	opener_tween.tween_interval(opener_hold_seconds)
	opener_tween.tween_property(opener_overlay, "modulate:a", 0.0, opener_fade_out_seconds)
	opener_tween.parallel().tween_property(opener_label, "modulate:a", 0.0, opener_fade_out_seconds)
	opener_tween.tween_callback(func() -> void:
		_play_transition_flash()
		if opener_overlay != null:
			opener_overlay.visible = false
		_start_credits_content_fade_in()
	)

func _start_credits_content_fade_in() -> void:
	if content_root == null:
		_scroll_enabled = true
		return
	content_root.modulate.a = 0.0
	var reveal := create_tween()
	reveal.tween_property(content_root, "modulate:a", 1.0, content_fade_in_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal.tween_callback(func() -> void:
		_scroll_enabled = true
	)

func _restart_credits_cycle() -> void:
	if _loop_transitioning:
		return
	_loop_transitioning = true
	_scroll_enabled = false
	if content_root == null:
		_reset_scroll_to_start()
		_loop_transitioning = false
		_scroll_enabled = true
		return
	if finale_enabled and _finale_card != null:
		_play_finale_then_restart()
		return
	var cycle := create_tween()
	cycle.tween_property(content_root, "modulate:a", 0.0, loop_fade_out_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	cycle.tween_callback(func() -> void:
		_reset_scroll_to_start()
		_update_entry_emphasis()
	)
	cycle.tween_interval(0.08)
	cycle.tween_property(content_root, "modulate:a", 1.0, loop_fade_in_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	cycle.tween_callback(func() -> void:
		_loop_transitioning = false
		_scroll_enabled = true
	)

func _play_finale_then_restart() -> void:
	if content_root == null or _finale_card == null:
		_loop_transitioning = false
		_restart_credits_cycle()
		return
	_finale_title_label.text = finale_title_text.strip_edges()
	_finale_subtitle_label.text = finale_subtitle_text.strip_edges()
	if _finale_logo_rect != null:
		_finale_logo_rect.texture = finale_logo_texture
		_finale_logo_rect.modulate = finale_logo_modulate
		_finale_logo_rect.visible = finale_logo_texture != null
		_finale_logo_rect.scale = Vector2.ONE
	_layout_finale_card()
	_finale_card.visible = true
	_finale_card.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(content_root, "modulate:a", 0.0, loop_fade_out_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_finale_card, "modulate:a", 1.0, finale_fade_in_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _finale_logo_rect != null and _finale_logo_rect.visible:
		var logo_fade_duration: float = minf(finale_logo_pop_duration, maxf(0.08, finale_fade_in_seconds))
		var clamped_start_scale: float = clampf(finale_logo_pop_start_scale, 0.65, 1.15)
		var start_size: Vector2 = _finale_logo_target_size * clamped_start_scale
		_finale_logo_rect.custom_minimum_size = start_size
		_finale_logo_rect.modulate = Color(
			finale_logo_modulate.r,
			finale_logo_modulate.g,
			finale_logo_modulate.b,
			0.0
		)
		tween.parallel().tween_property(_finale_logo_rect, "custom_minimum_size", _finale_logo_target_size, logo_fade_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(_finale_logo_rect, "modulate:a", finale_logo_modulate.a, logo_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func() -> void:
			_start_finale_logo_glow_pulse()
		)
	tween.tween_interval(finale_hold_seconds)
	tween.tween_callback(func() -> void:
		_stop_finale_logo_glow_pulse()
	)
	tween.tween_property(_finale_card, "modulate:a", 0.0, finale_fade_out_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_stop_finale_logo_glow_pulse()
		if _finale_card != null:
			_finale_card.visible = false
		_reset_scroll_to_start()
		_update_entry_emphasis()
	)
	tween.tween_interval(0.05)
	tween.tween_property(content_root, "modulate:a", 1.0, loop_fade_in_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_loop_transitioning = false
		_scroll_enabled = true
	)

func _start_finale_logo_glow_pulse() -> void:
	if _finale_logo_rect == null or not _finale_logo_rect.visible:
		return
	_stop_finale_logo_glow_pulse()
	var pulse_strength: float = clampf(finale_logo_glow_strength, 0.0, 0.5)
	if pulse_strength <= 0.0:
		return
	var pulse_duration: float = maxf(0.12, finale_logo_glow_pulse_seconds)
	var boosted := Color(
		minf(1.0, finale_logo_modulate.r + pulse_strength),
		minf(1.0, finale_logo_modulate.g + pulse_strength),
		minf(1.0, finale_logo_modulate.b + pulse_strength),
		finale_logo_modulate.a
	)
	_finale_logo_rect.modulate = finale_logo_modulate
	_finale_logo_pulse_tween = create_tween()
	_finale_logo_pulse_tween.set_loops()
	_finale_logo_pulse_tween.tween_property(_finale_logo_rect, "modulate", boosted, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_finale_logo_pulse_tween.tween_property(_finale_logo_rect, "modulate", finale_logo_modulate, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_finale_logo_glow_pulse() -> void:
	if _finale_logo_pulse_tween != null:
		_finale_logo_pulse_tween.kill()
		_finale_logo_pulse_tween = null
	if _finale_logo_rect != null and _finale_logo_rect.visible:
		_finale_logo_rect.modulate = finale_logo_modulate

func _play_transition_flash() -> void:
	if transition_flash == null:
		return
	transition_flash.visible = true
	transition_flash.modulate.a = 0.0
	var burst := create_tween()
	burst.tween_property(transition_flash, "modulate:a", 0.56, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	burst.tween_property(transition_flash, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	burst.tween_callback(func() -> void:
		if transition_flash != null:
			transition_flash.visible = false
	)

func _start_theatrical_pass() -> void:
	if ambient_aura != null:
		ambient_aura.modulate.a = 0.12
		var aura_tween := create_tween()
		aura_tween.set_loops()
		aura_tween.tween_property(ambient_aura, "modulate:a", 0.28, 3.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		aura_tween.tween_property(ambient_aura, "modulate:a", 0.12, 5.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if card != null:
		card.scale = Vector2(0.995, 0.995)
		var card_tween := create_tween()
		card_tween.set_loops()
		card_tween.tween_property(card, "scale", Vector2(1.005, 1.005), 4.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		card_tween.tween_property(card, "scale", Vector2(0.995, 0.995), 4.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _spawn_sparkles() -> void:
	if backdrop == null:
		return
	for old_dot in _sparkles:
		if old_dot != null and is_instance_valid(old_dot):
			old_dot.queue_free()
	_sparkles.clear()
	var vp_size: Vector2 = get_viewport_rect().size
	for i in range(maxi(0, sparkles_count)):
		var dot := ColorRect.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var size_px: float = randf_range(1.0, 2.8)
		dot.custom_minimum_size = Vector2(size_px, size_px)
		dot.color = MENU_ACCENT_SOFT.lerp(MENU_ACCENT, randf())
		dot.modulate.a = randf_range(0.12, 0.42)
		dot.position = Vector2(randf_range(0.0, maxf(vp_size.x - 4.0, 1.0)), randf_range(0.0, maxf(vp_size.y - 4.0, 1.0)))
		backdrop.add_child(dot)
		_sparkles.append(dot)
		var drift := create_tween()
		drift.set_loops()
		var drift_x: float = randf_range(-26.0, 26.0)
		var drift_y: float = randf_range(-18.0, 18.0)
		var base_alpha: float = dot.modulate.a
		drift.tween_property(dot, "position", dot.position + Vector2(drift_x, drift_y), randf_range(3.2, 6.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.parallel().tween_property(dot, "modulate:a", clampf(base_alpha + randf_range(0.18, 0.34), 0.0, 0.75), randf_range(1.8, 3.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(dot, "position", dot.position, randf_range(3.2, 6.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.parallel().tween_property(dot, "modulate:a", base_alpha, randf_range(2.4, 3.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _update_entry_emphasis() -> void:
	if scroll == null or credits_vbox == null:
		return
	if _detail_visible:
		return
	var viewport_center_y: float = scroll.global_position.y + (scroll.size.y * 0.5)
	var viewport_top: float = scroll.global_position.y
	var viewport_bottom: float = viewport_top + scroll.size.y
	var edge_band: float = maxf(36.0, edge_fade_band_px)
	var falloff: float = maxf(scroll.size.y * 0.62, 220.0)
	for child in credits_vbox.get_children():
		var control := child as Control
		if control == null:
			continue
		if control == _top_spacer or control == _bottom_spacer:
			continue
		var local_center_y: float = control.global_position.y + (control.size.y * 0.5)
		var control_top: float = control.global_position.y
		var control_bottom: float = control_top + control.size.y
		if control_bottom <= viewport_top or control_top >= viewport_bottom:
			control.modulate.a = 0.0
			continue
		var distance_ratio: float = clampf(absf(local_center_y - viewport_center_y) / falloff, 0.0, 1.0)
		var highlight: float = 1.0 - distance_ratio
		var phase_variant: Variant = control.get_meta("credit_phase", 0.0)
		var phase: float = float(phase_variant)
		var pulse: float = 0.74 + (0.26 * (0.5 + 0.5 * sin((_time_accum * 1.65) + phase)))
		var alpha_val: float = clampf((0.42 + (highlight * center_highlight_strength)) * pulse, 0.22, 1.0)
		# Fast edge fade (center-based) so lines fully dissolve before clipping.
		var top_factor: float = clampf((local_center_y - viewport_top) / edge_band, 0.0, 1.0)
		var bottom_factor: float = clampf((viewport_bottom - local_center_y) / edge_band, 0.0, 1.0)
		var edge_factor: float = maxf(edge_fade_floor, minf(top_factor, bottom_factor))
		alpha_val *= edge_factor
		control.modulate.a = alpha_val
		var scale_val: float = lerpf(0.98, center_highlight_scale, highlight)
		var hovered: bool = bool(control.get_meta("credit_hovered", false))
		var hover_strength: float = float(control.get_meta("credit_hover_strength", 0.0))
		var hover_target: float = 1.0 if hovered else 0.0
		hover_strength = lerpf(hover_strength, hover_target, clampf(hover_pulse_smoothing, 0.01, 1.0))
		control.set_meta("credit_hover_strength", hover_strength)
		if hover_strength > 0.001:
			scale_val *= (1.0 + (hover_pulse_scale_bonus * hover_strength))
			control.modulate.a = minf(1.0, control.modulate.a + (hover_pulse_alpha_bonus * hover_strength))
		control.scale = Vector2(scale_val, scale_val)
