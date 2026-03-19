# CampExplore.gd
# Walkable Explore Camp scene: WASD/arrows movement, roster NPCs wandering, nearest-NPC talk.
# Entered from camp_menu via "Explore Camp" button; Back/Esc returns to camp menu.

extends Node2D

const CAMP_MENU_PATH: String = "res://Scenes/camp_menu.tscn"
const WALKER_SCENE := preload("res://Scenes/CampRosterWalker.tscn")
const INTERACT_RANGE: float = 70.0
const PLAYER_SPEED: float = 180.0
const PLAYER_ACCEL: float = 10.0
const PLAYER_FRICTION: float = 18.0
const CAMP_SPRITE_SCALE: Vector2 = Vector2(0.22, 0.22)
const PLAYER_STEP_BOB_HEIGHT: float = 2.0
const PLAYER_STEP_BOB_SPEED: float = 9.0
const PLAYER_MIN_MOVE_SPEED_FOR_BOB: float = 20.0
const BOUNDS_MARGIN: float = 40.0

const TASK_LOG_SCRIPT := preload("res://Scripts/TaskLog.gd")
const CAMP_BEHAVIOR_DB = preload("res://Scripts/Narrative/CampBehaviorDB.gd")
const CAMP_ROUTINE_DB = preload("res://Scripts/Narrative/CampRoutineDB.gd")
const CAMP_RUMOR_DB = preload("res://Scripts/Narrative/CampRumorDB.gd")
const CAMP_MICRO_BARK_DB = preload("res://Scripts/Narrative/CampMicroBarkDB.gd")
const CAMP_AMBIENT_CHATTER_DB = preload("res://Scripts/Narrative/CampAmbientChatterDB.gd")
const CAMP_AMBIENT_SOCIAL_DB = preload("res://Scripts/Narrative/CampAmbientSocialDB.gd")
const CAMP_PAIR_SCENE_TRIGGER_DB = preload("res://Scripts/Narrative/CampPairSceneTriggerDB.gd")
const DEBUG_TEST_CAMP_UNIT_NAMES: Array[String] = [
	"Kaelen",
	"Celia",
	"Sorrel",
	"Tariq",
	"Tamsin Reed",
	"Branik",
	"Nyx",
	"Hest \"Sparks\"",
	"Liora",
	"Brother Alden",
	"Garrick Vale",
	"Sabine Varr",
]
const DEBUG_TEST_CAMP_UNIT_RESOURCE_PATHS: Dictionary = {
	"Kaelen": ["res://Resources/Units/PlayableRoster/02_Kaelen.tres"],
	"Branik": ["res://Resources/Units/PlayableRoster/03_Branik.tres"],
	"Liora": ["res://Resources/Units/PlayableRoster/04_Liora.tres"],
	"Nyx": ["res://Resources/Units/PlayableRoster/05_Nyx.tres"],
	"Sorrel": ["res://Resources/Units/PlayableRoster/06_Sorrel.tres"],
	"Celia": ["res://Resources/Units/PlayableRoster/08_Celia.tres"],
	"Tariq": ["res://Resources/Units/PlayableRoster/11_Tariq.tres"],
	"Tamsin Reed": ["res://Resources/Units/PlayableRoster/14_Tamsin_Reed.tres"],
	"Hest \"Sparks\"": ["res://Resources/Units/PlayableRoster/15_Hest_Sparks.tres"],
	"Brother Alden": ["res://Resources/Units/PlayableRoster/16_Brother_Alden.tres"],
	"Garrick Vale": ["res://Resources/Units/PlayableRoster/18_Garrick_Vale.tres"],
	"Sabine Varr": ["res://Resources/Units/PlayableRoster/19_Sabine_Varr.tres"],
}

# Default camp music from shared source (DefaultCampMusic); set in _ready().
var _camp_music_tracks: Array[AudioStream] = []

# Walk area in world coordinates (set from viewport or fixed rect).
var _walk_min: Vector2 = Vector2(80, 80)
var _walk_max: Vector2 = Vector2(720, 520)

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

var _dialogue_active: bool = false
var _walker_nodes: Array[Node] = []
var _offer_giver_name: String = ""
var _offer_is_personal: bool = false
var _pending_offer: Dictionary = {}
var _current_walker: Node = null

# Branching "check on someone" state (compact; one step only).
var _branching_active: bool = false
var _branching_data: Dictionary = {}
var _branching_choices: Array = []
var _branching_giver: String = ""
var _choice_container: HBoxContainer = null
var _pending_lore_id: String = ""
var _pending_pair_scene_id: String = ""

var _task_log: TaskLog = null
var _camp_zones: Array = []
@export_enum("auto", "dawn", "day", "night") var debug_time_block_override: String = "auto"
@export_enum("auto", "normal", "hopeful", "tense", "somber") var debug_camp_mood_override: String = "auto"
@export var debug_use_test_camp_roster: bool = false
@export var debug_replace_roster_entirely: bool = true
var _active_time_block: String = "day"
var _active_camp_mood: String = "normal"

var _rumor_shown_this_visit: Dictionary = {}
var _micro_bark_shown_this_visit: Dictionary = {}
var _rumor_hide_at: float = 0.0
var _rumor_cooldown_until: float = 0.0
const RUMOR_OVERHEAR_RADIUS: float = 160.0
const RUMOR_DISPLAY_DURATION: float = 3.6
const RUMOR_COOLDOWN: float = 2.3
const RUMOR_NEAR_ZONE_MARGIN: float = 24.0
const RUMOR_NEARBY_UNITS_RADIUS: float = 140.0
const PAIR_LISTEN_RADIUS: float = 120.0
const CHATTER_ATTEMPT_INTERVAL_MIN: float = 2.6
const CHATTER_ATTEMPT_INTERVAL_MAX: float = 4.4
const CHATTER_LINE_DURATION: float = 2.6
const CHATTER_MEETUP_TIMEOUT: float = 4.8
const CHATTER_SOCIAL_SETTLE_BEAT: float = 0.06
const SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MIN: float = 3.4
const SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MAX: float = 5.8
const SPONTANEOUS_SOCIAL_LINE_DURATION: float = 2.2
const SPONTANEOUS_SOCIAL_COOLDOWN: float = 1.2
const SPONTANEOUS_SOCIAL_FOLLOW_HOLD_MIN: float = 0.65
const SPONTANEOUS_SOCIAL_FOLLOW_HOLD_MAX: float = 1.25
const SPONTANEOUS_SOCIAL_MEETUP_TIMEOUT: float = 4.8
const SPONTANEOUS_SOCIAL_SETTLE_BEAT: float = 0.05
const SPONTANEOUS_SOCIAL_FORMATION_RADIUS: float = 34.0
const SPONTANEOUS_SOCIAL_OBSERVER_RADIUS: float = 132.0
const SPONTANEOUS_SOCIAL_MAX_OBSERVERS: int = 2
const CHATTER_SOCIAL_PAIR_OFFSET: float = 16.0
const SPONTANEOUS_SOCIAL_PAIR_OFFSET: float = 18.0
const AMBIENT_RECENT_SPEAKER_MAX: int = 4
const AMBIENT_RECENT_EVENT_MAX: int = 6
const AMBIENT_RECENT_SPEAKER_PENALTY: float = 1.1
const AMBIENT_RECENT_EVENT_PENALTY: float = 1.7
const AMBIENT_TEXT_BONUS_CHAR_STEP: float = 26.0
const AMBIENT_TEXT_BONUS_PER_STEP: float = 0.22
const AMBIENT_LINE_DURATION_MIN: float = 1.8
const AMBIENT_LINE_DURATION_MAX: float = 6.2
const AMBIENT_BUBBLE_WORLD_Y_OFFSET: float = 54.0

# Phase-1 trigger pair scenes: line-by-line playback, once_per_visit per camp.
var _pair_scene_active: bool = false
var _pair_scene_lines: Array = []
var _pair_scene_index: int = 0
var _pair_scene_data: Dictionary = {}
var _pair_scene_walker_a: Node = null
var _pair_scene_walker_b: Node = null
var _pair_scenes_shown_this_visit: Dictionary = {}
var _chatter_active: bool = false
var _chatter_lines: Array = []
var _chatter_index: int = 0
var _chatter_walker_a: Node = null
var _chatter_walker_b: Node = null
var _chatter_current_until: float = 0.0
var _chatter_shown_this_visit: Dictionary = {}
var _chatter_next_attempt_time: float = 0.0
var _chatter_entry: Dictionary = {}
var _chatter_meetup_started_at: float = 0.0
var _chatter_social_settle_until: float = 0.0
var _chatter_familiarity_awarded_this_visit: Dictionary = {}
var _spontaneous_social_active: bool = false
var _spontaneous_social_entry: Dictionary = {}
var _spontaneous_social_participants: Array = []
var _spontaneous_social_speaker: CampRosterWalker = null
var _spontaneous_social_lines: Array = []
var _spontaneous_social_index: int = 0
var _spontaneous_social_current_until: float = 0.0
var _spontaneous_social_next_attempt_time: float = 0.0
var _spontaneous_social_meetup_started_at: float = 0.0
var _spontaneous_social_settle_until: float = 0.0
var _spontaneous_social_shown_this_visit: Dictionary = {}
var _ambient_line_last_variant_by_event: Dictionary = {}
var _ambient_recent_speakers: Array[String] = []
var _ambient_recent_event_keys: Array[String] = []
var _social_hold_walkers: Array = []
var _social_hold_release_at: float = 0.0
var _ambient_bubble_speaker: CampRosterWalker = null
var _debug_flags_logged_once: bool = false
var _debug_spawn_count_logged_once: bool = false

func _ready() -> void:
	_compute_bounds()
	if not _debug_flags_logged_once:
		print("DEBUG_CAMP_FLAGS use_test=", debug_use_test_camp_roster, " replace_entirely=", debug_replace_roster_entirely)
		_debug_flags_logged_once = true
	var override: String = str(debug_time_block_override).strip_edges().to_lower()
	if override == "auto":
		_active_time_block = _pick_random_time_block()
	else:
		if override in ["dawn", "day", "night"]:
			_active_time_block = override
		else:
			_active_time_block = "day"
	var mood_override: String = str(debug_camp_mood_override).strip_edges().to_lower()
	if mood_override == "auto":
		_active_camp_mood = _get_auto_camp_mood()
	else:
		_active_camp_mood = _normalize_camp_mood(mood_override)
	_apply_time_of_day_visuals()
	_spawn_player()
	if player != null and _player_sprite == null:
		_player_sprite = player.get_node_or_null("Sprite2D")
		if _player_sprite != null:
			_player_base_sprite_offset = _player_sprite.position
	_gather_camp_zones()
	_spawn_walkers()
	_connect_ui()
	_camp_music_tracks = DefaultCampMusic.get_default_camp_music_tracks()
	if camp_music and _camp_music_tracks.size() > 0:
		camp_music.finished.connect(_on_camp_music_finished)
		_play_random_camp_music()
	_validate_camp_request_roster()
	_update_request_markers()
	_setup_branching_choice_container()
	if interact_prompt:
		interact_prompt.visible = false
	if dialogue_panel:
		dialogue_panel.visible = false
	_hide_request_buttons()
	_rumor_shown_this_visit.clear()
	_micro_bark_shown_this_visit.clear()
	_pair_scenes_shown_this_visit.clear()
	_chatter_shown_this_visit.clear()
	_chatter_familiarity_awarded_this_visit.clear()
	_spontaneous_social_shown_this_visit.clear()
	_ambient_line_last_variant_by_event.clear()
	_chatter_active = false
	_chatter_meetup_started_at = 0.0
	_chatter_social_settle_until = 0.0
	_spontaneous_social_active = false
	_spontaneous_social_entry = {}
	_spontaneous_social_participants.clear()
	_spontaneous_social_speaker = null
	_spontaneous_social_lines.clear()
	_spontaneous_social_index = 0
	_spontaneous_social_current_until = 0.0
	_spontaneous_social_meetup_started_at = 0.0
	_spontaneous_social_settle_until = 0.0
	_ambient_recent_speakers.clear()
	_ambient_recent_event_keys.clear()
	_release_post_social_hold()
	_hide_ambient_bubble()
	if CampaignManager:
		CampaignManager.ensure_camp_unit_condition()
		CampaignManager.advance_camp_condition_recovery_on_visit()
		CampaignManager.apply_post_battle_camp_condition()
		CampaignManager.ensure_camp_memory()
		CampaignManager.increment_camp_visit()
	var now_time: float = Time.get_ticks_msec() / 1000.0
	_chatter_next_attempt_time = now_time + randf_range(CHATTER_ATTEMPT_INTERVAL_MIN, CHATTER_ATTEMPT_INTERVAL_MAX)
	_spontaneous_social_next_attempt_time = now_time + randf_range(SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MIN, SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MAX)
	if rumor_label:
		rumor_label.visible = false
		rumor_label.text = ""

func _pick_random_time_block() -> String:
	var r: float = randf()
	if r < 0.2:
		return "dawn"
	if r < 0.7:
		return "day"
	return "night"

func _apply_time_of_day_visuals() -> void:
	var tb: String = str(_active_time_block).strip_edges().to_lower()
	var mood: String = _normalize_camp_mood(_active_camp_mood)
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

func _gather_camp_zones() -> void:
	_camp_zones.clear()
	var nodes: Array = get_tree().get_nodes_in_group("camp_behavior_zone")
	for n in nodes:
		_camp_zones.append(n)

func _build_camp_context() -> Dictionary:
	var ctx: Dictionary = {}
	var tb: String = str(_active_time_block).strip_edges().to_lower()
	if tb == "" or tb not in ["dawn", "day", "night"]:
		tb = "day"
	var mood: String = _normalize_camp_mood(_active_camp_mood)
	var progress_level: int = 0
	var story_flags: Dictionary = {}
	if CampaignManager:
		progress_level = maxi(0, int(CampaignManager.camp_request_progress_level))
		var flags_v: Variant = CampaignManager.encounter_flags
		if flags_v is Dictionary:
			for key_v in (flags_v as Dictionary).keys():
				var k: String = str(key_v).strip_edges()
				if k == "":
					continue
				if bool((flags_v as Dictionary).get(key_v, false)):
					story_flags[k] = true
	ctx["time_block"] = tb
	ctx["camp_mood"] = mood
	ctx["progress_level"] = progress_level
	ctx["story_flags"] = story_flags
	return ctx

func _normalize_camp_mood(value: String) -> String:
	var mood: String = str(value).strip_edges().to_lower()
	if mood in ["normal", "hopeful", "tense", "somber"]:
		return mood
	return "normal"

func _get_auto_camp_mood() -> String:
	if CampaignManager:
		var mood: String = _normalize_camp_mood(CampaignManager.resolve_auto_camp_mood())
		CampaignManager.set_current_camp_mood(mood)
		return mood
	return "normal"

func _compute_bounds() -> void:
	var vp: Viewport = get_viewport()
	if vp:
		var size: Vector2 = vp.get_visible_rect().size
		_walk_min = Vector2(BOUNDS_MARGIN, BOUNDS_MARGIN)
		_walk_max = size - Vector2(BOUNDS_MARGIN, BOUNDS_MARGIN)

func _spawn_player() -> void:
	if player == null:
		player = Node2D.new()
		player.name = "Player"
		add_child(player)
	var sprite: Sprite2D = player.get_node_or_null("Sprite2D")
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		player.add_child(sprite)
	# Use roster leader's battle_sprite if available
	var roster: Array = CampaignManager.player_roster if CampaignManager else []
	if roster.size() > 0:
		var first: Dictionary = roster[0]
		var tex: Variant = first.get("battle_sprite", null)
		if tex is Texture2D:
			sprite.texture = tex
		else:
			sprite.texture = load("res://icon.svg") as Texture2D
	else:
		sprite.texture = load("res://icon.svg") as Texture2D
	sprite.scale = CAMP_SPRITE_SCALE
	_player_sprite = sprite
	_player_base_sprite_offset = sprite.position
	player.position = (_walk_min + _walk_max) * 0.5

func _get_camp_request_status() -> String:
	if not CampaignManager:
		return ""
	return str(CampaignManager.camp_request_status).strip_edges().to_lower()

func _prepend_unique_zones(existing: Variant, preferred_first: Array[String]) -> Array:
	var out: Array = []
	for z in preferred_first:
		var key: String = str(z).strip_edges()
		if key != "" and key not in out:
			out.append(key)
	if existing is Array:
		for z2 in existing:
			var key2: String = str(z2).strip_edges()
			if key2 != "" and key2 not in out:
				out.append(key2)
	return out

func _apply_condition_behavior_bias(profile: Dictionary, unit_name: String) -> Dictionary:
	var merged: Dictionary = profile.duplicate(true)
	if not CampaignManager:
		return merged
	var injured: bool = CampaignManager.is_unit_injured(unit_name)
	var fatigued: bool = CampaignManager.is_unit_fatigued(unit_name)
	if not injured and not fatigued:
		return merged
	if injured:
		merged["preferred_zones"] = _prepend_unique_zones(merged.get("preferred_zones", []), ["infirmary", "bench", "fire"])
		merged["secondary_zones"] = _prepend_unique_zones(merged.get("secondary_zones", []), ["bench", "fire", "wagon"])
		var freq_i: float = float(merged.get("movement_frequency", 0.5))
		merged["movement_frequency"] = clampf(freq_i * 0.72, 0.15, 1.0)
	elif fatigued:
		merged["preferred_zones"] = _prepend_unique_zones(merged.get("preferred_zones", []), ["bench", "fire", "wagon"])
		merged["secondary_zones"] = _prepend_unique_zones(merged.get("secondary_zones", []), ["bench", "fire"])
		var freq_f: float = float(merged.get("movement_frequency", 0.5))
		merged["movement_frequency"] = clampf(freq_f * 0.85, 0.15, 1.0)
	return merged

func _content_condition_matches(entry: Dictionary, speaker_name: String, listener_name: String = "") -> bool:
	if not CampaignManager:
		return not bool(entry.get("requires_injured_speaker", false)) and not bool(entry.get("requires_fatigued_speaker", false)) and not bool(entry.get("requires_injured_listener", false)) and not bool(entry.get("requires_fatigued_listener", false))
	var speaker: String = str(speaker_name).strip_edges()
	var listener: String = str(listener_name).strip_edges()
	if bool(entry.get("requires_injured_speaker", false)) and not CampaignManager.is_unit_injured(speaker):
		return false
	if bool(entry.get("requires_fatigued_speaker", false)) and not CampaignManager.is_unit_fatigued(speaker):
		return false
	if bool(entry.get("requires_injured_listener", false)):
		if listener == "" or not CampaignManager.is_unit_injured(listener):
			return false
	if bool(entry.get("requires_fatigued_listener", false)):
		if listener == "" or not CampaignManager.is_unit_fatigued(listener):
			return false
	return true

func _normalize_unit_name_for_matching(raw_name: String) -> String:
	var out: String = str(raw_name).strip_edges()
	out = out.replace("“", "\"")
	out = out.replace("”", "\"")
	out = out.replace("’", "'")
	return out

func _resource_prop_or(res: Resource, prop: String, fallback: Variant) -> Variant:
	if res == null:
		return fallback
	var value: Variant = res.get(prop)
	return value if value != null else fallback

func _build_roster_entry_from_unit_data(unit_data: Resource) -> Dictionary:
	var name_raw: String = str(_resource_prop_or(unit_data, "display_name", "")).strip_edges()
	var unit_name: String = _normalize_unit_name_for_matching(name_raw)
	var max_hp_v: int = int(_resource_prop_or(unit_data, "max_hp", 1))
	max_hp_v = maxi(1, max_hp_v)
	var class_data: Variant = unit_data.get("character_class")
	var move_range_v: int = int(class_data.get("move_range")) if class_data != null and class_data.get("move_range") != null else 5
	var move_type_v: int = int(class_data.get("move_type")) if class_data != null and class_data.get("move_type") != null else 0
	var unit_class_name: String = str(class_data.get("job_name")) if class_data != null and class_data.get("job_name") != null else ""
	var starting_weapon: Variant = _resource_prop_or(unit_data, "starting_weapon", null)
	var equipped_weapon: Variant = starting_weapon
	if equipped_weapon != null and CampaignManager != null and CampaignManager.has_method("duplicate_item"):
		equipped_weapon = CampaignManager.duplicate_item(equipped_weapon)
	var inventory: Array = []
	if equipped_weapon != null:
		inventory.append(equipped_weapon)
	var ability_name: String = str(_resource_prop_or(unit_data, "ability", ""))
	return {
		"unit_name": unit_name,
		"unit_class": unit_class_name,
		"class_name": unit_class_name,
		"is_promoted": false,
		"data": unit_data,
		"data_path_hint": str(unit_data.resource_path).strip_edges(),
		"class_data": class_data,
		"level": 1,
		"experience": 0,
		"max_hp": max_hp_v,
		"current_hp": max_hp_v,
		"strength": int(_resource_prop_or(unit_data, "strength", 1)),
		"magic": int(_resource_prop_or(unit_data, "magic", 0)),
		"defense": int(_resource_prop_or(unit_data, "defense", 0)),
		"resistance": int(_resource_prop_or(unit_data, "resistance", 0)),
		"speed": int(_resource_prop_or(unit_data, "speed", 0)),
		"agility": int(_resource_prop_or(unit_data, "agility", 0)),
		"move_range": move_range_v,
		"move_type": move_type_v,
		"equipped_weapon": equipped_weapon,
		"inventory": inventory,
		"portrait": _resource_prop_or(unit_data, "portrait", null),
		"battle_sprite": _resource_prop_or(unit_data, "unit_sprite", null),
		"ability": ability_name,
		"skill_points": 0,
		"unlocked_skills": [],
		"unlocked_abilities": [ability_name] if ability_name != "" else [],
		"unit_tags": [],
	}

func _load_first_existing_resource(paths: Array) -> Dictionary:
	for p in paths:
		var path_str: String = str(p).strip_edges()
		if path_str == "":
			continue
		var res: Variant = load(path_str)
		if res != null and res is Resource:
			return {
				"resource": res as Resource,
				"path": path_str,
			}
	return {}

func _get_debug_test_camp_roster(base_roster: Array) -> Array:
	var out: Array = []
	if not debug_use_test_camp_roster:
		return base_roster
	if not debug_replace_roster_entirely:
		for entry in base_roster:
			if entry is Dictionary:
				out.append((entry as Dictionary).duplicate(true))

	var existing_names: Dictionary = {}
	for entry2 in out:
		if not (entry2 is Dictionary):
			continue
		var n0: String = _normalize_unit_name_for_matching(str((entry2 as Dictionary).get("unit_name", "")))
		if n0 != "":
			existing_names[n0] = true

	var wanted: Dictionary = {}
	for n in DEBUG_TEST_CAMP_UNIT_NAMES:
		var wn: String = _normalize_unit_name_for_matching(str(n))
		if wn != "":
			wanted[wn] = true
	var scanned_files: int = 0
	var accepted_names: Array[String] = []
	for desired_name in DEBUG_TEST_CAMP_UNIT_NAMES:
		var desired_norm: String = _normalize_unit_name_for_matching(desired_name)
		if desired_norm == "" or not wanted.has(desired_norm):
			continue
		if existing_names.has(desired_norm):
			continue
		var path_options: Array = DEBUG_TEST_CAMP_UNIT_RESOURCE_PATHS.get(desired_name, [])
		scanned_files += path_options.size()
		var resolved: Dictionary = _load_first_existing_resource(path_options)
		if resolved.is_empty():
			if debug_use_test_camp_roster:
				print("DEBUG_CAMP_LOAD name=", desired_norm, " path=<missing>")
			continue
		var unit_data: Resource = resolved.get("resource", null)
		var loaded_path: String = str(resolved.get("path", "")).strip_edges()
		if unit_data == null:
			continue
		var display_name: String = _normalize_unit_name_for_matching(str(_resource_prop_or(unit_data, "display_name", "")))
		var resolved_name: String = display_name if display_name != "" else desired_norm
		if debug_use_test_camp_roster:
			print("DEBUG_CAMP_LOAD path=", loaded_path)
			print("DEBUG_CAMP_NAME display_name=", display_name, " desired=", desired_norm)
		if resolved_name == "" or not wanted.has(resolved_name):
			continue
		if existing_names.has(resolved_name):
			continue
		out.append(_build_roster_entry_from_unit_data(unit_data))
		existing_names[resolved_name] = true
		accepted_names.append(resolved_name)

	var ordered: Array = []
	var by_name: Dictionary = {}
	for entry3 in out:
		if not (entry3 is Dictionary):
			continue
		var d: Dictionary = entry3
		by_name[_normalize_unit_name_for_matching(str(d.get("unit_name", "")))] = d
	for desired in DEBUG_TEST_CAMP_UNIT_NAMES:
		var dn: String = _normalize_unit_name_for_matching(str(desired))
		if by_name.has(dn):
			ordered.append((by_name[dn] as Dictionary).duplicate(true))
	var final_roster: Array = ordered if not ordered.is_empty() else out
	if debug_use_test_camp_roster:
		print("DEBUG_CAMP_ROSTER_COUNT scanned=", scanned_files, " accepted=", accepted_names.size(), " final=", final_roster.size())
	if debug_replace_roster_entirely and final_roster.is_empty():
		print("CAMP_DEBUG_TEST_ROSTER fallback to base roster (debug list resolved empty).")
		return base_roster
	return final_roster

func _get_camp_spawn_roster() -> Array:
	var base_roster: Array = CampaignManager.player_roster if CampaignManager else []
	var roster: Array = _get_debug_test_camp_roster(base_roster)
	if roster.is_empty() and not base_roster.is_empty():
		roster = base_roster
		if debug_use_test_camp_roster:
			print("CAMP_DEBUG_SPAWN_ROSTER fallback applied from base roster, size=", roster.size())
	if debug_use_test_camp_roster:
		var names: Array[String] = []
		for e in roster:
			if e is Dictionary:
				var n: String = str((e as Dictionary).get("unit_name", "")).strip_edges()
				if n != "":
					names.append(n)
		print("DEBUG_CAMP_ROSTER_NAMES ", names)
		print("CAMP_DEBUG_SPAWN_ROSTER size=", roster.size(), " names=", names)
	return roster

func _spawn_walkers() -> void:
	if walkers_container == null:
		walkers_container = Node2D.new()
		walkers_container.name = "Walkers"
		add_child(walkers_container)
	var roster: Array = _get_camp_spawn_roster()
	if debug_use_test_camp_roster and not _debug_spawn_count_logged_once:
		print("DEBUG_CAMP_SPAWN_FINAL_ROSTER_SIZE ", roster.size())
		_debug_spawn_count_logged_once = true
	if roster.is_empty():
		return
	var context: Dictionary = _build_camp_context()
	# Distribute anchor positions in the walk area to avoid dogpiling
	var anchors: Array[Vector2] = []
	var w: float = _walk_max.x - _walk_min.x
	var h: float = _walk_max.y - _walk_min.y
	var cols: int = maxi(2, int(sqrt(roster.size())))
	var rows: int = int(ceil(float(roster.size()) / float(cols))) if cols > 0 else 0
	for i in roster.size():
		var col: int = i % cols
		var row: int = int(float(i) / float(cols)) if cols > 0 else 0
		var fx: float = (float(col) + 0.5) / float(cols)
		var fy: float = (float(row) + 0.5) / float(rows)
		anchors.append(Vector2(_walk_min.x + w * fx, _walk_min.y + h * fy))
	for i in roster.size():
		var entry: Dictionary = (roster[i] as Dictionary).duplicate(true)
		entry["unit_name"] = _normalize_unit_name_for_matching(str(entry.get("unit_name", "")))
		var inst: Node = WALKER_SCENE.instantiate()
		walkers_container.add_child(inst)
		inst.global_position = anchors[i] if i < anchors.size() else (_walk_min + _walk_max) * 0.5
		if inst is CampRosterWalker:
			var walker: CampRosterWalker = inst as CampRosterWalker
			walker.home_position = inst.global_position
			walker.roam_radius = 60.0
			walker.setup_from_roster(entry)
			var base_profile: Dictionary = CAMP_BEHAVIOR_DB.get_profile(walker.unit_name)
			var routine: Dictionary = CAMP_ROUTINE_DB.get_best_routine(walker.unit_name, context)
			var merged: Dictionary = base_profile.duplicate()
			if not routine.is_empty():
				if routine.has("preferred_zones"):
					merged["preferred_zones"] = routine.get("preferred_zones")
				if routine.has("secondary_zones"):
					merged["secondary_zones"] = routine.get("secondary_zones")
				if routine.has("movement_frequency"):
					merged["movement_frequency"] = routine.get("movement_frequency")
				if routine.has("idle_style"):
					merged["idle_style"] = routine.get("idle_style")
			merged = _apply_condition_behavior_bias(merged, walker.unit_name)
			walker.apply_behavior_profile(merged)
			if CampaignManager:
				walker.apply_condition_flags(
					CampaignManager.is_unit_injured(walker.unit_name),
					CampaignManager.is_unit_fatigued(walker.unit_name)
				)
			walker.set_behavior_zones(_camp_zones)
			walker.start_behavior()
		_walker_nodes.append(inst)
	_apply_relationship_home_bias()
	# One offer giver when no active request: scoring by level-based eligibility, recent givers, completed count.
	var status: String = _get_camp_request_status()
	if status != "active" and status != "ready_to_turn_in" and status != "failed" and CampaignManager:
		var roster_names: Array = []
		var item_names: Array = _get_requestable_item_names()
		for walk_node in _walker_nodes:
			if walk_node is CampRosterWalker:
				roster_names.append((walk_node as CampRosterWalker).unit_name)
		var best_name: String = ""
		var best_offer: Dictionary = {}
		var best_score: int = -99999
		var progress_level: int = CampaignManager.camp_request_progress_level
		var next_eligible: Dictionary = CampaignManager.camp_request_unit_next_eligible_level
		var recent: Array = CampaignManager.camp_request_recent_givers
		var completed_by: Dictionary = CampaignManager.camp_requests_completed_by_unit
		for w2 in _walker_nodes:
			if not (w2 is CampRosterWalker):
				continue
			var walker: CampRosterWalker = w2 as CampRosterWalker
			var name_str: String = walker.unit_name
			var score: int = 0
			var completed: int = int(completed_by.get(name_str, 0))
			if completed == 0:
				score += 20
			elif completed == 1:
				score += 10
			if name_str in recent:
				score -= 30
			# Level-based eligibility: eligible if progress_level >= next_eligible_level (no entry = eligible).
			var threshold: int = int(next_eligible.get(name_str, -1))
			if threshold >= 0 and progress_level < threshold:
				score -= 100
			var tiebreak: int = (name_str.hash() + progress_level) % 1000
			score = score * 1000 + (500 - tiebreak)
			var giver_tier: String = CampaignManager.get_avatar_relationship_tier(name_str) if CampaignManager else ""
			var personal_eligible: bool = CampaignManager.is_personal_quest_eligible(name_str) if CampaignManager else false
			var offer: Dictionary = CampRequestDB.get_offer(name_str, CampRequestDB.get_personality(walker.unit_data.get("data", null), name_str), roster_names, item_names, false, giver_tier, personal_eligible)
			if offer.is_empty():
				continue
			if score > best_score:
				best_score = score
				best_name = name_str
				best_offer = offer
		if best_name != "":
			_offer_giver_name = best_name
			_offer_is_personal = str(best_offer.get("request_depth", "")).strip_edges().to_lower() == "personal"
			print("EXPLORE_SELECTED_GIVER =", best_name)
			print("EXPLORE_SELECTED_OFFER =", best_offer)
			print("EXPLORE_STATUS =", str(CampaignManager.camp_request_status) if CampaignManager else "")
			print("EXPLORE_GIVER_STORED =", _offer_giver_name)
			# Do NOT update persistent recent givers here; only on Accept/Decline to avoid open/close spam exploit.

func _connect_ui() -> void:
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if dialogue_close_btn:
		dialogue_close_btn.pressed.connect(_on_dialogue_close_pressed)
	if accept_btn:
		accept_btn.pressed.connect(_on_accept_pressed)
	if decline_btn:
		decline_btn.pressed.connect(_on_decline_pressed)
	if turn_in_btn:
		turn_in_btn.pressed.connect(_on_turn_in_pressed)

func _input(event: InputEvent) -> void:
	if _task_log != null and is_instance_valid(_task_log) and _task_log.visible:
		# While the Task Log overlay is open, explore-camp should not react to input;
		# TaskLog will handle Esc/J itself via _unhandled_input.
		return
	if _dialogue_active:
		if event.is_action_pressed("camp_cancel") or event.is_action_pressed("ui_cancel"):
			if _pair_scene_active:
				_advance_pair_scene()
			else:
				_close_dialogue()
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
			print("TASKLOG_OPEN_BRANCH_REACHED")
			print("TASKLOG_OPEN_FUNCTION_CALL =", "_toggle_task_log")
			_toggle_task_log()
	# Optional: click on NPC to talk
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_click_interact(event.position)

func _process(delta: float) -> void:
	_update_ambient_bubble_position()
	if _dialogue_active:
		_hide_ambient_bubble()
		return
	_handle_movement(delta)
	_update_interact_prompt()
	_update_rumor(delta)

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
	player.position.x = clampf(player.position.x, _walk_min.x, _walk_max.x)
	player.position.y = clampf(player.position.y, _walk_min.y, _walk_max.y)
	var speed_now: float = _player_velocity.length()
	if _player_sprite != null:
		if speed_now > PLAYER_MIN_MOVE_SPEED_FOR_BOB:
			_player_walk_cycle += PLAYER_STEP_BOB_SPEED * delta
			var bob: float = sin(_player_walk_cycle) * PLAYER_STEP_BOB_HEIGHT
			_player_sprite.position = _player_base_sprite_offset + Vector2(0, bob)
		else:
			_player_walk_cycle = 0.0
			_player_sprite.position = _player_base_sprite_offset

func _get_nearest_walker_in_range() -> Node:
	if player == null:
		return null
	var best: Node = null
	var best_d: float = INTERACT_RANGE * INTERACT_RANGE
	for w in _walker_nodes:
		if not is_instance_valid(w):
			continue
		var d_sq: float = player.global_position.distance_squared_to(w.global_position)
		if d_sq < best_d:
			best_d = d_sq
			best = w
	return best

func _update_interact_prompt() -> void:
	if interact_prompt == null:
		return
	if _dialogue_active:
		interact_prompt.visible = false
		return
	var nearest: Node = _get_nearest_walker_in_range()
	var eligible_pair: Dictionary = _get_eligible_pair_scene()
	if nearest != null and _would_single_walker_priority(nearest):
		interact_prompt.visible = true
		interact_prompt.text = "E  Talk"
	elif not eligible_pair.is_empty():
		interact_prompt.visible = true
		interact_prompt.text = "E  Listen"
	elif nearest != null:
		interact_prompt.visible = true
		interact_prompt.text = "E  Talk"
	else:
		interact_prompt.visible = false

func _update_rumor(_delta: float) -> void:
	if player == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	_update_social_hold(now)
	var pending_social_meetup: bool = false
	if _chatter_active:
		if now >= _chatter_current_until:
			_advance_ambient_chatter()
		return
	if _chatter_lines.size() > 0 and _chatter_walker_a is CampRosterWalker and _chatter_walker_b is CampRosterWalker:
		var wa2: CampRosterWalker = _chatter_walker_a as CampRosterWalker
		var wb2: CampRosterWalker = _chatter_walker_b as CampRosterWalker
		var ready_a: bool = wa2.has_reached_social_target()
		var ready_b: bool = wb2.has_reached_social_target()
		if ready_a and ready_b:
			wa2.face_toward(wb2.global_position)
			wb2.face_toward(wa2.global_position)
			if _chatter_social_settle_until <= 0.0:
				wa2.play_social_settle_beat()
				wb2.play_social_settle_beat()
				_chatter_social_settle_until = now + CHATTER_SOCIAL_SETTLE_BEAT
			if now < _chatter_social_settle_until:
				return
			var entry_local: Dictionary = _chatter_entry
			if entry_local.get("once_per_visit", false):
				var cid2: String = str(entry_local.get("id", "")).strip_edges()
				if cid2 != "":
					_chatter_shown_this_visit[cid2] = true
			_chatter_active = true
			_chatter_meetup_started_at = 0.0
			_chatter_social_settle_until = 0.0
			_show_ambient_chatter_line()
		elif _chatter_meetup_started_at > 0.0 and now - _chatter_meetup_started_at >= CHATTER_MEETUP_TIMEOUT:
			_cancel_pending_ambient_chatter()
		else:
			pending_social_meetup = true
	if _spontaneous_social_active:
		if now >= _spontaneous_social_current_until:
			_advance_spontaneous_social()
		return
	if _spontaneous_social_lines.size() > 0 and not _spontaneous_social_participants.is_empty():
		var all_ready: bool = true
		for p in _spontaneous_social_participants:
			if not (p is CampRosterWalker) or not is_instance_valid(p) or not (p as CampRosterWalker).has_reached_social_target():
				all_ready = false
				break
		if all_ready:
			if _spontaneous_social_settle_until <= 0.0:
				for p2 in _spontaneous_social_participants:
					if p2 is CampRosterWalker and is_instance_valid(p2):
						(p2 as CampRosterWalker).play_social_settle_beat()
				_spontaneous_social_settle_until = now + SPONTANEOUS_SOCIAL_SETTLE_BEAT
			if now < _spontaneous_social_settle_until:
				return
			if bool(_spontaneous_social_entry.get("once_per_visit", false)):
				var sid_ready: String = str(_spontaneous_social_entry.get("id", "")).strip_edges()
				if sid_ready != "":
					_spontaneous_social_shown_this_visit[sid_ready] = true
			_spontaneous_social_active = true
			_spontaneous_social_meetup_started_at = 0.0
			_spontaneous_social_settle_until = 0.0
			_show_spontaneous_social_line()
		elif _spontaneous_social_meetup_started_at > 0.0 and now - _spontaneous_social_meetup_started_at >= SPONTANEOUS_SOCIAL_MEETUP_TIMEOUT:
			_cancel_pending_spontaneous_social()
		else:
			pending_social_meetup = true
	if _dialogue_active or _pair_scene_active:
		return
	var bubble_active: bool = ambient_speech_bubble != null and ambient_speech_bubble.visible and is_instance_valid(_ambient_bubble_speaker)
	var fallback_label_active: bool = rumor_label != null and rumor_label.visible
	if bubble_active or fallback_label_active:
		if now >= _rumor_hide_at:
			_hide_ambient_bubble()
			_rumor_cooldown_until = now + RUMOR_COOLDOWN
		return
	if not pending_social_meetup:
		if now >= _chatter_next_attempt_time:
			var candidate: Dictionary = _get_eligible_ambient_chatter()
			if candidate.is_empty():
				_chatter_next_attempt_time = now + randf_range(CHATTER_ATTEMPT_INTERVAL_MIN, CHATTER_ATTEMPT_INTERVAL_MAX)
			else:
				_start_ambient_chatter(candidate)
			return
		if now >= _spontaneous_social_next_attempt_time:
			var spontaneous: Dictionary = _get_best_spontaneous_social_candidate()
			if spontaneous.is_empty():
				_spontaneous_social_next_attempt_time = now + randf_range(SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MIN, SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MAX)
			else:
				_start_spontaneous_social(spontaneous)
			return
	if now < _rumor_cooldown_until:
		return
	var micro_bark: Dictionary = _get_eligible_micro_bark()
	if not micro_bark.is_empty():
		var mb_text: String = _get_entry_text_with_variants(micro_bark, "micro")
		if mb_text == "":
			return
		var mb_speaker: String = str(micro_bark.get("speaker", "")).strip_edges()
		var micro_speaker_walker: CampRosterWalker = _get_walker_by_name(mb_speaker)
		_record_ambient_history("micro", micro_bark, mb_speaker)
		_show_ambient_bubble(mb_text, micro_speaker_walker, mb_speaker)
		var mid: String = str(micro_bark.get("id", "")).strip_edges()
		if mid != "" and micro_bark.get("once_per_visit", false):
			_micro_bark_shown_this_visit[mid] = true
		_rumor_hide_at = now + _get_dynamic_ambient_duration(mb_text, 2, RUMOR_DISPLAY_DURATION - 0.6)
		return
	var rumor: Dictionary = _get_eligible_rumor()
	if rumor.is_empty():
		return
	var r_text: String = _get_entry_text_with_variants(rumor, "rumor")
	if r_text == "":
		return
	var r_speaker: String = str(rumor.get("speaker", "")).strip_edges()
	var rumor_speaker_walker: CampRosterWalker = _get_walker_by_name(r_speaker)
	_record_ambient_history("rumor", rumor, r_speaker)
	_show_ambient_bubble(r_text, rumor_speaker_walker, r_speaker)
	var rid: String = str(rumor.get("id", "")).strip_edges()
	if rid != "" and rumor.get("once_per_visit", false):
		_rumor_shown_this_visit[rid] = true
	_rumor_hide_at = now + _get_dynamic_ambient_duration(r_text, 1, RUMOR_DISPLAY_DURATION)

func _get_eligible_rumor() -> Dictionary:
	var context: Dictionary = _build_camp_context()
	var best: Dictionary = {}
	var best_score: float = -99999.0
	for r in CAMP_RUMOR_DB.get_all_rumors():
		if not (r is Dictionary):
			continue
		var rumor: Dictionary = r
		if rumor.get("once_per_visit", false):
			var rid: String = str(rumor.get("id", "")).strip_edges()
			if rid != "" and _rumor_shown_this_visit.get(rid, false):
				continue
		if not CAMP_RUMOR_DB.when_matches(rumor, context):
			continue
		var speaker: String = str(rumor.get("speaker", "")).strip_edges()
		if speaker.is_empty():
			continue
		var listener: String = str(rumor.get("listener", "")).strip_edges()
		if not _content_condition_matches(rumor, speaker, listener):
			continue
		if listener != "":
			var listener_walker: Node = _find_walker_by_name(listener)
			if listener_walker == null:
				continue
			if not _pair_memory_matches(rumor, speaker, listener):
				continue
		var speaker_walker: Node = null
		for w in _walker_nodes:
			if not is_instance_valid(w) or not (w is CampRosterWalker):
				continue
			if (w as CampRosterWalker).unit_name == speaker:
				speaker_walker = w
				break
		if speaker_walker == null:
			continue
		var radius: float = float(rumor.get("radius", CAMP_RUMOR_DB.RUMOR_DEFAULT_RADIUS))
		if player.global_position.distance_squared_to(speaker_walker.global_position) > radius * radius:
			continue
		if rumor.has("zone_type"):
			var zt: String = str(rumor.get("zone_type", "")).strip_edges()
			if zt != "" and not _is_walker_near_zone(speaker_walker, zt):
				continue
		if rumor.has("nearby_units"):
			var names: Array = rumor.get("nearby_units", [])
			var all_nearby_found: bool = true
			for n in names:
				var want: String = str(n).strip_edges()
				if want.is_empty():
					continue
				var found: bool = false
				for w2 in _walker_nodes:
					if not is_instance_valid(w2) or w2 == speaker_walker or not (w2 is CampRosterWalker):
						continue
					if (w2 as CampRosterWalker).unit_name != want:
						continue
					if speaker_walker.global_position.distance_squared_to(w2.global_position) <= RUMOR_NEARBY_UNITS_RADIUS * RUMOR_NEARBY_UNITS_RADIUS:
						found = true
						break
				if not found:
					all_nearby_found = false
					break
			if not all_nearby_found:
				continue
		var score: float = float(rumor.get("priority", 0))
		if listener != "":
			score = _score_with_relationship_bias(score, rumor, speaker, listener)
		score -= _get_recent_history_penalty("rumor", rumor, speaker)
		if score > best_score:
			best_score = score
			best = rumor
	return best

func _is_walker_near_zone(walker_node: Node, zone_type: String) -> bool:
	var pos: Vector2 = walker_node.global_position
	for z in _camp_zones:
		if not is_instance_valid(z) or not ("zone_type" in z):
			continue
		var zt: String = str(z.zone_type).strip_edges()
		if zt != zone_type:
			continue
		var z_pos: Vector2 = z.global_position
		var z_radius: float = float(z.radius) if "radius" in z else 32.0
		if pos.distance_squared_to(z_pos) <= (z_radius + RUMOR_NEAR_ZONE_MARGIN) * (z_radius + RUMOR_NEAR_ZONE_MARGIN):
			return true
	return false

func _find_walker_by_name(unit_name: String) -> Node:
	var key: String = _normalize_unit_name_for_matching(unit_name)
	if key.is_empty():
		return null
	for w in _walker_nodes:
		if not is_instance_valid(w) or not (w is CampRosterWalker):
			continue
		var walker_name: String = _normalize_unit_name_for_matching((w as CampRosterWalker).unit_name)
		if walker_name == key:
			return w
	return null

func _are_walkers_near_each_other(w1: Node, w2: Node, pair_radius: float) -> bool:
	if w1 == null or w2 == null or w1 == w2:
		return false
	return w1.global_position.distance_squared_to(w2.global_position) <= pair_radius * pair_radius

func _make_pair_key(name_a: String, name_b: String) -> String:
	if CampaignManager:
		return CampaignManager.make_pair_key(name_a, name_b)
	var a: String = str(name_a).strip_edges()
	var b: String = str(name_b).strip_edges()
	if a == "" or b == "":
		return ""
	if a <= b:
		return "%s|%s" % [a, b]
	return "%s|%s" % [b, a]

func _get_pair_stats(name_a: String, name_b: String) -> Dictionary:
	if CampaignManager:
		CampaignManager.ensure_camp_memory()
		return CampaignManager.get_pair_stats(name_a, name_b)
	return { "familiarity": 0, "tension": 0, "last_visit_spoke": 0 }

func _set_pair_stats(name_a: String, name_b: String, stats: Dictionary) -> void:
	if CampaignManager:
		CampaignManager.ensure_camp_memory()
		CampaignManager.set_pair_stats(name_a, name_b, stats)

func _get_pair_familiarity(name_a: String, name_b: String) -> int:
	if CampaignManager:
		CampaignManager.ensure_camp_memory()
		return CampaignManager.get_pair_familiarity(name_a, name_b)
	return 0

func _get_pair_tension(name_a: String, name_b: String) -> int:
	var stats: Dictionary = _get_pair_stats(name_a, name_b)
	return int(stats.get("tension", 0))

func _get_pair_affinity_bias(name_a: String, name_b: String) -> float:
	var familiarity: float = float(_get_pair_familiarity(name_a, name_b))
	return clampf(familiarity * 0.12, 0.0, 0.6)

func _get_pair_social_bias(name_a: String, name_b: String) -> float:
	var affinity_bias: float = _get_pair_affinity_bias(name_a, name_b)
	var tension_bias: float = float(_get_pair_tension(name_a, name_b)) * 0.08
	return clampf(affinity_bias - tension_bias, -0.4, 0.6)

func _get_relationship_tone(entry: Dictionary) -> String:
	var tone: String = str(entry.get("relationship_tone", "neutral")).strip_edges().to_lower()
	if tone in ["warm", "neutral", "tense"]:
		return tone
	return "neutral"

func _score_with_relationship_bias(base_priority: float, entry: Dictionary, name_a: String, name_b: String) -> float:
	var tone: String = _get_relationship_tone(entry)
	var social_bias: float = _get_pair_social_bias(name_a, name_b)
	match tone:
		"tense":
			# Tense-authored entries should not be penalized for pair tension.
			social_bias = maxf(social_bias, 0.0)
		"warm":
			social_bias += maxf(0.0, _get_pair_affinity_bias(name_a, name_b)) * 0.2
		_:
			pass
	social_bias = clampf(social_bias, -0.4, 0.6)
	return base_priority + social_bias

func _apply_relationship_home_bias() -> void:
	if not CampaignManager:
		return
	var adjusted_count: int = 0
	for node in _walker_nodes:
		if adjusted_count >= 8:
			break
		if not (node is CampRosterWalker):
			continue
		var walker: CampRosterWalker = node as CampRosterWalker
		var source_name: String = str(walker.unit_name).strip_edges()
		if source_name == "":
			continue
		var best_partner: CampRosterWalker = null
		var best_score: float = 0.1
		for other_node in _walker_nodes:
			if other_node == node or not (other_node is CampRosterWalker):
				continue
			var other: CampRosterWalker = other_node as CampRosterWalker
			var other_name: String = str(other.unit_name).strip_edges()
			if other_name == "":
				continue
			var familiarity: int = _get_pair_familiarity(source_name, other_name)
			if familiarity < 1:
				continue
			var social_bias: float = _get_pair_social_bias(source_name, other_name)
			if social_bias <= 0.1:
				continue
			var dist: float = walker.home_position.distance_to(other.home_position)
			if dist > 360.0:
				continue
			var score: float = social_bias - clampf(dist / 900.0, 0.0, 0.35)
			if score > best_score:
				best_score = score
				best_partner = other
		if best_partner == null:
			continue
		var to_partner: Vector2 = best_partner.home_position - walker.home_position
		var distance_to_partner: float = to_partner.length()
		if distance_to_partner <= 0.001:
			continue
		var nudge_len: float = minf(30.0, minf(distance_to_partner * 0.45, 12.0 + best_score * 24.0))
		if nudge_len <= 0.0:
			continue
		var nudged_home: Vector2 = walker.home_position + to_partner.normalized() * nudge_len
		nudged_home.x = clampf(nudged_home.x, _walk_min.x, _walk_max.x)
		nudged_home.y = clampf(nudged_home.y, _walk_min.y, _walk_max.y)
		walker.home_position = nudged_home
		adjusted_count += 1

func _was_pair_recently_active(name_a: String, name_b: String, within_visits: int) -> bool:
	if within_visits < 0:
		return false
	if not CampaignManager:
		return false
	CampaignManager.ensure_camp_memory()
	var current_visit: int = int(CampaignManager.get_camp_visit_index())
	var stats: Dictionary = _get_pair_stats(name_a, name_b)
	var last_visit: int = int(stats.get("last_visit_spoke", 0))
	if last_visit <= 0:
		return false
	var delta_visits: int = current_visit - last_visit
	return delta_visits >= 0 and delta_visits <= within_visits

func _pair_memory_matches(entry: Dictionary, name_a: String, name_b: String) -> bool:
	var has_memory_gate: bool = entry.has("min_familiarity") or entry.has("max_familiarity") or entry.has("min_tension") or entry.has("max_tension") or entry.has("recent_within_visits")
	if not has_memory_gate:
		return true
	var a_name: String = str(name_a).strip_edges()
	var b_name: String = str(name_b).strip_edges()
	if a_name.is_empty() or b_name.is_empty():
		return true
	var stats: Dictionary = _get_pair_stats(a_name, b_name)
	var familiarity: int = int(stats.get("familiarity", 0))
	var tension: int = int(stats.get("tension", 0))
	if entry.has("min_familiarity") and familiarity < int(entry.get("min_familiarity", 0)):
		return false
	if entry.has("max_familiarity") and familiarity > int(entry.get("max_familiarity", 999999)):
		return false
	if entry.has("min_tension") and tension < int(entry.get("min_tension", 0)):
		return false
	if entry.has("max_tension") and tension > int(entry.get("max_tension", 999999)):
		return false
	if entry.has("recent_within_visits"):
		var within_visits: int = int(entry.get("recent_within_visits", 0))
		if not _was_pair_recently_active(a_name, b_name, within_visits):
			return false
	return true

func _record_pair_scene_completion(scene: Dictionary) -> void:
	if not CampaignManager:
		return
	var sid: String = str(scene.get("id", "")).strip_edges()
	var a_name: String = str(scene.get("unit_a", "")).strip_edges()
	var b_name: String = str(scene.get("unit_b", "")).strip_edges()
	var stats: Dictionary = _get_pair_stats(a_name, b_name)
	var familiarity: int = int(stats.get("familiarity", 0)) + int(scene.get("grants_familiarity", 1))
	var tension: int = int(stats.get("tension", 0)) + int(scene.get("grants_tension", 0))
	stats["familiarity"] = maxi(0, familiarity)
	stats["tension"] = maxi(0, tension)
	stats["last_visit_spoke"] = int(CampaignManager.get_camp_visit_index())
	_set_pair_stats(a_name, b_name, stats)
	if sid != "":
		CampaignManager.mark_camp_memory_scene_seen(sid)

func _record_chatter_completion(entry: Dictionary) -> void:
	if not CampaignManager:
		return
	var a_name: String = str(entry.get("unit_a", "")).strip_edges()
	var b_name: String = str(entry.get("unit_b", "")).strip_edges()
	if a_name == "" or b_name == "":
		return
	var key: String = _make_pair_key(a_name, b_name)
	var stats: Dictionary = _get_pair_stats(a_name, b_name)
	stats["last_visit_spoke"] = int(CampaignManager.get_camp_visit_index())
	if not _chatter_familiarity_awarded_this_visit.get(key, false):
		stats["familiarity"] = maxi(0, int(stats.get("familiarity", 0)) + 1)
		_chatter_familiarity_awarded_this_visit[key] = true
	_set_pair_stats(a_name, b_name, stats)

func _get_eligible_ambient_chatter() -> Dictionary:
	var context: Dictionary = _build_camp_context()
	var best: Dictionary = {}
	var best_score: float = -99999.0
	for entry_variant in CAMP_AMBIENT_CHATTER_DB.get_all_chatters():
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if entry.get("once_per_visit", false):
			var cid: String = str(entry.get("id", "")).strip_edges()
			if cid != "" and _chatter_shown_this_visit.get(cid, false):
				continue
		if not CAMP_AMBIENT_CHATTER_DB.when_matches(entry, context):
			continue
		var a_name: String = str(entry.get("unit_a", "")).strip_edges()
		var b_name: String = str(entry.get("unit_b", "")).strip_edges()
		if a_name == "" or b_name == "":
			continue
		var w_a: Node = _find_walker_by_name(a_name)
		var w_b: Node = _find_walker_by_name(b_name)
		if w_a == null or w_b == null or w_a == w_b:
			continue
		if not (w_a is CampRosterWalker) or not (w_b is CampRosterWalker):
			continue
		if not (w_a as CampRosterWalker).is_available_for_chatter():
			continue
		if not (w_b as CampRosterWalker).is_available_for_chatter():
			continue
		if entry.has("zone_type"):
			var zt: String = str(entry.get("zone_type", "")).strip_edges()
			if zt != "" and not _is_walker_near_zone(w_a, zt) and not _is_walker_near_zone(w_b, zt):
				continue
		var pair_radius: float = float(entry.get("pair_radius", CAMP_AMBIENT_CHATTER_DB.AMBIENT_CHATTER_DEFAULT_PAIR_RADIUS)) * 1.12
		var approach_radius: float = float(entry.get("approach_radius", pair_radius)) * 1.2
		var dist_sq: float = w_a.global_position.distance_squared_to(w_b.global_position)
		if dist_sq > approach_radius * approach_radius:
			continue
		var mid: Vector2 = (w_a.global_position + w_b.global_position) * 0.5
		var overhear_radius: float = float(entry.get("overhear_radius", RUMOR_OVERHEAR_RADIUS))
		var dist_sq_player: float = minf(
			player.global_position.distance_squared_to(w_a.global_position),
			minf(
				player.global_position.distance_squared_to(w_b.global_position),
				player.global_position.distance_squared_to(mid)
			)
		)
		if dist_sq_player > overhear_radius * overhear_radius:
			continue
		var score: float = _score_with_relationship_bias(float(entry.get("priority", 0)), entry, a_name, b_name)
		score -= _get_recent_history_penalty("chatter", entry, a_name)
		if score > best_score:
			best_score = score
			best = { "entry": entry, "walker_a": w_a, "walker_b": w_b }
	return best

func _start_ambient_chatter(data: Dictionary) -> void:
	_release_post_social_hold()
	var entry: Dictionary = data.get("entry", {})
	var lines: Array = _get_chatter_line_sequence(entry)
	if lines.is_empty():
		return
	_chatter_entry = entry
	_chatter_lines = lines
	_chatter_index = 0
	_chatter_walker_a = data.get("walker_a", null)
	_chatter_walker_b = data.get("walker_b", null)
	_chatter_social_settle_until = 0.0
	if _chatter_walker_a is CampRosterWalker and _chatter_walker_b is CampRosterWalker:
		var wa: CampRosterWalker = _chatter_walker_a as CampRosterWalker
		var wb: CampRosterWalker = _chatter_walker_b as CampRosterWalker
		var mid: Vector2 = (wa.global_position + wb.global_position) * 0.5
		var offset: Vector2 = (wa.global_position - wb.global_position)
		if offset.length() < 0.01:
			offset = Vector2(1, 0)
		offset = offset.normalized()
		var meet_a: Vector2 = mid + offset * CHATTER_SOCIAL_PAIR_OFFSET
		var meet_b: Vector2 = mid - offset * CHATTER_SOCIAL_PAIR_OFFSET
		wa.begin_social_move(meet_a)
		wb.begin_social_move(meet_b)
		_chatter_meetup_started_at = Time.get_ticks_msec() / 1000.0
	else:
		_chatter_meetup_started_at = 0.0
	_chatter_active = false

func _show_ambient_chatter_line() -> void:
	if _chatter_index < 0 or _chatter_index >= _chatter_lines.size():
		return
	_clear_chatter_speaking_state()
	var line: Dictionary = _chatter_lines[_chatter_index]
	var speaker: String = str(line.get("speaker", "")).strip_edges()
	var text: String = str(line.get("text", "")).strip_edges()
	var now: float = Time.get_ticks_msec() / 1000.0
	_chatter_current_until = now + _get_dynamic_ambient_duration(text, 2, CHATTER_LINE_DURATION)
	var speaker_walker: CampRosterWalker = null
	var other_walker: CampRosterWalker = null
	if _chatter_walker_a is CampRosterWalker and (_chatter_walker_a as CampRosterWalker).unit_name == speaker:
		speaker_walker = _chatter_walker_a as CampRosterWalker
		if _chatter_walker_b is CampRosterWalker:
			other_walker = _chatter_walker_b as CampRosterWalker
	elif _chatter_walker_b is CampRosterWalker and (_chatter_walker_b as CampRosterWalker).unit_name == speaker:
		speaker_walker = _chatter_walker_b as CampRosterWalker
		if _chatter_walker_a is CampRosterWalker:
			other_walker = _chatter_walker_a as CampRosterWalker
	if speaker_walker != null:
		if other_walker != null:
			speaker_walker.face_toward(other_walker.global_position)
			other_walker.face_toward(speaker_walker.global_position)
		speaker_walker.begin_speaking()
		if other_walker != null:
			other_walker.begin_listening()
	_record_ambient_history("chatter", _chatter_entry, speaker, _chatter_index == 0)
	_show_ambient_bubble(text, speaker_walker, speaker)

func _advance_ambient_chatter() -> void:
	_chatter_index += 1
	if _chatter_index >= _chatter_lines.size():
		_end_ambient_chatter()
		return
	_show_ambient_chatter_line()

func _end_ambient_chatter() -> void:
	_clear_chatter_speaking_state()
	var hold_min: float = float(_chatter_entry.get("follow_hold_min", SPONTANEOUS_SOCIAL_FOLLOW_HOLD_MIN))
	var hold_max: float = float(_chatter_entry.get("follow_hold_max", SPONTANEOUS_SOCIAL_FOLLOW_HOLD_MAX))
	_record_chatter_completion(_chatter_entry)
	var release_candidates: Array = []
	if _chatter_walker_a is CampRosterWalker:
		release_candidates.append(_chatter_walker_a)
	if _chatter_walker_b is CampRosterWalker:
		release_candidates.append(_chatter_walker_b)
	_chatter_active = false
	_chatter_lines.clear()
	_chatter_index = 0
	_chatter_entry = {}
	_chatter_meetup_started_at = 0.0
	_chatter_social_settle_until = 0.0
	_start_post_social_hold(release_candidates, hold_min, hold_max)
	_chatter_walker_a = null
	_chatter_walker_b = null
	_hide_ambient_bubble()
	var now: float = Time.get_ticks_msec() / 1000.0
	_chatter_next_attempt_time = now + randf_range(CHATTER_ATTEMPT_INTERVAL_MIN, CHATTER_ATTEMPT_INTERVAL_MAX)

func _clear_chatter_speaking_state() -> void:
	if _chatter_walker_a is CampRosterWalker:
		var wa: CampRosterWalker = _chatter_walker_a as CampRosterWalker
		wa.end_speaking()
		wa.end_listening()
	if _chatter_walker_b is CampRosterWalker:
		var wb: CampRosterWalker = _chatter_walker_b as CampRosterWalker
		wb.end_speaking()
		wb.end_listening()

func _cancel_pending_ambient_chatter() -> void:
	_clear_chatter_speaking_state()
	_chatter_active = false
	_chatter_lines.clear()
	_chatter_index = 0
	_chatter_entry = {}
	_chatter_meetup_started_at = 0.0
	_chatter_social_settle_until = 0.0
	if _chatter_walker_a is CampRosterWalker:
		(_chatter_walker_a as CampRosterWalker).end_social_move()
	if _chatter_walker_b is CampRosterWalker:
		(_chatter_walker_b as CampRosterWalker).end_social_move()
	_chatter_walker_a = null
	_chatter_walker_b = null
	_hide_ambient_bubble()
	var now: float = Time.get_ticks_msec() / 1000.0
	_chatter_next_attempt_time = now + randf_range(CHATTER_ATTEMPT_INTERVAL_MIN, CHATTER_ATTEMPT_INTERVAL_MAX)

func _update_social_hold(now: float) -> void:
	if _social_hold_release_at <= 0.0:
		return
	if now < _social_hold_release_at:
		return
	_release_post_social_hold()

func _start_post_social_hold(walkers: Array, min_duration: float = SPONTANEOUS_SOCIAL_FOLLOW_HOLD_MIN, max_duration: float = SPONTANEOUS_SOCIAL_FOLLOW_HOLD_MAX) -> void:
	_release_post_social_hold()
	for node in walkers:
		if not (node is CampRosterWalker):
			continue
		var walker: CampRosterWalker = node as CampRosterWalker
		if not is_instance_valid(walker):
			continue
		if walker in _social_hold_walkers:
			continue
		walker.begin_social_move(walker.global_position)
		_social_hold_walkers.append(walker)
	if _social_hold_walkers.is_empty():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var min_d: float = maxf(0.2, min_duration)
	var max_d: float = maxf(min_d, max_duration)
	_social_hold_release_at = now + randf_range(min_d, max_d)

func _release_post_social_hold() -> void:
	for node in _social_hold_walkers:
		if node is CampRosterWalker and is_instance_valid(node):
			(node as CampRosterWalker).end_social_move()
	_social_hold_walkers.clear()
	_social_hold_release_at = 0.0

func _pick_visit_non_repeat_index(event_key: String, option_count: int) -> int:
	if option_count <= 0:
		return -1
	if option_count == 1:
		return 0
	var key: String = str(event_key).strip_edges()
	if key == "":
		return randi() % option_count
	var last_index: int = int(_ambient_line_last_variant_by_event.get(key, -1))
	var idx: int = randi() % option_count
	if idx == last_index:
		idx = (idx + 1 + int(randi() % (option_count - 1))) % option_count
	_ambient_line_last_variant_by_event[key] = idx
	return idx

func _get_chatter_line_sequence(entry: Dictionary) -> Array:
	var variants: Array = []
	var base_lines: Variant = entry.get("lines", [])
	if base_lines is Array and not (base_lines as Array).is_empty():
		variants.append((base_lines as Array))
	var alt_variants_v: Variant = entry.get("line_variants", [])
	if alt_variants_v is Array:
		for seq_v in alt_variants_v:
			if seq_v is Array and not (seq_v as Array).is_empty():
				variants.append(seq_v as Array)
	if variants.is_empty():
		return []
	var entry_id: String = str(entry.get("id", "")).strip_edges()
	var key: String = "chatter:%s" % entry_id if entry_id != "" else ""
	var idx: int = _pick_visit_non_repeat_index(key, variants.size())
	if idx < 0:
		return []
	var chosen: Variant = variants[idx]
	if chosen is Array:
		return (chosen as Array).duplicate(true)
	return []

func _get_best_spontaneous_social_candidate() -> Dictionary:
	var context: Dictionary = _build_camp_context()
	var best: Dictionary = {}
	var best_score: float = -99999.0
	for entry_variant in CAMP_AMBIENT_SOCIAL_DB.get_all_entries():
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if entry.get("once_per_visit", false):
			var sid: String = str(entry.get("id", "")).strip_edges()
			if sid != "" and bool(_spontaneous_social_shown_this_visit.get(sid, false)):
				continue
		if not CAMP_AMBIENT_SOCIAL_DB.when_matches(entry, context):
			continue
		var kind: String = str(entry.get("kind", "passing_remark")).strip_edges().to_lower()
		var candidate: Dictionary = {}
		match kind:
			"small_cluster", "opportunistic_cluster":
				candidate = _build_spontaneous_cluster_candidate(entry)
			_:
				candidate = _build_spontaneous_passing_candidate(entry)
		if candidate.is_empty():
			continue
		var speaker_name: String = str(entry.get("speaker", "")).strip_edges()
		var score: float = float(candidate.get("score", float(entry.get("priority", 0))))
		score -= _get_recent_history_penalty("social", entry, speaker_name)
		if score > best_score:
			best_score = score
			best = candidate
	return best

func _build_spontaneous_passing_candidate(entry: Dictionary) -> Dictionary:
	var speaker_name: String = str(entry.get("speaker", "")).strip_edges()
	var listener_name: String = str(entry.get("listener", "")).strip_edges()
	if speaker_name == "":
		return {}
	var speaker_node: Node = _find_walker_by_name(speaker_name)
	if not (speaker_node is CampRosterWalker):
		return {}
	var speaker_walker: CampRosterWalker = speaker_node as CampRosterWalker
	if not speaker_walker.is_available_for_social():
		return {}
	var listener_walker: CampRosterWalker = null
	if listener_name != "":
		var listener_node: Node = _find_walker_by_name(listener_name)
		if not (listener_node is CampRosterWalker):
			return {}
		listener_walker = listener_node as CampRosterWalker
		if listener_walker == speaker_walker:
			return {}
		if not listener_walker.is_available_for_social():
			return {}
		if not _pair_memory_matches(entry, speaker_name, listener_name):
			return {}
	if not _content_condition_matches(entry, speaker_name, listener_name):
		return {}
	if entry.has("zone_type"):
		var zt: String = str(entry.get("zone_type", "")).strip_edges()
		if zt != "":
			var speaker_near: bool = _is_walker_near_zone(speaker_walker, zt)
			var listener_near: bool = listener_walker != null and _is_walker_near_zone(listener_walker, zt)
			if not speaker_near and not listener_near:
				return {}
	var pair_radius: float = float(entry.get("pair_radius", CAMP_AMBIENT_SOCIAL_DB.SOCIAL_DEFAULT_PAIR_RADIUS))
	if listener_walker != null and not _are_walkers_near_each_other(speaker_walker, listener_walker, pair_radius):
		return {}
	var center: Vector2 = speaker_walker.global_position
	if listener_walker != null:
		center = (speaker_walker.global_position + listener_walker.global_position) * 0.5
	var overhear_radius: float = float(entry.get("radius", CAMP_AMBIENT_SOCIAL_DB.SOCIAL_DEFAULT_RADIUS))
	if player.global_position.distance_squared_to(center) > overhear_radius * overhear_radius:
		return {}
	var lines: Array = _get_spontaneous_social_sequence(entry)
	if lines.is_empty():
		return {}
	var score: float = float(entry.get("priority", 0))
	if listener_walker != null:
		score = _score_with_relationship_bias(score, entry, speaker_name, listener_name)
	var participants: Array = [speaker_walker]
	if listener_walker != null:
		participants.append(listener_walker)
	var observers: Array = _collect_passing_observers(entry, participants, center)
	for observer in observers:
		participants.append(observer)
	score += float(observers.size()) * 0.12
	return {
		"kind": "passing_remark",
		"entry": entry,
		"score": score,
		"participants": participants,
		"speaker_walker": speaker_walker,
		"lines": lines,
	}

func _build_spontaneous_cluster_candidate(entry: Dictionary) -> Dictionary:
	var required_units: Array = entry.get("required_units", [])
	if required_units.size() < 2:
		return {}
	var participants: Array = []
	for unit_name_variant in required_units:
		var unit_name: String = str(unit_name_variant).strip_edges()
		if unit_name == "":
			return {}
		var node: Node = _find_walker_by_name(unit_name)
		if not (node is CampRosterWalker):
			return {}
		var walker: CampRosterWalker = node as CampRosterWalker
		if not walker.is_available_for_social():
			return {}
		participants.append(walker)
	var speaker_name: String = str(entry.get("speaker", "")).strip_edges()
	if speaker_name == "":
		speaker_name = str(required_units[0]).strip_edges()
	var speaker_walker: CampRosterWalker = _get_walker_by_name(speaker_name)
	if speaker_walker == null or speaker_walker not in participants:
		return {}
	if not _content_condition_matches(entry, speaker_name):
		return {}
	var lines: Array = _get_spontaneous_social_sequence(entry)
	if lines.is_empty():
		return {}
	var cluster_radius: float = float(entry.get("cluster_radius", CAMP_AMBIENT_SOCIAL_DB.SOCIAL_DEFAULT_CLUSTER_RADIUS))
	var center_seed: Vector2 = _get_social_group_center(participants)
	if entry.has("zone_type"):
		var zt: String = str(entry.get("zone_type", "")).strip_edges()
		if zt != "":
			var any_near_zone: bool = false
			for p in participants:
				if _is_walker_near_zone(p, zt):
					any_near_zone = true
					break
			if not any_near_zone:
				return {}
	var optional_units_v: Variant = entry.get("optional_units", [])
	var optional_candidates: Array = []
	if optional_units_v is Array:
		var recruit_radius: float = float(entry.get("observer_radius", maxf(cluster_radius * 1.15, SPONTANEOUS_SOCIAL_OBSERVER_RADIUS)))
		for unit_name_variant2 in optional_units_v:
			var optional_name: String = str(unit_name_variant2).strip_edges()
			if optional_name == "":
				continue
			var optional_walker: CampRosterWalker = _get_walker_by_name(optional_name)
			if optional_walker == null or optional_walker in participants:
				continue
			if not optional_walker.is_available_for_social():
				continue
			var dist_sq: float = optional_walker.global_position.distance_squared_to(center_seed)
			if dist_sq > recruit_radius * recruit_radius:
				continue
			optional_candidates.append({ "walker": optional_walker, "dist_sq": dist_sq })
		optional_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("dist_sq", 0.0)) < float(b.get("dist_sq", 0.0))
		)
	var min_participants: int = maxi(3, int(entry.get("min_participants", required_units.size())))
	var max_participants: int = maxi(min_participants, int(entry.get("max_participants", min_participants)))
	for candidate in optional_candidates:
		if participants.size() >= max_participants:
			break
		participants.append(candidate.get("walker"))
	if participants.size() < min_participants:
		return {}
	var center: Vector2 = _get_social_group_center(participants)
	for p in participants:
		if (p as CampRosterWalker).global_position.distance_squared_to(center) > cluster_radius * cluster_radius:
			return {}
	var overhear_radius: float = float(entry.get("radius", CAMP_AMBIENT_SOCIAL_DB.SOCIAL_DEFAULT_RADIUS))
	if player.global_position.distance_squared_to(center) > overhear_radius * overhear_radius:
		return {}
	var score: float = float(entry.get("priority", 0))
	var pair_count: int = 0
	for p in participants:
		var walker2: CampRosterWalker = p as CampRosterWalker
		if walker2 == speaker_walker:
			continue
		score += _get_pair_social_bias(speaker_walker.unit_name, walker2.unit_name)
		pair_count += 1
	if pair_count > 0:
		score /= float(pair_count + 1)
	return {
		"kind": "small_cluster",
		"entry": entry,
		"score": score,
		"participants": participants,
		"speaker_walker": speaker_walker,
		"lines": lines,
	}

func _start_spontaneous_social(data: Dictionary) -> void:
	_release_post_social_hold()
	var entry: Dictionary = data.get("entry", {})
	var lines: Array = data.get("lines", [])
	if lines.is_empty():
		lines = _get_spontaneous_social_sequence(entry)
	if lines.is_empty():
		return
	var participants: Array = _get_valid_social_participants(data.get("participants", []))
	if participants.is_empty():
		return
	var speaker_node: Node = data.get("speaker_walker", null)
	var speaker_walker: CampRosterWalker = null
	if speaker_node is CampRosterWalker:
		speaker_walker = speaker_node as CampRosterWalker
	_spontaneous_social_active = false
	_spontaneous_social_entry = entry
	_spontaneous_social_participants = participants.duplicate()
	_spontaneous_social_speaker = speaker_walker
	_spontaneous_social_lines = lines.duplicate(true)
	_spontaneous_social_index = 0
	_spontaneous_social_current_until = 0.0
	_spontaneous_social_meetup_started_at = Time.get_ticks_msec() / 1000.0
	_spontaneous_social_settle_until = 0.0
	_apply_spontaneous_social_formation(_spontaneous_social_participants, speaker_walker)

func _end_spontaneous_social() -> void:
	var participants: Array = _spontaneous_social_participants.duplicate()
	_clear_spontaneous_social_speaking_state()
	var hold_chance: float = clampf(float(_spontaneous_social_entry.get("follow_hold_chance", 0.45)), 0.0, 1.0)
	var hold_min: float = float(_spontaneous_social_entry.get("follow_hold_min", SPONTANEOUS_SOCIAL_FOLLOW_HOLD_MIN))
	var hold_max: float = float(_spontaneous_social_entry.get("follow_hold_max", SPONTANEOUS_SOCIAL_FOLLOW_HOLD_MAX))
	if participants.size() >= 2 and randf() < hold_chance:
		_start_post_social_hold(participants, hold_min, hold_max)
	else:
		for p in participants:
			if p is CampRosterWalker and is_instance_valid(p):
				(p as CampRosterWalker).end_social_move()
	_spontaneous_social_active = false
	_spontaneous_social_entry = {}
	_spontaneous_social_participants.clear()
	_spontaneous_social_speaker = null
	_spontaneous_social_lines.clear()
	_spontaneous_social_index = 0
	_spontaneous_social_current_until = 0.0
	_spontaneous_social_meetup_started_at = 0.0
	_spontaneous_social_settle_until = 0.0
	_hide_ambient_bubble()
	var now: float = Time.get_ticks_msec() / 1000.0
	_rumor_cooldown_until = maxf(_rumor_cooldown_until, now + SPONTANEOUS_SOCIAL_COOLDOWN)
	_spontaneous_social_next_attempt_time = now + randf_range(SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MIN, SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MAX)


func _get_dynamic_ambient_duration(text: String, participant_count: int, base_duration: float) -> float:
	var line_text: String = str(text).strip_edges()
	var extra_steps: float = maxf(0.0, float(line_text.length() - 32) / AMBIENT_TEXT_BONUS_CHAR_STEP)
	var participant_bonus: float = float(maxi(0, participant_count - 1)) * 0.12
	return clampf(base_duration + extra_steps * AMBIENT_TEXT_BONUS_PER_STEP + participant_bonus, AMBIENT_LINE_DURATION_MIN, AMBIENT_LINE_DURATION_MAX)

func _push_recent_string(history: Array, value: String, max_size: int) -> void:
	var key: String = str(value).strip_edges()
	if key == "":
		return
	if key in history:
		history.erase(key)
	history.push_front(key)
	while history.size() > max_size:
		history.pop_back()

func _get_ambient_entry_key(event_type: String, entry: Dictionary, fallback_speaker: String = "") -> String:
	var entry_id: String = str(entry.get("id", "")).strip_edges()
	if entry_id != "":
		return "%s:%s" % [event_type, entry_id]
	var speaker: String = str(fallback_speaker).strip_edges()
	if speaker == "":
		speaker = str(entry.get("speaker", "")).strip_edges()
	if speaker == "":
		speaker = str(entry.get("unit_a", "")).strip_edges()
	if speaker == "":
		speaker = "unknown"
	return "%s:%s" % [event_type, speaker]

func _get_recent_history_penalty(event_type: String, entry: Dictionary, speaker_name: String = "") -> float:
	var penalty: float = 0.0
	var event_key: String = _get_ambient_entry_key(event_type, entry, speaker_name)
	var event_index: int = _ambient_recent_event_keys.find(event_key)
	if event_index >= 0:
		penalty += maxf(0.3, AMBIENT_RECENT_EVENT_PENALTY - float(event_index) * 0.3)
	var speaker: String = str(speaker_name).strip_edges()
	if speaker != "":
		var speaker_index: int = _ambient_recent_speakers.find(speaker)
		if speaker_index >= 0:
			penalty += maxf(0.15, AMBIENT_RECENT_SPEAKER_PENALTY - float(speaker_index) * 0.25)
	return penalty

func _record_ambient_history(event_type: String, entry: Dictionary, speaker_name: String = "", record_event: bool = true) -> void:
	var speaker: String = str(speaker_name).strip_edges()
	if speaker != "":
		_push_recent_string(_ambient_recent_speakers, speaker, AMBIENT_RECENT_SPEAKER_MAX)
	if record_event:
		_push_recent_string(_ambient_recent_event_keys, _get_ambient_entry_key(event_type, entry, speaker_name), AMBIENT_RECENT_EVENT_MAX)

func _get_entry_text_with_variants(entry: Dictionary, event_type: String) -> String:
	var options: Array = []
	var base_text: String = str(entry.get("text", "")).strip_edges()
	if base_text != "":
		options.append(base_text)
	var variants_v: Variant = entry.get("text_variants", [])
	if variants_v is Array:
		for option_v in variants_v:
			var option_text: String = str(option_v).strip_edges()
			if option_text != "":
				options.append(option_text)
	if options.is_empty():
		return ""
	var entry_id: String = str(entry.get("id", "")).strip_edges()
	var key: String = "%s:text:%s" % [event_type, entry_id] if entry_id != "" else ""
	var idx: int = _pick_visit_non_repeat_index(key, options.size())
	if idx < 0 or idx >= options.size():
		return ""
	return str(options[idx]).strip_edges()

func _normalize_spontaneous_line(raw_line: Variant, fallback_speaker: String) -> Dictionary:
	if raw_line is Dictionary:
		var d: Dictionary = raw_line
		var speaker: String = str(d.get("speaker", fallback_speaker)).strip_edges()
		var text: String = str(d.get("text", "")).strip_edges()
		if text == "":
			return {}
		return { "speaker": speaker, "text": text }
	var simple_text: String = str(raw_line).strip_edges()
	if simple_text == "":
		return {}
	return { "speaker": str(fallback_speaker).strip_edges(), "text": simple_text }

func _get_spontaneous_social_sequence(entry: Dictionary) -> Array:
	var fallback_speaker: String = str(entry.get("speaker", "")).strip_edges()
	var variants: Array = []
	var sequence_variants: Variant = entry.get("line_sequences", [])
	if sequence_variants is Array:
		for seq_v in sequence_variants:
			if not (seq_v is Array):
				continue
			var seq_norm: Array = []
			for raw_line in (seq_v as Array):
				var line_dict: Dictionary = _normalize_spontaneous_line(raw_line, fallback_speaker)
				if not line_dict.is_empty():
					seq_norm.append(line_dict)
			if not seq_norm.is_empty():
				variants.append(seq_norm)
	var lines_v: Variant = entry.get("lines", [])
	if lines_v is Array:
		for raw_variant in (lines_v as Array):
			var line_single: Dictionary = _normalize_spontaneous_line(raw_variant, fallback_speaker)
			if not line_single.is_empty():
				variants.append([line_single])
	var line_variants_v: Variant = entry.get("line_variants", [])
	if line_variants_v is Array:
		for variant_v in (line_variants_v as Array):
			if variant_v is Array:
				var seq_variant: Array = []
				for raw_line2 in (variant_v as Array):
					var line_dict2: Dictionary = _normalize_spontaneous_line(raw_line2, fallback_speaker)
					if not line_dict2.is_empty():
						seq_variant.append(line_dict2)
				if not seq_variant.is_empty():
					variants.append(seq_variant)
			else:
				var line_variant_dict: Dictionary = _normalize_spontaneous_line(variant_v, fallback_speaker)
				if not line_variant_dict.is_empty():
					variants.append([line_variant_dict])
	if variants.is_empty():
		return []
	var entry_id: String = str(entry.get("id", "")).strip_edges()
	var key: String = "spont_seq:%s" % entry_id if entry_id != "" else ""
	var idx: int = _pick_visit_non_repeat_index(key, variants.size())
	if idx < 0 or idx >= variants.size():
		return []
	var chosen: Variant = variants[idx]
	if chosen is Array:
		return (chosen as Array).duplicate(true)
	return []

func _get_valid_social_participants(participants: Array) -> Array:
	var out: Array = []
	for p in participants:
		if not (p is CampRosterWalker) or not is_instance_valid(p):
			continue
		if p in out:
			continue
		out.append(p)
	return out

func _get_social_group_center(participants: Array) -> Vector2:
	var valid: Array = _get_valid_social_participants(participants)
	if valid.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for p in valid:
		center += (p as CampRosterWalker).global_position
	return center / float(valid.size())

func _apply_spontaneous_social_formation(participants: Array, speaker_walker: CampRosterWalker = null) -> void:
	var valid: Array = _get_valid_social_participants(participants)
	if valid.is_empty():
		return
	var center: Vector2 = _get_social_group_center(valid)
	if valid.size() == 1:
		(valid[0] as CampRosterWalker).begin_social_move((valid[0] as CampRosterWalker).global_position)
		return
	if valid.size() == 2:
		var a: CampRosterWalker = valid[0] as CampRosterWalker
		var b: CampRosterWalker = valid[1] as CampRosterWalker
		var dir: Vector2 = a.global_position - b.global_position
		if dir.length() < 0.01:
			dir = Vector2.RIGHT
		dir = dir.normalized()
		var midpoint: Vector2 = (a.global_position + b.global_position) * 0.5
		a.begin_social_move(midpoint + dir * SPONTANEOUS_SOCIAL_PAIR_OFFSET)
		b.begin_social_move(midpoint - dir * SPONTANEOUS_SOCIAL_PAIR_OFFSET)
		return
	var ordered: Array = valid.duplicate()
	if speaker_walker != null and speaker_walker in ordered:
		ordered.erase(speaker_walker)
		ordered.push_front(speaker_walker)
	var count: int = ordered.size()
	var radius: float = SPONTANEOUS_SOCIAL_FORMATION_RADIUS + float(maxi(0, count - 3)) * 4.0
	for i in range(count):
		var walker: CampRosterWalker = ordered[i] as CampRosterWalker
		var angle: float = -PI * 0.5 + TAU * float(i) / float(count)
		var target: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		walker.begin_social_move(target)

func _get_social_participant_by_name(participants: Array, unit_name: String) -> CampRosterWalker:
	var key: String = str(unit_name).strip_edges()
	if key == "":
		return null
	for p in participants:
		if not (p is CampRosterWalker) or not is_instance_valid(p):
			continue
		var walker: CampRosterWalker = p as CampRosterWalker
		if walker.unit_name == key:
			return walker
	return null

func _clear_spontaneous_social_speaking_state() -> void:
	for p in _spontaneous_social_participants:
		if not (p is CampRosterWalker) or not is_instance_valid(p):
			continue
		var walker: CampRosterWalker = p as CampRosterWalker
		walker.end_speaking()
		walker.end_listening()

func _show_spontaneous_social_line() -> void:
	if _spontaneous_social_index < 0 or _spontaneous_social_index >= _spontaneous_social_lines.size():
		return
	_clear_spontaneous_social_speaking_state()
	var line: Dictionary = _spontaneous_social_lines[_spontaneous_social_index]
	var speaker_name: String = str(line.get("speaker", "")).strip_edges()
	var text: String = str(line.get("text", "")).strip_edges()
	var speaker_walker: CampRosterWalker = _get_social_participant_by_name(_spontaneous_social_participants, speaker_name)
	var center: Vector2 = _get_social_group_center(_spontaneous_social_participants)
	for p in _spontaneous_social_participants:
		if not (p is CampRosterWalker) or not is_instance_valid(p):
			continue
		var walker: CampRosterWalker = p as CampRosterWalker
		if speaker_walker != null and walker == speaker_walker:
			var focus_target: Vector2 = center
			for other in _spontaneous_social_participants:
				if other is CampRosterWalker and other != walker and is_instance_valid(other):
					focus_target = (other as CampRosterWalker).global_position
					break
			walker.face_toward(focus_target)
			walker.begin_speaking()
		else:
			if speaker_walker != null:
				walker.face_toward(speaker_walker.global_position)
			walker.begin_listening()
	_record_ambient_history("social", _spontaneous_social_entry, speaker_name, _spontaneous_social_index == 0)
	_show_ambient_bubble(text, speaker_walker, speaker_name)
	var now: float = Time.get_ticks_msec() / 1000.0
	_spontaneous_social_current_until = now + _get_dynamic_ambient_duration(text, _spontaneous_social_participants.size(), float(_spontaneous_social_entry.get("duration", SPONTANEOUS_SOCIAL_LINE_DURATION)))

func _advance_spontaneous_social() -> void:
	_spontaneous_social_index += 1
	if _spontaneous_social_index >= _spontaneous_social_lines.size():
		_end_spontaneous_social()
		return
	_show_spontaneous_social_line()

func _cancel_pending_spontaneous_social() -> void:
	_clear_spontaneous_social_speaking_state()
	for p in _spontaneous_social_participants:
		if p is CampRosterWalker and is_instance_valid(p):
			(p as CampRosterWalker).end_social_move()
	_spontaneous_social_active = false
	_spontaneous_social_entry = {}
	_spontaneous_social_participants.clear()
	_spontaneous_social_speaker = null
	_spontaneous_social_lines.clear()
	_spontaneous_social_index = 0
	_spontaneous_social_current_until = 0.0
	_spontaneous_social_meetup_started_at = 0.0
	_spontaneous_social_settle_until = 0.0
	_hide_ambient_bubble()
	var now: float = Time.get_ticks_msec() / 1000.0
	_spontaneous_social_next_attempt_time = now + randf_range(SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MIN, SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MAX)

func _collect_passing_observers(entry: Dictionary, existing_participants: Array, center: Vector2) -> Array:
	var max_observers: int = mini(clampi(int(entry.get("max_observers", 0)), 0, SPONTANEOUS_SOCIAL_MAX_OBSERVERS), SPONTANEOUS_SOCIAL_MAX_OBSERVERS)
	if max_observers <= 0:
		return []
	var observer_units_v: Variant = entry.get("observer_units", [])
	if not (observer_units_v is Array):
		return []
	var observer_radius: float = float(entry.get("observer_radius", SPONTANEOUS_SOCIAL_OBSERVER_RADIUS))
	var candidates: Array = []
	for unit_name_v in observer_units_v:
		var unit_name: String = str(unit_name_v).strip_edges()
		if unit_name == "":
			continue
		var observer: CampRosterWalker = _get_walker_by_name(unit_name)
		if observer == null or observer in existing_participants:
			continue
		if not observer.is_available_for_social():
			continue
		var dist_sq: float = observer.global_position.distance_squared_to(center)
		if dist_sq > observer_radius * observer_radius:
			continue
		candidates.append({ "walker": observer, "dist_sq": dist_sq })
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("dist_sq", 0.0)) < float(b.get("dist_sq", 0.0))
	)
	var out: Array = []
	for candidate in candidates:
		if out.size() >= max_observers:
			break
		out.append(candidate.get("walker"))
	return out

func _get_walker_by_name(unit_name: String) -> CampRosterWalker:
	var node: Node = _find_walker_by_name(unit_name)
	if node is CampRosterWalker:
		return node as CampRosterWalker
	return null

func _show_ambient_bubble(text: String, speaker_walker: CampRosterWalker, speaker_name: String = "") -> void:
	var bubble_text: String = str(text).strip_edges()
	if bubble_text == "":
		_hide_ambient_bubble()
		return
	var debug_speaker_name: String = str(speaker_name).strip_edges()
	if ambient_speech_bubble != null and ambient_speech_text != null:
		if not is_instance_valid(speaker_walker):
			if rumor_label != null:
				var prefix_no_speaker: String = ""
				if debug_speaker_name != "":
					prefix_no_speaker = "%s: " % debug_speaker_name
				rumor_label.text = prefix_no_speaker + bubble_text
				rumor_label.visible = true
			_ambient_bubble_speaker = null
			ambient_speech_bubble.visible = false
			return
		ambient_speech_text.text = bubble_text
		if ambient_speech_name != null:
			ambient_speech_name.text = debug_speaker_name
			ambient_speech_name.visible = debug_speaker_name != ""
		_ambient_bubble_speaker = speaker_walker
		ambient_speech_bubble.visible = true
		_update_ambient_bubble_position()
		if rumor_label != null:
			rumor_label.visible = false
			rumor_label.text = ""
		return
	if rumor_label != null:
		var prefix: String = ""
		var fallback_name: String = str(speaker_name).strip_edges()
		if fallback_name != "":
			prefix = "%s: " % fallback_name
		rumor_label.text = prefix + bubble_text
		rumor_label.visible = true
	_ambient_bubble_speaker = null

func _hide_ambient_bubble() -> void:
	_ambient_bubble_speaker = null
	if ambient_speech_bubble != null:
		ambient_speech_bubble.visible = false
	if rumor_label != null:
		rumor_label.visible = false
		rumor_label.text = ""

func _update_ambient_bubble_position() -> void:
	if ambient_speech_bubble == null or not ambient_speech_bubble.visible:
		return
	if not is_instance_valid(_ambient_bubble_speaker):
		_hide_ambient_bubble()
		return
	var world_pos: Vector2 = _ambient_bubble_speaker.global_position + Vector2(0.0, -AMBIENT_BUBBLE_WORLD_Y_OFFSET)
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	var bubble_size: Vector2 = ambient_speech_bubble.size
	if bubble_size.x <= 1.0 or bubble_size.y <= 1.0:
		bubble_size = ambient_speech_bubble.get_combined_minimum_size()
	var target: Vector2 = screen_pos - Vector2(bubble_size.x * 0.5, bubble_size.y)
	var view_size: Vector2 = get_viewport_rect().size
	target.x = clampf(target.x, 8.0, maxf(8.0, view_size.x - bubble_size.x - 8.0))
	target.y = clampf(target.y, 8.0, maxf(8.0, view_size.y - bubble_size.y - 8.0))
	ambient_speech_bubble.position = target

func _get_eligible_pair_scene() -> Dictionary:
	var context: Dictionary = _build_camp_context()
	var best: Dictionary = {}
	var best_score: float = -99999.0
	for scene in CAMP_PAIR_SCENE_TRIGGER_DB.get_all_trigger_scenes():
		if not (scene is Dictionary):
			continue
		var s: Dictionary = scene
		if not CAMP_PAIR_SCENE_TRIGGER_DB.when_matches(s, context):
			continue
		var a_name: String = str(s.get("unit_a", "")).strip_edges()
		var b_name: String = str(s.get("unit_b", "")).strip_edges()
		if a_name.is_empty() or b_name.is_empty():
			continue
		if not _content_condition_matches(s, a_name, b_name):
			continue
		var min_familiarity: int = int(s.get("min_familiarity", 0))
		if _get_pair_familiarity(a_name, b_name) < min_familiarity:
			continue
		if bool(s.get("once_ever", false)):
			var sid_ever: String = str(s.get("id", "")).strip_edges()
			if sid_ever != "" and CampaignManager and CampaignManager.has_seen_camp_memory_scene(sid_ever):
				continue
		var w_a: Node = _find_walker_by_name(a_name)
		var w_b: Node = _find_walker_by_name(b_name)
		if w_a == null or w_b == null or w_a == w_b:
			continue
		var pair_radius: float = float(s.get("pair_radius", CAMP_PAIR_SCENE_TRIGGER_DB.PAIR_LISTEN_RADIUS_DEFAULT)) * 1.08
		if not _are_walkers_near_each_other(w_a, w_b, pair_radius):
			continue
		if s.has("zone_type"):
			var zt: String = str(s.get("zone_type", "")).strip_edges()
			if zt != "" and not _is_walker_near_zone(w_a, zt) and not _is_walker_near_zone(w_b, zt):
				continue
		var mid: Vector2 = (w_a.global_position + w_b.global_position) * 0.5
		var dist_sq_player: float = minf(
			player.global_position.distance_squared_to(w_a.global_position),
			minf(
				player.global_position.distance_squared_to(w_b.global_position),
				player.global_position.distance_squared_to(mid)
			)
		)
		if dist_sq_player > PAIR_LISTEN_RADIUS * PAIR_LISTEN_RADIUS:
			continue
		if s.get("once_per_visit", false):
			var sid: String = str(s.get("id", "")).strip_edges()
			if sid != "" and _pair_scenes_shown_this_visit.get(sid, false):
				continue
		var prio: float = float(s.get("priority", 0))
		var score: float = _score_with_relationship_bias(prio, s, a_name, b_name)
		if score > best_score:
			best_score = score
			best = { "scene": s, "walker_a": w_a, "walker_b": w_b }
	return best

func _is_pair_scene_available() -> bool:
	return not _get_eligible_pair_scene().is_empty()

func _would_single_walker_priority(nearest: Node) -> bool:
	if nearest == null or not (nearest is CampRosterWalker):
		return false
	var unit_name: String = (nearest as CampRosterWalker).unit_name
	var status: String = _get_camp_request_status()
	var giver: String = str(CampaignManager.camp_request_giver_name).strip_edges() if CampaignManager else ""
	if status == "failed" and unit_name == giver:
		return true
	if status == "ready_to_turn_in" and unit_name == giver:
		return true
	if status == "active" and unit_name == giver:
		return true
	if status == "active" and CampaignManager and str(CampaignManager.camp_request_type) == CampRequestDB.TYPE_ITEM_DELIVERY and unit_name == giver:
		return true
	if status == "active" and CampaignManager and str(CampaignManager.camp_request_type) == CampRequestDB.TYPE_TALK_TO_UNIT:
		var target: String = str(CampaignManager.camp_request_target_name).strip_edges()
		if unit_name == target:
			return true
	if status != "active" and status != "ready_to_turn_in" and status != "failed" and CampaignManager and unit_name != "":
		var tier: String = CampaignManager.get_avatar_relationship_tier(unit_name)
		for scene_tier in ["close", "trusted"]:
			var scene: Dictionary = CampRequestContentDB.get_special_camp_scene(unit_name, scene_tier)
			if not scene.is_empty() and not scene.get("lines", []).is_empty():
				var tier_ok: bool = (scene_tier == "close" and tier in ["close", "bonded"]) or (scene_tier == "trusted" and tier in ["trusted", "close", "bonded"])
				if tier_ok and not (scene.get("one_time", true) and CampaignManager.has_seen_special_scene(unit_name, scene_tier)):
					return true
		if CampaignManager.get_available_pair_scene_for_unit(unit_name).is_empty() == false:
			return true
		if CampaignManager.get_available_camp_lore(unit_name).is_empty() == false:
			return true
	if _offer_giver_name == unit_name:
		return true
	return false

func _start_pair_scene(data: Dictionary) -> void:
	var scene: Dictionary = data.get("scene", {})
	var lines: Array = scene.get("lines", [])
	if lines.is_empty():
		return
	_pair_scene_active = true
	_dialogue_active = true
	_pair_scene_lines = lines
	_pair_scene_index = 0
	_pair_scene_data = scene
	_pair_scene_walker_a = data.get("walker_a", null)
	_pair_scene_walker_b = data.get("walker_b", null)
	for w in _walker_nodes:
		if w is CampRosterWalker:
			(w as CampRosterWalker).set_wander_paused(true)
	if interact_prompt:
		interact_prompt.visible = false
	if dialogue_panel:
		dialogue_panel.visible = true
	_show_pair_scene_line()

func _show_pair_scene_line() -> void:
	if _pair_scene_index < 0 or _pair_scene_index >= _pair_scene_lines.size():
		return
	var line: Dictionary = _pair_scene_lines[_pair_scene_index]
	var speaker: String = str(line.get("speaker", "")).strip_edges()
	var text: String = str(line.get("text", "")).strip_edges()
	if dialogue_name:
		dialogue_name.text = speaker
	if dialogue_text:
		dialogue_text.text = text
	var walker_for_portrait: Node = null
	if _pair_scene_walker_a != null and _pair_scene_walker_a is CampRosterWalker and ( _pair_scene_walker_a as CampRosterWalker).unit_name == speaker:
		walker_for_portrait = _pair_scene_walker_a
	elif _pair_scene_walker_b != null and _pair_scene_walker_b is CampRosterWalker and (_pair_scene_walker_b as CampRosterWalker).unit_name == speaker:
		walker_for_portrait = _pair_scene_walker_b
	if dialogue_portrait and walker_for_portrait is CampRosterWalker:
		var roster_entry: Dictionary = (walker_for_portrait as CampRosterWalker).unit_data
		var tex: Variant = roster_entry.get("portrait", null)
		dialogue_portrait.texture = tex if tex is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	else:
		if dialogue_portrait:
			dialogue_portrait.visible = false
	_hide_request_buttons()
	if dialogue_close_btn:
		dialogue_close_btn.visible = true
		dialogue_close_btn.text = "Continue" if _pair_scene_index < _pair_scene_lines.size() - 1 else "Close"
	if dialogue_panel:
		dialogue_panel.visible = true

func _advance_pair_scene() -> void:
	_pair_scene_index += 1
	if _pair_scene_index >= _pair_scene_lines.size():
		_end_pair_scene()
		return
	_show_pair_scene_line()

func _end_pair_scene() -> void:
	var scene: Dictionary = _pair_scene_data
	if scene.get("once_per_visit", false):
		var sid: String = str(scene.get("id", "")).strip_edges()
		if sid != "":
			_pair_scenes_shown_this_visit[sid] = true
	_record_pair_scene_completion(scene)
	_pair_scene_active = false
	_dialogue_active = false
	_pair_scene_lines.clear()
	_pair_scene_index = 0
	_pair_scene_data = {}
	_pair_scene_walker_a = null
	_pair_scene_walker_b = null
	for w in _walker_nodes:
		if w is CampRosterWalker:
			(w as CampRosterWalker).set_wander_paused(false)
	if dialogue_panel:
		dialogue_panel.visible = false
	_hide_request_buttons()
	if dialogue_close_btn:
		dialogue_close_btn.text = "Close"

func _get_eligible_micro_bark() -> Dictionary:
	var context: Dictionary = _build_camp_context()
	var best: Dictionary = {}
	var best_score: float = -99999.0
	for entry in CAMP_MICRO_BARK_DB.get_all_micro_barks():
		if not (entry is Dictionary):
			continue
		var bark: Dictionary = entry
		if bark.get("once_per_visit", false):
			var mid: String = str(bark.get("id", "")).strip_edges()
			if mid != "" and _micro_bark_shown_this_visit.get(mid, false):
				continue
		if not CAMP_MICRO_BARK_DB.when_matches(bark, context):
			continue
		var speaker: String = str(bark.get("speaker", "")).strip_edges()
		var listener: String = str(bark.get("listener", "")).strip_edges()
		if speaker.is_empty() or listener.is_empty():
			continue
		if not _content_condition_matches(bark, speaker, listener):
			continue
		if not _pair_memory_matches(bark, speaker, listener):
			continue
		var speaker_walker: Node = _find_walker_by_name(speaker)
		var listener_walker: Node = _find_walker_by_name(listener)
		if speaker_walker == null or listener_walker == null:
			continue
		var pair_radius: float = float(bark.get("pair_radius", CAMP_MICRO_BARK_DB.MICRO_BARK_DEFAULT_PAIR_RADIUS)) * 1.1
		if not _are_walkers_near_each_other(speaker_walker, listener_walker, pair_radius):
			continue
		var radius: float = float(bark.get("radius", CAMP_MICRO_BARK_DB.MICRO_BARK_DEFAULT_RADIUS)) * 1.1
		if player.global_position.distance_squared_to(speaker_walker.global_position) > radius * radius:
			continue
		if bark.has("zone_type"):
			var zt: String = str(bark.get("zone_type", "")).strip_edges()
			if zt != "" and not _is_walker_near_zone(speaker_walker, zt):
				continue
		var score: float = _score_with_relationship_bias(float(bark.get("priority", 0)), bark, speaker, listener)
		score -= _get_recent_history_penalty("micro", bark, speaker)
		if score > best_score:
			best_score = score
			best = bark
	return best

func _try_interact() -> void:
	if _pair_scene_active:
		return
	var eligible_pair: Dictionary = _get_eligible_pair_scene()
	var nearest: Node = _get_nearest_walker_in_range()
	if nearest != null and _would_single_walker_priority(nearest):
		_open_dialogue(nearest)
		return
	if not eligible_pair.is_empty():
		_start_pair_scene(eligible_pair)
		return
	if nearest != null:
		_open_dialogue(nearest)

func _try_click_interact(_screen_pos: Vector2) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	var world_pos: Vector2
	if cam:
		world_pos = cam.get_global_mouse_position()
	else:
		world_pos = get_viewport().get_mouse_position()
	for w in _walker_nodes:
		if not is_instance_valid(w):
			continue
		if w.global_position.distance_to(world_pos) <= INTERACT_RANGE:
			_open_dialogue(w)
			return

func _open_dialogue(walker_node: Node) -> void:
	_dialogue_active = true
	_current_walker = walker_node
	_pending_lore_id = ""
	_pending_pair_scene_id = ""
	for w in _walker_nodes:
		if w is CampRosterWalker:
			(w as CampRosterWalker).set_wander_paused(true)
	var unit_name: String = "Unit"
	var unit_data: Variant = null
	if walker_node is CampRosterWalker:
		var w: CampRosterWalker = walker_node as CampRosterWalker
		unit_name = w.unit_name
		unit_data = w.unit_data.get("data", null)
	var cm: Variant = CampaignManager
	var status: String = _get_camp_request_status()
	var giver: String = str(cm.camp_request_giver_name).strip_edges() if cm else ""
	# Failed branching: return to giver shows reaction, then clear request
	if status == "failed" and unit_name == giver:
		var failed_line: String = CampRequestContentDB.get_failed_reaction_line(giver)
		if giver != "":
			failed_line += "\n\nRelationship worsened with %s." % giver
		if dialogue_name: dialogue_name.text = unit_name
		if dialogue_portrait and walker_node is CampRosterWalker:
			var roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data
			var tex: Variant = roster_entry.get("portrait", null)
			dialogue_portrait.texture = tex if tex is Texture2D else null
			dialogue_portrait.visible = dialogue_portrait.texture != null
		if dialogue_text: dialogue_text.text = failed_line
		_hide_request_buttons()
		_hide_branching_choices()
		if dialogue_close_btn: dialogue_close_btn.visible = true
		if dialogue_panel: dialogue_panel.visible = true
		_clear_camp_request_state()
		_update_request_markers()
		return
	# Request ready to turn in: show turn-in panel
	if status == "ready_to_turn_in" and unit_name == giver:
		_show_turn_in_panel(walker_node, unit_name, unit_data)
		return
	# Active item_delivery: if player has enough items, treat as ready to turn in
	if status == "active" and unit_name == giver and str(cm.camp_request_type) == CampRequestDB.TYPE_ITEM_DELIVERY:
		var have: int = _count_camp_request_items(_get_camp_request_item_identifier())
		if have >= cm.camp_request_target_amount:
			CampaignManager.camp_request_status = "ready_to_turn_in"
			_update_request_markers()
			_show_turn_in_panel(walker_node, unit_name, unit_data)
			return
	# Active request: giver shows progress
	if status == "active" and unit_name == giver:
		_show_progress_panel(walker_node, unit_name, unit_data)
		return
	# talk_to_unit: talking to target — branching check or auto-complete
	if status == "active" and str(cm.camp_request_type) == CampRequestDB.TYPE_TALK_TO_UNIT:
		var target: String = str(cm.camp_request_target_name).strip_edges()
		if unit_name == target and int(cm.camp_request_progress) == 0:
			var payload: Dictionary = cm.camp_request_payload if cm.camp_request_payload is Dictionary else {}
			if payload.get("branching_check") == true:
				_start_branching_check(walker_node, unit_name, unit_data, giver)
				return
			# Non-branching: complete on first talk
			CampaignManager.camp_request_progress = 1
			CampaignManager.camp_request_status = "ready_to_turn_in"
			_update_request_markers()
			if dialogue_name: dialogue_name.text = unit_name
			if dialogue_portrait:
				var roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data if walker_node is CampRosterWalker else {}
				var tex: Variant = roster_entry.get("portrait", null)
				dialogue_portrait.texture = tex if tex is Texture2D else null
				dialogue_portrait.visible = dialogue_portrait.texture != null
			if dialogue_text: dialogue_text.text = "Done. Return to %s to complete the request." % giver
			_hide_request_buttons()
			if dialogue_close_btn: dialogue_close_btn.visible = true
			if dialogue_panel: dialogue_panel.visible = true
			return
	# Special camp scene (trusted/close): one-time or occasional; show before normal idle dialogue.
	if status != "active" and status != "ready_to_turn_in" and status != "failed" and CampaignManager and unit_name != "":
		var tier: String = CampaignManager.get_avatar_relationship_tier(unit_name)
		for scene_tier in ["close", "trusted"]:
			var scene: Dictionary = CampRequestContentDB.get_special_camp_scene(unit_name, scene_tier)
			if scene.is_empty() or scene.get("lines", []).is_empty():
				continue
			var tier_ok: bool = (scene_tier == "close" and tier in ["close", "bonded"]) or (scene_tier == "trusted" and tier in ["trusted", "close", "bonded"])
			if not tier_ok:
				continue
			if scene.get("one_time", true) and CampaignManager.has_seen_special_scene(unit_name, scene_tier):
				continue
			_show_special_camp_scene(walker_node, unit_name, unit_data, scene, scene_tier)
			return

	# Paired camp scene (two-character interaction) before camp lore, request offers, and ambient chatter.
	if CampaignManager:
		var pair_scene: Dictionary = CampaignManager.get_available_pair_scene_for_unit(unit_name)
		if not pair_scene.is_empty():
			var other_name: String = unit_name
			var a_name: String = str(pair_scene.get("unit_a", "")).strip_edges()
			var b_name: String = str(pair_scene.get("unit_b", "")).strip_edges()
			if unit_name == a_name and b_name != "":
				other_name = "%s & %s" % [unit_name, b_name]
			elif unit_name == b_name and a_name != "":
				other_name = "%s & %s" % [unit_name, a_name]

			if dialogue_name:
				dialogue_name.text = other_name
			if dialogue_portrait and walker_node is CampRosterWalker:
				var pair_roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data
				var pair_tex: Variant = pair_roster_entry.get("portrait", null)
				dialogue_portrait.texture = pair_tex if pair_tex is Texture2D else null
				dialogue_portrait.visible = dialogue_portrait.texture != null
			if dialogue_text:
				dialogue_text.text = str(pair_scene.get("text", "")).strip_edges()
			_hide_request_buttons()
			_hide_branching_choices()
			if dialogue_close_btn:
				dialogue_close_btn.visible = true
			if dialogue_panel:
				dialogue_panel.visible = true
			_pending_pair_scene_id = str(pair_scene.get("id", "")).strip_edges()
			return

	# One-time camp lore beat (relationship-gated) before normal request offer and ambient chatter.
	if CampaignManager:
		var lore: Dictionary = CampaignManager.get_available_camp_lore(unit_name)
		if not lore.is_empty():
			if dialogue_name:
				dialogue_name.text = unit_name
			if dialogue_portrait and walker_node is CampRosterWalker:
				var lore_roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data
				var lore_tex: Variant = lore_roster_entry.get("portrait", null)
				dialogue_portrait.texture = lore_tex if lore_tex is Texture2D else null
				dialogue_portrait.visible = dialogue_portrait.texture != null
			if dialogue_text:
				dialogue_text.text = str(lore.get("text", "")).strip_edges()
			_hide_request_buttons()
			_hide_branching_choices()
			if dialogue_close_btn:
				dialogue_close_btn.visible = true
			if dialogue_panel:
				dialogue_panel.visible = true
			_pending_lore_id = str(lore.get("id", "")).strip_edges()
			return

	# Offer available from this unit (after forced/special scenes and lore).
	if _offer_giver_name == unit_name and _pending_offer.is_empty():
		var roster_names: Array = []
		for w in _walker_nodes:
			if w is CampRosterWalker:
				roster_names.append((w as CampRosterWalker).unit_name)
		var item_names: Array = _get_requestable_item_names()
		var giver_tier: String = CampaignManager.get_avatar_relationship_tier(unit_name) if CampaignManager else ""
		var personal_eligible: bool = CampaignManager.is_personal_quest_eligible(unit_name) if CampaignManager else false
		_pending_offer = CampRequestDB.get_offer(unit_name, CampRequestDB.get_personality(unit_data, unit_name), roster_names, item_names, status == "active" or status == "ready_to_turn_in", giver_tier, personal_eligible)
		_offer_is_personal = str(_pending_offer.get("request_depth", "")).strip_edges().to_lower() == "personal"
	if not _pending_offer.is_empty() and _offer_giver_name == unit_name:
		_show_offer_panel(walker_node, unit_name, unit_data)
		return
	# Normal camp line (idle talk); show Avatar–unit bond tier as lightweight visible hook
	var line: String = CampExploreDialogueDB.get_line_for_unit(unit_data, unit_name)
	if CampaignManager and unit_name != "":
		var tier: String = CampaignManager.get_avatar_relationship_tier(unit_name)
		if tier != "":
			line += "\n\nBond: " + tier.capitalize()
	if dialogue_name:
		dialogue_name.text = unit_name
	if dialogue_portrait:
		var roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data if walker_node is CampRosterWalker else {}
		var tex: Variant = roster_entry.get("portrait", null)
		dialogue_portrait.texture = tex if tex is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	if dialogue_text:
		dialogue_text.text = line
	_hide_request_buttons()
	if dialogue_close_btn:
		dialogue_close_btn.visible = true
	if dialogue_panel:
		dialogue_panel.visible = true

func _close_dialogue() -> void:
	_dialogue_active = false
	_current_walker = null
	_branching_active = false
	_hide_branching_choices()
	if _pending_lore_id.strip_edges() != "" and CampaignManager:
		CampaignManager.mark_camp_lore_seen(_pending_lore_id)
	_pending_lore_id = ""
	if _pending_pair_scene_id.strip_edges() != "" and CampaignManager:
		CampaignManager.mark_pair_scene_seen(_pending_pair_scene_id)
	_pending_pair_scene_id = ""
	for w in _walker_nodes:
		if w is CampRosterWalker:
			(w as CampRosterWalker).set_wander_paused(false)
	if dialogue_panel:
		dialogue_panel.visible = false
	_hide_request_buttons()

func _on_dialogue_close_pressed() -> void:
	if _pair_scene_active:
		_advance_pair_scene()
		return
	_close_dialogue()

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
	# Ensure the Task Log root Control occupies the full viewport so it is visible.
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
	# Always open/show the Task Log when this is called; closing is handled inside TaskLog itself.
	_task_log.visible = true
	if _task_log is Control:
		(_task_log as Control).show()
	_task_log.open_and_refresh()

## Mirrors camp_menu: pick a random track from _camp_music_tracks and play. No crossfade/jukebox.
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

# --- Camp Requests v1 ---
func _clear_camp_request_state() -> void:
	if not CampaignManager:
		return
	var was_personal: bool = false
	var giver: String = str(CampaignManager.camp_request_giver_name).strip_edges()
	if CampaignManager.camp_request_payload is Dictionary and giver != "":
		was_personal = str(CampaignManager.camp_request_payload.get("request_depth", "")).strip_edges().to_lower() == "personal"
	CampaignManager.camp_request_status = ""
	CampaignManager.camp_request_giver_name = ""
	CampaignManager.camp_request_type = ""
	CampaignManager.camp_request_title = ""
	CampaignManager.camp_request_description = ""
	CampaignManager.camp_request_target_name = ""
	CampaignManager.camp_request_target_amount = 0
	CampaignManager.camp_request_progress = 0
	CampaignManager.camp_request_reward_gold = 0
	CampaignManager.camp_request_reward_affinity = 0
	CampaignManager.camp_request_payload = {}
	if was_personal and giver != "":
		CampaignManager.set_personal_quest_active(giver, false)

func _get_camp_request_item_identifier() -> String:
	if not CampaignManager:
		return ""
	var payload: Dictionary = CampaignManager.camp_request_payload if CampaignManager.camp_request_payload is Dictionary else {}
	var stored: Variant = payload.get("item_display_name", null)
	if stored != null and str(stored).strip_edges() != "":
		return str(stored).strip_edges()
	return str(CampaignManager.camp_request_target_name).strip_edges()

func _validate_camp_request_roster() -> void:
	var status: String = _get_camp_request_status()
	if status != "active" and status != "ready_to_turn_in" and status != "failed":
		return
	var names: Array = []
	for w in _walker_nodes:
		if w is CampRosterWalker:
			names.append((w as CampRosterWalker).unit_name)
	var giver: String = str(CampaignManager.camp_request_giver_name).strip_edges()
	if giver != "" and giver not in names:
		_clear_camp_request_state()
		return
	if status == "failed":
		return
	if str(CampaignManager.camp_request_type) == CampRequestDB.TYPE_TALK_TO_UNIT:
		var target: String = str(CampaignManager.camp_request_target_name).strip_edges()
		if target != "" and target not in names:
			_clear_camp_request_state()

func _update_request_markers() -> void:
	var cm: Variant = CampaignManager
	var status: String = _get_camp_request_status()
	var giver: String = str(cm.camp_request_giver_name).strip_edges() if cm else ""
	var has_active_or_ready: bool = (status == "active" or status == "ready_to_turn_in" or status == "failed")
	for w in _walker_nodes:
		if not (w is CampRosterWalker):
			continue
		var walker: CampRosterWalker = w as CampRosterWalker
		if status == "ready_to_turn_in" and walker.unit_name == giver:
			walker.request_marker = "turn_in"
		elif not has_active_or_ready and _offer_giver_name != "" and walker.unit_name == _offer_giver_name:
			walker.request_marker = "offer_personal" if _offer_is_personal else "offer"
		else:
			walker.request_marker = "none"

## Adds giver to persistent recent-givers list (cap 3, no duplicates, newest first). Only call on Accept/Decline.
func _add_giver_to_recent(giver_name: String) -> void:
	if not CampaignManager or giver_name.is_empty():
		return
	var recent_list: Array = CampaignManager.camp_request_recent_givers.duplicate()
	if giver_name in recent_list:
		recent_list.erase(giver_name)
	recent_list.push_front(giver_name)
	while recent_list.size() > 3:
		recent_list.pop_back()
	CampaignManager.camp_request_recent_givers = recent_list

func _hide_request_buttons() -> void:
	if accept_btn: accept_btn.visible = false
	if decline_btn: decline_btn.visible = false
	if turn_in_btn: turn_in_btn.visible = false
	if dialogue_close_btn: dialogue_close_btn.visible = true

func _setup_branching_choice_container() -> void:
	if dialogue_panel == null:
		return
	var vbox: Node = dialogue_panel.get_node_or_null("VBox")
	if vbox == null:
		return
	_choice_container = HBoxContainer.new()
	_choice_container.name = "ChoiceContainer"
	_choice_container.visible = false
	vbox.add_child(_choice_container)

func _hide_branching_choices() -> void:
	if _choice_container == null:
		return
	for c in _choice_container.get_children():
		c.queue_free()
	_choice_container.visible = false
	if accept_btn and accept_btn.get_parent():
		accept_btn.get_parent().visible = true
	if dialogue_close_btn:
		dialogue_close_btn.visible = true

func _start_branching_check(walker_node: Node, unit_name: String, unit_data: Variant, giver: String) -> void:
	var payload: Dictionary = CampaignManager.camp_request_payload if CampaignManager and CampaignManager.camp_request_payload is Dictionary else {}
	var style: String = str(payload.get("challenge_style", "")).strip_edges().to_lower()
	var personality: String = CampRequestDB.get_personality(unit_data, unit_name)
	var state: String = CampRequestContentDB.get_challenge_state_for_personality(personality)
	var data: Dictionary = CampRequestContentDB.get_branching_data(style, state)
	if data.is_empty() or not data.has("choices") or (data["choices"] as Array).is_empty():
		CampaignManager.camp_request_progress = 1
		CampaignManager.camp_request_status = "ready_to_turn_in"
		_update_request_markers()
		if dialogue_name: dialogue_name.text = unit_name
		if dialogue_portrait and walker_node is CampRosterWalker:
			var roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data
			var tex: Variant = roster_entry.get("portrait", null)
			dialogue_portrait.texture = tex if tex is Texture2D else null
			dialogue_portrait.visible = dialogue_portrait.texture != null
		if dialogue_text: dialogue_text.text = "Done. Return to %s to complete the request." % giver
		_hide_request_buttons()
		if dialogue_close_btn: dialogue_close_btn.visible = true
		if dialogue_panel: dialogue_panel.visible = true
		return
	_branching_active = true
	_branching_data = data
	_branching_choices = (data["choices"] as Array).duplicate()
	_branching_giver = giver
	if dialogue_name: dialogue_name.text = unit_name
	if dialogue_portrait and walker_node is CampRosterWalker:
		var roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data
		var tex: Variant = roster_entry.get("portrait", null)
		dialogue_portrait.texture = tex if tex is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	if dialogue_text: dialogue_text.text = str(data.get("opening_line", "")).strip_edges()
	if accept_btn and accept_btn.get_parent():
		accept_btn.get_parent().visible = false
	if dialogue_close_btn: dialogue_close_btn.visible = false
	if _choice_container == null:
		return
	for c in _choice_container.get_children():
		c.queue_free()
	var choices: Array = _branching_choices
	for i in range(choices.size()):
		var choice: Dictionary = choices[i] if i < choices.size() else {}
		var btn: Button = Button.new()
		btn.text = str(choice.get("text", "…")).strip_edges()
		if btn.text.is_empty():
			btn.text = "…"
		var idx: int = i
		btn.pressed.connect(_on_branching_choice_pressed.bind(idx))
		_choice_container.add_child(btn)
	_choice_container.visible = true
	if dialogue_panel: dialogue_panel.visible = true

func _on_branching_choice_pressed(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= _branching_choices.size():
		return
	var choice: Dictionary = _branching_choices[choice_index]
	var result_line: String = str(choice.get("result_line", "")).strip_edges()
	var outcome: String = str(choice.get("outcome", "fail")).strip_edges().to_lower()
	if dialogue_text: dialogue_text.text = result_line
	_hide_branching_choices()
	if outcome == "success":
		CampaignManager.camp_request_progress = 1
		CampaignManager.camp_request_status = "ready_to_turn_in"
		_update_request_markers()
		if dialogue_text: dialogue_text.text = result_line + "\n\nReturn to %s to complete the request." % _branching_giver
	else:
		CampaignManager.camp_request_status = "failed"
		if _branching_giver != "":
			CampaignManager.record_avatar_branching_failure(_branching_giver)
		_update_request_markers()
	_branching_active = false
	if accept_btn and accept_btn.get_parent():
		accept_btn.get_parent().visible = false
	if dialogue_close_btn: dialogue_close_btn.visible = true

func _show_special_camp_scene(walker_node: Node, unit_name: String, _unit_data: Variant, scene: Dictionary, scene_tier: String) -> void:
	if scene.get("one_time", true) and CampaignManager:
		CampaignManager.mark_special_scene_seen(unit_name, scene_tier)
	var lines_arr: Array = scene.get("lines", [])
	var text: String = ""
	for i in range(lines_arr.size()):
		if i > 0:
			text += "\n\n"
		text += str(lines_arr[i]).strip_edges()
	if text.is_empty():
		text = "..."
	if dialogue_name: dialogue_name.text = unit_name
	if dialogue_portrait and walker_node is CampRosterWalker:
		var roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data
		var tex: Variant = roster_entry.get("portrait", null)
		dialogue_portrait.texture = tex if tex is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	if dialogue_text: dialogue_text.text = text
	_hide_request_buttons()
	if dialogue_close_btn: dialogue_close_btn.visible = true
	if dialogue_panel: dialogue_panel.visible = true

func _show_offer_panel(walker_node: Node, unit_name: String, unit_data: Variant) -> void:
	if dialogue_name: dialogue_name.text = unit_name
	if dialogue_portrait:
		var roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data if walker_node is CampRosterWalker else {}
		var tex: Variant = roster_entry.get("portrait", null)
		dialogue_portrait.texture = tex if tex is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	var personality: String = CampRequestDB.get_personality(unit_data, unit_name)
	var line: String = CampRequestDB.get_line("offer", personality, _pending_offer, 0, unit_name)
	var title: String = str(_pending_offer.get("title", "")).strip_edges()
	var desc: String = str(_pending_offer.get("description", "")).strip_edges()
	var reward_g: int = int(_pending_offer.get("reward_gold", 0))
	var _reward_a: int = int(_pending_offer.get("reward_affinity", 0))
	if dialogue_text:
		dialogue_text.text = line + "\n\n" + title + "\n" + desc + "\n\nReward: %d gold. (Favor noted when completed.)" % reward_g
	if dialogue_close_btn: dialogue_close_btn.visible = false
	if accept_btn: accept_btn.visible = true
	if decline_btn: decline_btn.visible = true
	if turn_in_btn: turn_in_btn.visible = false
	if dialogue_panel: dialogue_panel.visible = true

func _show_progress_panel(walker_node: Node, unit_name: String, unit_data: Variant) -> void:
	if dialogue_name: dialogue_name.text = unit_name
	if dialogue_portrait:
		var roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data if walker_node is CampRosterWalker else {}
		var tex: Variant = roster_entry.get("portrait", null)
		dialogue_portrait.texture = tex if tex is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	var personality: String = CampRequestDB.get_personality(unit_data, unit_name)
	var depth_str: String = "normal"
	if CampaignManager.camp_request_payload is Dictionary:
		depth_str = str(CampaignManager.camp_request_payload.get("request_depth", "normal"))
	var data: Dictionary = {
		"type": CampaignManager.camp_request_type,
		"target_name": CampaignManager.camp_request_target_name,
		"target_amount": CampaignManager.camp_request_target_amount,
		"request_depth": depth_str,
	}
	var line: String = CampRequestDB.get_line("in_progress", personality, data, 0, unit_name)
	if CampaignManager.camp_request_type == CampRequestDB.TYPE_ITEM_DELIVERY:
		var have: int = _count_camp_request_items(_get_camp_request_item_identifier())
		var need: int = CampaignManager.camp_request_target_amount
		line += "\n\nProgress: %d / %d" % [have, need]
	if dialogue_text: dialogue_text.text = line
	_hide_request_buttons()
	if dialogue_close_btn: dialogue_close_btn.visible = true
	if dialogue_panel: dialogue_panel.visible = true

func _show_turn_in_panel(walker_node: Node, unit_name: String, unit_data: Variant) -> void:
	if dialogue_name: dialogue_name.text = unit_name
	if dialogue_portrait:
		var roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data if walker_node is CampRosterWalker else {}
		var tex: Variant = roster_entry.get("portrait", null)
		dialogue_portrait.texture = tex if tex is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	var personality: String = CampRequestDB.get_personality(unit_data, unit_name)
	var depth_str: String = "normal"
	if CampaignManager.camp_request_payload is Dictionary:
		depth_str = str(CampaignManager.camp_request_payload.get("request_depth", "normal"))
	var data: Dictionary = {
		"type": CampaignManager.camp_request_type,
		"request_depth": depth_str,
	}
	var line: String = CampRequestDB.get_line("ready_to_turn_in", personality, data, 0, unit_name)
	if dialogue_text: dialogue_text.text = line
	if dialogue_close_btn: dialogue_close_btn.visible = false
	if accept_btn: accept_btn.visible = false
	if decline_btn: decline_btn.visible = false
	if turn_in_btn: turn_in_btn.visible = true
	if dialogue_panel: dialogue_panel.visible = true

func _on_accept_pressed() -> void:
	if _pending_offer.is_empty() or not CampaignManager or _current_walker == null:
		_close_dialogue()
		return
	CampaignManager.camp_request_status = "active"
	var unit_name_accept: String = (_current_walker as CampRosterWalker).unit_name if _current_walker is CampRosterWalker else ""
	CampaignManager.camp_request_giver_name = unit_name_accept
	CampaignManager.camp_request_type = str(_pending_offer.get("type", ""))
	CampaignManager.camp_request_title = str(_pending_offer.get("title", ""))
	CampaignManager.camp_request_description = str(_pending_offer.get("description", ""))
	CampaignManager.camp_request_target_name = str(_pending_offer.get("target_name", ""))
	CampaignManager.camp_request_target_amount = int(_pending_offer.get("target_amount", 0))
	CampaignManager.camp_request_progress = 0
	CampaignManager.camp_request_reward_gold = int(_pending_offer.get("reward_gold", 0))
	CampaignManager.camp_request_reward_affinity = int(_pending_offer.get("reward_affinity", 0))
	var payload: Dictionary = _pending_offer.get("payload", {}).duplicate()
	if CampaignManager.camp_request_type == CampRequestDB.TYPE_ITEM_DELIVERY:
		payload["item_display_name"] = CampaignManager.camp_request_target_name
	payload["request_depth"] = str(_pending_offer.get("request_depth", "normal")).strip_edges().to_lower()
	CampaignManager.camp_request_payload = payload
	if payload.get("request_depth") == "personal" and CampaignManager and unit_name_accept != "":
		CampaignManager.set_personal_quest_active(unit_name_accept, true)
	var unit_data_accept: Variant = (_current_walker as CampRosterWalker).unit_data.get("data", null) if _current_walker is CampRosterWalker else null
	var personality_accept: String = CampRequestDB.get_personality(unit_data_accept, unit_name_accept)
	var accepted_line: String = CampRequestDB.get_line("accepted", personality_accept, _pending_offer, 0, unit_name_accept)
	_add_giver_to_recent(unit_name_accept)
	_offer_giver_name = ""
	_pending_offer = {}
	_update_request_markers()
	if dialogue_text:
		dialogue_text.text = accepted_line
	if accept_btn: accept_btn.visible = false
	if decline_btn: decline_btn.visible = false
	if turn_in_btn: turn_in_btn.visible = false
	if dialogue_close_btn: dialogue_close_btn.visible = true

func _on_decline_pressed() -> void:
	if _current_walker == null:
		_pending_offer = {}
		_close_dialogue()
		return
	var unit_name_decline: String = (_current_walker as CampRosterWalker).unit_name if _current_walker is CampRosterWalker else ""
	var unit_data_decline: Variant = (_current_walker as CampRosterWalker).unit_data.get("data", null) if _current_walker is CampRosterWalker else null
	var personality_decline: String = CampRequestDB.get_personality(unit_data_decline, unit_name_decline)
	var declined_line: String = CampRequestDB.get_line("declined", personality_decline, _pending_offer, 0, unit_name_decline)
	if CampaignManager and unit_name_decline != "":
		CampaignManager.camp_request_unit_next_eligible_level[unit_name_decline] = CampaignManager.camp_request_progress_level + 1
	_add_giver_to_recent(unit_name_decline)
	_pending_offer = {}
	if dialogue_text:
		dialogue_text.text = declined_line
	if accept_btn: accept_btn.visible = false
	if decline_btn: decline_btn.visible = false
	if turn_in_btn: turn_in_btn.visible = false
	if dialogue_close_btn: dialogue_close_btn.visible = true

func _on_turn_in_pressed() -> void:
	if not CampaignManager:
		_close_dialogue()
		return
	var req_type: String = CampaignManager.camp_request_type
	var target_name: String = _get_camp_request_item_identifier()
	var target_amount: int = CampaignManager.camp_request_target_amount
	if req_type == CampRequestDB.TYPE_ITEM_DELIVERY:
		var have: int = _count_camp_request_items(target_name)
		if have < target_amount:
			_close_dialogue()
			return
		var removed: int = _remove_camp_request_items(target_name, target_amount)
		if removed < target_amount:
			_close_dialogue()
			return
	var giver_name: String = str(CampaignManager.camp_request_giver_name).strip_edges()
	var completed_before: int = int(CampaignManager.camp_requests_completed_by_unit.get(giver_name, 0))
	var reward_g: int = CampaignManager.camp_request_reward_gold
	var reward_a: int = CampaignManager.camp_request_reward_affinity
	var first_time_bonus: int = 15 if completed_before == 0 else 0
	reward_g += first_time_bonus
	CampaignManager.global_gold += reward_g
	if giver_name != "":
		CampaignManager.camp_request_unit_next_eligible_level[giver_name] = CampaignManager.camp_request_progress_level + 2
		CampaignManager.camp_requests_completed_by_unit[giver_name] = completed_before + 1
	var unit_name_turnin: String = ""
	var personality_turnin: String = "neutral"
	if _current_walker is CampRosterWalker:
		var w: CampRosterWalker = _current_walker as CampRosterWalker
		unit_name_turnin = w.unit_name
		var ud: Variant = w.unit_data.get("data", null)
		personality_turnin = CampRequestDB.get_personality(ud, unit_name_turnin)
	var is_branching: bool = false
	var request_depth: String = "normal"
	if CampaignManager.camp_request_payload is Dictionary:
		is_branching = CampaignManager.camp_request_payload.get("branching_check") == true
		request_depth = str(CampaignManager.camp_request_payload.get("request_depth", "normal")).strip_edges().to_lower()
	if giver_name != "":
		CampaignManager.record_avatar_request_completed(giver_name, is_branching, request_depth)
		if request_depth == "personal":
			CampaignManager.mark_personal_quest_completed(giver_name)
	var completed_data: Dictionary = {"type": CampaignManager.camp_request_type, "request_depth": request_depth}
	var completed_line: String = CampRequestDB.get_line("completed", personality_turnin, completed_data, completed_before + 1, unit_name_turnin)
	var reward_feedback: String = "Received %d gold." % reward_g
	if first_time_bonus > 0:
		reward_feedback += " (First-time bonus: +%d gold.)" % first_time_bonus
	if reward_a > 0:
		reward_feedback += " Favor noted."
	if giver_name != "":
		reward_feedback += " Relationship improved with %s." % giver_name
	if dialogue_text:
		dialogue_text.text = completed_line + "\n\n" + reward_feedback
	if turn_in_btn: turn_in_btn.visible = false
	if dialogue_close_btn: dialogue_close_btn.visible = true
	_clear_camp_request_state()
	_update_request_markers()

func _get_requestable_item_names() -> Array:
	var out: Array = []
	if not ItemDatabase:
		return out
	for item in ItemDatabase.master_item_pool:
		if item == null:
			continue
		var name_str: String = _get_item_display_name_camp(item)
		if name_str == "Unknown" or name_str.is_empty():
			continue
		if item is MaterialData or item is ConsumableData:
			out.append(name_str)
	return out

func _get_item_display_name_camp(item: Variant) -> String:
	if item == null:
		return "Unknown"
	var wn: Variant = item.get("weapon_name")
	if wn != null and str(wn).strip_edges() != "":
		return str(wn).strip_edges()
	var iname: Variant = item.get("item_name")
	if iname != null and str(iname).strip_edges() != "":
		return str(iname).strip_edges()
	return "Unknown"

func _count_camp_request_items(item_name: String) -> int:
	var total: int = 0
	for item in CampaignManager.global_inventory:
		if item != null and _get_item_display_name_camp(item) == item_name:
			total += 1
	for unit_data in CampaignManager.player_roster:
		var inv_raw: Variant = unit_data.get("inventory", [])
		var inv: Array = inv_raw if inv_raw is Array else []
		for item in inv:
			if item != null and _get_item_display_name_camp(item) == item_name:
				total += 1
	return total

func _remove_camp_request_items(item_name: String, amount: int) -> int:
	var removed: int = 0
	for i in range(CampaignManager.global_inventory.size() - 1, -1, -1):
		if removed >= amount:
			break
		var item: Variant = CampaignManager.global_inventory[i]
		if item != null and _get_item_display_name_camp(item) == item_name:
			CampaignManager.global_inventory.remove_at(i)
			removed += 1
	for unit_data in CampaignManager.player_roster:
		if removed >= amount:
			break
		var inv_raw: Variant = unit_data.get("inventory", [])
		var inv: Array = inv_raw if inv_raw is Array else []
		for i in range(inv.size() - 1, -1, -1):
			if removed >= amount:
				break
			var item: Variant = inv[i]
			if item != null and _get_item_display_name_camp(item) == item_name:
				if unit_data.get("equipped_weapon") == item:
					unit_data["equipped_weapon"] = null
				inv.remove_at(i)
				removed += 1
	return removed
