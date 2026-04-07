extends Control

const DEFAULT_ENGINE_LOGO_PATH := "res://Assets/UI/godot_engine_logo.svg"
const ATMOSPHERE_SHADER_PATH := "res://Scripts/UI/studio_intro_atmosphere.gdshader"
const SHOCKWAVE_SHADER_PATH := "res://Scripts/UI/studio_intro_shockwave.gdshader"
const GAME_LOGO_SHADER_PATH := "res://Scripts/UI/studio_intro_game_logo.gdshader"
const GAME_MOTE_SHADER_PATH := "res://Scripts/UI/studio_intro_game_mote.gdshader"

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

@export_group("Beat – Game juice (LoA)")
## Master toggle for game-beat logo shader + motion + sting-linked FX (Korvain beat unchanged).
@export var game_logo_juice_enabled: bool = true
@export_range(0.0, 0.04) var game_logo_rift_amount: float = 0.008
@export_range(0.0, 0.008) var game_logo_parallax_uv: float = 0.0022
@export_range(0.0, 1.0) var game_logo_shimmer: float = 0.48
@export_range(0.0, 0.2) var game_logo_breath: float = 0.07
@export_range(0.88, 1.0) var game_logo_entry_scale_from: float = 0.94
@export_range(1.0, 1.06) var game_logo_settle_overshoot: float = 1.02
@export_range(0.0, 0.2) var game_logo_sting_vignette_pulse: float = 0.09
@export_range(0.0, 16.0) var game_logo_sting_shake_px: float = 5.0
## Continuous spawn rate during the game beat (stable “river,” not timer bursts).
@export_range(18.0, 280.0) var game_logo_motes_per_second: float = 132.0
## Cap live motes; when full, accumulation pauses (no catch-up storms).
@export_range(60, 520) var game_logo_mote_max_alive: int = 400
## Max fractional motes banked right after the cap opens (limits one-frame catch-up).
@export_range(1.5, 22.0) var game_logo_mote_spawn_burst_cap: float = 11.0
## Side-to-side loops along the path (0 = straight suck-in).
@export_range(0.0, 6.0) var game_logo_mote_swirl_loops: float = 1.65
## Peak perpendicular offset (px, bucket space); dies off at start/end of path.
@export_range(0.0, 140.0) var game_logo_mote_swirl_amplitude_px: float = 26.0
## Extra spin on each speck (rad); 0 disables.
@export_range(0.0, 4.5) var game_logo_mote_spin_max_rad: float = 1.15
@export_range(0.0, 0.12) var game_logo_mote_uv_distort: float = 0.042
@export_range(0.5, 8.0) var game_logo_mote_wobble_hz: float = 3.2
@export_range(0.0, 0.28) var game_logo_mote_stream_strength: float = 0.1
@export_range(0.2, 14.0) var game_logo_mote_stream_speed: float = 5.0
@export_range(2.0, 14.0) var game_logo_mote_stream_ribbons: float = 7.0
@export_range(1.5, 12.0) var game_logo_mote_px_min: float = 3.4
@export_range(2.0, 18.0) var game_logo_mote_px_max: float = 7.8
## Ember field opacity during the LoA beat (0 = fully faded out).
@export_range(0.0, 1.0) var game_beat_background_sparkle_alpha: float = 0.0

@export_group("Scene Handoff")
@export var use_soft_scene_handoff: bool = true
@export var handoff_fade_out_seconds: float = 0.70
@export var handoff_fade_in_seconds: float = 0.95
@export var handoff_hold_black_seconds: float = 0.10
@export var handoff_from_black_no_flash: bool = true

@export_group("Audio")
## Play the sting when the studio beat begins (ignored if no stream).
@export var play_sting_on_studio_beat: bool = true
## Play the game/title sting when the game beat begins (ignored if no stream).
@export var play_sting_on_game_beat: bool = true
## Optional delay (seconds) after the game beat begins before playing the game sting.
@export var game_sting_delay_seconds: float = 0.0
## Studio sting trim (seconds). If stop > start, the sting fades out and stops by [member studio_sting_stop_seconds].
@export var studio_sting_start_seconds: float = 0.0
@export var studio_sting_stop_seconds: float = 0.0
@export var studio_sting_fadein_seconds: float = 0.0
@export var studio_sting_fadeout_seconds: float = 0.25
## Game sting trim (seconds). If stop > start, the sting fades out and stops by [member game_sting_stop_seconds].
@export var game_sting_start_seconds: float = 0.0
@export var game_sting_stop_seconds: float = 0.0
@export var game_sting_fadein_seconds: float = 0.0
@export var game_sting_fadeout_seconds: float = 0.25
## Slightly lower pitch reads heavier / more ominous on the studio sting (single StingPlayer only).
@export_range(0.5, 1.2) var sting_pitch_scale: float = 1.0
## Slight pitch lift helps the game/title sting read brighter than the studio sting.
@export_range(0.5, 1.3) var game_sting_pitch_scale: float = 1.0
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
@export var sparkles_count: int = 45 # Increased from 16
@export var sparkles_min_speed: float = 2.0
@export var sparkles_max_speed: float = 8.0
@export var sparkles_min_size: int = 12 # Massively increased to account for soft texture falloff
@export var sparkles_max_size: int = 36 # Massively increased
@export var sparkles_alpha_min: float = 0.45 # Huge boost from 0.08
@export var sparkles_alpha_max: float = 0.95 # Huge boost from 0.38
@export var sparkles_tint: Color = Color(0.98, 0.88, 0.55, 1.0) # Switched from dark blue to bright warm gold

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

@export_group("Studio Burst")
## Multiplies the outward impulse when the studio beat begins.
@export_range(0.0, 6.0) var studio_burst_strength: float = 3.0
## Briefly scales sparkles up during the burst (then returns to normal).
@export_range(0.0, 2.0) var studio_burst_scale_boost: float = 0.75
## Seconds for the burst scale/alpha to settle back to normal.
@export_range(0.02, 2.0) var studio_burst_settle_seconds: float = 0.55
## Boosts sparkle opacity during the burst (then returns to normal). 0 disables.
@export_range(0.0, 1.0) var studio_burst_alpha_boost: float = 0.35
## Minimum/maximum base impulse used before applying strength multiplier.
@export var studio_burst_force_min: float = 260.0
@export var studio_burst_force_max: float = 1250.0
## Seconds after the studio sting begins before the visual burst triggers.
@export var studio_burst_delay_seconds: float = 1.0

@export_group("Studio Impact")
## Micro shake on the studio burst.
@export_range(0.0, 24.0) var studio_impact_shake_px: float = 10.0
@export_range(0.02, 0.6) var studio_impact_shake_seconds: float = 0.16
@export_range(0.0, 1.0) var studio_impact_shake_decay: float = 0.65
## Shockwave ring.
@export_range(0.05, 1.5) var studio_shockwave_seconds: float = 0.42
@export_range(0.0, 2.0) var studio_shockwave_strength: float = 0.75
@export_range(0.01, 0.2) var studio_shockwave_thickness: float = 0.075
@export_range(0.005, 0.12) var studio_shockwave_softness: float = 0.03
@export var studio_shockwave_tint: Color = Color(1.0, 0.92, 0.62, 1.0)
## Screen-space distortion amount for the shockwave (0 disables).
@export_range(0.0, 0.08) var studio_shockwave_distort_strength: float = 0.03

@export_group("Studio Logo Fall")
@export var studio_logo_fall_enabled: bool = true
@export var studio_logo_fall_height_px: float = 520.0
## Extra margin so the scaled proxy is fully outside the viewport before the tween (px).
@export_range(0.0, 240.0) var studio_logo_fall_screen_margin_px: float = 96.0
## Which screen edge the logo enters from before landing in the layout slot.
@export var studio_logo_fall_from_edge: String = "top" # "top" | "left" | "right"
@export_range(0.05, 2.0) var studio_logo_fall_seconds: float = 0.85
@export_range(0.0, 0.6) var studio_logo_impact_settle_seconds: float = 0.18

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
@onready var game_sting_player: AudioStreamPlayer = get_node_or_null("GameStingPlayer") as AudioStreamPlayer
@onready var backdrop: ColorRect = $Backdrop

var _sting_base_volume_db: float = 0.0
var _game_sting_base_volume_db: float = 0.0

var _elapsed: float = 0.0
var _is_leaving: bool = false
var _skip_beat_requested: bool = false
var _sequence_running: bool = false
var _active_beat_tween: Tween = null
var _active_beat_root: Control = null
var _sparkle_layer: Control = null
var _sparkles: Array[Sprite2D] = []
var _sparkle_velocity: Array[Vector2] = []
var _sparkle_base_alpha: Array[float] = []
var _sparkle_phase: Array[float] = []
var _sparkle_twinkle_speed: Array[float] = []
var _sparkle_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _handoff_black_rect: ColorRect = null
var _cold_mist_layer: ColorRect = null
var _atmosphere_shader_rect: ColorRect = null
var _atmosphere_mat: ShaderMaterial = null
var _shockwave_rect: ColorRect = null
var _shockwave_mat: ShaderMaterial = null
var _atmosphere_tween: Tween = null
var _ambient_player: AudioStreamPlayer = null
var _wind_player: AudioStreamPlayer = null
var _studio_riser_player: AudioStreamPlayer = null
var _studio_bell_player: AudioStreamPlayer = null
var _studio_tail_player: AudioStreamPlayer = null
var _beats_pivot_ready: bool = false
var _beats_shake_origin: Vector2 = Vector2.ZERO
var _beats_shake_tw: Tween = null
var _game_beat_motes_holder: Control = null
var _game_beat_mote_stream_active: bool = false
var _game_beat_mote_spawn_acc: float = 0.0
var _game_sting_fx_tween: Tween = null
var _game_logo_juice_mat: ShaderMaterial = null
var _game_beat_mote_shared_mat: ShaderMaterial = null
var _studio_sting_started_at_usec: int = 0
## Bumped on skip / scene exit so one-shot SceneTreeTimers (burst, sting delay) no-op.
var _skip_abort_token: int = 0
var _beat_panel_rest_pos: Dictionary = {}
var _beats_root_rest_pos: Vector2 = Vector2.ZERO
var _studio_logo_fall_tw: Tween = null
var _studio_logo_settle_tw: Tween = null
var _game_logo_settle_tw: Tween = null
var _shockwave_run_tw: Tween = null


func _ready() -> void:
	if sting_player != null:
		sting_player.bus = "SFX"
		sting_player.pitch_scale = sting_pitch_scale
		_sting_base_volume_db = sting_player.volume_db
	if game_sting_player != null:
		game_sting_player.bus = "SFX"
		game_sting_player.pitch_scale = game_sting_pitch_scale
		_game_sting_base_volume_db = game_sting_player.volume_db
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
	_cache_beat_panel_rest_positions()
	if beats_root != null:
		_beats_root_rest_pos = beats_root.position
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

	if _shockwave_rect == null and ResourceLoader.exists(SHOCKWAVE_SHADER_PATH):
		var sh_sw: Shader = load(SHOCKWAVE_SHADER_PATH) as Shader
		if sh_sw != null:
			_shockwave_rect = ColorRect.new()
			_shockwave_rect.name = "Shockwave"
			_shockwave_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_shockwave_rect.layout_mode = 1
			_shockwave_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			_shockwave_rect.anchor_right = 1.0
			_shockwave_rect.anchor_bottom = 1.0
			_shockwave_rect.color = Color(1, 1, 1, 0)
			var sw_mat := ShaderMaterial.new()
			sw_mat.shader = sh_sw
			_shockwave_rect.material = sw_mat
			_shockwave_mat = sw_mat
			_shockwave_rect.visible = false
			add_child(_shockwave_rect)
	elif _shockwave_rect != null:
		# Keep hidden unless actively animating a burst; avoids unintended glow on other beats.
		_shockwave_rect.visible = false
		_shockwave_mat = _shockwave_rect.material as ShaderMaterial
	if _shockwave_rect != null:
		_shockwave_rect.z_index = 3
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
	if _shockwave_rect != null and _shockwave_rect.get_parent() == self and _shockwave_rect.visible:
		move_child(_shockwave_rect, mini(insert_idx, get_child_count() - 1))
		insert_idx = _shockwave_rect.get_index() + 1
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


func _cache_beat_panel_rest_positions() -> void:
	_beat_panel_rest_pos.clear()
	for p in [beat_engine, beat_studio, beat_game]:
		if p != null:
			_beat_panel_rest_pos[p] = p.position


func _invalidate_intro_deferred_callbacks() -> void:
	_skip_abort_token += 1


func _kill_studio_logo_fall_tweens() -> void:
	if _studio_logo_fall_tw != null and is_instance_valid(_studio_logo_fall_tw):
		if _studio_logo_fall_tw.is_running():
			_studio_logo_fall_tw.kill()
	_studio_logo_fall_tw = null
	if _studio_logo_settle_tw != null and is_instance_valid(_studio_logo_settle_tw):
		if _studio_logo_settle_tw.is_running():
			_studio_logo_settle_tw.kill()
	_studio_logo_settle_tw = null


func _kill_all_intro_overlap_tweens() -> void:
	_kill_atmosphere_tween()
	if _game_sting_fx_tween != null and is_instance_valid(_game_sting_fx_tween):
		if _game_sting_fx_tween.is_running():
			_game_sting_fx_tween.kill()
	_game_sting_fx_tween = null
	if _game_logo_settle_tw != null and is_instance_valid(_game_logo_settle_tw):
		if _game_logo_settle_tw.is_running():
			_game_logo_settle_tw.kill()
	_game_logo_settle_tw = null
	_kill_studio_logo_fall_tweens()
	if _beats_shake_tw != null and is_instance_valid(_beats_shake_tw):
		if _beats_shake_tw.is_running():
			_beats_shake_tw.kill()
	_beats_shake_tw = null
	if _shockwave_run_tw != null and is_instance_valid(_shockwave_run_tw):
		if _shockwave_run_tw.is_running():
			_shockwave_run_tw.kill()
	_shockwave_run_tw = null
	_stop_game_beat_mote_spawning()


func _remove_studio_logo_proxies() -> void:
	for c in get_children():
		if c.name == "StudioLogoFallProxy":
			if c is Control:
				(c as Control).hide()
			c.queue_free()


## Stop stray motion when the player skips a beat so the next beat / fade doesn’t stack tweens.
func _abort_intro_overlaps_for_skip(root: Control) -> void:
	_invalidate_intro_deferred_callbacks()
	_kill_all_intro_overlap_tweens()
	_remove_studio_logo_proxies()
	# Beat panel / beats_root positions and logo scale are tweened in _fast_fade_out_beat
	# so skip doesn’t snap ~40px in one frame. Don’t force studio logo alpha (mid-fall slot stays 0;
	# raising it here caused a one-frame “real logo” flash when the proxy was removed).


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
			_play_trimmed_sting(
				sting_player,
				_sting_base_volume_db,
				studio_sting_start_seconds,
				studio_sting_stop_seconds,
				studio_sting_fadein_seconds,
				studio_sting_fadeout_seconds
			)
			_studio_sting_started_at_usec = Time.get_ticks_usec()
		return
	var bell: AudioStream = intro_studio_bell_stream
	var riser: AudioStream = intro_studio_reversed_riser_stream
	var tail: AudioStream = intro_studio_reversed_tail_stream
	if bell == null and riser == null and tail == null:
		if sting_player != null and sting_player.stream != null:
			_play_trimmed_sting(
				sting_player,
				_sting_base_volume_db,
				studio_sting_start_seconds,
				studio_sting_stop_seconds,
				studio_sting_fadein_seconds,
				studio_sting_fadeout_seconds
			)
			_studio_sting_started_at_usec = Time.get_ticks_usec()
		return
	_ensure_studio_sting_players()
	var tree := get_tree()
	if tree == null:
		return
	if riser != null:
		_studio_riser_player.stream = riser
		_studio_riser_player.play()
	var expect: int = _skip_abort_token
	var delay: float = intro_riser_lead_seconds if riser != null else 0.0
	tree.create_timer(delay).timeout.connect(func() -> void:
		if _is_leaving or _skip_abort_token != expect:
			return
		_on_studio_sting_bell_step(bell, tail, expect)
	, CONNECT_ONE_SHOT)


func _on_studio_sting_bell_step(bell: AudioStream, tail: AudioStream, expect: int) -> void:
	if _is_leaving or _skip_abort_token != expect:
		return
	if bell != null and _studio_bell_player != null:
		_studio_bell_player.stream = bell
		_studio_bell_player.play()
	if tail == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(intro_post_bell_tail_delay_sec).timeout.connect(func() -> void:
		if _is_leaving or _skip_abort_token != expect:
			return
		_on_studio_sting_tail_step(tail)
	, CONNECT_ONE_SHOT)


func _on_studio_sting_tail_step(tail: AudioStream) -> void:
	if _is_leaving or tail == null or _studio_tail_player == null:
		return
	_studio_tail_player.stream = tail
	_studio_tail_player.play()


func _apply_game_logo_juice_material() -> void:
	if not game_logo_juice_enabled or game_logo_rect == null or game_logo_texture == null:
		if game_logo_rect != null:
			game_logo_rect.material = null
		_game_logo_juice_mat = null
		return
	if not ResourceLoader.exists(GAME_LOGO_SHADER_PATH):
		return
	var sh: Shader = load(GAME_LOGO_SHADER_PATH) as Shader
	if sh == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("rift_amount", game_logo_rift_amount)
	mat.set_shader_parameter("parallax_uv", game_logo_parallax_uv)
	mat.set_shader_parameter("shimmer", game_logo_shimmer)
	mat.set_shader_parameter("breath", game_logo_breath)
	game_logo_rect.material = mat
	_game_logo_juice_mat = mat


func _ensure_game_mote_material() -> ShaderMaterial:
	if _game_beat_mote_shared_mat != null and is_instance_valid(_game_beat_mote_shared_mat):
		_game_beat_mote_shared_mat.set_shader_parameter("distort", game_logo_mote_uv_distort)
		_game_beat_mote_shared_mat.set_shader_parameter("wobble_hz", game_logo_mote_wobble_hz)
		_game_beat_mote_shared_mat.set_shader_parameter("stream_strength", game_logo_mote_stream_strength)
		_game_beat_mote_shared_mat.set_shader_parameter("stream_speed", game_logo_mote_stream_speed)
		_game_beat_mote_shared_mat.set_shader_parameter("stream_ribbons", game_logo_mote_stream_ribbons)
		return _game_beat_mote_shared_mat
	if not ResourceLoader.exists(GAME_MOTE_SHADER_PATH):
		return null
	var sh: Shader = load(GAME_MOTE_SHADER_PATH) as Shader
	if sh == null:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("distort", game_logo_mote_uv_distort)
	mat.set_shader_parameter("wobble_hz", game_logo_mote_wobble_hz)
	mat.set_shader_parameter("stream_strength", game_logo_mote_stream_strength)
	mat.set_shader_parameter("stream_speed", game_logo_mote_stream_speed)
	mat.set_shader_parameter("stream_ribbons", game_logo_mote_stream_ribbons)
	_game_beat_mote_shared_mat = mat
	return mat


func _cleanup_game_beat_juice() -> void:
	if _game_sting_fx_tween != null and _game_sting_fx_tween.is_valid():
		_game_sting_fx_tween.kill()
	_game_sting_fx_tween = null
	_stop_game_beat_mote_spawning()
	if _game_beat_motes_holder != null and is_instance_valid(_game_beat_motes_holder):
		_game_beat_motes_holder.queue_free()
	_game_beat_motes_holder = null
	if game_logo_rect != null and is_instance_valid(game_logo_rect):
		game_logo_rect.material = null
	_game_logo_juice_mat = null


func _stop_game_beat_mote_spawning() -> void:
	_game_beat_mote_stream_active = false
	_game_beat_mote_spawn_acc = 0.0


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
		_apply_game_logo_juice_material()
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

	var fade_in: float = b["fade_in"]
	var hold: float = b["hold"]
	var fade_out: float = b["fade_out"]
	var wants_studio_logo_fall: bool = false
	var studio_logo: Control = null
	var studio_logo_restore_modulate: Color = Color.WHITE

	if b.get("id") == "studio":
		if play_sting_on_studio_beat:
			_begin_studio_sting_sequence()
			# Avoid cutting off the sting on normal auto-advance.
			if sting_player != null and sting_player.stream != null:
				hold = maxf(hold, _estimate_effective_sting_hold_seconds(true))
		if studio_logo_fall_enabled and logo is Control and logo != null:
			# Defer until after the beat's slide-in tween completes, otherwise VBox layout + root motion
			# make the target position drift and the impact reads "mid air".
			wants_studio_logo_fall = true
			studio_logo = logo as Control
			studio_logo_restore_modulate = studio_logo.modulate
			# Do NOT use visible=false — VBox would reflow and the logo would teleport on show.
			# Hide with alpha; layout slot stays stable for proxy landing + shockwave origin.
			studio_logo.modulate = Color(studio_logo_restore_modulate.r, studio_logo_restore_modulate.g, studio_logo_restore_modulate.b, 0.0)
			hold = maxf(hold, studio_logo_fall_seconds + studio_logo_impact_settle_seconds + 0.10)
		else:
			# Trigger the burst after the sting has had time to land (keeps the beat feeling authored).
			_schedule_studio_burst()
	elif b.get("id") == "game":
		if play_sting_on_game_beat:
			_begin_game_sting_sequence()
			# Avoid cutting off the game sting on normal auto-advance.
			if game_sting_player != null and game_sting_player.stream != null:
				hold = maxf(hold, _estimate_effective_sting_hold_seconds(false))

	var is_game_beat: bool = b.get("id") == "game"

	if skip_hint != null:
		skip_hint.visible = allow_skip and show_skip_hint

	# Fade in (separate tween so completion is reliable across Godot versions).
	var start_y = root.position.y
	root.position.y += 40.0
	root.modulate.a = 1.0 # Root stays solid, children stagger
	var tw_in := create_tween()
	tw_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_in.set_parallel(true)
	tw_in.tween_property(root, "position:y", start_y, fade_in + 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	var stagger_delay: float = 0.0
	for child in root.get_children():
		if child is Control and child.visible:
			# Studio fall: keep logo slot in layout but skip its fade (proxy draws until impact).
			if wants_studio_logo_fall and studio_logo != null and child == studio_logo:
				continue
			# Game beat: logo has its own entry tween (scale + fade).
			if is_game_beat and game_logo_rect != null and child == game_logo_rect:
				continue
			child.modulate.a = 0.0
			tw_in.tween_property(child, "modulate:a", 1.0, fade_in).set_delay(stagger_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			stagger_delay += 0.15

	if is_game_beat and sparkles_enabled and _sparkle_layer != null and is_instance_valid(_sparkle_layer):
		tw_in.tween_property(
			_sparkle_layer,
			"modulate:a",
			clampf(game_beat_background_sparkle_alpha, 0.0, 1.0),
			maxf(0.08, fade_in)
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_game_beat and game_logo_juice_enabled and game_logo_rect != null and game_logo_texture != null:
		game_logo_rect.modulate.a = 0.0
		var ec: Color = game_logo_rect.modulate
		game_logo_rect.modulate = Color(ec.r, ec.g, ec.b, 0.0)
		game_logo_rect.scale = Vector2.ONE * game_logo_entry_scale_from
		tw_in.tween_property(game_logo_rect, "modulate:a", 1.0, fade_in * 1.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_in.tween_property(game_logo_rect, "scale", Vector2.ONE, fade_in).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif logo is Control and logo != null:
		tw_in.tween_property(logo as Control, "scale", Vector2.ONE, fade_in).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var studio_tw_in_total: float = fade_in + 0.3
	var code := await _await_tween_with_skip(tw_in, root, true)
	if code != 0 or _is_leaving:
		_finalize_beat_panel(root)
		return

	if is_game_beat and game_logo_juice_enabled and game_logo_rect != null and game_logo_texture != null:
		if _game_logo_settle_tw != null and is_instance_valid(_game_logo_settle_tw):
			if _game_logo_settle_tw.is_running():
				_game_logo_settle_tw.kill()
		var settle_tw := create_tween()
		settle_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_game_logo_settle_tw = settle_tw
		settle_tw.finished.connect(func(): _game_logo_settle_tw = null, CONNECT_ONE_SHOT)
		settle_tw.tween_property(game_logo_rect, "scale", Vector2.ONE * game_logo_settle_overshoot, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		settle_tw.tween_property(game_logo_rect, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_start_game_beat_mote_stream()

	# Start the "logo falls from the sky" animation only after the studio panel has settled.
	if wants_studio_logo_fall and studio_logo != null and is_instance_valid(studio_logo):
		# Sync impact to the sting using a real timestamp (staggered tweens can exceed fade_in).
		var elapsed: float = 0.0
		if _studio_sting_started_at_usec > 0:
			elapsed = float(Time.get_ticks_usec() - _studio_sting_started_at_usec) / 1_000_000.0
		var remaining: float = maxf(0.05, maxf(0.05, studio_burst_delay_seconds) - elapsed)
		_play_studio_logo_fall_and_impact(studio_logo, studio_logo_restore_modulate, remaining)

	code = await _await_hold_with_skip(root, hold)
	if code != 0 or _is_leaving:
		_finalize_beat_panel(root)
		return

	_stop_game_beat_mote_spawning()
	var tw_out := create_tween()
	tw_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_out.set_parallel(true)
	tw_out.tween_property(root, "modulate:a", 0.0, fade_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if is_game_beat and sparkles_enabled and _sparkle_layer != null and is_instance_valid(_sparkle_layer):
		tw_out.tween_property(_sparkle_layer, "modulate:a", 1.0, fade_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if is_game_beat and _game_beat_motes_holder != null and is_instance_valid(_game_beat_motes_holder):
		tw_out.tween_property(_game_beat_motes_holder, "modulate:a", 0.0, fade_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _await_tween_with_skip(tw_out, root, true)
	_finalize_beat_panel(root)


func _begin_game_sting_sequence() -> void:
	if game_sting_player == null or game_sting_player.stream == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var expect: int = _skip_abort_token
	var delay: float = maxf(0.0, game_sting_delay_seconds)
	if delay <= 0.0:
		if _skip_abort_token == expect:
			_play_trimmed_sting(
				game_sting_player,
				_game_sting_base_volume_db,
				game_sting_start_seconds,
				game_sting_stop_seconds,
				game_sting_fadein_seconds,
				game_sting_fadeout_seconds
			)
			_on_game_sting_fx()
		return
	tree.create_timer(delay).timeout.connect(func():
		if _is_leaving or game_sting_player == null or _skip_abort_token != expect:
			return
		_play_trimmed_sting(
			game_sting_player,
			_game_sting_base_volume_db,
			game_sting_start_seconds,
			game_sting_stop_seconds,
			game_sting_fadein_seconds,
			game_sting_fadeout_seconds
		)
		_on_game_sting_fx()
	, CONNECT_ONE_SHOT)


func _on_game_sting_fx() -> void:
	if _is_leaving or not game_logo_juice_enabled:
		return
	_game_sting_atmosphere_pulse()
	_game_sting_micro_shake()


func _game_sting_atmosphere_pulse() -> void:
	if not eerie_atmosphere_enabled or _atmosphere_mat == null:
		return
	var pulse: float = maxf(0.0, game_logo_sting_vignette_pulse)
	if pulse <= 0.001:
		return
	if _game_sting_fx_tween != null and _game_sting_fx_tween.is_valid():
		_game_sting_fx_tween.kill()
	var mat: ShaderMaterial = _atmosphere_mat
	var inner0: float = float(mat.get_shader_parameter("inner_radius"))
	var stren0: float = float(mat.get_shader_parameter("vignette_strength"))
	var inner1: float = clampf(inner0 - pulse * 0.55, 0.06, 0.75)
	var stren1: float = clampf(stren0 + pulse * 1.15, 0.5, 2.0)
	var tw := create_tween()
	_game_sting_fx_tween = tw
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("inner_radius", v), inner0, inner1, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("vignette_strength", v), stren0, stren1, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.set_parallel(true)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("inner_radius", v), inner1, inner0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("vignette_strength", v), stren1, stren0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _game_sting_micro_shake() -> void:
	if beats_root == null:
		return
	var px: float = maxf(0.0, game_logo_sting_shake_px)
	if px <= 0.5:
		return
	if _beats_shake_tw != null and _beats_shake_tw.is_valid():
		_beats_shake_tw.kill()
	var origin: Vector2 = beats_root.position
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_beats_shake_tw = tw
	var nudge := Vector2(_sparkle_rng.randf_range(-px, px) * 0.6, _sparkle_rng.randf_range(-px, px) * 0.45)
	tw.tween_property(beats_root, "position", origin + nudge, 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(beats_root, "position", origin, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _start_game_beat_mote_stream() -> void:
	if not game_logo_juice_enabled or game_logo_rect == null or beats_root == null or _is_leaving:
		return
	_stop_game_beat_mote_spawning()
	if _game_beat_motes_holder != null and is_instance_valid(_game_beat_motes_holder):
		_game_beat_motes_holder.queue_free()
		_game_beat_motes_holder = null
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
	if _is_leaving or game_logo_rect == null or not game_logo_juice_enabled or beats_root == null:
		return
	var bucket := Control.new()
	bucket.name = "GameBeatMotes"
	bucket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Control.LayoutMode is not exposed in all Godot 4.x builds; 1 == anchors (same as scene files).
	bucket.layout_mode = 1
	bucket.set_anchors_preset(Control.PRESET_FULL_RECT)
	bucket.offset_left = 0.0
	bucket.offset_top = 0.0
	bucket.offset_right = 0.0
	bucket.offset_bottom = 0.0
	bucket.z_index = 8
	bucket.modulate = Color.WHITE
	beats_root.add_child(bucket)
	_game_beat_motes_holder = bucket
	_game_beat_mote_spawn_acc = 0.0
	_game_beat_mote_stream_active = true


func _tick_game_beat_mote_stream(delta: float) -> void:
	if not _game_beat_mote_stream_active or _is_leaving or not game_logo_juice_enabled:
		return
	var bucket: Control = _game_beat_motes_holder
	if bucket == null or not is_instance_valid(bucket) or game_logo_rect == null:
		return
	var cap_i: int = clampi(game_logo_mote_max_alive, 60, 520)
	var n_live: int = bucket.get_child_count()
	if n_live < cap_i:
		var rate: float = maxf(18.0, game_logo_motes_per_second)
		_game_beat_mote_spawn_acc += rate * delta
	var backlog_cap: float = maxf(1.5, game_logo_mote_spawn_burst_cap)
	_game_beat_mote_spawn_acc = minf(_game_beat_mote_spawn_acc, backlog_cap)
	while _game_beat_mote_spawn_acc >= 1.0:
		n_live = bucket.get_child_count()
		if n_live >= cap_i:
			break
		_spawn_single_game_beat_mote()
		_game_beat_mote_spawn_acc -= 1.0


func _spawn_single_game_beat_mote() -> void:
	var bucket: Control = _game_beat_motes_holder
	if bucket == null or not is_instance_valid(bucket) or game_logo_rect == null:
		return
	var xform_inv: Transform2D = bucket.get_global_transform_with_canvas().affine_inverse()
	var center_g: Vector2 = game_logo_rect.get_global_rect().get_center()
	var vps: Vector2 = get_viewport_rect().size
	var m := ColorRect.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lo: float = mini(game_logo_mote_px_min, game_logo_mote_px_max)
	var hi: float = maxf(game_logo_mote_px_min, game_logo_mote_px_max)
	var sz: float = _sparkle_rng.randf_range(lo, hi)
	m.size = Vector2(sz, sz)
	var mat_m := _ensure_game_mote_material()
	if mat_m != null:
		m.material = mat_m
	# Rift / violet bias (shader adds a little rim fringing on top).
	m.color = Color(
		_sparkle_rng.randf_range(0.56, 0.82),
		_sparkle_rng.randf_range(0.22, 0.48),
		_sparkle_rng.randf_range(0.86, 1.0),
		_sparkle_rng.randf_range(0.38, 0.74)
	)
	var edge := _sparkle_rng.randi_range(0, 3)
	var gp: Vector2
	match edge:
		0:
			gp = Vector2(_sparkle_rng.randf_range(0.0, vps.x), -24.0)
		1:
			gp = Vector2(_sparkle_rng.randf_range(0.0, vps.x), vps.y + 24.0)
		2:
			gp = Vector2(-24.0, _sparkle_rng.randf_range(0.0, vps.y))
		_:
			gp = Vector2(vps.x + 24.0, _sparkle_rng.randf_range(0.0, vps.y))
	m.position = xform_inv * gp - m.size * 0.5
	m.pivot_offset = m.size * 0.5
	bucket.add_child(m)
	var dest_g := center_g + Vector2(_sparkle_rng.randf_range(-56.0, 56.0), _sparkle_rng.randf_range(-40.0, 40.0))
	var dest_local: Vector2 = xform_inv * dest_g - m.size * 0.5
	var dur := _sparkle_rng.randf_range(2.1, 3.8)
	var start_local: Vector2 = m.position
	var chord: Vector2 = dest_local - start_local
	var chord_len: float = chord.length()
	var perp: Vector2
	if chord_len > 0.5:
		perp = Vector2(-chord.y, chord.x) / chord_len
	else:
		perp = Vector2(0.0, 1.0)
	var loops_var: float = maxf(0.0, game_logo_mote_swirl_loops) * _sparkle_rng.randf_range(0.72, 1.18)
	var amp_var: float = maxf(0.0, game_logo_mote_swirl_amplitude_px) * _sparkle_rng.randf_range(0.65, 1.12)
	var phase: float = _sparkle_rng.randf() * TAU
	var twm := create_tween()
	twm.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	twm.set_parallel(true)
	if loops_var < 0.04 or amp_var < 0.4:
		twm.tween_property(m, "position", dest_local, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		var swirl_pos: Callable = func(p_prog: float) -> void:
			if not is_instance_valid(m):
				return
			var p: float = clampf(p_prog, 0.0, 1.0)
			var base: Vector2 = start_local.lerp(dest_local, p)
			var env: float = sin(p * PI)
			var swirl_amt: float = sin(p * TAU * loops_var + phase) * amp_var * env
			m.position = base + perp * swirl_amt
		twm.tween_method(swirl_pos, 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if game_logo_mote_spin_max_rad > 0.02:
		var spin: float = _sparkle_rng.randf_range(
			-game_logo_mote_spin_max_rad,
			game_logo_mote_spin_max_rad
		)
		twm.tween_property(m, "rotation", spin, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	twm.tween_property(m, "color", Color(m.color.r, m.color.g, m.color.b, 0.0), dur * 0.92).set_delay(0.08)
	twm.chain()
	twm.tween_callback(m.queue_free)


func _play_trimmed_sting(
	player: AudioStreamPlayer,
	base_volume_db: float,
	start_s: float,
	stop_s: float,
	fade_in_s: float,
	fade_out_s: float
) -> void:
	if player == null or player.stream == null or _is_leaving:
		return

	var fade_in: float = maxf(0.0, float(fade_in_s))
	if fade_in > 0.0:
		player.volume_db = -40.0
	else:
		player.volume_db = base_volume_db
	var start_at: float = maxf(0.0, float(start_s))
	player.play(start_at)

	if fade_in > 0.0:
		var tw_in := create_tween()
		tw_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_in.tween_property(player, "volume_db", base_volume_db, fade_in).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var stop_at: float = float(stop_s)
	if stop_at <= 0.0 or stop_at <= start_at:
		return

	var pitch: float = maxf(0.01, float(player.pitch_scale))
	var run_s: float = (stop_at - start_at) / pitch
	if run_s <= 0.0:
		return

	var fade_real: float = clampf(float(fade_out_s), 0.02, 2.0) / pitch
	fade_real = minf(fade_real, maxf(0.02, run_s))
	var fade_start_in: float = maxf(0.0, run_s - fade_real)

	var tree := get_tree()
	if tree == null:
		return

	tree.create_timer(fade_start_in).timeout.connect(func():
		if _is_leaving or player == null:
			return
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(player, "volume_db", -40.0, fade_real).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN),
		CONNECT_ONE_SHOT
	)
	tree.create_timer(run_s).timeout.connect(func():
		if player == null:
			return
		player.stop()
		player.volume_db = base_volume_db,
		CONNECT_ONE_SHOT
	)


func _estimate_effective_sting_hold_seconds(is_studio: bool) -> float:
	var p: AudioStreamPlayer = sting_player if is_studio else game_sting_player
	if p == null or p.stream == null:
		return 0.0
	var pitch: float = maxf(0.01, float(p.pitch_scale))

	var start_at: float = maxf(0.0, studio_sting_start_seconds if is_studio else game_sting_start_seconds)
	var stop_at: float = float(studio_sting_stop_seconds if is_studio else game_sting_stop_seconds)
	var dur: float = 0.0
	if stop_at > start_at:
		dur = (stop_at - start_at) / pitch
	else:
		dur = float(p.stream.get_length()) / pitch
	if not is_studio:
		dur += maxf(0.0, game_sting_delay_seconds)
	return maxf(0.0, dur)


func _schedule_studio_burst() -> void:
	var tree := get_tree()
	if tree == null or _is_leaving:
		return
	var expect: int = _skip_abort_token
	var delay: float = maxf(0.0, studio_burst_delay_seconds)
	if delay <= 0.0:
		if _skip_abort_token == expect:
			_trigger_studio_impact_and_burst()
		return
	tree.create_timer(delay).timeout.connect(func():
		if _is_leaving or _skip_abort_token != expect:
			return
		_trigger_studio_impact_and_burst()
	, CONNECT_ONE_SHOT)


func _trigger_studio_impact_and_burst(origin_global: Variant = null) -> void:
	_play_studio_impact(origin_global)
	_burst_sparkles_outward()


func _play_studio_impact(origin_global: Variant = null) -> void:
	_play_impact_shake()
	_play_shockwave(origin_global)


func _play_impact_shake() -> void:
	if beats_root == null:
		return
	if _beats_shake_tw != null and _beats_shake_tw.is_valid():
		_beats_shake_tw.kill()
	_beats_shake_origin = beats_root.position
	var strength: float = maxf(0.0, studio_impact_shake_px)
	var dur: float = clampf(studio_impact_shake_seconds, 0.02, 0.6)
	if strength <= 0.01:
		return
	var steps: int = maxi(2, int(round(dur / 0.03)))
	_beats_shake_tw = create_tween()
	_beats_shake_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for s in range(steps):
		var t: float = float(s) / float(maxi(1, steps - 1))
		var amp: float = strength * lerpf(1.0, 1.0 - clampf(studio_impact_shake_decay, 0.0, 1.0), t)
		var off := Vector2(_sparkle_rng.randf_range(-amp, amp), _sparkle_rng.randf_range(-amp, amp))
		_beats_shake_tw.tween_property(beats_root, "position", _beats_shake_origin + off, dur / float(steps)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_beats_shake_tw.tween_property(beats_root, "position", _beats_shake_origin, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _play_studio_logo_fall_and_impact(logo: Control, restore_modulate: Color = Color.WHITE, fall_seconds_override: float = -1.0) -> void:
	if logo == null or _is_leaving:
		return
	_kill_studio_logo_fall_tweens()
	_remove_studio_logo_proxies()
	var fall_h: float = maxf(0.0, studio_logo_fall_height_px)
	var fall_s: float = clampf(studio_logo_fall_seconds, 0.05, 2.0) if fall_seconds_override < 0.0 else clampf(fall_seconds_override, 0.05, 2.0)
	var settle_s: float = clampf(studio_logo_impact_settle_seconds, 0.0, 0.6)

	# Logo lives under a VBoxContainer — keep it in layout (alpha 0) so global_rect stays stable.
	var tex: Texture2D = null
	if logo is TextureRect:
		tex = (logo as TextureRect).texture
	if tex == null:
		return

	var gr: Rect2 = logo.get_global_rect()
	var target_gpos: Vector2 = gr.position
	var target_size: Vector2 = gr.size
	var target_scale: Vector2 = logo.scale

	var proxy := TextureRect.new()
	proxy.name = "StudioLogoFallProxy"
	proxy.top_level = true
	proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proxy.texture = tex
	proxy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	proxy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	proxy.size = target_size
	proxy.pivot_offset = Vector2.ZERO

	var start_scale := target_scale * 1.55
	proxy.scale = start_scale
	var scaled_sz: Vector2 = target_size * start_scale
	var margin: float = maxf(0.0, studio_logo_fall_screen_margin_px)
	var vpsz: Vector2 = get_viewport_rect().size
	var edge_key := studio_logo_fall_from_edge.strip_edges().to_lower()
	var start_gpos: Vector2 = target_gpos + Vector2(0.0, -fall_h)
	match edge_key:
		"left":
			start_gpos = Vector2(-margin - scaled_sz.x, target_gpos.y)
		"right":
			start_gpos = Vector2(vpsz.x + margin, target_gpos.y)
		_:
			# Top: fully above the viewport; take the higher of legacy offset and strict off-screen.
			var offscreen_top_y: float = -margin - scaled_sz.y
			var legacy_top_y: float = target_gpos.y - fall_h
			start_gpos = Vector2(target_gpos.x, minf(legacy_top_y, offscreen_top_y))
	proxy.global_position = start_gpos
	proxy.modulate = Color(1, 1, 1, 1)
	add_child(proxy)

	var tw := create_tween()
	_studio_logo_fall_tw = tw
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(proxy, "global_position", target_gpos, fall_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(proxy, "scale", target_scale, fall_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(func():
		_studio_logo_fall_tw = null
		if _is_leaving:
			return
		# Snap so parallel easing can't leave sub-pixel drift vs layout slot.
		if is_instance_valid(proxy):
			proxy.global_position = target_gpos
			proxy.scale = target_scale
		logo.scale = target_scale
		logo.modulate = restore_modulate
		var impact_center := logo.get_global_rect().get_center()
		if is_instance_valid(proxy):
			proxy.queue_free()
		_trigger_studio_impact_and_burst(impact_center)
	)

	if settle_s > 0.0:
		var base_scale := target_scale
		var bump := base_scale * 0.965
		var settle := create_tween()
		_studio_logo_settle_tw = settle
		settle.finished.connect(func(): _studio_logo_settle_tw = null, CONNECT_ONE_SHOT)
		settle.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		settle.tween_property(logo, "scale", bump, settle_s * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		settle.tween_property(logo, "scale", base_scale, settle_s * 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _play_shockwave(origin_global: Variant = null) -> void:
	if _shockwave_mat == null or _shockwave_rect == null:
		return
	var dur: float = clampf(studio_shockwave_seconds, 0.05, 1.5)
	var strength: float = clampf(studio_shockwave_strength, 0.0, 2.0)
	if strength <= 0.001:
		return
	_shockwave_rect.visible = true
	var rect_size: Vector2 = get_viewport_rect().size
	var center_uv := Vector2(0.5, 0.5)
	if origin_global is Vector2 and rect_size.x > 1.0 and rect_size.y > 1.0:
		var gp: Vector2 = origin_global as Vector2
		center_uv = Vector2(clampf(gp.x / rect_size.x, 0.0, 1.0), clampf(gp.y / rect_size.y, 0.0, 1.0))
	elif rect_size.x > 1.0 and rect_size.y > 1.0 and beats_root != null:
		var gp2: Vector2 = beats_root.global_position + beats_root.size * 0.5
		center_uv = Vector2(clampf(gp2.x / rect_size.x, 0.0, 1.0), clampf(gp2.y / rect_size.y, 0.0, 1.0))
	_shockwave_mat.set_shader_parameter("center_uv", center_uv)
	_shockwave_mat.set_shader_parameter("thickness", clampf(studio_shockwave_thickness, 0.01, 0.2))
	_shockwave_mat.set_shader_parameter("softness", clampf(studio_shockwave_softness, 0.005, 0.12))
	_shockwave_mat.set_shader_parameter("strength", strength)
	_shockwave_mat.set_shader_parameter("distort_strength", clampf(studio_shockwave_distort_strength, 0.0, 0.08))
	_shockwave_mat.set_shader_parameter("tint", Vector3(studio_shockwave_tint.r, studio_shockwave_tint.g, studio_shockwave_tint.b))
	_shockwave_mat.set_shader_parameter("radius", 0.02)
	if _shockwave_run_tw != null and is_instance_valid(_shockwave_run_tw):
		if _shockwave_run_tw.is_running():
			_shockwave_run_tw.kill()
	var tw := create_tween()
	_shockwave_run_tw = tw
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(func(v: float) -> void: if _shockwave_mat != null: _shockwave_mat.set_shader_parameter("radius", v), 0.02, 1.05, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: if _shockwave_mat != null: _shockwave_mat.set_shader_parameter("strength", v), strength, 0.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_shockwave_run_tw = null
		if _shockwave_rect != null:
			_shockwave_rect.visible = false
	)


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
	if beat_game != null and root == beat_game:
		_cleanup_game_beat_juice()
		if sparkles_enabled and _sparkle_layer != null and is_instance_valid(_sparkle_layer):
			_sparkle_layer.modulate.a = 1.0
	if _beat_panel_rest_pos.has(root):
		root.position = _beat_panel_rest_pos[root]
	root.visible = false
	root.modulate.a = 0.0


func _fast_fade_out_beat(root: Control) -> void:
	if root == null:
		return
	_abort_intro_overlaps_for_skip(root)
	var dur: float = maxf(0.04, skip_fast_fade_seconds)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(root, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _beat_panel_rest_pos.has(root):
		var rest: Vector2 = _beat_panel_rest_pos[root] as Vector2
		tw.tween_property(root, "position", rest, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if beats_root != null:
		tw.tween_property(beats_root, "position", _beats_root_rest_pos, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if beat_game != null and root == beat_game and game_logo_rect != null:
		tw.tween_property(game_logo_rect, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if beat_studio != null and root == beat_studio and logo_rect != null and logo_rect.modulate.a > 0.05:
		tw.tween_property(logo_rect, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if beat_game != null and root == beat_game and _game_beat_motes_holder != null and is_instance_valid(_game_beat_motes_holder):
		tw.tween_property(_game_beat_motes_holder, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if sparkles_enabled and _sparkle_layer != null and is_instance_valid(_sparkle_layer):
		tw.tween_property(_sparkle_layer, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished


func _process(delta: float) -> void:
	_elapsed += delta
	_tick_game_beat_mote_stream(delta)
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
	_invalidate_intro_deferred_callbacks()
	_kill_all_intro_overlap_tweens()
	_remove_studio_logo_proxies()
	_cleanup_game_beat_juice()
	if beats_root != null:
		beats_root.position = _beats_root_rest_pos
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
	tw.set_parallel(true)
	tw.tween_property(_handoff_black_rect, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	if beats_root != null:
		beats_root.pivot_offset = beats_root.size * 0.5
		tw.tween_property(beats_root, "scale", Vector2(1.8, 1.8), fade_duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
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
	
	var img = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	var center = Vector2(8, 8)
	var radius = 7.0
	for x in range(16):
		for y in range(16):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				var alpha = clampf(1.0 - (dist / radius), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, alpha * alpha))
			else:
				img.set_pixel(x, y, Color(1, 1, 1, 0))
	var tex = ImageTexture.create_from_image(img)
	
	for i in count:
		var dot := Sprite2D.new()
		dot.texture = tex
		var px_size: float = float(_sparkle_rng.randi_range(maxi(1, sparkles_min_size), maxi(maxi(1, sparkles_min_size), sparkles_max_size)))
		dot.scale = Vector2(px_size / 16.0, px_size / 16.0)
		var base_alpha: float = _sparkle_rng.randf_range(clampf(sparkles_alpha_min, 0.02, 1.0), clampf(maxf(sparkles_alpha_min, sparkles_alpha_max), 0.02, 1.0))
		dot.modulate = Color(sparkles_tint.r, sparkles_tint.g, sparkles_tint.b, base_alpha)
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
		var dot: Sprite2D = _sparkles[i]
		if dot == null:
			continue
		var vel: Vector2 = _sparkle_velocity[i]
		var base_vy = sparkles_min_speed
		if eerie_atmosphere_enabled:
			base_vy += sparkle_sink_bias * 8.0
		# Apply drag to simulate magical explosion braking
		vel = vel.lerp(Vector2(_sparkle_rng.randf_range(-5.0, 5.0), base_vy), 1.8 * delta)
		_sparkle_velocity[i] = vel
		dot.position += vel * delta
		if eerie_atmosphere_enabled:
			var wisp: float = sin(twinkle_time * 0.62 + float(i) * 1.17) * 18.0
			dot.position.x += wisp * delta
		# No border bounce/wrap: let sparkles drift out, then respawn softly.
		var margin: float = 24.0
		if (
			dot.position.x < -margin
			or dot.position.x > viewport_size.x + margin
			or dot.position.y < -margin
			or dot.position.y > viewport_size.y + margin
		):
			dot.position = Vector2(
				_sparkle_rng.randf_range(0.0, maxf(viewport_size.x, 1.0)),
				_sparkle_rng.randf_range(0.0, maxf(viewport_size.y, 1.0))
			)
			var vx := _sparkle_rng.randf_range(-5.0, 5.0)
			var vy := _sparkle_rng.randf_range(sparkles_min_speed, maxf(sparkles_min_speed, sparkles_max_speed))
			if eerie_atmosphere_enabled:
				vy += sparkle_sink_bias * (6.0 + _sparkle_rng.randf() * 4.0)
			_sparkle_velocity[i] = Vector2(vx, vy)
		var base_alpha: float = _sparkle_base_alpha[i]
		var phase: float = _sparkle_phase[i]
		var speed: float = _sparkle_twinkle_speed[i]
		var twinkle: float = 0.78 + 0.22 * sin((twinkle_time * speed) + phase)
		dot.modulate = Color(
			sparkles_tint.r,
			sparkles_tint.g,
			sparkles_tint.b,
			clampf(base_alpha * twinkle, 0.0, 1.0)
		)

func _burst_sparkles_outward() -> void:
	if not sparkles_enabled or _sparkles.is_empty():
		return
	var center = get_viewport_rect().size * 0.5
	var settle: float = clampf(studio_burst_settle_seconds, 0.02, 2.0)
	var scale_boost: float = maxf(0.0, studio_burst_scale_boost)
	var alpha_boost: float = clampf(studio_burst_alpha_boost, 0.0, 1.0)
	var base_min: float = maxf(0.0, studio_burst_force_min)
	var base_max: float = maxf(base_min, studio_burst_force_max)
	var strength: float = maxf(0.0, studio_burst_strength)
	for i in _sparkles.size():
		var dot = _sparkles[i]
		if dot == null: continue
		var dir = (dot.position - center).normalized()
		var p_force = _sparkle_rng.randf_range(base_min, base_max) * strength
		_sparkle_velocity[i] += dir * p_force

		if scale_boost > 0.0:
			var tw := create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(dot, "scale", dot.scale * (1.0 + scale_boost), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(dot, "scale", Vector2.ONE, settle).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if alpha_boost > 0.0 and i < _sparkle_base_alpha.size():
			_sparkle_base_alpha[i] = clampf(_sparkle_base_alpha[i] + alpha_boost, 0.0, 1.0)
			var idx := i
			get_tree().create_timer(settle).timeout.connect(func():
				if idx < _sparkle_base_alpha.size():
					_sparkle_base_alpha[idx] = clampf(_sparkle_base_alpha[idx] - alpha_boost, 0.0, 1.0),
				CONNECT_ONE_SHOT
			)
