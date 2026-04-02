extends Node2D

# ==============================================================================
# PURPOSE
# ==============================================================================
# World map controller for tactical RPG campaign navigation, node interaction,
# announcements, base management, and high-feedback presentation when a base is
# established.
#
# ==============================================================================
# DEPENDENCIES
# ==============================================================================
# - CampaignManager singleton:
#     current_level_index, max_unlocked_index, player_roster, custom_avatar,
#     active_base_level_index, base_under_attack, base_resource_storage,
#     base_last_harvest_report, base_yield_table, establish_new_base(),
#     abandon_base(), collect_base_resources(), save_current_progress(),
#     _process_base_economy(), enter_level_from_map(), launch_expedition_from_map()
# - EncounterDatabase.map_encounters
# - SceneTransition singleton
# - LevelNode buttons under $MapNodes
# - Optional active Camera2D in the current viewport for map shake
# - Optional AudioStreams assigned to fanfare_sound and thud_sound
#
# ==============================================================================
# PREFLOADS (avoids on-demand load in hot path)
# ==============================================================================
const MapEncounterUIScene: PackedScene = preload("res://Scenes/MapEncounterUI.tscn")
const ExpeditionCharterStagingUIScene: PackedScene = preload("res://Scenes/UI/ExpeditionCharterStagingUI.tscn")
#
# ==============================================================================
# NOTES
# ==============================================================================
# - The screen shake prefers the active Camera2D. If no active camera exists,
#   the WorldMap Node2D itself is shaken as a safe fallback.
# - The victory banner is created dynamically in a CanvasLayer so it stays
#   screen-space even while the world shakes.
# - The base marker is reused, but its entrance is animated with a drop,
#   impact, squash, and elastic settle before returning to its idle hover.
# - Comments are intentionally verbose for maintainability and code review.


@onready var player_icon = $PlayerIcon
@onready var camp_button = $UI/CampButton
@onready var city_button = get_node_or_null("UI/CityButton")
@onready var map_music = $MapMusic
@onready var map_announcement = get_node_or_null("%MapAnnouncement")

# --- CONFIGURATION ---
@export var music_track: AudioStream
@export var player_icon_scale: Vector2 = Vector2(0.5, 0.5)
@export var player_icon_offset: Vector2 = Vector2(0, -40)

@export var move_speed_pixels_per_second: float = 450.0
@export var min_move_duration: float = 0.18
@export var max_move_duration: float = 0.70
@export var move_arc_height: float = 24.0

@export var node_hover_scale: Vector2 = Vector2(1.08, 1.08)
@export var ui_hover_scale: Vector2 = Vector2(1.05, 1.05)
@export var player_bob_height: float = 6.0
@export var player_bob_time: float = 0.85

# --- BASE ESTABLISHMENT FEEDBACK ---
@export_category("Base Establishment Feedback")
@export var base_shake_intensity: float = 18.0
@export var base_shake_duration: float = 0.35
@export var base_marker_drop_height: float = 220.0
@export var base_marker_resting_offset: Vector2 = Vector2(-12.0, -40.0)
@export var base_banner_hold_time: float = 20
@export var base_banner_y: float = 72.0
@export var base_particle_count: int = 42

# Audio placeholders.
# Assign streams in the inspector when assets are ready.
@export var fanfare_sound: AudioStream
@export var thud_sound: AudioStream

## Release exports: OS.is_debug_build() is false. Enable on the WorldMap root (or in WorldMap.tscn) so Ctrl+Shift+P opens co-op staging + ENet.
@export_group("Co-op staging debug (Ctrl+Shift+P)")
@export var allow_coop_staging_debug_panel_in_release: bool = false

# --- BASE MANAGEMENT UI ---
var node_context_menu: PanelContainer = null
var base_garrison_ui: CanvasLayer = null
var selected_garrison_units: Array[String] = []
var base_marker_visual: Panel = null

@onready var level_nodes: Array = [
	$MapNodes/LevelNode0,
	$MapNodes/LevelNode1,
	$MapNodes/LevelNode2,
	$MapNodes/LevelNode3,
	$MapNodes/ExpeditionNodeShatteredSanctum
]

var target_node_index: int = 0
var is_moving: bool = false

var _scale_cache: Dictionary = {}
var _hover_tweens: Dictionary = {}
var _current_node_pulse_tween: Tween
var _current_node_index: int = -1
var _player_bob_tween: Tween
var _player_arrival_tween: Tween
var _music_fade_tween: Tween
var _announcement_tween: Tween
var _logged_expedition_unlocks: Dictionary = {}

## Solo vs co-op charter prompt when tapping a co-op-enabled expedition node.
var _expedition_mode_chooser_layer: CanvasLayer = null

## Debug-only co-op staging tester (Ctrl+Shift+P on world map). See _toggle_coop_staging_debug_panel.
var _coop_staging_debug_layer: CanvasLayer = null
var _coop_staging_debug_status_label: Label = null
var _coop_staging_debug_last_finalize: Dictionary = {}
var _coop_staging_debug_last_handoff: Dictionary = {}
var _coop_enet_port_field: LineEdit = null
var _coop_enet_join_field: LineEdit = null

# --- BASE FEEDBACK RUNTIME STATE ---
var fanfare_player: AudioStreamPlayer = null
var thud_player: AudioStreamPlayer2D = null

var _base_marker_float_tween: Tween
var _base_marker_drop_tween: Tween
var _base_banner_tween: Tween

# Announcement: timestamp-based debounce (no _process or Timer).
var _announce_last_show_time_msec: int = 0
const ANNOUNCE_DEBOUNCE_MSEC: int = 220
const DEBUG_EXPEDITION_NODE_LOGS: bool = true

# Cached node display names (avoids repeated _get_node_display_name / property scans).
var _node_display_names: Array[String] = []

# Screen shake state.
# The active camera is preferred. The map node is the fallback.
var _shake_time_left: float = 0.0
var _shake_duration_total: float = 0.0
var _shake_strength: float = 0.0
var _shake_target_camera: Camera2D = null
var _shake_original_camera_offset: Vector2 = Vector2.ZERO
var _shake_original_map_position: Vector2 = Vector2.ZERO
var _shake_using_camera: bool = false


func _ready() -> void:
	print("\n=== WORLD MAP TRUTH SERUM ===")
	print("Current Max Unlocked Index: ", CampaignManager.max_unlocked_index)
	print("=============================\n")

	_setup_music()
	_setup_avatar()
	_ensure_feedback_audio_nodes()

	# _process only for screen shake; debounce is timestamp-based.
	set_process(false)

	target_node_index = clamp(CampaignManager.current_level_index, 0, max(level_nodes.size() - 1, 0))

	_connect_level_nodes()
	_connect_ui_buttons()
	_apply_expedition_node_requirements()
	_cache_all_base_scales()
	_cache_node_display_names()
	_refresh_node_visuals()
	_place_player_at_current_node()
	_start_player_idle_bob()
	_announce_current_node(false)

	# --- BASE EMERGENCY CHECK ---
	if CampaignManager.base_under_attack:
		_show_announcement("URGENT: Base is under attack! Return immediately to defend it!", false)
		if map_announcement != null:
			map_announcement.add_theme_color_override("font_color", Color.RED)

	_show_harvest_report()
	_update_base_marker()


func _process(delta: float) -> void:
	# Only run while shake is active (set in map_shake, cleared in _clear_map_shake).
	if _shake_time_left <= 0.0:
		return

	_shake_time_left = max(_shake_time_left - delta, 0.0)

	# Decay the shake so the impact feels punchy and then settles naturally.
	var normalized: float = _shake_time_left / max(_shake_duration_total, 0.001)
	var current_strength: float = _shake_strength * normalized
	var random_offset := Vector2(
		randf_range(-current_strength, current_strength),
		randf_range(-current_strength, current_strength)
	)

	if _shake_using_camera and is_instance_valid(_shake_target_camera):
		_shake_target_camera.offset = _shake_original_camera_offset + random_offset
	else:
		position = _shake_original_map_position + random_offset

	if _shake_time_left <= 0.0:
		_clear_map_shake()


# ==============================================================================
# SETUP
# ==============================================================================

func _setup_music() -> void:
	if map_music == null:
		push_warning("WorldMap: $MapMusic node not found.")
		return

	if music_track == null:
		push_warning("WorldMap: music_track is empty.")
		return

	map_music.stream = music_track
	map_music.volume_db = -24.0
	map_music.play()

	if _music_fade_tween:
		_music_fade_tween.kill()

	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(map_music, "volume_db", 0.0, 1.2)


func _setup_avatar() -> void:
	if CampaignManager.custom_avatar.has("battle_sprite") and CampaignManager.custom_avatar["battle_sprite"] != null:
		player_icon.texture = CampaignManager.custom_avatar["battle_sprite"]
	elif CampaignManager.player_roster.size() > 0:
		var first_unit = CampaignManager.player_roster[0]
		if first_unit.has("battle_sprite") and first_unit["battle_sprite"] != null:
			player_icon.texture = first_unit["battle_sprite"]

	player_icon.scale = player_icon_scale


func _ensure_feedback_audio_nodes() -> void:
	if fanfare_player == null:
		fanfare_player = AudioStreamPlayer.new()
		fanfare_player.name = "BaseFanfarePlayer"
		add_child(fanfare_player)

	if thud_player == null:
		thud_player = AudioStreamPlayer2D.new()
		thud_player.name = "BaseThudPlayer"
		thud_player.max_distance = 2400.0
		add_child(thud_player)


func _connect_level_nodes() -> void:
	for i in range(level_nodes.size()):
		var btn = level_nodes[i]
		if btn == null:
			continue

		var press_callable := Callable(self, "_on_node_pressed").bind(i)
		if btn.has_signal("pressed") and not btn.pressed.is_connected(press_callable):
			btn.pressed.connect(press_callable)

		var enter_callable := Callable(self, "_on_node_mouse_entered").bind(i)
		if btn.has_signal("mouse_entered") and not btn.mouse_entered.is_connected(enter_callable):
			btn.mouse_entered.connect(enter_callable)

		var exit_callable := Callable(self, "_on_node_mouse_exited").bind(i)
		if btn.has_signal("mouse_exited") and not btn.mouse_exited.is_connected(exit_callable):
			btn.mouse_exited.connect(exit_callable)


func _connect_ui_buttons() -> void:
	if camp_button != null:
		var camp_press := Callable(self, "_on_camp_pressed")
		if camp_button.has_signal("pressed") and not camp_button.pressed.is_connected(camp_press):
			camp_button.pressed.connect(camp_press)

		var camp_enter := Callable(self, "_on_ui_button_mouse_entered").bind(camp_button)
		if camp_button.has_signal("mouse_entered") and not camp_button.mouse_entered.is_connected(camp_enter):
			camp_button.mouse_entered.connect(camp_enter)

		var camp_exit := Callable(self, "_on_ui_button_mouse_exited").bind(camp_button)
		if camp_button.has_signal("mouse_exited") and not camp_button.mouse_exited.is_connected(camp_exit):
			camp_button.mouse_exited.connect(camp_exit)

	if city_button != null:
		var city_press := Callable(self, "_on_city_pressed")
		if city_button.has_signal("pressed") and not city_button.pressed.is_connected(city_press):
			city_button.pressed.connect(city_press)

		var city_enter := Callable(self, "_on_ui_button_mouse_entered").bind(city_button)
		if city_button.has_signal("mouse_entered") and not city_button.mouse_entered.is_connected(city_enter):
			city_button.mouse_entered.connect(city_enter)

		var city_exit := Callable(self, "_on_ui_button_mouse_exited").bind(city_button)
		if city_button.has_signal("mouse_exited") and not city_button.mouse_exited.is_connected(city_exit):
			city_button.mouse_exited.connect(city_exit)


func _cache_all_base_scales() -> void:
	_cache_base_scale(player_icon)

	for node in level_nodes:
		if node != null:
			_cache_base_scale(node)

	if camp_button != null:
		_cache_base_scale(camp_button)

	if city_button != null:
		_cache_base_scale(city_button)


func _cache_base_scale(node) -> void:
	if node == null:
		return

	var id: int = node.get_instance_id()
	if not _scale_cache.has(id):
		_scale_cache[id] = node.scale


func _cache_node_display_names() -> void:
	_node_display_names.clear()
	for i in range(level_nodes.size()):
		_node_display_names.append(_get_node_display_name_impl(i))


func _get_base_scale(node) -> Vector2:
	if node == null:
		return Vector2.ONE

	var id: int = node.get_instance_id()
	if _scale_cache.has(id):
		return _scale_cache[id]

	_scale_cache[id] = node.scale
	return node.scale


func _place_player_at_current_node() -> void:
	if target_node_index < 0 or target_node_index >= level_nodes.size():
		return
	if level_nodes[target_node_index] == null:
		return

	player_icon.position = level_nodes[target_node_index].position + player_icon_offset


# ==============================================================================
# VISUAL STATE
# ==============================================================================

func _refresh_node_visuals() -> void:
	for i in range(level_nodes.size()):
		var node = level_nodes[i]
		if node == null:
			continue

		var required_map_id: String = _get_required_expedition_map_id(i)
		var has_expedition_requirement: bool = required_map_id != ""
		var progression_locked: bool = (not has_expedition_requirement) and i > CampaignManager.max_unlocked_index
		var expedition_locked := _is_expedition_locked_for_index(i)
		var is_locked := progression_locked or expedition_locked
		var is_current: bool = i == int(CampaignManager.current_level_index)
		var is_completed: bool = i < int(CampaignManager.max_unlocked_index)

		if has_expedition_requirement:
			node.visible = not expedition_locked
		else:
			node.visible = true

		if node is BaseButton:
			node.disabled = is_locked

		if expedition_locked:
			node.modulate = Color(0.20, 0.28, 0.36, 0.55)
		elif is_locked:
			node.modulate = Color(0.35, 0.35, 0.35, 0.55)
		elif is_current:
			node.modulate = Color(1.0, 1.0, 1.0, 1.0)
		elif is_completed:
			node.modulate = Color(0.92, 0.90, 0.84, 0.95)
		else:
			node.modulate = Color(0.95, 0.95, 0.95, 1.0)

		if has_expedition_requirement and not expedition_locked and CampaignManager.has_completed_expedition(required_map_id):
			node.modulate *= Color(0.94, 1.02, 0.96, 1.0)

		_log_expedition_unlock_once(i)
		node.scale = _get_base_scale(node)

	_start_current_node_pulse()


func _start_current_node_pulse() -> void:
	if _current_node_pulse_tween:
		_current_node_pulse_tween.kill()
		_current_node_pulse_tween = null

	_current_node_index = CampaignManager.current_level_index

	if _current_node_index < 0 or _current_node_index >= level_nodes.size():
		return

	var node = level_nodes[_current_node_index]
	if node == null:
		return

	_current_node_pulse_tween = create_tween().set_loops(9999)
	_current_node_pulse_tween.tween_property(node, "modulate", Color(1.0, 0.96, 0.90, 1.0), 0.55)
	_current_node_pulse_tween.tween_property(node, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.55)


# ==============================================================================
# PLAYER ICON JUICE
# ==============================================================================

func _start_player_idle_bob() -> void:
	if player_icon == null or is_moving:
		return

	if _player_bob_tween:
		_player_bob_tween.kill()

	player_icon.position = _get_resting_player_position()

	_player_bob_tween = create_tween().set_loops(9999)
	_player_bob_tween.tween_property(
		player_icon,
		"position:y",
		_get_resting_player_position().y - player_bob_height,
		player_bob_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_player_bob_tween.tween_property(
		player_icon,
		"position:y",
		_get_resting_player_position().y,
		player_bob_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_player_idle_bob() -> void:
	if _player_bob_tween:
		_player_bob_tween.kill()
		_player_bob_tween = null

	if player_icon != null:
		player_icon.position = _get_resting_player_position()


func _get_resting_player_position() -> Vector2:
	if player_icon == null:
		return Vector2.ZERO
	if CampaignManager.current_level_index >= 0 \
	and CampaignManager.current_level_index < level_nodes.size() \
	and level_nodes[CampaignManager.current_level_index] != null:
		return level_nodes[CampaignManager.current_level_index].position + player_icon_offset
	return player_icon.position


func _play_player_arrival_bounce() -> void:
	if _player_arrival_tween:
		_player_arrival_tween.kill()
	if player_icon == null:
		return

	player_icon.scale = player_icon_scale

	_player_arrival_tween = create_tween()
	_player_arrival_tween.tween_property(player_icon, "scale", player_icon_scale * Vector2(0.92, 1.12), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_player_arrival_tween.tween_property(player_icon, "scale", player_icon_scale * Vector2(1.06, 0.94), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_player_arrival_tween.tween_property(player_icon, "scale", player_icon_scale, 0.08).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ==============================================================================
# INPUT / HOVER
# ==============================================================================

func _on_node_mouse_entered(index: int) -> void:
	if index < 0 or index >= level_nodes.size():
		return

	var node = level_nodes[index]
	if node == null:
		return
	if _is_expedition_locked_for_index(index):
		_show_announcement_debounced(_get_expedition_lock_message(index), false)
		return
	if node is BaseButton and node.disabled:
		return

	_tween_scale(node, _get_base_scale(node) * node_hover_scale, 0.10)
	var exp_map_id: String = _get_required_expedition_map_id(index)
	if exp_map_id != "":
		var exp_entry: Dictionary = ExpeditionMapDatabase.get_map_by_id(exp_map_id)
		if not exp_entry.is_empty():
			var hover_msg: String = ExpeditionMapDatabase.build_world_map_hover_announcement(exp_entry)
			hover_msg += ExpeditionMapDatabase.append_completion_hover_suffix(exp_entry, CampaignManager.has_completed_expedition(exp_map_id))
			hover_msg += ExpeditionMapDatabase.append_outcome_annotation_hover_suffix(CampaignManager.get_expedition_outcome_note(exp_map_id))
			hover_msg += ExpeditionMapDatabase.append_expedition_modifier_hover_suffix(exp_entry)
			_show_announcement_debounced(hover_msg, false)
			return
	_show_announcement_debounced("Destination: " + _get_node_display_name(index), false)


func _on_node_mouse_exited(index: int) -> void:
	if index < 0 or index >= level_nodes.size():
		return

	var node = level_nodes[index]
	if node == null:
		return

	_tween_scale(node, _get_base_scale(node), 0.10)
	_announce_current_node(false)


func _on_ui_button_mouse_entered(button) -> void:
	if button == null:
		return
	_tween_scale(button, _get_base_scale(button) * ui_hover_scale, 0.10)


func _on_ui_button_mouse_exited(button) -> void:
	if button == null:
		return
	_tween_scale(button, _get_base_scale(button), 0.10)


func _tween_scale(node, target_scale: Vector2, duration: float) -> void:
	if node == null:
		return

	var id: int = node.get_instance_id()
	if _hover_tweens.has(id):
		var old_tween: Tween = _hover_tweens[id]
		if is_instance_valid(old_tween):
			old_tween.kill()

	var t := create_tween()
	_hover_tweens[id] = t
	t.tween_property(node, "scale", target_scale, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.finished.connect(func(): _hover_tweens.erase(id))


# ==============================================================================
# MAP NAVIGATION
# ==============================================================================

func _on_node_pressed(index: int) -> void:
	if is_moving:
		return
	if index < 0 or index >= level_nodes.size():
		return
	if level_nodes[index] == null:
		return
	if _is_expedition_locked_for_index(index):
		_show_announcement(_get_expedition_lock_message(index), true)
		return
	if _get_required_expedition_map_id(index) != "":
		if not _validate_expedition_launch_ready(index):
			return
		_close_node_context_menu()
		var exp_map_id: String = _get_required_expedition_map_id(index)
		var exp_entry: Dictionary = ExpeditionMapDatabase.get_map_by_id(exp_map_id)
		if bool(exp_entry.get("coop_enabled", false)):
			_show_expedition_solo_or_charter_choice(exp_map_id)
		else:
			_launch_expedition_solo_from_world_map(exp_map_id)
		return
	if index > CampaignManager.max_unlocked_index:
		return

	_close_node_context_menu()

	# If the player is already at this node, open the contextual interaction.
	if index == CampaignManager.current_level_index:
		if index == CampaignManager.active_base_level_index and CampaignManager.base_under_attack:
			_start_base_defense(index)
		else:
			_show_node_context_menu(index)
	else:
		_move_player_to(index)


# Purpose: Moves the player icon to the targeted level node with arc, speed-based duration, and arrival bounce.
# Stops idle bob before moving and restores it after arrival.
func _move_player_to(index: int) -> void:
	is_moving = true

	# 30 percent chance to trigger a map encounter once per map cycle.
	if not CampaignManager.has_triggered_map_encounter and randf() <= 0.30:
		CampaignManager.has_triggered_map_encounter = true
		await _trigger_random_encounter(index)

	_stop_player_idle_bob()

	var dest_node = level_nodes[index]
	if dest_node == null:
		CampaignManager.current_level_index = index
		is_moving = false
		_start_player_idle_bob()
		return

	var target_pos: Vector2 = dest_node.position + player_icon_offset
	var start_pos: Vector2 = player_icon.position
	var distance: float = start_pos.distance_to(target_pos)

	# Duration from speed and min/max (fast and readable, not floaty).
	var raw_duration: float = distance / max(move_speed_pixels_per_second, 1.0)
	var duration: float = clampf(raw_duration, min_move_duration, max_move_duration)

	# Arc: midpoint raised by move_arc_height for a tasteful hop.
	var mid: Vector2 = (start_pos + target_pos) * 0.5
	mid.y -= move_arc_height

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	# Parabolic arc via two segments: start -> mid -> target.
	tween.tween_property(player_icon, "position", mid, duration * 0.5)
	tween.tween_property(player_icon, "position", target_pos, duration * 0.5)
	await tween.finished

	CampaignManager.current_level_index = index
	_refresh_node_visuals()
	_play_player_arrival_bounce()
	_announce_current_node(true)

	is_moving = false
	_start_player_idle_bob()


# Purpose: Pauses map interaction to display a narrative event. Uses region-weighted selection when destination node is given. Passes roster unit names for personal-arc weighting.
# Inputs: destination_level_index (int) - level/node index the player is moving to; used to resolve region for encounter weighting.
# Side Effects: Instantiates MapEncounterUI and yields until closed.
func _trigger_random_encounter(destination_level_index: int = -1) -> void:
	var regions: Dictionary = EncounterDatabase.get_regions_for_level(destination_level_index)
	var roster_names: Array = []
	var avatar_name: String = str(CampaignManager.custom_avatar.get("unit_name", CampaignManager.custom_avatar.get("name", ""))).strip_edges()
	for unit in CampaignManager.player_roster:
		var name_val = unit.get("unit_name", unit.get("name", ""))
		if name_val != null and str(name_val).strip_edges() != "":
			roster_names.append(str(name_val).strip_edges())
	if avatar_name != "" and roster_names.has(avatar_name):
		roster_names.append(EncounterDatabase.AVATAR_SENTINEL)
	var random_event: Dictionary = EncounterDatabase.pick_random_encounter_for_region(
		regions.get("primary", ""),
		regions.get("secondary", ""),
		roster_names
	)
	if random_event.is_empty():
		return
	var encounter_ui = MapEncounterUIScene.instantiate()
	add_child(encounter_ui)
	encounter_ui.load_encounter(random_event)
	await encounter_ui.encounter_finished


func _enter_level(index: int) -> void:
	CampaignManager.enter_level_from_map(index)


func _on_camp_pressed() -> void:
	SceneTransition.change_scene_to_file("res://Scenes/camp_menu.tscn")


func _on_city_pressed() -> void:
	SceneTransition.change_scene_to_file("res://Scenes/CityMenu.tscn")


# ==============================================================================
# ANNOUNCEMENTS
# ==============================================================================

func _announce_current_node(fade: bool = false) -> void:
	_show_announcement("Current Destination: " + _get_node_display_name(CampaignManager.current_level_index), fade)


# Timestamp-based debounce: avoids announcement spam when rapidly moving mouse across nodes (no Timer/_process).
func _show_announcement_debounced(msg: String, fade: bool) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _announce_last_show_time_msec < ANNOUNCE_DEBOUNCE_MSEC:
		return
	_announce_last_show_time_msec = now
	_show_announcement(msg, fade)


# Purpose: Displays a highly visible text announcement on the World Map.
# Resets font color to default so urgent red does not persist.
func _show_announcement(msg: String, fade: bool = true) -> void:
	if map_announcement == null:
		map_announcement = Label.new()
		map_announcement.name = "MapAnnouncement"
		map_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		map_announcement.add_theme_font_size_override("font_size", 28)
		map_announcement.add_theme_color_override("font_outline_color", Color.BLACK)
		map_announcement.add_theme_constant_override("outline_size", 8)

		map_announcement.size = Vector2(get_viewport_rect().size.x, 50)
		map_announcement.position = Vector2(0, 80)

		var ui_node = get_node_or_null("UI")
		if ui_node != null:
			ui_node.add_child(map_announcement)
		else:
			add_child(map_announcement)

	# Reset style so urgent red does not persist after normal announcements.
	map_announcement.remove_theme_color_override("font_color")
	map_announcement.visible = true
	map_announcement.modulate.a = 1.0
	map_announcement.text = msg

	if _announcement_tween:
		_announcement_tween.kill()

	if fade:
		_announcement_tween = create_tween()
		_announcement_tween.tween_property(map_announcement, "modulate:a", 0.0, 2.8).set_delay(1.2)
		_announcement_tween.tween_callback(Callable(self, "_hide_announcement"))


func _hide_announcement() -> void:
	if map_announcement:
		map_announcement.visible = false


# ==============================================================================
# HELPERS
# ==============================================================================

func _get_node_display_name(index: int) -> String:
	if index >= 0 and index < _node_display_names.size():
		return _node_display_names[index]
	return _get_node_display_name_impl(index)


func _get_node_display_name_impl(index: int) -> String:
	if index < 0 or index >= level_nodes.size():
		return "Unknown"

	var node = level_nodes[index]
	if node == null:
		return "Unknown"

	if node.has_meta("expedition_short_title"):
		var exp_title: String = str(node.get_meta("expedition_short_title")).strip_edges()
		if exp_title != "":
			return exp_title

	if node is Button:
		var txt := String(node.text).strip_edges()
		if txt != "":
			return txt
	if node is Control:
		var tooltip := String(node.tooltip_text).strip_edges()
		if tooltip != "":
			return tooltip

	var fallback := String(node.name)
	return fallback.replace("_", " ")

func _apply_expedition_node_requirements() -> void:
	var requirements: Dictionary = ExpeditionMapDatabase.get_world_node_requirements()
	for node_name in requirements.keys():
		var map_id: String = str(requirements[node_name]).strip_edges()
		if map_id == "":
			continue

		var node_path := "MapNodes/%s" % str(node_name)
		var map_node = get_node_or_null(node_path)
		if map_node == null:
			push_warning("WorldMap: Expedition map '%s' references missing node '%s'." % [map_id, str(node_name)])
			continue

		map_node.set_meta("required_expedition_map_id", map_id)
		var map_data: Dictionary = ExpeditionMapDatabase.get_map_by_id(map_id)
		if not map_data.is_empty():
			var tip: String = ExpeditionMapDatabase.build_world_map_tooltip_text(map_data)
			tip += ExpeditionMapDatabase.append_completion_tooltip_line(map_data, CampaignManager.has_completed_expedition(map_id))
			tip += ExpeditionMapDatabase.append_outcome_annotation_tooltip_line(CampaignManager.get_expedition_outcome_note(map_id))
			if tip != "" and map_node is Control:
				(map_node as Control).tooltip_text = tip
			var short_title: String = ExpeditionMapDatabase.build_world_map_short_title(map_data)
			if short_title != "":
				map_node.set_meta("expedition_short_title", short_title)

func _get_required_expedition_map_id(index: int) -> String:
	if index < 0 or index >= level_nodes.size():
		return ""

	var node = level_nodes[index]
	if node == null:
		return ""
	if not node.has_meta("required_expedition_map_id"):
		return ""

	return str(node.get_meta("required_expedition_map_id")).strip_edges()

func _is_expedition_locked_for_index(index: int) -> bool:
	var required_map_id: String = _get_required_expedition_map_id(index)
	if required_map_id == "":
		return false
	return not CampaignManager.has_expedition_map(required_map_id)

func _get_expedition_lock_message(index: int) -> String:
	var required_map_id: String = _get_required_expedition_map_id(index)
	if required_map_id == "":
		return "That route is currently inaccessible."

	var map_data: Dictionary = ExpeditionMapDatabase.get_map_by_id(required_map_id)
	if map_data.is_empty():
		return "That route requires an expedition map."

	return "Locked: Requires %s from the Grand Tavern Cartographer." % str(map_data.get("display_name", required_map_id))

func _validate_expedition_launch_ready(node_index: int) -> bool:
	var map_id: String = _get_required_expedition_map_id(node_index)
	if map_id == "":
		_show_announcement("Expedition: missing map binding on this node.", true)
		return false
	var map_data: Dictionary = ExpeditionMapDatabase.get_map_by_id(map_id)
	if map_data.is_empty():
		_show_announcement("Expedition: unknown map id " + map_id + ".", true)
		return false
	var battle_path: String = str(map_data.get("battle_scene_path", "")).strip_edges()
	if battle_path == "":
		_show_announcement("Expedition: no battle scene configured for this map.", true)
		return false
	if not ResourceLoader.exists(battle_path):
		_show_announcement("Expedition: scene missing: " + battle_path, true)
		return false
	var launch_index: int = CampaignManager.campaign_levels.find(battle_path)
	if launch_index < 0:
		_show_announcement("Expedition: scene not registered in campaign_levels: " + battle_path, true)
		return false
	return true


func _close_expedition_mode_chooser() -> void:
	if _expedition_mode_chooser_layer != null and is_instance_valid(_expedition_mode_chooser_layer):
		_expedition_mode_chooser_layer.queue_free()
	_expedition_mode_chooser_layer = null


func _show_expedition_solo_or_charter_choice(exp_map_id: String) -> void:
	_close_expedition_mode_chooser()
	var layer := CanvasLayer.new()
	layer.layer = 40
	_expedition_mode_chooser_layer = layer

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 310)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var prompt := Label.new()
	prompt.text = "This contract supports co-op staging. How do you want to begin?"
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prompt)

	var solo_btn := Button.new()
	solo_btn.text = "Solo expedition"
	solo_btn.pressed.connect(func():
		_close_expedition_mode_chooser()
		_launch_expedition_solo_from_world_map(exp_map_id)
	)
	vbox.add_child(solo_btn)

	var charter_btn := Button.new()
	charter_btn.text = "Expedition Charter (co-op staging)"
	charter_btn.pressed.connect(func():
		_close_expedition_mode_chooser()
		_open_expedition_charter_for_map(exp_map_id)
	)
	vbox.add_child(charter_btn)

	var online_btn := Button.new()
	online_btn.text = "Online room code (co-op)"
	online_btn.tooltip_text = "Open the charter, then use Host online room or Join online room."
	online_btn.pressed.connect(func():
		_close_expedition_mode_chooser()
		_open_expedition_charter_for_map(exp_map_id)
		_show_announcement("Online co-op: use Host online room / Join online room in the charter.", true)
	)
	vbox.add_child(online_btn)

	var join_lan_btn := Button.new()
	join_lan_btn.text = "Join friend's LAN (co-op)"
	join_lan_btn.tooltip_text = "Connect as guest first, then open the charter. Use the host's LAN IP and port (not 127.0.0.1 on a second PC)."
	join_lan_btn.pressed.connect(func():
		_close_expedition_mode_chooser()
		_open_expedition_lan_join_dialog(exp_map_id)
	)
	vbox.add_child(join_lan_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_close_expedition_mode_chooser)
	vbox.add_child(cancel_btn)

	add_child(layer)


func _launch_expedition_solo_from_world_map(exp_map_id: String) -> void:
	if not CampaignManager.launch_expedition_from_map(exp_map_id):
		var exp_fail: Dictionary = ExpeditionMapDatabase.get_map_by_id(exp_map_id)
		if CampaignManager.has_completed_expedition(exp_map_id) and not ExpeditionMapDatabase.is_entry_repeatable(exp_fail):
			_show_announcement("Expedition: this contract is already fulfilled.", true)
		else:
			_show_announcement("Expedition: launch failed. Check expedition data and campaign registration.", true)


func _open_expedition_lan_join_dialog(exp_map_id: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 42
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.68)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "Join LAN co-op"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	var hint := Label.new()
	hint.text = "Enter the host's address and port. On another computer, use their LAN IP (e.g. 192.168.0.12:7779), not 127.0.0.1."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(380, 0)
	vbox.add_child(hint)
	var addr := LineEdit.new()
	addr.text = "127.0.0.1:7779"
	addr.placeholder_text = "host:port"
	addr.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(addr)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var cancel := Button.new()
	cancel.text = "Cancel"
	var join := Button.new()
	join.text = "Join & open charter"
	row.add_child(cancel)
	row.add_child(join)
	vbox.add_child(row)
	add_child(layer)
	var close_layer := func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
	cancel.pressed.connect(close_layer)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_layer.call()
	)
	join.pressed.connect(func() -> void:
		var jp: String = str(addr.text).strip_edges()
		if jp == "":
			_show_announcement("Enter host:port (example: 192.168.1.5:7779).", true)
			return
		CoopExpeditionSessionManager.leave_session()
		var enet_transport := ENetCoopTransport.new()
		if jp.contains(":"):
			var parts: PackedStringArray = jp.split(":")
			if parts.size() >= 2:
				var pt: int = int(str(parts[parts.size() - 1]).strip_edges())
				if pt > 0:
					enet_transport.configure_listen_port(pt)
		CoopExpeditionSessionManager.set_transport(enet_transport)
		var r: Dictionary = CoopExpeditionSessionManager.join_session(jp)
		if not bool(r.get("ok", false)):
			_show_announcement("Join failed: %s" % str(r.get("error", r)), true)
			return
		close_layer.call()
		_open_expedition_charter_for_map(exp_map_id)
	)


func _open_expedition_charter_for_map(exp_map_id: String) -> void:
	var node: Node = ExpeditionCharterStagingUIScene.instantiate()
	if node == null:
		_show_announcement("Expedition Charter UI failed to load.", true)
		return
	add_child(node)
	if node.has_signal("closed"):
		node.closed.connect(_on_expedition_charter_closed)
	if node.has_method("open_for_expedition"):
		node.open_for_expedition(exp_map_id)
	else:
		_show_announcement("Expedition Charter UI script mismatch.", true)
		node.queue_free()


func _on_expedition_charter_closed() -> void:
	pass


func _log_expedition_unlock_once(index: int) -> void:
	if not DEBUG_EXPEDITION_NODE_LOGS:
		return
	var required_map_id: String = _get_required_expedition_map_id(index)
	if required_map_id == "":
		return
	if _is_expedition_locked_for_index(index):
		return

	var key: String = "%d|%s" % [index, required_map_id]
	if _logged_expedition_unlocks.get(key, false):
		return
	_logged_expedition_unlocks[key] = true
	print("WorldMap: Expedition node unlocked by map ownership -> ", _get_node_display_name(index), " [", required_map_id, "]")


func _get_active_map_camera() -> Camera2D:
	var active_camera := get_viewport().get_camera_2d()
	if active_camera != null and is_instance_valid(active_camera) and active_camera.is_current():
		return active_camera
	return null


func _get_level_node_center_global(index: int) -> Vector2:
	if index < 0 or index >= level_nodes.size():
		return Vector2.ZERO

	var node = level_nodes[index]
	if node == null:
		return Vector2.ZERO

	if node is Control:
		return node.global_position + node.size * 0.5

	return node.global_position


func _get_base_marker_target_global(base_idx: int) -> Vector2:
	return _get_level_node_center_global(base_idx) + base_marker_resting_offset


# ==============================================================================
# BASE ESTABLISHMENT FEEDBACK
# ==============================================================================

# Purpose:
# Starts a short impact shake. Prefers the active Camera2D, but falls back to
# shaking the WorldMap Node2D when no active camera is present.
func map_shake(intensity: int, duration: float) -> void:
	_clear_map_shake()

	_shake_strength = max(float(intensity), 0.0)
	_shake_duration_total = max(duration, 0.01)
	_shake_time_left = _shake_duration_total

	var active_camera := _get_active_map_camera()
	if active_camera != null:
		_shake_using_camera = true
		_shake_target_camera = active_camera
		_shake_original_camera_offset = active_camera.offset
	else:
		_shake_using_camera = false
		_shake_original_map_position = position

	set_process(true)


func _clear_map_shake() -> void:
	if _shake_using_camera and is_instance_valid(_shake_target_camera):
		_shake_target_camera.offset = _shake_original_camera_offset
	else:
		position = _shake_original_map_position

	_shake_time_left = 0.0
	_shake_duration_total = 0.0
	_shake_strength = 0.0
	_shake_target_camera = null
	_shake_using_camera = false
	set_process(false)


func _play_base_established_sequence(level_index: int) -> void:
	var node_name := _get_node_display_name(level_index)
	var node_center := _get_level_node_center_global(level_index)

	# The first shake confirms the base immediately.
	map_shake(int(round(base_shake_intensity)), base_shake_duration)

	# Presentation layers are launched in parallel.
	_play_base_fanfare()
	_show_base_established_banner(node_name)
	_spawn_base_established_particles(node_center)

	# The marker entrance includes its own secondary impact and thud.
	_update_base_marker(true)


func _play_base_fanfare() -> void:
	if fanfare_player == null or fanfare_sound == null:
		return

	fanfare_player.stream = fanfare_sound
	fanfare_player.play()


func _play_marker_thud(world_position: Vector2) -> void:
	if thud_player == null or thud_sound == null:
		return

	thud_player.global_position = world_position
	thud_player.stream = thud_sound
	thud_player.play()


func _show_base_established_banner(node_name: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 250
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var holder := Control.new()
	holder.size = Vector2(920, 170)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.modulate.a = 0.0
	root.add_child(holder)

	var shadow := Panel.new()
	shadow.position = Vector2(10, 10)
	shadow.size = holder.size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0.0, 0.0, 0.0, 0.30)
	shadow_style.corner_radius_top_left = 10
	shadow_style.corner_radius_top_right = 10
	shadow_style.corner_radius_bottom_left = 10
	shadow_style.corner_radius_bottom_right = 10
	shadow.add_theme_stylebox_override("panel", shadow_style)
	holder.add_child(shadow)

	var banner := PanelContainer.new()
	banner.size = holder.size
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color(0.08, 0.08, 0.11, 0.96)
	banner_style.border_color = Color(1.0, 0.82, 0.28, 1.0)
	banner_style.set_border_width_all(4)
	banner_style.corner_radius_top_left = 10
	banner_style.corner_radius_top_right = 10
	banner_style.corner_radius_bottom_left = 10
	banner_style.corner_radius_bottom_right = 10
	banner_style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	banner_style.shadow_size = 10
	banner.add_theme_stylebox_override("panel", banner_style)
	holder.add_child(banner)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 18)
	banner.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 22)
	margin.add_child(hbox)

	var accent := ColorRect.new()
	accent.color = Color(1.0, 0.82, 0.28, 1.0)
	accent.custom_minimum_size = Vector2(16, 0)
	accent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(accent)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", 6)
	hbox.add_child(text_box)

	var title := Label.new()
	title.text = "BASE ESTABLISHED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	title.add_theme_constant_override("outline_size", 10)
	text_box.add_child(title)

	var divider := ColorRect.new()
	divider.color = Color(1.0, 0.82, 0.28, 0.60)
	divider.custom_minimum_size = Vector2(0, 3)
	text_box.add_child(divider)

	var subtitle := Label.new()
	subtitle.text = node_name
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.70, 0.88, 1.0))
	subtitle.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	subtitle.add_theme_constant_override("outline_size", 6)
	text_box.add_child(subtitle)

	var viewport_size := get_viewport_rect().size
	var target_position := Vector2((viewport_size.x - holder.size.x) * 0.5, base_banner_y)
	var start_position := Vector2(-holder.size.x - 80.0, base_banner_y)
	holder.position = start_position

	if _base_banner_tween:
		_base_banner_tween.kill()

	_base_banner_tween = create_tween()
	_base_banner_tween.set_parallel(true)
	_base_banner_tween.tween_property(holder, "position", target_position, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_base_banner_tween.tween_property(holder, "modulate:a", 1.0, 0.18)
	_base_banner_tween.set_parallel(false)
	_base_banner_tween.tween_interval(base_banner_hold_time)
	_base_banner_tween.set_parallel(true)
	_base_banner_tween.tween_property(holder, "position", target_position + Vector2(80.0, 0.0), 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_base_banner_tween.tween_property(holder, "modulate:a", 0.0, 0.30).set_delay(0.05)
	_base_banner_tween.set_parallel(false)
	_base_banner_tween.tween_callback(func(): layer.queue_free())


func _spawn_base_established_particles(world_position: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.name = "BaseEstablishedBurst"
	particles.global_position = world_position
	particles.local_coords = false
	particles.one_shot = true
	particles.emitting = false
	particles.amount = base_particle_count
	particles.lifetime = 0.95
	particles.lifetime_randomness = 0.35
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 650.0)
	particles.initial_velocity_min = 110.0
	particles.initial_velocity_max = 250.0
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.linear_accel_min = -30.0
	particles.linear_accel_max = 45.0
	particles.scale_amount_min = 0.55
	particles.scale_amount_max = 1.25
	particles.color = Color(1.0, 0.92, 0.68, 1.0)

	var ramp := Gradient.new()
	ramp.add_point(0.00, Color(1.0, 0.98, 0.82, 1.0))
	ramp.add_point(0.28, Color(1.0, 0.78, 0.28, 0.95))
	ramp.add_point(0.72, Color(0.70, 0.52, 0.26, 0.55))
	ramp.add_point(1.00, Color(0.35, 0.27, 0.16, 0.0))
	particles.color_ramp = ramp

	add_child(particles)
	particles.finished.connect(func(): particles.queue_free())
	particles.emitting = true


func _ensure_base_marker_visual() -> void:
	if base_marker_visual != null and is_instance_valid(base_marker_visual):
		return

	base_marker_visual = Panel.new()
	base_marker_visual.name = "BaseMarkerVisual"
	base_marker_visual.size = Vector2(24, 24)
	base_marker_visual.pivot_offset = Vector2(12, 12)
	base_marker_visual.rotation_degrees = 45.0
	base_marker_visual.scale = Vector2.ONE
	base_marker_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.80, 0.20)
	style.border_color = Color(1.0, 1.0, 1.0)
	style.set_border_width_all(2)
	base_marker_visual.add_theme_stylebox_override("panel", style)


func _attach_base_marker_to_node(base_idx: int) -> void:
	if base_idx < 0 or base_idx >= level_nodes.size():
		return
	if level_nodes[base_idx] == null:
		return

	var target_node = level_nodes[base_idx]

	if base_marker_visual.get_parent() != null:
		base_marker_visual.get_parent().remove_child(base_marker_visual)

	target_node.add_child(base_marker_visual)
	base_marker_visual.visible = true
	base_marker_visual.scale = Vector2.ONE
	base_marker_visual.rotation_degrees = 45.0

	if target_node is Control:
		base_marker_visual.position = Vector2(target_node.size.x * 0.5, 0.0) + base_marker_resting_offset
	else:
		base_marker_visual.position = base_marker_resting_offset


func _start_base_marker_float() -> void:
	if base_marker_visual == null or not is_instance_valid(base_marker_visual):
		return

	if _base_marker_float_tween:
		_base_marker_float_tween.kill()

	var start_y := base_marker_visual.position.y
	_base_marker_float_tween = create_tween().set_loops(9999)
	_base_marker_float_tween.tween_property(base_marker_visual, "position:y", start_y - 8.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_base_marker_float_tween.tween_property(base_marker_visual, "position:y", start_y, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _animate_base_marker_drop(base_idx: int) -> void:
	if base_idx < 0 or base_idx >= level_nodes.size():
		return
	if level_nodes[base_idx] == null:
		return

	_ensure_base_marker_visual()

	if _base_marker_float_tween:
		_base_marker_float_tween.kill()
	if _base_marker_drop_tween:
		_base_marker_drop_tween.kill()

	var final_global := _get_base_marker_target_global(base_idx)

	# Temporarily parent to WorldMap so the drop can be driven in world space.
	if base_marker_visual.get_parent() != null:
		base_marker_visual.get_parent().remove_child(base_marker_visual)

	add_child(base_marker_visual)
	base_marker_visual.visible = true
	base_marker_visual.modulate.a = 0.0
	base_marker_visual.scale = Vector2(0.70, 0.70)
	base_marker_visual.rotation_degrees = 45.0
	base_marker_visual.global_position = final_global + Vector2(0.0, -base_marker_drop_height)

	_base_marker_drop_tween = create_tween()
	_base_marker_drop_tween.set_parallel(true)
	_base_marker_drop_tween.tween_property(base_marker_visual, "global_position", final_global, 0.34).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_base_marker_drop_tween.tween_property(base_marker_visual, "modulate:a", 1.0, 0.10)
	_base_marker_drop_tween.tween_property(base_marker_visual, "scale", Vector2(1.06, 1.06), 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_base_marker_drop_tween.set_parallel(false)

	_base_marker_drop_tween.tween_callback(func():
		_play_marker_thud(_get_level_node_center_global(base_idx))
		map_shake(int(round(base_shake_intensity * 0.55)), 0.16)
	)

	# The "thud" moment uses squash and then a soft elastic settle.
	_base_marker_drop_tween.tween_property(base_marker_visual, "scale", Vector2(0.82, 1.18), 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_base_marker_drop_tween.tween_property(base_marker_visual, "scale", Vector2(1.10, 0.92), 0.10).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_base_marker_drop_tween.tween_property(base_marker_visual, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_base_marker_drop_tween.tween_callback(func():
		_attach_base_marker_to_node(base_idx)
		_start_base_marker_float()
	)


# ==============================================================================
# BASE MANAGEMENT & CONTEXT MENU
# ==============================================================================

# Purpose: Displays a context menu allowing the player to manage their base or enter a level.
func _show_node_context_menu(index: int) -> void:
	_close_node_context_menu()

	var node = level_nodes[index]
	node_context_menu = PanelContainer.new()

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_color = Color(0.8, 0.6, 0.2)
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	node_context_menu.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	node_context_menu.add_child(vbox)

	var is_base_here = (index == CampaignManager.active_base_level_index)

	# --- SCENARIO A: THE BASE IS HERE ---
	if is_base_here:
		var lbl_base = Label.new()
		lbl_base.text = "--- ACTIVE BASE ---"
		lbl_base.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_base.add_theme_color_override("font_color", Color.GOLD)
		vbox.add_child(lbl_base)

		if CampaignManager.base_under_attack:
			var btn_defend = Button.new()
			btn_defend.text = "DEFEND BASE"
			btn_defend.add_theme_font_size_override("font_size", 20)
			btn_defend.add_theme_color_override("font_color", Color.RED)
			btn_defend.pressed.connect(func():
				_close_node_context_menu()
				_start_base_defense(index)
			)
			vbox.add_child(btn_defend)
		else:
			var btn_enter = Button.new()
			btn_enter.text = "Enter Map"
			btn_enter.pressed.connect(func():
				_close_node_context_menu()
				_enter_level(index)
			)
			vbox.add_child(btn_enter)

			var stored_gold = CampaignManager.base_resource_storage.get("gold", 0)
			var btn_collect = Button.new()
			btn_collect.text = "Collect Yield (" + str(stored_gold) + "G)"
			btn_collect.disabled = (stored_gold == 0)
			btn_collect.add_theme_color_override("font_color", Color.LIME)
			btn_collect.pressed.connect(func():
				var yields = CampaignManager.collect_base_resources()
				_show_collection_success_ui(yields)
				_show_announcement("Collected " + str(yields["gold"]) + " Gold.", true)
				_close_node_context_menu()
			)
			vbox.add_child(btn_collect)

			var btn_abandon = Button.new()
			btn_abandon.text = "Dismantle Base"
			btn_abandon.add_theme_color_override("font_color", Color.GRAY)
			btn_abandon.pressed.connect(func():
				CampaignManager.abandon_base()
				_update_base_marker()
				_show_announcement("Base dismantled. Garrison returned to roster.", true)
				_close_node_context_menu()
			)
			vbox.add_child(btn_abandon)

	# --- SCENARIO B: NO BASE HERE ---
	else:
		var btn_enter = Button.new()
		btn_enter.text = "Enter Map"
		btn_enter.add_theme_font_size_override("font_size", 20)
		btn_enter.pressed.connect(func():
			_close_node_context_menu()
			_enter_level(index)
		)
		vbox.add_child(btn_enter)

		var btn_base = Button.new()
		btn_base.text = "Establish Base"
		btn_base.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		btn_base.pressed.connect(func():
			_close_node_context_menu()
			_open_garrison_selection_ui(index)
		)
		vbox.add_child(btn_base)

	$UI.add_child(node_context_menu)
	# Position in screen space so menu appears next to the node (Control in tree).
	node_context_menu.global_position = node.global_position + Vector2(40, -40)


func _close_node_context_menu() -> void:
	if node_context_menu != null and is_instance_valid(node_context_menu):
		node_context_menu.queue_free()
		node_context_menu = null


# Purpose: Opens a UI to select 3 defenders for the new base.
func _open_garrison_selection_ui(level_index: int) -> void:
	selected_garrison_units.clear()

	base_garrison_ui = CanvasLayer.new()
	base_garrison_ui.layer = 100
	add_child(base_garrison_ui)

	var dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.8)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_garrison_ui.add_child(dimmer)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(800, 600)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position.y -= 120

	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.1, 0.1, 0.12, 0.98)
	p_style.border_color = Color(0.4, 0.8, 1.0)
	p_style.set_border_width_all(3)
	p_style.set_content_margin_all(25)
	panel.add_theme_stylebox_override("panel", p_style)
	base_garrison_ui.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "SELECT GARRISON (Choose 3)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	vbox.add_child(title)

	var instructions = Label.new()
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if CampaignManager.active_base_level_index != -1:
		var old_base_name = _get_node_display_name(CampaignManager.active_base_level_index)
		instructions.text = "WARNING: Establishing a base here will dismantle your active base at " + old_base_name + ".\nIts current garrison will be returned to your roster."
		instructions.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	else:
		instructions.text = "These units will defend the base and collect resources.\nThey cannot be used in the main campaign until the base is moved."
		instructions.add_theme_color_override("font_color", Color.GRAY)
	vbox.add_child(instructions)

	var grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 15)
	vbox.add_child(grid)

	var confirm_btn = Button.new()
	confirm_btn.text = "ESTABLISH BASE"
	confirm_btn.disabled = true
	confirm_btn.custom_minimum_size = Vector2(0, 60)
	confirm_btn.add_theme_font_size_override("font_size", 24)
	vbox.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func():
		if base_garrison_ui != null and is_instance_valid(base_garrison_ui):
			base_garrison_ui.queue_free()
			base_garrison_ui = null
	)
	vbox.add_child(cancel_btn)

	var yield_info = CampaignManager.base_yield_table.get(level_index, {"name": "Wilderness", "wood": "Low", "iron": "Low", "gold": "Low"})

	var yield_panel = PanelContainer.new()
	var y_style = StyleBoxFlat.new()
	y_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	y_style.set_border_width_all(1)
	y_style.border_color = Color(0.4, 0.6, 1.0, 0.5)
	yield_panel.add_theme_stylebox_override("panel", y_style)
	vbox.add_child(yield_panel)

	var yield_label = Label.new()
	yield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	yield_label.text = "LOCATION: " + yield_info["name"] + "\n"
	yield_label.text += "EXPECTED YIELDS:  [Planks: " + yield_info["wood"] + "]  [Ore: " + yield_info["iron"] + "]  [Gold: " + yield_info["gold"] + "]"
	yield_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	yield_panel.add_child(yield_label)

	for unit in CampaignManager.player_roster:
		var u_name = str(unit.get("unit_name", ""))
		var avatar_name = str(CampaignManager.custom_avatar.get("unit_name", CampaignManager.custom_avatar.get("name", "")))
		var is_avatar = (u_name != "" and u_name == avatar_name)

		if unit.get("is_dragon", false) or is_avatar:
			continue

		var u_btn = Button.new()
		u_btn.text = unit.get("unit_name", "Unknown")
		u_btn.icon = unit.get("portrait")
		u_btn.expand_icon = true
		u_btn.custom_minimum_size = Vector2(160, 60)

		if unit.get("is_garrisoned", false):
			u_btn.modulate = Color(0.5, 0.5, 0.5)
			u_btn.text += "\n(Current)"

		u_btn.pressed.connect(func():
			if selected_garrison_units.has(u_name):
				selected_garrison_units.erase(u_name)
				u_btn.modulate = Color.WHITE
			else:
				if selected_garrison_units.size() < 3:
					selected_garrison_units.append(u_name)
					u_btn.modulate = Color.GREEN

			confirm_btn.disabled = (selected_garrison_units.size() != 3)
		)
		grid.add_child(u_btn)

	confirm_btn.pressed.connect(func():
		CampaignManager.establish_new_base(level_index, selected_garrison_units)
		CampaignManager.save_current_progress()

		if base_garrison_ui != null and is_instance_valid(base_garrison_ui):
			base_garrison_ui.queue_free()
			base_garrison_ui = null

		_play_base_established_sequence(level_index)
		_show_announcement("Base Established at " + _get_node_display_name(level_index), true)
	)


# Purpose: Triggers the hijack flag and loads the map for a defense scenario.
func _start_base_defense(index: int) -> void:
	CampaignManager.is_base_defense_active = true
	CampaignManager.base_under_attack = false
	CampaignManager.save_current_progress()
	CampaignManager.enter_level_from_map(index)


# Purpose: Displays a temporary popup showing base resource generation.
func _show_harvest_report() -> void:
	var report = CampaignManager.base_last_harvest_report
	if report.is_empty():
		return

	var report_ui = CanvasLayer.new()
	report_ui.layer = 150
	add_child(report_ui)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 200)

	var vp_size = get_viewport_rect().size
	panel.position = Vector2(40, vp_size.y - 240)

	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	p_style.set_border_width_all(2)
	p_style.set_content_margin_all(15)

	var txt = Label.new()
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.add_theme_font_size_override("font_size", 20)

	if report.get("robbed", false):
		p_style.border_color = Color.RED
		txt.text = "BASE PILLAGED\n\n80% of stored resources were lost because the defense was ignored."
		txt.add_theme_color_override("font_color", Color.TOMATO)
	else:
		p_style.border_color = Color.LIME
		txt.text = "BASE YIELD\n\n"
		txt.text += "Wood: +" + str(report.get("wood", 0)) + " (Total: " + str(report.get("total_wood", 0)) + ")\n"
		txt.text += "Iron: +" + str(report.get("iron", 0)) + " (Total: " + str(report.get("total_iron", 0)) + ")\n"
		txt.text += "Gold: +" + str(report.get("gold", 0)) + " (Total: " + str(report.get("total_gold", 0)) + ")"
		txt.add_theme_color_override("font_color", Color.WHITE)

	panel.add_theme_stylebox_override("panel", p_style)
	panel.add_child(txt)
	report_ui.add_child(panel)

	var tw = create_tween()
	panel.position.y += 300
	tw.tween_property(panel, "position:y", vp_size.y - 240, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(4.0)
	tw.tween_property(panel, "position:y", vp_size.y + 100, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): report_ui.queue_free())

	CampaignManager.base_last_harvest_report.clear()


# Purpose:
# Creates, positions, or hides the active base marker.
# When play_drop_animation is true, the marker performs the full entrance.
func _update_base_marker(play_drop_animation: bool = false) -> void:
	_ensure_base_marker_visual()

	var base_idx = CampaignManager.active_base_level_index

	if base_idx != -1 and base_idx < level_nodes.size() and level_nodes[base_idx] != null:
		base_marker_visual.visible = true

		if play_drop_animation:
			_animate_base_marker_drop(base_idx)
		else:
			if _base_marker_drop_tween:
				_base_marker_drop_tween.kill()
			_attach_base_marker_to_node(base_idx)
			_start_base_marker_float()
	else:
		if _base_marker_float_tween:
			_base_marker_float_tween.kill()
		if _base_marker_drop_tween:
			_base_marker_drop_tween.kill()

		if base_marker_visual != null and is_instance_valid(base_marker_visual):
			base_marker_visual.visible = false


# Purpose: Shows a dramatic visual list of items collected from the base.
func _show_collection_success_ui(yields: Dictionary) -> void:
	var popup = CanvasLayer.new()
	popup.layer = 200
	add_child(popup)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(center)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.set_border_width_all(4)
	style.border_color = Color.GOLD
	style.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "RESOURCES COLLECTED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title)

	var grid = VBoxContainer.new()
	vbox.add_child(grid)

	var add_row = func(label_text: String, amount: int, color: Color):
		if amount <= 0:
			return
		var lbl = Label.new()
		lbl.text = "+ " + str(amount) + " " + label_text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", color)
		lbl.add_theme_font_size_override("font_size", 24)
		grid.add_child(lbl)

	add_row.call("Gold", yields["gold"], Color.GOLD)
	add_row.call("Wooden Planks", yields["wood"], Color.SADDLE_BROWN)
	add_row.call("Iron Ores", yields["iron"], Color.LIGHT_GRAY)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	var close_btn = Button.new()
	close_btn.text = "Dismiss"
	close_btn.custom_minimum_size = Vector2(200, 50)
	close_btn.pressed.connect(func(): popup.queue_free())
	vbox.add_child(close_btn)


# ==============================================================================
# DEBUG CONTROLS
# ==============================================================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			if not is_moving:
				_trigger_random_encounter()

		elif event.keycode == KEY_B:
			if CampaignManager.active_base_level_index == -1:
				_show_announcement("Debug: Establish a base first.", true)
				return

			CampaignManager.base_under_attack = true
			_show_announcement("URGENT: Base is under attack!", false)
			if map_announcement != null:
				map_announcement.add_theme_color_override("font_color", Color.RED)
			_close_node_context_menu()

		elif event.keycode == KEY_G:
			if CampaignManager.active_base_level_index == -1:
				_show_announcement("Debug: No base to generate for.", true)
				return

			CampaignManager._process_base_economy()
			_show_harvest_report()
			_close_node_context_menu()
			print("Debug: Generated resources. Storage: ", CampaignManager.base_resource_storage)

		elif event.keycode == KEY_I:
			print("--- GLOBAL CONVOY ---")
			print("Gold: ", CampaignManager.global_gold)
			for item in CampaignManager.global_inventory:
				var i_name = "Unknown Item"
				if item.get("weapon_name") != null:
					i_name = item.weapon_name
				elif item.get("item_name") != null:
					i_name = item.item_name
				print("- ", i_name)

		elif event.keycode == KEY_M and event.ctrl_pressed:
			var granted_map_id: String = CampaignManager.grant_first_debug_expedition_map()
			if granted_map_id == "":
				_show_announcement("Debug: No new expedition map available to grant.", true)
				return
			_refresh_node_visuals()
			_show_announcement("Debug: Granted expedition map " + granted_map_id, true)


func _is_coop_staging_debug_panel_allowed() -> bool:
	return OS.is_debug_build() or allow_coop_staging_debug_panel_in_release


func _unhandled_input(event: InputEvent) -> void:
	## Ctrl+Shift+P: co-op staging / ENet tester. Uses unhandled so UI focus does not swallow it; physical_keycode helps non-US layouts.
	if not (event is InputEventKey):
		return
	var ek: InputEventKey = event as InputEventKey
	if not ek.pressed or ek.echo:
		return
	var is_p: bool = (ek.keycode == KEY_P) or (ek.physical_keycode == KEY_P)
	if not (is_p and ek.ctrl_pressed and ek.shift_pressed):
		return
	if _is_coop_staging_debug_panel_allowed():
		_toggle_coop_staging_debug_panel()
	else:
		_show_announcement(
			"Co-op staging (Ctrl+Shift+P): open Scenes/UI/WorldMap.tscn, select root WorldMap, enable “Allow Coop Staging Debug Panel In Release” (group: Co-op staging debug), or export/run a debug build.",
			true,
		)
	get_viewport().set_input_as_handled()


func _on_coop_staging_debug_session_changed() -> void:
	_refresh_coop_staging_debug_status()


func _coop_staging_debug_pick_test_map_id() -> String:
	var coop_ids: Array[String] = CampaignManager.get_coop_eligible_expedition_map_ids()
	if not coop_ids.is_empty():
		return coop_ids[0]
	for entry in ExpeditionMapDatabase.get_all_maps():
		var mid: String = str(entry.get("id", "")).strip_edges()
		if mid == "":
			continue
		if bool(entry.get("coop_enabled", false)):
			return mid
	return ""


func _coop_staging_debug_add_action_btn(parent: Control, label_text: String, on_press: Callable) -> void:
	var b := Button.new()
	b.text = label_text
	b.custom_minimum_size = Vector2(220, 28)
	b.pressed.connect(func():
		on_press.call()
		_refresh_coop_staging_debug_status()
	)
	parent.add_child(b)


func _refresh_coop_staging_debug_status() -> void:
	if _coop_staging_debug_status_label == null or not is_instance_valid(_coop_staging_debug_status_label):
		return
	var mgr := CoopExpeditionSessionManager
	var lines: Array[String] = []
	lines.append("Staging: %s" % mgr.get_coop_staging_state_name())
	lines.append("phase=%d session_id=%s" % [mgr.phase, mgr.session_id])
	lines.append("selected_map=%s" % mgr.selected_expedition_map_id)
	lines.append("local_ready=%s remote_ready=%s" % [str(mgr.local_ready), str(mgr.remote_ready)])
	var blk: PackedStringArray = mgr.get_coop_launch_blockers()
	if blk.is_empty():
		lines.append("Blockers: (none)")
	else:
		var btxt: String = ""
		for i in range(blk.size()):
			btxt += "- %s\n" % str(blk[i])
		lines.append("Blockers:\n" + btxt.strip_edges())
	if not _coop_staging_debug_last_finalize.is_empty():
		lines.append("Last finalize ok=%s errors=%s" % [
			str(_coop_staging_debug_last_finalize.get("ok", "?")),
			str(_coop_staging_debug_last_finalize.get("errors", []))
		])
		var pl: Variant = _coop_staging_debug_last_finalize.get("payload", {})
		if pl is Dictionary and not (pl as Dictionary).is_empty():
			lines.append("Last payload keys: %s" % str((pl as Dictionary).keys()))
	if not _coop_staging_debug_last_handoff.is_empty():
		lines.append("Last handoff ok=%s errors=%s" % [
			str(_coop_staging_debug_last_handoff.get("ok", "?")),
			str(_coop_staging_debug_last_handoff.get("errors", [])),
		])
		var hh: Variant = _coop_staging_debug_last_handoff.get("handoff", {})
		if hh is Dictionary and not (hh as Dictionary).is_empty():
			lines.append("Last handoff keys: %s" % str((hh as Dictionary).keys()))
	lines.append("pending_handoff_stored=%s" % str(CampaignManager.has_pending_mock_coop_battle_handoff()))
	_coop_staging_debug_status_label.text = "\n".join(lines)


func _toggle_coop_staging_debug_panel() -> void:
	if _coop_staging_debug_layer != null and is_instance_valid(_coop_staging_debug_layer):
		if CoopExpeditionSessionManager.session_state_changed.is_connected(_on_coop_staging_debug_session_changed):
			CoopExpeditionSessionManager.session_state_changed.disconnect(_on_coop_staging_debug_session_changed)
		_coop_staging_debug_layer.queue_free()
		_coop_staging_debug_layer = null
		_coop_staging_debug_status_label = null
		_coop_enet_port_field = null
		_coop_enet_join_field = null
		return
	var layer := CanvasLayer.new()
	layer.layer = 120
	layer.name = "CoopStagingDebugLayer"
	add_child(layer)
	_coop_staging_debug_layer = layer
	CoopExpeditionSessionManager.session_state_changed.connect(_on_coop_staging_debug_session_changed)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 16.0
	panel.offset_top = 64.0
	panel.custom_minimum_size = Vector2(500, 680)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	var hint := Label.new()
	hint.text = "Co-op staging tester (debug). Ctrl+Shift+P closes. Loopback = same process; ENet = two instances (LAN)."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(460, 0)
	vbox.add_child(hint)
	_coop_staging_debug_status_label = Label.new()
	_coop_staging_debug_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coop_staging_debug_status_label.custom_minimum_size = Vector2(460, 150)
	vbox.add_child(_coop_staging_debug_status_label)
	var enet_hint := Label.new()
	enet_hint.text = "ENet: port below = host listen port. Join field = host:port (e.g. 127.0.0.1:7779 or LAN IP)."
	enet_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enet_hint.custom_minimum_size = Vector2(460, 0)
	vbox.add_child(enet_hint)
	_coop_enet_port_field = LineEdit.new()
	_coop_enet_port_field.text = "7779"
	_coop_enet_port_field.placeholder_text = "host listen port"
	_coop_enet_port_field.custom_minimum_size = Vector2(200, 28)
	vbox.add_child(_coop_enet_port_field)
	_coop_enet_join_field = LineEdit.new()
	_coop_enet_join_field.text = "127.0.0.1:7779"
	_coop_enet_join_field.placeholder_text = "host:port"
	_coop_enet_join_field.custom_minimum_size = Vector2(320, 28)
	vbox.add_child(_coop_enet_join_field)
	var enet_grid := GridContainer.new()
	enet_grid.columns = 2
	enet_grid.add_theme_constant_override("h_separation", 8)
	enet_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(enet_grid)
	_coop_staging_debug_add_action_btn(enet_grid, "ENet: bind + host", Callable(self, "_coop_debug_enet_bind_and_host"))
	_coop_staging_debug_add_action_btn(enet_grid, "ENet: bind + join", Callable(self, "_coop_debug_enet_bind_and_join"))
	_coop_staging_debug_add_action_btn(enet_grid, "Restore loopback transport", Callable(self, "_coop_debug_restore_loopback_transport"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)
	_coop_staging_debug_add_action_btn(grid, "1 Host: create session", Callable(self, "_coop_debug_action_host"))
	_coop_staging_debug_add_action_btn(grid, "2 Mock guest payload", Callable(self, "_coop_debug_action_mock_guest"))
	_coop_staging_debug_add_action_btn(grid, "3 Select coop map", Callable(self, "_coop_debug_action_select_map"))
	_coop_staging_debug_add_action_btn(grid, "4 Toggle local ready", Callable(self, "_coop_debug_action_toggle_local_ready"))
	_coop_staging_debug_add_action_btn(grid, "5 Toggle remote ready", Callable(self, "_coop_debug_action_toggle_remote_ready"))
	_coop_staging_debug_add_action_btn(grid, "6 Finalize launch", Callable(self, "_coop_debug_action_finalize"))
	_coop_staging_debug_add_action_btn(grid, "7 Build battle handoff", Callable(self, "_coop_debug_action_battle_handoff"))
	_coop_staging_debug_add_action_btn(grid, "8 Store pending handoff", Callable(self, "_coop_debug_action_store_handoff"))
	_coop_staging_debug_add_action_btn(grid, "9 Launch battle (pending)", Callable(self, "_coop_debug_action_launch_pending_handoff"))
	_coop_staging_debug_add_action_btn(grid, "Guest: join (clears host)", Callable(self, "_coop_debug_action_guest_join"))
	_coop_staging_debug_add_action_btn(grid, "Mock host (guest side)", Callable(self, "_coop_debug_action_mock_host"))
	_coop_staging_debug_add_action_btn(grid, "Leave session", Callable(self, "_coop_debug_action_leave"))
	_refresh_coop_staging_debug_status()


func _coop_debug_action_host() -> void:
	var r: Dictionary = CoopExpeditionSessionManager.begin_host_session()
	_show_announcement("Co-op debug host: %s" % str(r), true)


func _coop_debug_action_mock_guest() -> void:
	var mid: String = _coop_staging_debug_pick_test_map_id()
	if mid == "":
		_show_announcement("Co-op debug: grant a coop map (Ctrl+Shift+M) or add DB entry.", true)
		return
	var r: Dictionary = CoopExpeditionSessionManager.debug_apply_mock_guest_payload_for_staging([mid], false)
	_show_announcement("Co-op debug mock guest: %s" % str(r), true)


func _coop_debug_action_select_map() -> void:
	var mid: String = _coop_staging_debug_pick_test_map_id()
	if mid == "":
		_show_announcement("Co-op debug: no map id to select.", true)
		return
	if CoopExpeditionSessionManager.set_selected_expedition_map(mid):
		_show_announcement("Co-op debug: selected %s" % mid, true)
	else:
		_show_announcement("Co-op debug: select failed for %s" % mid, true)


func _coop_debug_action_toggle_local_ready() -> void:
	CoopExpeditionSessionManager.set_local_ready(not CoopExpeditionSessionManager.local_ready)


func _coop_debug_action_toggle_remote_ready() -> void:
	CoopExpeditionSessionManager.set_remote_ready(not CoopExpeditionSessionManager.remote_ready)


func _coop_debug_action_finalize() -> void:
	_coop_staging_debug_last_finalize = CoopExpeditionSessionManager.finalize_coop_expedition_launch()
	_show_announcement("Co-op debug finalize: ok=%s" % str(_coop_staging_debug_last_finalize.get("ok", false)), true)


func _coop_debug_action_battle_handoff() -> void:
	_coop_staging_debug_last_finalize = CoopExpeditionSessionManager.finalize_coop_expedition_launch()
	_coop_staging_debug_last_handoff = CoopExpeditionBattleHandoff.prepare_from_finalize_result(_coop_staging_debug_last_finalize)
	var ok: bool = bool(_coop_staging_debug_last_handoff.get("ok", false))
	var msg: String = "Co-op handoff ok=%s" % str(ok)
	if not ok:
		msg += " errors=%s" % str(_coop_staging_debug_last_handoff.get("errors", []))
		var fe: Variant = _coop_staging_debug_last_handoff.get("finalize_errors", [])
		if fe is Array and not (fe as Array).is_empty():
			msg += " finalize_errors=%s" % str(fe)
	_show_announcement(msg, true)


func _coop_debug_action_store_handoff() -> void:
	if not bool(_coop_staging_debug_last_handoff.get("ok", false)):
		_show_announcement("Co-op debug store: build handoff (7) with ok=true first.", true)
		return
	var hh: Variant = _coop_staging_debug_last_handoff.get("handoff", {})
	if typeof(hh) != TYPE_DICTIONARY or (hh as Dictionary).is_empty():
		_show_announcement("Co-op debug store: no handoff dict on last result.", true)
		return
	var res: Dictionary = CampaignManager.store_pending_mock_coop_battle_handoff(hh as Dictionary)
	_show_announcement("Co-op debug store pending: ok=%s %s" % [str(res.get("ok", false)), str(res.get("errors", []))], true)


func _coop_debug_action_launch_pending_handoff() -> void:
	var res: Dictionary = CampaignManager.launch_expedition_with_pending_mock_coop_handoff()
	if not bool(res.get("ok", false)):
		_show_announcement("Co-op debug launch failed: %s" % str(res.get("errors", [])), true)
	else:
		_show_announcement("Co-op debug: launching battle with pending handoff…", true)


func _coop_debug_action_guest_join() -> void:
	var sid: String = CoopExpeditionSessionManager.session_id
	if sid == "":
		sid = "local_join_debug"
	var r: Dictionary = CoopExpeditionSessionManager.join_session(sid)
	_show_announcement("Co-op debug join: %s" % str(r), true)


func _coop_debug_action_mock_host() -> void:
	var mid: String = _coop_staging_debug_pick_test_map_id()
	if mid == "":
		_show_announcement("Co-op debug: no map id for mock host.", true)
		return
	var r: Dictionary = CoopExpeditionSessionManager.debug_apply_mock_host_payload_for_staging([mid], false)
	_show_announcement("Co-op debug mock host: %s" % str(r), true)


func _coop_debug_action_leave() -> void:
	CoopExpeditionSessionManager.leave_session()
	CampaignManager.clear_pending_mock_coop_battle_handoff()
	_coop_staging_debug_last_finalize = {}
	_coop_staging_debug_last_handoff = {}


func _coop_debug_enet_bind_and_host() -> void:
	if _coop_enet_port_field == null:
		return
	CoopExpeditionSessionManager.leave_session()
	var enet_transport := ENetCoopTransport.new()
	var p: int = int(str(_coop_enet_port_field.text).strip_edges())
	if p <= 0:
		p = ENetCoopTransport.DEFAULT_PORT
	enet_transport.configure_listen_port(p)
	CoopExpeditionSessionManager.set_transport(enet_transport)
	var r: Dictionary = CoopExpeditionSessionManager.begin_host_session()
	_show_announcement("ENet bind+host: %s" % str(r), true)


func _coop_debug_enet_bind_and_join() -> void:
	if _coop_enet_join_field == null:
		return
	var jp: String = str(_coop_enet_join_field.text).strip_edges()
	if jp == "":
		_show_announcement("ENet join: enter host:port", true)
		return
	CoopExpeditionSessionManager.leave_session()
	var enet_transport := ENetCoopTransport.new()
	if jp.contains(":"):
		var parts: PackedStringArray = jp.split(":")
		if parts.size() >= 2:
			var pt: int = int(str(parts[parts.size() - 1]).strip_edges())
			if pt > 0:
				enet_transport.configure_listen_port(pt)
	CoopExpeditionSessionManager.set_transport(enet_transport)
	var r: Dictionary = CoopExpeditionSessionManager.join_session(jp)
	_show_announcement("ENet bind+join: %s" % str(r), true)


func _coop_debug_restore_loopback_transport() -> void:
	CoopExpeditionSessionManager.leave_session()
	var lb := LocalLoopbackCoopTransport.new()
	CoopExpeditionSessionManager.set_transport(lb)
	_show_announcement("Co-op transport restored to loopback.", true)
