extends Control

const DEFAULT_ENGINE_LOGO_PATH := "res://Assets/UI/godot_engine_logo.svg"
const ATMOSPHERE_SHADER_PATH := "res://Scripts/UI/studio_intro_atmosphere.gdshader"

@export_file("*.tscn") var next_scene_path: String = "res://Scenes/main_menu.tscn"
@export var allow_skip: bool = true
## If true, shows “Press any key to skip” at the bottom. Beats always advance on their own when this is off.
@export var show_skip_hint: bool = false
## If true, skip jumps to the next beat; on the last beat, goes to the main menu. If false, skip always exits the whole intro.
@export var skip_advances_beat: bool = true
@export var minimum_skip_delay: float = 0.25
@export var skip_fast_fade_seconds: float = 0.12

@export_group("Beat – Engine")
@export var beat_engine_enabled: bool = true
@export var engine_line_primary: String = "MADE WITH GODOT"
@export var engine_line_secondary: String = ""
@export var engine_logo_texture: Texture2D
@export var engine_fade_in_seconds: float = 0.55
@export var engine_hold_seconds: float = 0.9
@export var engine_fade_out_seconds: float = 0.45

@export_group("Beat – Studio")
@export var beat_studio_enabled: bool = true
@export var logo_texture: Texture2D
@export var studio_name: String = "KORVAIN GAMES"
@export var studio_tagline: String = "Forging tactical legends."
@export var studio_fade_in_seconds: float = 0.8
@export var studio_hold_seconds: float = 1.2
@export var studio_fade_out_seconds: float = 0.7

@export_group("Beat – Game")
@export var beat_game_enabled: bool = true
@export var game_logo_texture: Texture2D
@export var game_title_text: String = "LEGENDS OF AURELIA : THE RIFT"
@export var game_tagline_text: String = ""
@export var game_fade_in_seconds: float = 0.85
@export var game_hold_seconds: float = 1.4
@export var game_fade_out_seconds: float = 0.7

@export_group("Scene Handoff")
@export var use_soft_scene_handoff: bool = true
@export var handoff_fade_out_seconds: float = 0.70
@export var handoff_fade_in_seconds: float = 0.95
@export var handoff_hold_black_seconds: float = 0.10
@export var handoff_from_black_no_flash: bool = true

@export_group("Audio")
## Play the sting when the studio beat begins (ignored if no stream).
@export var play_sting_on_studio_beat: bool = true
## Slightly lower pitch reads heavier / more ominous on the studio sting (single StingPlayer only).
@export_range(0.5, 1.2) var sting_pitch_scale: float = 0.84
## Optional looping bed when layered intro wind is off or no wind stream is set.
@export var ambient_drone_stream: AudioStream
@export var ambient_drone_volume_db: float = -26.0
@export var ambient_drone_bus: String = "Music"
## When on, plays **Intro wind / drone** from `intro_wind_stream` (assign an AudioStream in the inspector). Sends to `intro_wind_bus` (e.g. IntroAtmos with a low-pass).
@export var intro_use_layered_bed: bool = false
@export var intro_wind_stream: AudioStream
@export var intro_wind_volume_db: float = -24.0
@export var intro_wind_bus: String = "IntroAtmos"
## Optional one-shots for the studio beat (assign streams here). Used only when **Intro studio sting use layers** is on; otherwise the scene **StingPlayer** is used.
@export var intro_studio_reversed_riser_stream: AudioStream
@export var intro_studio_bell_stream: AudioStream
@export var intro_studio_reversed_tail_stream: AudioStream
@export var intro_studio_sting_use_layers: bool = false
@export var intro_sting_bus: String = "SFX"
@export var intro_riser_lead_seconds: float = 0.72
@export var intro_post_bell_tail_delay_sec: float = 0.14

@export_group("Atmosphere")
@export var sparkles_enabled: bool = true
@export var sparkles_count: int = 16
@export var sparkles_min_speed: float = 2.0
@export var sparkles_max_speed: float = 8.0
@export var sparkles_min_size: int = 1
@export var sparkles_max_size: int = 3
@export var sparkles_alpha_min: float = 0.08
@export var sparkles_alpha_max: float = 0.38
@export var sparkles_tint: Color = Color(0.32, 0.48, 0.62, 1.0)

@export_group("Eerie atmosphere")
@export var eerie_atmosphere_enabled: bool = true
@export var deep_backdrop_color: Color = Color(0.004, 0.007, 0.014, 1.0)
@export var cold_mist_color: Color = Color(0.025, 0.048, 0.072, 0.58)
## Subtle “breathing” scale on the whole logo stack (center pivot).
@export_range(0.0, 0.06) var breathing_strength: float = 0.018
@export_range(0.05, 1.5) var breathing_hz: float = 0.28
## Tiny sway in degrees — unsettling without feeling like camera shake.
@export_range(0.0, 2.0) var unease_sway_degrees: float = 0.55
@export_range(0.02, 0.5) var unease_sway_hz: float = 0.095
@export_range(0.0, 1.0) var sparkle_sink_bias: float = 0.42

@export_group("Atmosphere per beat")
@export var atmosphere_beat_tween_enabled: bool = true
@export_range(0.05, 3.0) var atmosphere_beat_tween_seconds: float = 0.9
## Engine (Made with Godot): coldest mist, tightest vignette.
@export var atmosphere_engine_mist_color: Color = Color(0.02, 0.05, 0.085, 0.66)
@export_range(0.08, 0.75) var atmosphere_engine_vignette_inner: float = 0.28
@export_range(0.55, 1.0) var atmosphere_engine_vignette_outer: float = 0.93
@export_range(0.7, 1.35) var atmosphere_engine_vignette_strength: float = 1.08
@export var atmosphere_engine_deep_tint: Color = Color(0.008, 0.022, 0.045, 1.0)
@export_range(0.0, 0.12) var atmosphere_engine_grain: float = 0.05
## Studio title card: slightly warmer / less crush than engine.
@export var atmosphere_studio_mist_color: Color = Color(0.038, 0.065, 0.098, 0.52)
@export_range(0.08, 0.75) var atmosphere_studio_vignette_inner: float = 0.34
@export_range(0.55, 1.0) var atmosphere_studio_vignette_outer: float = 0.955
@export_range(0.7, 1.35) var atmosphere_studio_vignette_strength: float = 0.92
@export var atmosphere_studio_deep_tint: Color = Color(0.014, 0.034, 0.062, 1.0)
@export_range(0.0, 0.12) var atmosphere_studio_grain: float = 0.038
## Game title beat: between engine cold and studio lift.
@export var atmosphere_game_mist_color: Color = Color(0.03, 0.055, 0.088, 0.56)
@export_range(0.08, 0.75) var atmosphere_game_vignette_inner: float = 0.31
@export_range(0.55, 1.0) var atmosphere_game_vignette_outer: float = 0.94
@export_range(0.7, 1.35) var atmosphere_game_vignette_strength: float = 1.0
@export var atmosphere_game_deep_tint: Color = Color(0.01, 0.028, 0.052, 1.0)
@export_range(0.0, 0.12) var atmosphere_game_grain: float = 0.044

@onready var beats_root: Control = $BeatsRoot
@onready var beat_engine: Control = $BeatsRoot/BeatEngine
@onready var engine_logo_rect: TextureRect = $BeatsRoot/BeatEngine/EngineLogo
@onready var engine_primary_label: Label = $BeatsRoot/BeatEngine/EnginePrimary
@onready var engine_secondary_label: Label = $BeatsRoot/BeatEngine/EngineSecondary
@onready var engine_godot_version: Label = $BeatsRoot/BeatEngine/EngineGodotVersion
@onready var engine_godot_legal: Label = $BeatsRoot/BeatEngine/EngineGodotLegal
@onready var beat_studio: Control = $BeatsRoot/BeatStudio
@onready var logo_rect: TextureRect = $BeatsRoot/BeatStudio/Logo
@onready var title_label: Label = $BeatsRoot/BeatStudio/Title
@onready var tagline_label: Label = $BeatsRoot/BeatStudio/Tagline
@onready var studio_copyright_label: Label = $BeatsRoot/BeatStudio/StudioCopyright
@onready var beat_game: Control = $BeatsRoot/BeatGame
@onready var game_logo_rect: TextureRect = $BeatsRoot/BeatGame/GameLogo
@onready var game_title_label: Label = $BeatsRoot/BeatGame/GameTitle
@onready var game_tagline_label: Label = $BeatsRoot/BeatGame/GameTagline
@onready var game_copyright_label: Label = $BeatsRoot/BeatGame/GameCopyright

@onready var skip_hint: Label = $SkipHint
@onready var sting_player: AudioStreamPlayer = $StingPlayer
@onready var backdrop: ColorRect = $Backdrop

var _elapsed: float = 0.0
var _is_leaving: bool = false
var _skip_beat_requested: bool = false
var _sequence_running: bool = false
var _active_beat_tween: Tween = null
var _active_beat_root: Control = null
var _sparkle_layer: Control = null
var _sparkles: Array[ColorRect] = []
var _sparkle_velocity: Array[Vector2] = []
var _sparkle_base_alpha: Array[float] = []
var _sparkle_phase: Array[float] = []
var _sparkle_twinkle_speed: Array[float] = []
var _sparkle_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _handoff_black_rect: ColorRect = null
var _cold_mist_layer: ColorRect = null
var _atmosphere_shader_rect: ColorRect = null
var _atmosphere_mat: ShaderMaterial = null
var _atmosphere_tween: Tween = null
var _ambient_player: AudioStreamPlayer = null
var _wind_player: AudioStreamPlayer = null
var _studio_riser_player: AudioStreamPlayer = null
var _studio_bell_player: AudioStreamPlayer = null
var _studio_tail_player: AudioStreamPlayer = null
var _beats_pivot_ready: bool = false


func _ready() -> void:
	if sting_player != null:
		sting_player.bus = "SFX"
		sting_player.pitch_scale = sting_pitch_scale
	_sparkle_rng.randomize()
	_apply_export_textures_and_copy()
	_setup_visual_state()
	_hide_all_beats()
	_ensure_atmosphere_layers()
	_spawn_sparkles()
	_start_intro_audio_beds()
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_viewport_resized_for_pivot):
		vp.size_changed.connect(_on_viewport_resized_for_pivot)
	call_deferred("_refresh_beats_center_pivot")
	call_deferred("_start_intro_sequence")


func _on_viewport_resized_for_pivot() -> void:
	_beats_pivot_ready = false
	call_deferred("_refresh_beats_center_pivot")


func _ensure_atmosphere_layers() -> void:
	if backdrop == null:
		return
	if not eerie_atmosphere_enabled:
		backdrop.color = Color(0.0, 0.0, 0.0, 1.0)
		if _cold_mist_layer != null:
			_cold_mist_layer.visible = false
		if _atmosphere_shader_rect != null:
			_atmosphere_shader_rect.visible = false
		_restack_intro_layers()
		return

	backdrop.color = deep_backdrop_color
	if _cold_mist_layer == null:
		_cold_mist_layer = ColorRect.new()
		_cold_mist_layer.name = "ColdMist"
		_cold_mist_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cold_mist_layer.layout_mode = 1
		_cold_mist_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_cold_mist_layer.anchor_right = 1.0
		_cold_mist_layer.anchor_bottom = 1.0
		add_child(_cold_mist_layer)
	else:
		_cold_mist_layer.visible = true
	_cold_mist_layer.color = cold_mist_color
	_cold_mist_layer.z_index = 0

	if _atmosphere_shader_rect == null and ResourceLoader.exists(ATMOSPHERE_SHADER_PATH):
		var sh: Shader = load(ATMOSPHERE_SHADER_PATH) as Shader
		if sh != null:
			_atmosphere_shader_rect = ColorRect.new()
			_atmosphere_shader_rect.name = "AtmosphereVignette"
			_atmosphere_shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_atmosphere_shader_rect.layout_mode = 1
			_atmosphere_shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			_atmosphere_shader_rect.anchor_right = 1.0
			_atmosphere_shader_rect.anchor_bottom = 1.0
			var mat := ShaderMaterial.new()
			mat.shader = sh
			_atmosphere_shader_rect.material = mat
			_atmosphere_mat = mat
			add_child(_atmosphere_shader_rect)
	elif _atmosphere_shader_rect != null:
		_atmosphere_shader_rect.visible = true
		_atmosphere_mat = _atmosphere_shader_rect.material as ShaderMaterial
	if _atmosphere_shader_rect != null:
		_atmosphere_shader_rect.z_index = 1
	if eerie_atmosphere_enabled:
		_apply_atmosphere_immediate("engine")
	_restack_intro_layers()


func _restack_intro_layers() -> void:
	if backdrop != null and backdrop.get_parent() == self:
		move_child(backdrop, 0)
	var insert_idx := 1
	if _cold_mist_layer != null and _cold_mist_layer.get_parent() == self and _cold_mist_layer.visible:
		move_child(_cold_mist_layer, mini(insert_idx, get_child_count() - 1))
		insert_idx = _cold_mist_layer.get_index() + 1
	if _atmosphere_shader_rect != null and _atmosphere_shader_rect.get_parent() == self and _atmosphere_shader_rect.visible:
		move_child(_atmosphere_shader_rect, mini(insert_idx, get_child_count() - 1))
		insert_idx = _atmosphere_shader_rect.get_index() + 1
	if _sparkle_layer != null and _sparkle_layer.get_parent() == self:
		move_child(_sparkle_layer, mini(insert_idx, get_child_count() - 1))
		insert_idx = _sparkle_layer.get_index() + 1
	if beats_root != null and beats_root.get_parent() == self:
		move_child(beats_root, mini(insert_idx, get_child_count() - 1))
		insert_idx = beats_root.get_index() + 1
	if has_node("SkipHint"):
		var skip_n := get_node("SkipHint")
		if skip_n.get_parent() == self:
			move_child(skip_n, mini(insert_idx, get_child_count() - 1))
			insert_idx = skip_n.get_index() + 1
	if sting_player != null and sting_player.get_parent() == self:
		move_child(sting_player, mini(insert_idx, get_child_count() - 1))


func _refresh_beats_center_pivot() -> void:
	if beats_root == null:
		return
	if beats_root.size.x < 8.0 or beats_root.size.y < 8.0:
		return
	beats_root.pivot_offset = beats_root.size * 0.5
	_beats_pivot_ready = true


func _start_intro_audio_beds() -> void:
	if intro_use_layered_bed and intro_wind_stream != null:
		if _wind_player == null:
			_wind_player = AudioStreamPlayer.new()
			_wind_player.name = "IntroWind"
			add_child(_wind_player)
		_try_enable_seamless_loop(intro_wind_stream)
		_wind_player.stream = intro_wind_stream
		_wind_player.bus = _safe_audio_bus_name(intro_wind_bus, "Music")
		_wind_player.volume_db = intro_wind_volume_db
		_wind_player.play()
	elif ambient_drone_stream != null:
		_start_ambient_drone_if_any()


func _start_ambient_drone_if_any() -> void:
	if ambient_drone_stream == null:
		return
	if _ambient_player == null:
		_ambient_player = AudioStreamPlayer.new()
		_ambient_player.name = "AmbientDrone"
		add_child(_ambient_player)
	_ambient_player.bus = _safe_audio_bus_name(ambient_drone_bus, "Music")
	_ambient_player.stream = ambient_drone_stream
	_ambient_player.volume_db = ambient_drone_volume_db
	if _ambient_player.stream is AudioStreamOggVorbis:
		(_ambient_player.stream as AudioStreamOggVorbis).loop = true
	elif _ambient_player.stream is AudioStreamMP3:
		(_ambient_player.stream as AudioStreamMP3).loop = true
	_ambient_player.play()


func _try_enable_seamless_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true


func _safe_audio_bus_name(bus_name: String, fallback: String) -> String:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return bus_name
	if AudioServer.get_bus_index(fallback) >= 0:
		return fallback
	return "Master"


func _atmosphere_targets_for_beat(beat_id: String) -> Dictionary:
	match beat_id:
		"engine":
			return {
				"mist": atmosphere_engine_mist_color,
				"inner": atmosphere_engine_vignette_inner,
				"outer": atmosphere_engine_vignette_outer,
				"strength": atmosphere_engine_vignette_strength,
				"deep_tint": atmosphere_engine_deep_tint,
				"grain": atmosphere_engine_grain,
			}
		"studio":
			return {
				"mist": atmosphere_studio_mist_color,
				"inner": atmosphere_studio_vignette_inner,
				"outer": atmosphere_studio_vignette_outer,
				"strength": atmosphere_studio_vignette_strength,
				"deep_tint": atmosphere_studio_deep_tint,
				"grain": atmosphere_studio_grain,
			}
		"game":
			return {
				"mist": atmosphere_game_mist_color,
				"inner": atmosphere_game_vignette_inner,
				"outer": atmosphere_game_vignette_outer,
				"strength": atmosphere_game_vignette_strength,
				"deep_tint": atmosphere_game_deep_tint,
				"grain": atmosphere_game_grain,
			}
		_:
			return _atmosphere_targets_for_beat("engine")


func _apply_atmosphere_immediate(beat_id: String) -> void:
	var t: Dictionary = _atmosphere_targets_for_beat(beat_id)
	if _cold_mist_layer != null:
		_cold_mist_layer.color = t["mist"] as Color
	if _atmosphere_mat != null:
		_atmosphere_mat.set_shader_parameter("inner_radius", t["inner"])
		_atmosphere_mat.set_shader_parameter("outer_radius", t["outer"])
		_atmosphere_mat.set_shader_parameter("vignette_strength", t["strength"])
		_atmosphere_mat.set_shader_parameter("grain_amount", t["grain"])
		var tc: Color = t["deep_tint"] as Color
		_atmosphere_mat.set_shader_parameter("deep_tint", Vector3(tc.r, tc.g, tc.b))


func _kill_atmosphere_tween() -> void:
	if _atmosphere_tween != null and is_instance_valid(_atmosphere_tween):
		if _atmosphere_tween.is_running():
			_atmosphere_tween.kill()
	_atmosphere_tween = null


func _tween_atmosphere_to_beat(beat_id: String) -> void:
	if not eerie_atmosphere_enabled:
		return
	_kill_atmosphere_tween()
	if not atmosphere_beat_tween_enabled:
		_apply_atmosphere_immediate(beat_id)
		return
	var t: Dictionary = _atmosphere_targets_for_beat(beat_id)
	var dur: float = maxf(0.02, atmosphere_beat_tween_seconds)
	var mat := _atmosphere_mat
	if _cold_mist_layer == null and mat == null:
		return
	var tw := create_tween()
	_atmosphere_tween = tw
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _cold_mist_layer != null:
		tw.tween_property(_cold_mist_layer, "color", t["mist"] as Color, dur)
	if mat != null:
		var cur_inner: float = float(mat.get_shader_parameter("inner_radius"))
		var cur_outer: float = float(mat.get_shader_parameter("outer_radius"))
		var cur_strength: float = float(mat.get_shader_parameter("vignette_strength"))
		var cur_grain: float = float(mat.get_shader_parameter("grain_amount"))
		var cur_tint_var: Variant = mat.get_shader_parameter("deep_tint")
		var cur_v3: Vector3
		if cur_tint_var is Vector3:
			cur_v3 = cur_tint_var as Vector3
		elif cur_tint_var is Color:
			var cc: Color = cur_tint_var as Color
			cur_v3 = Vector3(cc.r, cc.g, cc.b)
		else:
			var dc: Color = t["deep_tint"] as Color
			cur_v3 = Vector3(dc.r, dc.g, dc.b)
		var dc2: Color = t["deep_tint"] as Color
		var end_v3 := Vector3(dc2.r, dc2.g, dc2.b)
		tw.tween_method(
			func(v: float) -> void: mat.set_shader_parameter("inner_radius", v),
			cur_inner, float(t["inner"]), dur
		)
		tw.tween_method(
			func(v: float) -> void: mat.set_shader_parameter("outer_radius", v),
			cur_outer, float(t["outer"]), dur
		)
		tw.tween_method(
			func(v: float) -> void: mat.set_shader_parameter("vignette_strength", v),
			cur_strength, float(t["strength"]), dur
		)
		tw.tween_method(
			func(v: float) -> void: mat.set_shader_parameter("grain_amount", v),
			cur_grain, float(t["grain"]), dur
		)
		tw.tween_method(
			func(v: Vector3) -> void: mat.set_shader_parameter("deep_tint", v),
			cur_v3, end_v3, dur
		)


func _ensure_studio_sting_players() -> void:
	if _studio_riser_player == null:
		_studio_riser_player = AudioStreamPlayer.new()
		_studio_riser_player.name = "IntroRiser"
		_studio_riser_player.bus = _safe_audio_bus_name(intro_sting_bus, "SFX")
		add_child(_studio_riser_player)
	if _studio_bell_player == null:
		_studio_bell_player = AudioStreamPlayer.new()
		_studio_bell_player.name = "IntroBell"
		_studio_bell_player.bus = _safe_audio_bus_name(intro_sting_bus, "SFX")
		add_child(_studio_bell_player)
	if _studio_tail_player == null:
		_studio_tail_player = AudioStreamPlayer.new()
		_studio_tail_player.name = "IntroReversedTail"
		_studio_tail_player.bus = _safe_audio_bus_name(intro_sting_bus, "SFX")
		add_child(_studio_tail_player)


func _begin_studio_sting_sequence() -> void:
	if not intro_studio_sting_use_layers:
		if sting_player != null and sting_player.stream != null:
			sting_player.play()
		return
	var bell: AudioStream = intro_studio_bell_stream
	var riser: AudioStream = intro_studio_reversed_riser_stream
	var tail: AudioStream = intro_studio_reversed_tail_stream
	if bell == null and riser == null and tail == null:
		if sting_player != null and sting_player.stream != null:
			sting_player.play()
		return
	_ensure_studio_sting_players()
	var tree := get_tree()
	if tree == null:
		return
	if riser != null:
		_studio_riser_player.stream = riser
		_studio_riser_player.play()
	var delay: float = intro_riser_lead_seconds if riser != null else 0.0
	tree.create_timer(delay).timeout.connect(_on_studio_sting_bell_step.bind(bell, tail), CONNECT_ONE_SHOT)


func _on_studio_sting_bell_step(bell: AudioStream, tail: AudioStream) -> void:
	if _is_leaving:
		return
	if bell != null and _studio_bell_player != null:
		_studio_bell_player.stream = bell
		_studio_bell_player.play()
	if tail == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(intro_post_bell_tail_delay_sec).timeout.connect(_on_studio_sting_tail_step.bind(tail), CONNECT_ONE_SHOT)


func _on_studio_sting_tail_step(tail: AudioStream) -> void:
	if _is_leaving or tail == null or _studio_tail_player == null:
		return
	_studio_tail_player.stream = tail
	_studio_tail_player.play()


func _apply_export_textures_and_copy() -> void:
	if engine_primary_label != null:
		engine_primary_label.text = engine_line_primary
	if engine_secondary_label != null:
		engine_secondary_label.text = engine_line_secondary
		engine_secondary_label.visible = not engine_line_secondary.strip_edges().is_empty()
	if engine_logo_rect != null:
		var eng_tex: Texture2D = engine_logo_texture
		if eng_tex == null and ResourceLoader.exists(DEFAULT_ENGINE_LOGO_PATH):
			eng_tex = load(DEFAULT_ENGINE_LOGO_PATH) as Texture2D
		engine_logo_rect.visible = eng_tex != null
		if eng_tex != null:
			engine_logo_rect.texture = eng_tex
	if logo_texture != null and logo_rect != null:
		logo_rect.texture = logo_texture
	if title_label != null:
		title_label.text = studio_name
	if tagline_label != null:
		tagline_label.text = studio_tagline
		tagline_label.visible = not studio_tagline.strip_edges().is_empty()
	if game_logo_rect != null:
		game_logo_rect.visible = game_logo_texture != null
		if game_logo_texture != null:
			game_logo_rect.texture = game_logo_texture
	if game_title_label != null:
		game_title_label.text = game_title_text
		game_title_label.visible = not game_title_text.strip_edges().is_empty()
	if game_tagline_label != null:
		game_tagline_label.text = game_tagline_text
		game_tagline_label.visible = not game_tagline_text.strip_edges().is_empty()
	if engine_godot_version != null:
		engine_godot_version.text = GameVersion.get_godot_version_label()
	if engine_godot_legal != null:
		engine_godot_legal.text = "%s\n%s" % [GameVersion.get_godot_attribution_short(), "https://godotengine.org"]
	if studio_copyright_label != null:
		studio_copyright_label.text = GameVersion.get_game_copyright_line()
	if game_copyright_label != null:
		game_copyright_label.text = GameVersion.get_game_copyright_line()


func _hide_all_beats() -> void:
	for p in [beat_engine, beat_studio, beat_game]:
		if p == null:
			continue
		p.visible = false
		p.modulate.a = 0.0


func _start_intro_sequence() -> void:
	_sequence_running = true
	var beats: Array[Dictionary] = _build_beat_queue()
	if beats.is_empty():
		_go_next_scene()
		return
	for b in beats:
		if _is_leaving:
			return
		await _play_beat_async(b)
		if _is_leaving:
			return
	_sequence_running = false
	if not _is_leaving:
		_go_next_scene()


func _build_beat_queue() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if beat_engine_enabled and beat_engine != null:
		var eng_logo: Control = null
		if engine_logo_rect != null and engine_logo_rect.visible:
			eng_logo = engine_logo_rect
		out.append({
			"id": "engine",
			"root": beat_engine,
			"logo": eng_logo,
			"fade_in": maxf(0.05, engine_fade_in_seconds),
			"hold": maxf(0.0, engine_hold_seconds),
			"fade_out": maxf(0.05, engine_fade_out_seconds),
		})
	if beat_studio_enabled and beat_studio != null:
		out.append({
			"id": "studio",
			"root": beat_studio,
			"logo": logo_rect,
			"fade_in": maxf(0.05, studio_fade_in_seconds),
			"hold": maxf(0.0, studio_hold_seconds),
			"fade_out": maxf(0.05, studio_fade_out_seconds),
		})
	if beat_game_enabled and beat_game != null and _beat_game_has_visible_content():
		out.append({
			"id": "game",
			"root": beat_game,
			"logo": game_logo_rect if game_logo_rect != null and game_logo_rect.visible else null,
			"fade_in": maxf(0.05, game_fade_in_seconds),
			"hold": maxf(0.0, game_hold_seconds),
			"fade_out": maxf(0.05, game_fade_out_seconds),
		})
	return out


func _beat_game_has_visible_content() -> bool:
	if game_logo_rect != null and game_logo_texture != null:
		return true
	if game_title_label != null and not game_title_text.strip_edges().is_empty():
		return true
	if game_tagline_label != null and not game_tagline_text.strip_edges().is_empty():
		return true
	return false


func _play_beat_async(b: Dictionary) -> void:
	var root: Control = b["root"] as Control
	var logo: Variant = b.get("logo", null)
	_active_beat_root = root
	_tween_atmosphere_to_beat(str(b.get("id", "")))
	root.visible = true
	root.modulate.a = 0.0
	if logo is Control and logo != null:
		(logo as Control).scale = Vector2(0.96, 0.96)

	if b.get("id") == "studio" and play_sting_on_studio_beat:
		_begin_studio_sting_sequence()

	if skip_hint != null:
		skip_hint.visible = allow_skip and show_skip_hint

	var fade_in: float = b["fade_in"]
	var hold: float = b["hold"]
	var fade_out: float = b["fade_out"]

	# Fade in (separate tween so completion is reliable across Godot versions).
	var tw_in := create_tween()
	tw_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_in.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(root, "modulate:a", 1.0, fade_in)
	if logo is Control and logo != null:
		tw_in.parallel().tween_property(logo as Control, "scale", Vector2.ONE, fade_in).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var code := await _await_tween_with_skip(tw_in, root, true)
	if code != 0 or _is_leaving:
		_finalize_beat_panel(root)
		return

	code = await _await_hold_with_skip(root, hold)
	if code != 0 or _is_leaving:
		_finalize_beat_panel(root)
		return

	var tw_out := create_tween()
	tw_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw_out.tween_property(root, "modulate:a", 0.0, fade_out)
	await _await_tween_with_skip(tw_out, root, true)
	_finalize_beat_panel(root)


## 0 = completed, 1 = advance to next beat (caller cleans up panel), 2 = exit intro to main menu
func _await_tween_with_skip(tw: Tween, root: Control, fast_fade_on_skip: bool) -> int:
	_active_beat_tween = tw
	while tw.is_running() and not _is_leaving:
		if allow_skip and _skip_beat_requested:
			_skip_beat_requested = false
			tw.kill()
			if not skip_advances_beat:
				_go_next_scene()
				_active_beat_tween = null
				return 2
			if fast_fade_on_skip and root != null:
				await _fast_fade_out_beat(root)
			_active_beat_tween = null
			return 1
		await get_tree().process_frame
	_active_beat_tween = null
	return 0


func _await_hold_with_skip(root: Control, hold: float) -> int:
	var end_usec: int = Time.get_ticks_usec() + int(round(clampf(hold, 0.0, 600.0) * 1_000_000.0))
	while Time.get_ticks_usec() < end_usec and not _is_leaving:
		if allow_skip and _skip_beat_requested:
			_skip_beat_requested = false
			if not skip_advances_beat:
				_go_next_scene()
				return 2
			await _fast_fade_out_beat(root)
			return 1
		await get_tree().process_frame
	return 0


func _finalize_beat_panel(root: Control) -> void:
	_active_beat_root = null
	if root == null:
		return
	root.visible = false
	root.modulate.a = 0.0


func _fast_fade_out_beat(root: Control) -> void:
	if root == null:
		return
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(root, "modulate:a", 0.0, maxf(0.04, skip_fast_fade_seconds))
	await tw.finished


func _process(delta: float) -> void:
	_elapsed += delta
	_update_sparkles(delta)
	if not _beats_pivot_ready and beats_root != null and beats_root.size.length() > 32.0:
		_refresh_beats_center_pivot()
	if _is_leaving:
		return
	if eerie_atmosphere_enabled and beats_root != null and _beats_pivot_ready:
		var breathe := 1.0 + breathing_strength * sin(_elapsed * TAU * breathing_hz)
		beats_root.scale = Vector2(breathe, breathe)
		beats_root.rotation_degrees = unease_sway_degrees * sin(_elapsed * TAU * unease_sway_hz)


func _unhandled_input(event: InputEvent) -> void:
	if not allow_skip:
		return
	if _elapsed < minimum_skip_delay:
		return
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		return
	if event is InputEventKey and not event.pressed:
		return
	if event is InputEventMouseButton and not event.pressed:
		return
	if event is InputEventJoypadButton and not event.pressed:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_request_skip()
		return
	if event is InputEventKey and event.pressed:
		_request_skip()
	elif event is InputEventMouseButton and event.pressed:
		_request_skip()
	elif event is InputEventJoypadButton and event.pressed:
		_request_skip()


func _request_skip() -> void:
	if not skip_advances_beat:
		_go_next_scene()
		return
	if not _sequence_running:
		_go_next_scene()
		return
	_skip_beat_requested = true


func _setup_visual_state() -> void:
	var gold_text := Color(0.95, 0.79, 0.28, 1.0)
	var cool_sub := Color(0.83, 0.90, 0.98, 0.95)
	if eerie_atmosphere_enabled:
		gold_text = Color(0.72, 0.62, 0.45, 1.0)
		cool_sub = Color(0.55, 0.70, 0.80, 0.88)
	for lbl in [engine_primary_label, engine_secondary_label]:
		if lbl == null:
			continue
		lbl.modulate.a = 1.0
		lbl.add_theme_font_size_override("font_size", 34 if lbl == engine_primary_label else 20)
		lbl.add_theme_color_override("font_color", Color(0.88, 0.90, 0.95, 1.0))
		lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
		lbl.add_theme_constant_override("outline_size", 2 if lbl == engine_primary_label else 1)

	if engine_logo_rect != null:
		engine_logo_rect.modulate.a = 1.0
		engine_logo_rect.custom_minimum_size = Vector2(220, 220)

	if engine_godot_version != null:
		engine_godot_version.modulate.a = 1.0
		engine_godot_version.add_theme_font_size_override("font_size", 22)
		engine_godot_version.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
		engine_godot_version.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
		engine_godot_version.add_theme_constant_override("outline_size", 1)
	if engine_godot_legal != null:
		engine_godot_legal.modulate.a = 1.0
		engine_godot_legal.add_theme_font_size_override("font_size", 15)
		engine_godot_legal.add_theme_color_override("font_color", Color(0.62, 0.60, 0.56, 0.95))
		engine_godot_legal.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		engine_godot_legal.add_theme_constant_override("outline_size", 1)

	for node in [logo_rect, title_label, tagline_label]:
		if node == null:
			continue
		node.modulate.a = 1.0
	if logo_rect != null:
		logo_rect.scale = Vector2.ONE
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", 56)
		title_label.add_theme_color_override("font_color", gold_text)
		title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		title_label.add_theme_constant_override("outline_size", 3)
	if tagline_label != null:
		tagline_label.add_theme_font_size_override("font_size", 24)
		tagline_label.add_theme_color_override("font_color", cool_sub)
		tagline_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		tagline_label.add_theme_constant_override("outline_size", 2)
	if studio_copyright_label != null:
		studio_copyright_label.modulate.a = 1.0
		studio_copyright_label.add_theme_font_size_override("font_size", 17)
		studio_copyright_label.add_theme_color_override("font_color", Color(0.65, 0.62, 0.56, 0.92))
		studio_copyright_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		studio_copyright_label.add_theme_constant_override("outline_size", 1)

	for node in [game_logo_rect, game_title_label, game_tagline_label]:
		if node == null:
			continue
		node.modulate.a = 1.0
	if game_logo_rect != null:
		game_logo_rect.scale = Vector2.ONE
		game_logo_rect.custom_minimum_size = Vector2(900, 320)
	if game_title_label != null:
		game_title_label.add_theme_font_size_override("font_size", 44)
		game_title_label.add_theme_color_override("font_color", gold_text)
		game_title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		game_title_label.add_theme_constant_override("outline_size", 3)
	if game_tagline_label != null:
		game_tagline_label.add_theme_font_size_override("font_size", 22)
		game_tagline_label.add_theme_color_override("font_color", cool_sub)
		game_tagline_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		game_tagline_label.add_theme_constant_override("outline_size", 2)
	if game_copyright_label != null:
		game_copyright_label.modulate.a = 1.0
		game_copyright_label.add_theme_font_size_override("font_size", 17)
		game_copyright_label.add_theme_color_override("font_color", Color(0.65, 0.62, 0.56, 0.92))
		game_copyright_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		game_copyright_label.add_theme_constant_override("outline_size", 1)

	if skip_hint != null:
		skip_hint.text = "Press any key to skip"
		skip_hint.visible = allow_skip and show_skip_hint
		skip_hint.modulate.a = 0.9
		skip_hint.add_theme_font_size_override("font_size", 18)
		skip_hint.add_theme_color_override("font_color", Color(0.78, 0.75, 0.70, 0.78))
		skip_hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		skip_hint.add_theme_constant_override("outline_size", 1)


func _go_next_scene() -> void:
	if _is_leaving:
		return
	_is_leaving = true
	if (_ambient_player != null and _ambient_player.playing) or (_wind_player != null and _wind_player.playing):
		var tw_a := create_tween()
		tw_a.set_parallel(true)
		if _ambient_player != null and _ambient_player.playing:
			tw_a.tween_property(_ambient_player, "volume_db", -80.0, 0.45)
		if _wind_player != null and _wind_player.playing:
			tw_a.tween_property(_wind_player, "volume_db", -80.0, 0.45)
	if _active_beat_tween != null:
		if _active_beat_tween.is_running():
			_active_beat_tween.kill()
		_active_beat_tween = null
	if next_scene_path.is_empty():
		next_scene_path = "res://Scenes/main_menu.tscn"
	if handoff_from_black_no_flash:
		_fade_to_black_before_handoff()
		return
	if Engine.has_singleton("SceneTransition"):
		if use_soft_scene_handoff:
			SceneTransition.change_scene_to_file(
				next_scene_path,
				handoff_fade_out_seconds,
				handoff_fade_in_seconds,
				handoff_hold_black_seconds
			)
		else:
			SceneTransition.change_scene_to_file(next_scene_path)
	else:
		get_tree().change_scene_to_file(next_scene_path)


func _fade_to_black_before_handoff() -> void:
	if _handoff_black_rect == null:
		_handoff_black_rect = ColorRect.new()
		_handoff_black_rect.name = "HandoffBlack"
		_handoff_black_rect.layout_mode = 1
		_handoff_black_rect.anchors_preset = Control.PRESET_FULL_RECT
		_handoff_black_rect.anchor_right = 1.0
		_handoff_black_rect.anchor_bottom = 1.0
		_handoff_black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_handoff_black_rect.z_index = 200
		_handoff_black_rect.color = Color(0.0, 0.0, 0.0, 1.0)
		_handoff_black_rect.modulate.a = 0.0
		add_child(_handoff_black_rect)

	var fade_duration: float = maxf(0.05, handoff_fade_out_seconds)
	var tw: Tween = create_tween()
	tw.tween_property(_handoff_black_rect, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		Engine.set_meta("studio_intro_black_handoff", true)
		Engine.set_meta("studio_intro_black_handoff_fade", handoff_fade_in_seconds)
		if Engine.has_singleton("SceneTransition") and SceneTransition.has_method("change_scene_from_black"):
			SceneTransition.change_scene_from_black(
				next_scene_path,
				0.0,
				handoff_hold_black_seconds
			)
			return
		get_tree().change_scene_to_file(next_scene_path)
	)


func _spawn_sparkles() -> void:
	if not sparkles_enabled:
		_restack_intro_layers()
		return
	var count: int = maxi(0, sparkles_count)
	if count <= 0:
		_restack_intro_layers()
		return
	_sparkle_layer = Control.new()
	_sparkle_layer.name = "SparkleLayer"
	_sparkle_layer.layout_mode = 1
	_sparkle_layer.anchors_preset = Control.PRESET_FULL_RECT
	_sparkle_layer.anchor_right = 1.0
	_sparkle_layer.anchor_bottom = 1.0
	_sparkle_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparkle_layer.z_index = 2
	add_child(_sparkle_layer)
	_restack_intro_layers()

	_sparkles.clear()
	_sparkle_velocity.clear()
	_sparkle_base_alpha.clear()
	_sparkle_phase.clear()
	_sparkle_twinkle_speed.clear()
	var viewport_size: Vector2 = get_viewport_rect().size
	for i in count:
		var dot := ColorRect.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var px_size: int = _sparkle_rng.randi_range(maxi(1, sparkles_min_size), maxi(maxi(1, sparkles_min_size), sparkles_max_size))
		dot.custom_minimum_size = Vector2(px_size, px_size)
		dot.size = Vector2(px_size, px_size)
		var base_alpha: float = _sparkle_rng.randf_range(clampf(sparkles_alpha_min, 0.02, 1.0), clampf(maxf(sparkles_alpha_min, sparkles_alpha_max), 0.02, 1.0))
		dot.color = Color(sparkles_tint.r, sparkles_tint.g, sparkles_tint.b, base_alpha)
		dot.position = Vector2(
			_sparkle_rng.randf_range(0.0, maxf(viewport_size.x, 1.0)),
			_sparkle_rng.randf_range(0.0, maxf(viewport_size.y, 1.0))
		)
		_sparkle_layer.add_child(dot)
		_sparkles.append(dot)
		var vx := _sparkle_rng.randf_range(-5.0, 5.0)
		var vy := _sparkle_rng.randf_range(sparkles_min_speed, maxf(sparkles_min_speed, sparkles_max_speed))
		if eerie_atmosphere_enabled:
			vy += sparkle_sink_bias * (6.0 + _sparkle_rng.randf() * 4.0)
		_sparkle_velocity.append(Vector2(vx, vy))
		_sparkle_base_alpha.append(base_alpha)
		_sparkle_phase.append(_sparkle_rng.randf_range(0.0, TAU))
		_sparkle_twinkle_speed.append(_sparkle_rng.randf_range(0.7, 1.8))


func _update_sparkles(delta: float) -> void:
	if _sparkles.is_empty():
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var twinkle_time: float = Time.get_ticks_msec() / 1000.0
	for i in _sparkles.size():
		var dot: ColorRect = _sparkles[i]
		if dot == null:
			continue
		var vel: Vector2 = _sparkle_velocity[i]
		dot.position += vel * delta
		if eerie_atmosphere_enabled:
			var wisp: float = sin(twinkle_time * 0.62 + float(i) * 1.17) * 18.0
			dot.position.x += wisp * delta
		if dot.position.y > viewport_size.y + 8.0:
			dot.position.y = -8.0
			dot.position.x = _sparkle_rng.randf_range(0.0, maxf(viewport_size.x, 1.0))
		elif dot.position.y < -8.0:
			dot.position.y = viewport_size.y + 8.0
			dot.position.x = _sparkle_rng.randf_range(0.0, maxf(viewport_size.x, 1.0))
		if dot.position.x > viewport_size.x + 8.0:
			dot.position.x = -8.0
		elif dot.position.x < -8.0:
			dot.position.x = viewport_size.x + 8.0
		var base_alpha: float = _sparkle_base_alpha[i]
		var phase: float = _sparkle_phase[i]
		var speed: float = _sparkle_twinkle_speed[i]
		var twinkle: float = 0.78 + 0.22 * sin((twinkle_time * speed) + phase)
		dot.color = Color(
			sparkles_tint.r,
			sparkles_tint.g,
			sparkles_tint.b,
			clampf(base_alpha * twinkle, 0.0, 1.0)
		)
