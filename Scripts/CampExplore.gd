# CampExplore.gd
# Walkable Explore Camp scene: WASD/arrows movement, roster NPCs wandering, nearest-NPC talk.
# Entered from camp_menu via "Explore Camp" button; Back/Esc returns to camp menu.

extends Node2D

const CAMP_MENU_PATH: String = "res://Scenes/camp_menu.tscn"
const BOUNDS_MARGIN: float = 40.0
const INTERACT_RANGE: float = 70.0
const PLAYER_SPEED: float = 180.0
const PLAYER_ACCEL: float = 13.5
const PLAYER_FRICTION: float = 24.0
const PLAYER_LEAN_SMOOTH: float = 18.0
const PLAYER_LEAN_VEL_SCALE: float = 0.00032
const PLAYER_LEAN_MAX_RAD: float = 0.068
const PLAYER_BOB_SETTLE_SMOOTH: float = 16.0
const PLAYER_STEP_BOB_HEIGHT: float = 2.0
const PLAYER_STEP_BOB_SPEED: float = 9.0
const PLAYER_MIN_MOVE_SPEED_FOR_BOB: float = 20.0
const TASK_LOG_SCRIPT := preload("res://Scripts/TaskLog.gd")
## Dev-only: when true, F9 dumps direct-conversation + micro-bark diagnostics for the nearest walker (see debug_dump_camp_selection).
const DEBUG_CAMP_SELECTION_DUMP: bool = false
const INTERACT_PROMPT_SLIDE_PX: float = 10.0
const INTERACT_PROMPT_FADE_IN_SEC: float = 0.13
const INTERACT_PROMPT_SLIDE_SEC: float = 0.15
const INTERACT_PROMPT_FADE_OUT_SEC: float = 0.11

var _camp_music_tracks: Array[AudioStream] = []

@onready var player: Node2D = get_node_or_null("Player")
@onready var camp_music: AudioStreamPlayer = get_node_or_null("CampMusic")
@onready var walkers_container: Node2D = get_node_or_null("Walkers")
@onready var background: ColorRect = get_node_or_null("Background")
@onready var time_of_day_overlay: ColorRect = get_node_or_null("TimeOfDayOverlay")
@onready var back_btn: Button = get_node_or_null("UI/BackButton")
@onready var interact_prompt: Label = get_node_or_null("UI/InteractPrompt")
@onready var dialogue_panel: PanelContainer = get_node_or_null("UI/DialoguePanel")
@onready var dialogue_name: Label = get_node_or_null("UI/DialoguePanel/VBox/NameLabel")
@onready var dialogue_portrait: TextureRect = get_node_or_null("UI/DialoguePanel/VBox/HBox/Portrait")
@onready var dialogue_text: Label = get_node_or_null("UI/DialoguePanel/VBox/HBox/TextLabel")
@onready var dialogue_close_btn: Button = get_node_or_null("UI/DialoguePanel/VBox/CloseButton")
@onready var accept_btn: Button = get_node_or_null("UI/DialoguePanel/VBox/ButtonRow/AcceptButton")
@onready var decline_btn: Button = get_node_or_null("UI/DialoguePanel/VBox/ButtonRow/DeclineButton")
@onready var turn_in_btn: Button = get_node_or_null("UI/DialoguePanel/VBox/ButtonRow/TurnInButton")
@onready var ui_layer: CanvasLayer = get_node_or_null("UI")
@onready var rumor_label: Label = get_node_or_null("UI/RumorLabel")
@onready var ambient_speech_bubble: PanelContainer = get_node_or_null("UI/AmbientSpeechBubble")
@onready var ambient_speech_name: Label = get_node_or_null("UI/AmbientSpeechBubble/Margin/VBox/Speaker")
@onready var ambient_speech_text: Label = get_node_or_null("UI/AmbientSpeechBubble/Margin/VBox/Text")

var _player_velocity: Vector2 = Vector2.ZERO
var _player_walk_cycle: float = 0.0
var _player_base_sprite_offset: Vector2 = Vector2.ZERO
var _player_sprite: Sprite2D = null
var _player_sprite_base_scale: Vector2 = Vector2.ONE
var _player_bob_smoothed: float = 0.0
var _player_lean_rad: float = 0.0
var _player_pulse_tween: Tween = null
var _interact_prev_nearest_id: int = 0
var _background_color_base: Color = Color(0.18, 0.22, 0.15, 1.0)
var _camp_bg_breathe_t: float = 0.0
var _camp_ui_pulse_t: float = 0.0

var _task_log: TaskLog = null
@export_enum("auto", "dawn", "day", "night") var debug_time_block_override: String = "auto"
@export_enum("auto", "normal", "hopeful", "tense", "somber") var debug_camp_mood_override: String = "auto"
@export var debug_use_test_camp_roster: bool = false
@export var debug_replace_roster_entirely: bool = true
@export var debug_camp_pacing: bool = false
var _debug_flags_logged_once: bool = false

var _ctx: CampContext
var _bubble_ctrl: CampBubbleController
var _requests: CampRequestController
var _dialogue: CampDialogueController
var _interactions: CampInteractionResolver
var _ambient: CampAmbientDirector
var _spawn: CampSpawnController

var _interact_prompt_base_offset_top: float = 0.0
var _interact_prompt_tween: Tween = null
var _interact_prompt_prev_nonempty: bool = false
var _interact_prompt_prev_line: String = ""


func _ready() -> void:
	_ctx = CampContext.new()
	_requests = CampRequestController.new(self, _ctx)
	_dialogue = CampDialogueController.new(self, _ctx, _requests)
	_bubble_ctrl = CampBubbleController.new(self)
	_bubble_ctrl.bind_nodes(ambient_speech_bubble, ambient_speech_name, ambient_speech_text, rumor_label)
	_dialogue.bind_dialogue_nodes(
		dialogue_panel, dialogue_name, dialogue_portrait, dialogue_text,
		dialogue_close_btn, accept_btn, decline_btn, turn_in_btn, interact_prompt
	)
	_interactions = CampInteractionResolver.new(self, _ctx, _dialogue, _requests)
	_ambient = CampAmbientDirector.new(self, _ctx, _bubble_ctrl, _dialogue)
	_spawn = CampSpawnController.new(self, _ctx, _requests)

	_compute_bounds()
	if not _debug_flags_logged_once and OS.is_debug_build():
		print("DEBUG_CAMP_FLAGS use_test=", debug_use_test_camp_roster, " replace_entirely=", debug_replace_roster_entirely)
		_debug_flags_logged_once = true
	var override: String = str(debug_time_block_override).strip_edges().to_lower()
	if override == "auto":
		_ctx.active_time_block = _pick_random_time_block()
	else:
		if override in ["dawn", "day", "night"]:
			_ctx.active_time_block = override
		else:
			_ctx.active_time_block = "day"
	var mood_override: String = str(debug_camp_mood_override).strip_edges().to_lower()
	if mood_override == "auto":
		_ctx.active_camp_mood = _get_auto_camp_mood()
	else:
		_ctx.active_camp_mood = _ctx.normalize_camp_mood(mood_override)
	_apply_time_of_day_visuals()
	var spawned: Array = _spawn.spawn_player(player)
	player = spawned[0] as Node2D
	_player_sprite = spawned[1] as Sprite2D
	if _player_sprite != null:
		_player_base_sprite_offset = _player_sprite.position
		_player_sprite_base_scale = _player_sprite.scale
	_spawn.gather_camp_zones()
	if CampaignManager:
		CampaignManager.ensure_camp_unit_condition()
		CampaignManager.advance_camp_condition_recovery_on_visit()
		CampaignManager.apply_post_battle_camp_condition()
	_ctx.resolve_visit_theme()
	_ctx.reset_activity_anchor_claims_for_visit()
	walkers_container = _spawn.spawn_walkers(walkers_container, debug_use_test_camp_roster, debug_replace_roster_entirely)
	_connect_ui()
	_camp_music_tracks = DefaultCampMusic.get_default_camp_music_tracks()
	if camp_music and _camp_music_tracks.size() > 0:
		camp_music.finished.connect(_on_camp_music_finished)
		_play_random_camp_music()
	_requests.validate_camp_request_roster()
	_requests.update_request_markers()
	_dialogue.setup_branching_choice_container()
	if interact_prompt:
		_interact_prompt_base_offset_top = interact_prompt.offset_top
		interact_prompt.visible = false
		interact_prompt.modulate = Color(1, 1, 1, 1)
		interact_prompt.offset_top = _interact_prompt_base_offset_top
	if dialogue_panel:
		dialogue_panel.visible = false
		dialogue_panel.modulate = Color(1, 1, 1, 1)
		dialogue_panel.scale = Vector2.ONE
		dialogue_panel.pivot_offset = Vector2.ZERO
	_dialogue.hide_request_buttons()
	_dialogue.reset_pair_scene_visit_flags()
	_dialogue.reset_direct_conversation_visit_flags()
	_ambient.reset_visit_state()
	if rumor_label:
		rumor_label.visible = false
		rumor_label.text = ""
	if CampaignManager:
		CampaignManager.ensure_camp_memory()
		CampaignManager.increment_camp_visit()
	var now_time: float = Time.get_ticks_msec() / 1000.0
	_dialogue.bind_pacing_ambient(_ambient)
	_ambient.set_debug_pacing(debug_camp_pacing)
	_ambient.prime_attempt_timers_after_ready(now_time)


func _pick_random_time_block() -> String:
	var r: float = randf()
	if r < 0.2:
		return "dawn"
	if r < 0.7:
		return "day"
	return "night"


func _apply_time_of_day_visuals() -> void:
	var tb: String = str(_ctx.active_time_block).strip_edges().to_lower()
	var mood: String = _ctx.normalize_camp_mood(_ctx.active_camp_mood)
	if background != null:
		var bg_col: Color
		match tb:
			"dawn":
				bg_col = Color(0.22, 0.20, 0.16, 1.0)
			"night":
				bg_col = Color(0.08, 0.09, 0.14, 1.0)
			_:
				bg_col = Color(0.18, 0.22, 0.15, 1.0)
		match mood:
			"hopeful":
				bg_col = bg_col.lerp(Color(0.24, 0.24, 0.20, 1.0), 0.12)
			"tense":
				bg_col = bg_col.lerp(Color(0.12, 0.14, 0.18, 1.0), 0.12)
			"somber":
				bg_col = bg_col.lerp(Color(0.14, 0.14, 0.15, 1.0), 0.16)
			_:
				pass
		_background_color_base = bg_col
		background.color = bg_col
	if time_of_day_overlay != null:
		var target: Color
		match tb:
			"dawn":
				target = Color(0.95, 0.82, 0.70, 0.14)
			"night":
				target = Color(0.15, 0.15, 0.28, 0.24)
			_:
				target = Color(1.0, 1.0, 1.0, 0.03)
		match mood:
			"hopeful":
				target = target.lerp(Color(1.00, 0.92, 0.78, target.a + 0.02), 0.35)
			"tense":
				target = target.lerp(Color(0.78, 0.86, 1.00, target.a + 0.03), 0.30)
			"somber":
				target = target.lerp(Color(0.74, 0.74, 0.78, target.a + 0.05), 0.40)
			_:
				pass
		time_of_day_overlay.color = Color(target.r, target.g, target.b, 0.0)
		var tween: Tween = create_tween()
		tween.tween_property(time_of_day_overlay, "color", target, 0.28)


func _get_auto_camp_mood() -> String:
	if CampaignManager:
		var mood: String = _ctx.normalize_camp_mood(CampaignManager.resolve_auto_camp_mood())
		CampaignManager.set_current_camp_mood(mood)
		return mood
	return "normal"


func _compute_bounds() -> void:
	var vp: Viewport = get_viewport()
	if vp:
		var size: Vector2 = vp.get_visible_rect().size
		_ctx.walk_min = Vector2(BOUNDS_MARGIN, BOUNDS_MARGIN)
		_ctx.walk_max = size - Vector2(BOUNDS_MARGIN, BOUNDS_MARGIN)


func _connect_ui() -> void:
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if dialogue_close_btn:
		dialogue_close_btn.pressed.connect(_dialogue.on_dialogue_close_pressed)
	if accept_btn:
		accept_btn.pressed.connect(_on_accept_pressed)
	if decline_btn:
		decline_btn.pressed.connect(_on_decline_pressed)
	if turn_in_btn:
		turn_in_btn.pressed.connect(_on_turn_in_pressed)


func _input(event: InputEvent) -> void:
	if _task_log != null and is_instance_valid(_task_log) and _task_log.visible:
		return
	if _dialogue.dialogue_active:
		if event.is_action_pressed("camp_cancel") or event.is_action_pressed("ui_cancel"):
			if _dialogue.pair_scene_active:
				_dialogue.advance_pair_scene()
			else:
				_dialogue.close_dialogue()
		return
	if event.is_action_pressed("camp_cancel") or event.is_action_pressed("ui_cancel"):
		_return_to_camp()
	if event.is_action_pressed("camp_interact") or event.is_action_pressed("ui_accept"):
		_try_interact()
	if event is InputEventKey and event.pressed and not event.echo:
		var wants_task_log: bool = false
		if InputMap.has_action("ui_task_log") and event.is_action_pressed("ui_task_log"):
			wants_task_log = true
		elif InputMap.has_action("camp_task_log") and event.is_action_pressed("camp_task_log"):
			wants_task_log = true
		elif event.physical_keycode == KEY_J or event.keycode == KEY_J:
			wants_task_log = true
		if wants_task_log:
			_toggle_task_log()
	if DEBUG_CAMP_SELECTION_DUMP and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9 or event.physical_keycode == KEY_F9:
			debug_dump_camp_selection_for_nearest()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_click_interact(event.position)


func _process(delta: float) -> void:
	_bubble_ctrl.update_ambient_bubble_position(delta)
	if _dialogue.dialogue_active:
		_bubble_ctrl.hide_ambient_bubble()
		return
	_handle_movement(delta)
	_interact_arrival_check()
	_update_interact_prompt()
	_ambient.update_rumor(delta)
	_apply_camp_atmosphere_idle(delta)


func _handle_movement(delta: float) -> void:
	if player == null:
		return
	var dir: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("camp_right"):
		dir.x += 1.0
	if Input.is_action_pressed("camp_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("camp_down"):
		dir.y += 1.0
	if Input.is_action_pressed("camp_up"):
		dir.y -= 1.0
	if dir.length_squared() > 0.0:
		dir = dir.normalized()
		var desired_velocity: Vector2 = dir * PLAYER_SPEED
		_player_velocity = _player_velocity.lerp(desired_velocity, clamp(PLAYER_ACCEL * delta, 0.0, 1.0))
	else:
		_player_velocity = _player_velocity.lerp(Vector2.ZERO, clamp(PLAYER_FRICTION * delta, 0.0, 1.0))
	player.position += _player_velocity * delta
	player.position.x = clampf(player.position.x, _ctx.walk_min.x, _ctx.walk_max.x)
	player.position.y = clampf(player.position.y, _ctx.walk_min.y, _ctx.walk_max.y)
	var speed_now: float = _player_velocity.length()
	var bob_target: float = 0.0
	if speed_now > PLAYER_MIN_MOVE_SPEED_FOR_BOB:
		_player_walk_cycle += PLAYER_STEP_BOB_SPEED * delta
		bob_target = sin(_player_walk_cycle) * PLAYER_STEP_BOB_HEIGHT
	else:
		_player_walk_cycle = 0.0
		bob_target = 0.0
	_player_bob_smoothed = lerpf(_player_bob_smoothed, bob_target, clampf(PLAYER_BOB_SETTLE_SMOOTH * delta, 0.0, 1.0))
	var lean_target: float = clampf(_player_velocity.x * PLAYER_LEAN_VEL_SCALE, -PLAYER_LEAN_MAX_RAD, PLAYER_LEAN_MAX_RAD)
	_player_lean_rad = lerpf(_player_lean_rad, lean_target, clampf(PLAYER_LEAN_SMOOTH * delta, 0.0, 1.0))
	if _player_sprite != null:
		_player_sprite.rotation = _player_lean_rad
		_player_sprite.position = _player_base_sprite_offset + Vector2(0, _player_bob_smoothed)


func _get_nearest_walker_in_range() -> Node:
	if player == null:
		return null
	var best: Node = null
	var best_d: float = INTERACT_RANGE * INTERACT_RANGE
	for w in _ctx.walker_nodes:
		if not is_instance_valid(w):
			continue
		var d_sq: float = player.global_position.distance_squared_to(w.global_position)
		if d_sq < best_d:
			best_d = d_sq
			best = w
	return best


func _interact_arrival_check() -> void:
	var nearest: Node = _get_nearest_walker_in_range()
	var eligible_pair: Dictionary = _dialogue.get_eligible_pair_scene()
	var prompt_line: String = _interactions.get_interact_prompt_primary_line(nearest, eligible_pair)
	var cur_id: int = 0
	if nearest != null and is_instance_valid(nearest) and prompt_line != "":
		cur_id = nearest.get_instance_id()
	if cur_id == 0:
		_interact_prev_nearest_id = 0
		return
	if cur_id == _interact_prev_nearest_id:
		return
	_interact_prev_nearest_id = cur_id
	_fire_interact_arrival_feedback(nearest, eligible_pair)


func _kill_player_pulse_tween() -> void:
	if _player_pulse_tween != null and is_instance_valid(_player_pulse_tween):
		_player_pulse_tween.kill()
	_player_pulse_tween = null


func _fire_interact_arrival_feedback(walker: Node, eligible_pair: Dictionary) -> void:
	# Pair listen: overhear prompt is not tied to the geometrically nearest walker; skip marker ping only there.
	var pair_listen: bool = _interactions.is_pair_listen_primary_prompt(walker, eligible_pair)
	if walker is CampRosterWalker and not pair_listen:
		(walker as CampRosterWalker).play_interact_proximity_ping()
	if _player_sprite != null:
		_kill_player_pulse_tween()
		var bs: Vector2 = _player_sprite_base_scale
		_player_pulse_tween = create_tween()
		_player_pulse_tween.tween_property(_player_sprite, "scale", bs * 1.07, 0.07)
		_player_pulse_tween.tween_property(_player_sprite, "scale", bs, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _apply_camp_atmosphere_idle(delta: float) -> void:
	if background != null:
		_camp_bg_breathe_t += delta
		var f: float = 1.0 + sin(_camp_bg_breathe_t * 0.19) * 0.0065
		var b: Color = _background_color_base
		background.color = Color(
			clampf(b.r * f, 0.0, 1.0),
			clampf(b.g * f, 0.0, 1.0),
			clampf(b.b * f, 0.0, 1.0),
			1.0
		)
	if back_btn != null:
		_camp_ui_pulse_t += delta
		var w: float = 0.992 + 0.008 * sin(_camp_ui_pulse_t * 0.55)
		back_btn.modulate = Color(w, w * 1.01, w * 1.02, 1.0)


func _get_nearest_walker_near_point(world_pos: Vector2, max_dist: float) -> Node:
	var best: Node = null
	var best_d_sq: float = INF
	var max_d_sq: float = max_dist * max_dist
	for w in _ctx.walker_nodes:
		if not is_instance_valid(w) or not (w is CampRosterWalker):
			continue
		var d_sq: float = world_pos.distance_squared_to(w.global_position)
		if d_sq > max_d_sq:
			continue
		if d_sq < best_d_sq:
			best_d_sq = d_sq
			best = w
	return best


func _gather_walker_names_for_debug() -> Array:
	var out: Array = []
	for w in _ctx.walker_nodes:
		if w is CampRosterWalker:
			out.append((w as CampRosterWalker).unit_name)
	return out


## Dev-only: print why CampConversationDB / micro-barks resolve as they do for this unit. Requires DEBUG_CAMP_SELECTION_DUMP := true, or warns once.
func debug_dump_camp_selection(unit_name: String) -> void:
	if not DEBUG_CAMP_SELECTION_DUMP:
		push_warning("CampExplore: set DEBUG_CAMP_SELECTION_DUMP := true to enable camp selection dumps.")
		return
	var un: String = str(unit_name).strip_edges()
	if un.is_empty():
		print("[CampSelectionDebug] empty unit_name")
		return
	var ctx: Dictionary = _ctx.build_camp_context_dict()
	var walkers: Array = _gather_walker_names_for_debug()
	var snap: Dictionary = _dialogue.get_direct_conversation_visit_snapshot()
	var drep: Dictionary = CampConversationDB.build_direct_conversation_debug_report(un, ctx, walkers, snap)
	print("========== CampSelectionDebug direct conversation: ", un, " ==========")
	print("  context: time_block=", drep.get("context_time_block"), " visit_theme=", drep.get("context_visit_theme"), " progress_level=", drep.get("context_progress_level"))
	print("  eligible_count=", drep.get("eligible_count"))
	var win: Dictionary = drep.get("winner", {}) as Dictionary
	if not win.is_empty():
		print("  WINNER id=", win.get("id"), " score=", drep.get("winner_score"), " (tie-break: higher score, then lexicographically smaller id if within 0.001)")
	else:
		print("  WINNER: <none>")
	var ru: Variant = drep.get("runners_up", [])
	if ru is Array:
		for item in ru as Array:
			if item is Dictionary:
				var it: Dictionary = item
				print("  runner_up id=", it.get("id"), " score=", it.get("score"))
	var bl: Variant = drep.get("blocked_high_priority", [])
	if bl is Array:
		print("  blocked (this unit, by priority):")
		for b in bl as Array:
			if b is Dictionary:
				print("    - id=", (b as Dictionary).get("id"), " prio=", (b as Dictionary).get("priority"), " :: ", (b as Dictionary).get("reason"))
	var now: float = Time.get_ticks_msec() / 1000.0
	var mrep: Dictionary = _ambient.debug_build_micro_bark_report(now, un)
	print("========== CampSelectionDebug micro-bark (global pool; blocked filtered to unit) ==========")
	print("  context: time_block=", mrep.get("context_time_block"), " visit_theme=", mrep.get("context_visit_theme"), " progress_level=", mrep.get("context_progress_level"))
	print("  eligible_count=", mrep.get("eligible_count"))
	var mw: Dictionary = mrep.get("winner", {}) as Dictionary
	if not mw.is_empty():
		print("  WINNER id=", mw.get("id"), " score=", mw.get("score"), " pair=", mw.get("speaker"), " -> ", mw.get("listener"))
	else:
		print("  WINNER: <none>")
	var mru: Variant = mrep.get("runners_up", [])
	if mru is Array:
		for item2 in mru as Array:
			if item2 is Dictionary:
				var it2: Dictionary = item2
				print("  runner_up id=", it2.get("id"), " score=", it2.get("score"))
	var mb: Variant = mrep.get("blocked_involving_unit", [])
	if mb is Array and (mb as Array).size() > 0:
		print("  blocked (entries involving ", un, ", by priority):")
		for b2 in mb as Array:
			if b2 is Dictionary:
				print("    - id=", (b2 as Dictionary).get("id"), " prio=", (b2 as Dictionary).get("priority"), " :: ", (b2 as Dictionary).get("reason"))
	print("========== CampSelectionDebug end ==========")


func debug_dump_camp_selection_for_nearest() -> void:
	if not DEBUG_CAMP_SELECTION_DUMP:
		push_warning("CampExplore: set DEBUG_CAMP_SELECTION_DUMP := true to enable camp selection dumps.")
		return
	var n: Node = _get_nearest_walker_in_range()
	if n == null or not (n is CampRosterWalker):
		print("[CampSelectionDebug] no CampRosterWalker within interact range")
		return
	debug_dump_camp_selection((n as CampRosterWalker).unit_name)


func _kill_interact_prompt_tween() -> void:
	if _interact_prompt_tween != null and is_instance_valid(_interact_prompt_tween):
		_interact_prompt_tween.kill()
	_interact_prompt_tween = null


func _reset_interact_prompt_visual() -> void:
	if interact_prompt == null:
		return
	interact_prompt.modulate = Color(1, 1, 1, 1)
	interact_prompt.offset_top = _interact_prompt_base_offset_top


func _update_interact_prompt() -> void:
	if interact_prompt == null:
		return
	if _dialogue.dialogue_active:
		_kill_interact_prompt_tween()
		interact_prompt.visible = false
		_reset_interact_prompt_visual()
		_interact_prompt_prev_nonempty = false
		_interact_prompt_prev_line = ""
		return
	var nearest: Node = _get_nearest_walker_in_range()
	var eligible_pair: Dictionary = _dialogue.get_eligible_pair_scene()
	var prompt_line: String = _interactions.get_interact_prompt_primary_line(nearest, eligible_pair)
	var want_show: bool = prompt_line != ""
	if want_show:
		interact_prompt.text = prompt_line
		if not _interact_prompt_prev_nonempty:
			_kill_interact_prompt_tween()
			interact_prompt.visible = true
			interact_prompt.modulate.a = 0.0
			interact_prompt.offset_top = _interact_prompt_base_offset_top + INTERACT_PROMPT_SLIDE_PX
			_interact_prompt_tween = create_tween()
			_interact_prompt_tween.set_parallel(true)
			_interact_prompt_tween.tween_property(interact_prompt, "modulate:a", 1.0, INTERACT_PROMPT_FADE_IN_SEC)
			_interact_prompt_tween.tween_property(interact_prompt, "offset_top", _interact_prompt_base_offset_top, INTERACT_PROMPT_SLIDE_SEC)
		elif prompt_line != _interact_prompt_prev_line:
			_kill_interact_prompt_tween()
			_interact_prompt_tween = create_tween()
			_interact_prompt_tween.tween_property(interact_prompt, "modulate", Color(1.14, 1.06, 0.9, 1.0), 0.06)
			_interact_prompt_tween.tween_property(interact_prompt, "modulate", Color(1, 1, 1, 1), 0.12)
		_interact_prompt_prev_nonempty = true
		_interact_prompt_prev_line = prompt_line
	else:
		if _interact_prompt_prev_nonempty and interact_prompt.visible:
			_kill_interact_prompt_tween()
			_interact_prompt_tween = create_tween()
			_interact_prompt_tween.set_parallel(true)
			_interact_prompt_tween.tween_property(interact_prompt, "modulate:a", 0.0, INTERACT_PROMPT_FADE_OUT_SEC)
			_interact_prompt_tween.tween_property(interact_prompt, "offset_top", _interact_prompt_base_offset_top + INTERACT_PROMPT_SLIDE_PX, INTERACT_PROMPT_FADE_OUT_SEC)
			_interact_prompt_tween.chain().tween_callback(func() -> void:
				interact_prompt.visible = false
				_reset_interact_prompt_visual()
			)
		elif not interact_prompt.visible:
			_reset_interact_prompt_visual()
		_interact_prompt_prev_nonempty = false
		_interact_prompt_prev_line = ""


func _try_interact() -> void:
	if _dialogue.pair_scene_active:
		return
	var eligible_pair: Dictionary = _dialogue.get_eligible_pair_scene()
	var nearest: Node = _get_nearest_walker_in_range()
	if nearest != null and _interactions.would_single_walker_priority(nearest):
		_interactions.open_dialogue(nearest)
		return
	if not eligible_pair.is_empty():
		_dialogue.start_pair_scene(eligible_pair)
		return
	if nearest != null:
		_interactions.open_dialogue(nearest)


func _try_click_interact(_screen_pos: Vector2) -> void:
	if _dialogue.pair_scene_active:
		return
	var cam: Camera2D = get_viewport().get_camera_2d()
	var world_pos: Vector2
	if cam:
		world_pos = cam.get_global_mouse_position()
	else:
		world_pos = get_viewport().get_mouse_position()
	var clicked: Node = _get_nearest_walker_near_point(world_pos, INTERACT_RANGE)
	var eligible_pair: Dictionary = _dialogue.get_eligible_pair_scene()
	if clicked != null and _interactions.would_single_walker_priority(clicked):
		_interactions.open_dialogue(clicked)
		return
	if not eligible_pair.is_empty():
		_dialogue.start_pair_scene(eligible_pair)
		return
	if clicked != null:
		_interactions.open_dialogue(clicked)


func _on_accept_pressed() -> void:
	if _requests.pending_offer.is_empty() or not CampaignManager or _dialogue.current_walker == null:
		_dialogue.close_dialogue()
		return
	_requests.on_accept_pressed(_dialogue.current_walker, dialogue_text)
	if accept_btn:
		accept_btn.visible = false
	if decline_btn:
		decline_btn.visible = false
	if turn_in_btn:
		turn_in_btn.visible = false
	if dialogue_close_btn:
		dialogue_close_btn.visible = true
	_dialogue.refresh_dialogue_action_emphasis()


func _on_decline_pressed() -> void:
	if _dialogue.current_walker == null:
		_requests.pending_offer = {}
		_dialogue.close_dialogue()
		return
	_requests.on_decline_pressed(_dialogue.current_walker, dialogue_text)
	if accept_btn:
		accept_btn.visible = false
	if decline_btn:
		decline_btn.visible = false
	if turn_in_btn:
		turn_in_btn.visible = false
	if dialogue_close_btn:
		dialogue_close_btn.visible = true
	_dialogue.refresh_dialogue_action_emphasis()


func _on_turn_in_pressed() -> void:
	if not _requests.apply_turn_in(_dialogue.current_walker, dialogue_text):
		_dialogue.close_dialogue()
		return
	if turn_in_btn:
		turn_in_btn.visible = false
	if dialogue_close_btn:
		dialogue_close_btn.visible = true
	_dialogue.refresh_dialogue_action_emphasis()


func _on_back_pressed() -> void:
	_return_to_camp()


func _return_to_camp() -> void:
	SceneTransition.change_scene_to_file(CAMP_MENU_PATH)


func _ensure_task_log() -> void:
	if _task_log != null and is_instance_valid(_task_log):
		return
	_task_log = TASK_LOG_SCRIPT.new()
	if ui_layer != null:
		ui_layer.add_child(_task_log)
	else:
		add_child(_task_log)
	if _task_log is Control:
		var c := _task_log as Control
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.offset_left = 0
		c.offset_top = 0
		c.offset_right = 0
		c.offset_bottom = 0
		var vp := get_viewport()
		if vp:
			c.size = vp.get_visible_rect().size
		c.show()


func _toggle_task_log() -> void:
	_ensure_task_log()
	if _task_log == null:
		return
	_task_log.visible = true
	if _task_log is Control:
		(_task_log as Control).show()
	_task_log.open_and_refresh()


func _play_random_camp_music() -> void:
	if camp_music == null or _camp_music_tracks.is_empty():
		return
	var random_track: AudioStream = _camp_music_tracks[randi() % _camp_music_tracks.size()]
	if _camp_music_tracks.size() > 1 and camp_music.stream == random_track:
		_play_random_camp_music()
		return
	camp_music.stream = random_track
	camp_music.play()


func _on_camp_music_finished() -> void:
	_play_random_camp_music()
