# ==============================================================================
# SCRIPT: SettingsMenu.gd
# PURPOSE: Manages global settings + feedback submission.
# NOTE: Settings are stored globally in user://settings.cfg via CampaignManager.
# ==============================================================================

extends Control

var _is_syncing_ui: bool = false

@onready var canvas_layer: CanvasLayer = get_node_or_null("CanvasLayer")

# --- SETTINGS PANEL / SCROLL ---
@onready var header_controls: Control = get_node_or_null("CanvasLayer/HeaderControls")
@onready var settings_scroll: ScrollContainer = get_node_or_null("CanvasLayer/ScrollContainer")
@onready var settings_vbox: VBoxContainer = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer")
@onready var close_button: TextureButton = get_node_or_null("CanvasLayer/HeaderControls/CloseButton")
@onready var quit_button: TextureButton = get_node_or_null("CanvasLayer/HeaderControls/QuitToTitleButton")

# --- EXISTING SETTINGS ---
@onready var volume_slider: HSlider = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/VolumeSlider")
@onready var camera_slider: HSlider = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/CameraSlider")
@onready var move_speed_slider: HSlider = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/MoveSpeedSlider")
@onready var follow_enemy_toggle: CheckBox = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/FollowEnemyToggle")

# --- NEW SETTINGS ---
@onready var danger_zone_toggle: CheckBox = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/DangerZoneToggle")
@onready var minimap_toggle: CheckBox = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/MinimapToggle")
@onready var minimap_opacity_slider: HSlider = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/MinimapOpacitySlider")

@onready var zoom_step_slider: HSlider = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/ZoomStepSlider")
@onready var min_zoom_slider: HSlider = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/MinZoomSlider")
@onready var max_zoom_slider: HSlider = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/MaxZoomSlider")
@onready var zoom_to_cursor_toggle: CheckBox = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/ZoomToCursorToggle")
@onready var edge_margin_slider: HSlider = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/EdgeMarginSlider")

@onready var show_grid_toggle: CheckBox = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/ShowGridToggle")
@onready var show_enemy_threat_toggle: CheckBox = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/ShowEnemyThreatToggle")
@onready var show_faction_tiles_toggle: CheckBox = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/ShowFactionTilesToggle")
@onready var show_path_toggle: CheckBox = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/ShowPathToggle")
@onready var path_pulse_toggle: CheckBox = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/PathPulseToggle")
@onready var show_battle_log_toggle: CheckBox = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/ShowBattleLogToggle")
@onready var allow_fog_toggle: CheckBox = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/AllowFogToggle")

@onready var reset_defaults_btn: Button = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/ResetDefaultsButton")

# --- FEEDBACK UI ---
@onready var feedback_title: LineEdit = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/FeedbackTitle")
@onready var feedback_body: TextEdit = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/FeedbackBody")
@onready var submit_feedback_btn: Button = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/SubmitFeedbackButton")
@onready var view_feedback_btn: Button = get_node_or_null("CanvasLayer/ScrollContainer/VBoxContainer/ViewFeedbackButton")

# --- BULLETIN BOARD ---
@onready var feedback_board: Panel = get_node_or_null("CanvasLayer/FeedbackBoard")
@onready var feedback_list: VBoxContainer = get_node_or_null("CanvasLayer/FeedbackBoard/FeedbackScroll/FeedbackList")

func _ready() -> void:
	print("canvas_layer:", canvas_layer != null)
	print("header_controls:", header_controls != null)
	print("settings_scroll:", settings_scroll != null)
	print("settings_vbox:", settings_vbox != null)
	print("close_button:", close_button != null)
	print("quit_button:", quit_button != null)
	print("volume_slider:", volume_slider != null)
	print("camera_slider:", camera_slider != null)
	print("move_speed_slider:", move_speed_slider != null)
	print("follow_enemy_toggle:", follow_enemy_toggle != null)
	print("danger_zone_toggle:", danger_zone_toggle != null)
	print("minimap_toggle:", minimap_toggle != null)
	print("submit_feedback_btn:", submit_feedback_btn != null)
	print("feedback_title:", feedback_title != null)
	print("feedback_body:", feedback_body != null)
	print("feedback_board:", feedback_board != null)
	print("feedback_list:", feedback_list != null)
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	CampaignManager.load_global_settings()
	_connect_all_signals()
	_sync_ui_from_settings()
	_apply_settings_to_runtime()

	hide_menu()

func _connect_all_signals() -> void:
	print("close_button found:", close_button != null)
	print("quit_button found:", quit_button != null)

	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

	if quit_button and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)

	if submit_feedback_btn and not submit_feedback_btn.pressed.is_connected(_on_submit_feedback_pressed):
		submit_feedback_btn.pressed.connect(_on_submit_feedback_pressed)

	# Existing
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)
	if camera_slider:
		camera_slider.value_changed.connect(_on_camera_speed_changed)
	if move_speed_slider:
		move_speed_slider.value_changed.connect(_on_move_speed_changed)
	if follow_enemy_toggle:
		follow_enemy_toggle.toggled.connect(_on_follow_enemy_toggled)

	# New
	if danger_zone_toggle:
		danger_zone_toggle.toggled.connect(_on_danger_zone_toggled)
	if minimap_toggle:
		minimap_toggle.toggled.connect(_on_minimap_toggled)
	if minimap_opacity_slider:
		minimap_opacity_slider.value_changed.connect(_on_minimap_opacity_changed)

	if zoom_step_slider:
		zoom_step_slider.value_changed.connect(_on_zoom_step_changed)
	if min_zoom_slider:
		min_zoom_slider.value_changed.connect(_on_min_zoom_changed)
	if max_zoom_slider:
		max_zoom_slider.value_changed.connect(_on_max_zoom_changed)
	if zoom_to_cursor_toggle:
		zoom_to_cursor_toggle.toggled.connect(_on_zoom_to_cursor_toggled)
	if edge_margin_slider:
		edge_margin_slider.value_changed.connect(_on_edge_margin_changed)

	if show_grid_toggle:
		show_grid_toggle.toggled.connect(_on_show_grid_toggled)
	if show_enemy_threat_toggle:
		show_enemy_threat_toggle.toggled.connect(_on_show_enemy_threat_toggled)
	if show_faction_tiles_toggle:
		show_faction_tiles_toggle.toggled.connect(_on_show_faction_tiles_toggled)
	if show_path_toggle:
		show_path_toggle.toggled.connect(_on_show_path_toggled)
	if path_pulse_toggle:
		path_pulse_toggle.toggled.connect(_on_path_pulse_toggled)
	if show_battle_log_toggle:
		show_battle_log_toggle.toggled.connect(_on_show_battle_log_toggled)
	if allow_fog_toggle:
		allow_fog_toggle.toggled.connect(_on_allow_fog_toggled)

	if reset_defaults_btn:
		reset_defaults_btn.pressed.connect(_on_reset_defaults_pressed)

	if view_feedback_btn:
		view_feedback_btn.pressed.connect(_open_feedback_board)

	if has_node("CanvasLayer/FeedbackBoard/CloseBoardButton"):
		$CanvasLayer/FeedbackBoard/CloseBoardButton.pressed.connect(func(): feedback_board.hide())

	if has_node("CanvasLayer/FeedbackBoard/RefreshBoardButton"):
		$CanvasLayer/FeedbackBoard/RefreshBoardButton.pressed.connect(_fetch_all_feedback)
		
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

	_is_syncing_ui = false

func _persist_and_apply() -> void:
	if _is_syncing_ui:
		return

	# Keep zoom bounds sane
	if CampaignManager.battle_max_zoom <= CampaignManager.battle_min_zoom:
		CampaignManager.battle_max_zoom = CampaignManager.battle_min_zoom + 0.10
		_sync_ui_from_settings()

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

# ==============================================================================
# FEEDBACK BOARD
# ==============================================================================

func _open_feedback_board() -> void:
	if feedback_board:
		feedback_board.show()
		_fetch_all_feedback()

func _fetch_all_feedback() -> void:
	print("--- STARTING FEEDBACK FETCH ---")
	if feedback_list == null:
		print("ERROR: feedback_list node not found! Check your path.")
		return

	for child in feedback_list.get_children():
		child.queue_free()

	print("Requesting scores from SilentWolf...")
	var _sw_result = await SilentWolf.Scores.get_scores(50, "player_feedback").sw_get_scores_complete
	var scores = SilentWolf.Scores.scores

	print("Scores received from Cloud: ", scores.size())

	if scores.is_empty():
		print("Cloud returned 0 scores for 'player_feedback'.")
		var empty_lbl = Label.new()
		empty_lbl.text = "No feedback reports found in the capital."
		feedback_list.add_child(empty_lbl)
		return

	for entry in scores:
		print("Found entry: ", entry.get("player_name"))
		_create_feedback_row(entry)

func _create_feedback_row(entry: Dictionary) -> void:
	var row = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_content_margin_all(15)
	row.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	row.add_child(vbox)

	var raw_metadata = entry.get("metadata", "{}")
	var data = {}
	if raw_metadata is String:
		data = JSON.parse_string(raw_metadata)
	else:
		data = raw_metadata

	if data == null:
		data = {"subject": "Legacy Report", "message": str(raw_metadata)}

	var header = Label.new()
	header.text = "[ " + str(data.get("subject", "Bug Report")).to_upper() + " ]"
	header.add_theme_color_override("font_color", Color.CYAN)
	header.add_theme_font_size_override("font_size", 20)
	vbox.add_child(header)

	var body = Label.new()
	body.text = data.get("message", "...")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	var footer = Label.new()
	var sender = entry.get("player_name", "Anonymous")
	var ver = str(data.get("version", "1.0.4"))
	var raw_time = str(data.get("timestamp", "Unknown Date"))
	var clean_time = raw_time.replace("T", " ")

	footer.text = "By: %s  |  Ver: %s  |  %s" % [sender, ver, clean_time]
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_theme_color_override("font_color", Color.DIM_GRAY)
	footer.add_theme_font_size_override("font_size", 14)
	vbox.add_child(footer)

	feedback_list.add_child(row)

# ==============================================================================
# FEEDBACK SUBMISSION
# ==============================================================================

func _on_submit_feedback_pressed() -> void:
	print("Submit Button Clicked!")
	var title = feedback_title.text.strip_edges()
	var body = feedback_body.text.strip_edges()

	if title == "" or body == "":
		_show_status_message("Please fill all fields.", Color.TOMATO)
		return

	submit_feedback_btn.disabled = true
	submit_feedback_btn.text = "Syncing with Cloud..."

	var metadata = {
		"subject": title,
		"message": body,
		"version": "1.0.4",
		"mmr": CampaignManager.arena_mmr,
		"timestamp": Time.get_datetime_string_from_system()
	}

	var player_name = CampaignManager.custom_avatar.get("name", "Unknown Player")
	var dummy_score = int(Time.get_unix_time_from_system())

	var sw_result = await SilentWolf.Scores.save_score(
		player_name,
		dummy_score,
		"player_feedback",
		metadata
	).sw_save_score_complete

	if sw_result:
		_clear_feedback_fields()
		submit_feedback_btn.text = "Feedback Received!"
		submit_feedback_btn.add_theme_color_override("font_color", Color.LIME)
		await get_tree().create_timer(3.0).timeout
		submit_feedback_btn.text = "Submit Feedback"
		submit_feedback_btn.disabled = false
		submit_feedback_btn.remove_theme_color_override("font_color")
	else:
		submit_feedback_btn.text = "Network Error: Try Again"
		submit_feedback_btn.disabled = false

func _clear_feedback_fields() -> void:
	if feedback_title:
		feedback_title.text = ""
	if feedback_body:
		feedback_body.text = ""

func _show_status_message(msg: String, _color: Color) -> void:
	print("[Settings] " + msg)

# ==============================================================================
# MENU FLOW
# ==============================================================================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_menuESC"):
		if canvas_layer == null:
			return
		if not canvas_layer.visible:
			show_menu()
		else:
			hide_menu()

func show_menu() -> void:
	get_tree().paused = true
	visible = true
	if canvas_layer:
		canvas_layer.visible = true
		canvas_layer.layer = 128
	_sync_ui_from_settings()
	print("Settings Opened")

func hide_menu() -> void:
	visible = false
	if canvas_layer:
		canvas_layer.visible = false
	get_tree().paused = false
	print("Settings Closed")

func _on_close_pressed() -> void:
	print("CLOSE PRESSED")
	hide_menu()

func _on_quit_pressed() -> void:
	print("QUIT PRESSED")
	hide_menu()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
