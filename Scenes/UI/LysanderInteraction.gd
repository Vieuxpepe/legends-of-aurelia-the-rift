# ==============================================================================
# Script Name: LysanderInteraction.gd
# Purpose: Handles Lysander's full interaction flow (dialogue -> tiered combo QTE -> rewards).
# Overall Goal: Deliver a centered, readable, replay-safe NPC minigame with stronger game feel,
#	multiple reward tiers, combo-based timing, moving/randomized hit zones, and robust input
#	handling that prevents accidental immediate reopening.
# Project Fit: Attach this directly to the Lysander TextureButton in the Grand Tavern.
# Dependencies:
#	- ConsumableData (Resource used for each reward disc).
#	- CampaignManager (Global singleton with add_item_to_inventory()).
# AI/Code Reviewer Guidance:
#	- Entry points:
#		1. _on_lysander_pressed() starts the interaction.
#		2. _input() advances dialogue, resolves each QTE press, and closes the interaction.
#		3. _process() drives the live QTE cursor motion and sweet-spot feedback.
#	- Core logic:
#		1. _build_dynamic_ui() creates all runtime-only UI under a full-screen UI root.
#		2. _layout_dynamic_ui() keeps dialogue and QTE correctly positioned on any viewport size.
#		3. _start_qte(), _resolve_qte(), _on_feedback_timer_timeout(), and _continue_qte_chain()
#		   form the combo-QTE loop.
#		4. _randomize_sweet_spot() enforces a fresh target location each beat.
#		5. Tier helpers (_get_current_tier_speed(), _get_current_tier_width(),
#		   _get_current_tier_required_hits()) scale difficulty.
#	- Admin logic:
#		1. _consume_current_input() prevents the focused TextureButton from re-triggering.
#		2. current_tier_index gates rewards so discs cannot be farmed.
#		3. _reset_qte_visuals() and _close_interaction() restore clean state between runs.
# ==============================================================================

extends TextureButton

# --- EXPORTS ---
@export_category("Lysander Settings")
@export var reward_discs: Array[ConsumableData] = []
@export var performance_setlist_discs: Array[ConsumableData] = []
@export var fallback_reward_name: String = "Music Disc"
@export var weekly_performance_requires_new_week: bool = true
@export var performance_close_hint_text: String = "(Press SPACE or click to close)"
@export var tavern_music_duck_db: float = -26.0
@export var tavern_music_fade_out_time: float = 0.65
@export var tavern_music_fade_in_time: float = 0.45
@export var performance_music_fade_in_time: float = 0.85
@export var performance_music_fade_in_start_db: float = -24.0
@export var performance_bob_attack: float = 10.0
@export var performance_bob_release: float = 4.5
@export var performance_bob_min_intensity: float = 0.18
@export var performance_bob_max_intensity: float = 0.72

@export_category("Performance FX")
@export var performance_breath_speed: float = 0.22
@export var performance_breath_amount: float = 0.006
@export var performance_blink_min_interval: float = 2.4
@export var performance_blink_max_interval: float = 5.8
@export var performance_blink_duration: float = 0.11
@export var performance_pluck_threshold: float = 0.56
@export var performance_pluck_cooldown: float = 0.18
@export var performance_pluck_scale_boost: float = 0.015
@export var performance_pluck_kick_px: float = 3.0
@export var performance_rune_glow_strength: float = 0.18
@export var performance_chorus_threshold: float = 0.66
@export var performance_chorus_zoom_strength: float = 0.018
@export var performance_chorus_zoom_in_time: float = 0.16
@export var performance_chorus_zoom_out_time: float = 0.22
@export var performance_chorus_cooldown: float = 1.1
@export var performance_flip_chance_per_second: float = 0.12
@export var performance_flip_min_interval: float = 1.6
@export var performance_flip_turn_smooth: float = 9.0
@export var performance_breakdown_threshold: float = 0.24
@export var performance_breakdown_hold_time: float = 0.34
@export var performance_breakdown_rearm_intensity: float = 0.52
@export var performance_twirl_duration: float = 0.90
@export var performance_twirl_spin_degrees: float = 540.0
@export var performance_twirl_cooldown: float = 1.15
@export var performance_twirl_intense_threshold: float = 0.56
@export var performance_twirl_intense_delta_min: float = 0.035
@export var performance_twirl_peak_chance: float = 0.45
@export var performance_twirl_sustain_threshold: float = 0.60
@export var performance_twirl_sustain_hold_time: float = 0.28
@export var performance_twirl_peak_interval: float = 2.30
@export var performance_lean_back_chance: float = 0.35
@export var performance_lean_back_duration: float = 0.64
@export var performance_lean_back_angle_degrees: float = 13.0
@export var performance_lean_back_push_px: float = 14.0
@export var performance_lean_back_lift_px: float = 18.0
@export var performance_lean_back_scale_y: float = 1.05
@export var performance_member_accent_chance: float = 0.78
@export var performance_member_accent_cooldown: float = 0.36
@export var performance_member_accent_duration: float = 0.38
@export var performance_member_accent_forward_px: float = 18.0
@export var performance_member_accent_lift_px: float = 15.0
@export var performance_member_accent_scale: float = 1.12
@export var performance_finale_bow_delay: float = 1.5
@export var performance_finale_bow_duration: float = 0.55
@export var performance_finale_bow_hold_time: float = 0.10
@export var performance_finale_bow_return_duration: float = 0.42
@export var performance_finale_bow_angle_degrees: float = 11.0
@export var performance_finale_bow_shift_x: float = 12.0
@export var performance_finale_bow_shift_y: float = 7.0
@export var performance_lyric_fade_time: float = 0.16
@export var performance_tip_gold_cost: int = 25
@export var performance_tip_boost_duration: float = 4.5
@export var performance_tip_boost_intensity: float = 0.48
@export var performance_tip_cooldown: float = 0.75
@export var performance_tip_throw_count: int = 8
@export var performance_tip_reaction_lines: PackedStringArray = PackedStringArray([
	"The crowd roars! Keep it coming!",
	"Ha! That's the spirit!",
	"Now that's how you tip a legend!",
	"Band, give them the good stuff!"
])
@export var performance_tip_spotlight_boost_alpha: float = 0.28
@export var performance_tip_particle_density_boost: float = 0.34
@export var performance_tip_extra_tracer_count: int = 6
@export var performance_lysander_texture: Texture2D = null
@export var performance_center_stage_lysander: bool = true
@export var performance_stage_center_x_ratio: float = 0.50
@export var performance_stage_y_offset: float = 8.0
@export var performance_showman_intro_text: String = "Ladies and ladies, enjoy the show..."
@export var performance_show_blackout_titlecard: bool = true
@export var performance_blackout_duration: float = 3.0
@export var performance_blackout_fade_in_time: float = 0.22
@export var performance_blackout_fade_out_time: float = 0.25
@export var performance_stage_backdrop_texture: Texture2D = null
@export var performance_stage_backdrop_alpha: float = 0.78
@export var performance_stage_backdrop_fade_in_time: float = 0.55
@export var performance_stage_backdrop_fade_out_time: float = 0.30
@export var performance_stage_backdrop_unfurl_scale: float = 1.06
@export var performance_scene_dim_alpha: float = 0.94
@export var performance_scene_dim_intensity_boost: float = 0.12
@export var performance_scene_dim_intensity_power: float = 1.15
@export var performance_intro_reveal_time: float = 0.42
@export var performance_band_member_textures: Array[Texture2D] = []
@export var performance_band_member_size: Vector2 = Vector2(240.0, 350.0)
@export var performance_band_member_x_offset: float = 42.0
@export var performance_band_member_spacing: float = 174.0
@export var performance_band_member_gap_from_lysander: float = 34.0
@export var performance_band_member_y_step: float = 14.0
@export var performance_band_member_alpha: float = 1.0
@export var performance_band_member_intensity_scale: float = 0.44
@export var performance_band_member_sway_scale: float = 0.55
@export var performance_band_member_glow_strength: float = 0.08
@export var performance_band_member_panel_overlap: float = 38.0
@export var performance_band_intro_fade_time: float = 1.5
@export var performance_band_intro_stagger_time: float = 0.6
@export var performance_lysander_intro_fade_time: float = 1.8
@export var performance_intro_spotlight_alpha: float = 0.22
@export var performance_intro_spotlight_width: float = 300.0
@export var performance_intro_spotlight_height: float = 540.0
@export var performance_intro_spotlight_top_y_offset: float = -8.0
@export var performance_intro_spotlight_fade_out_time: float = 1.15
@export var performance_intro_spotlight_color: Color = Color(1.0, 0.93, 0.74, 1.0)
@export var performance_intro_lysander_spotlight_color: Color = Color(0.08, 1.0, 0.30, 1.0)
@export var performance_intro_lysander_spotlight_alpha: float = 0.72
@export var performance_particles_enabled: bool = true
@export var performance_particle_colors: Array[Color] = [
	Color(1.0, 0.90, 0.55, 1.0),
	Color(0.55, 0.95, 1.0, 1.0),
	Color(1.0, 0.55, 0.92, 1.0),
	Color(0.70, 1.0, 0.62, 1.0)
]
@export var performance_particle_base_amount: int = 12
@export var performance_particle_max_amount: int = 30
@export var performance_particle_lifetime: float = 7.0
@export var performance_particle_base_alpha: float = 0.07
@export var performance_particle_max_alpha: float = 0.18
@export var performance_particle_intensity_response: float = 1.0
@export var performance_particle_strength_attack: float = 2.8
@export var performance_particle_strength_release: float = 0.35
@export var performance_particle_spiral_speed: float = 0.32
@export var performance_particle_spiral_radius_x: float = 22.0
@export var performance_particle_spiral_radius_y: float = 9.0
@export var performance_particle_spiral_intensity_scale: float = 0.30
@export var performance_tracer_enabled: bool = true
@export var performance_tracer_count: int = 8
@export var performance_tracer_points: int = 16
@export var performance_tracer_base_alpha: float = 0.04
@export var performance_tracer_max_alpha: float = 0.22

@export_category("Dialogue UI")
@export var dialogue_font_size: int = 42
@export var dialogue_side_margin: float = 60.0
@export var dialogue_bottom_margin: float = 30.0
@export var dialogue_panel_height: float = 260.0
@export var dialogue_dim_alpha: float = 0.88
@export var speaker_portrait_size: Vector2 = Vector2(250.0, 360.0)
@export var speaker_portrait_left_margin: float = 28.0
@export var speaker_portrait_panel_overlap: float = 18.0
@export var dialogue_text_left_padding_no_portrait: float = 28.0
@export var dialogue_text_left_padding_with_portrait: float = 340.0

@export_category("QTE UI")
@export var qte_bar_size: Vector2 = Vector2(1200.0, 120.0)
@export var qte_vertical_offset: float = 60.0
@export var cursor_width: float = 18.0
@export var cursor_height_padding: float = 20.0

@export_category("QTE Randomization")
@export var sweet_spot_left_padding: float = 220.0
@export var sweet_spot_right_padding: float = 40.0
@export var min_sweet_spot_move_distance: float = 180.0
@export var sweet_spot_random_retry_count: int = 12

@export_category("Tier Difficulty")
@export var base_qte_speed: float = 500.0
@export var base_sweet_spot_width: float = 260.0
@export var tier_speeds: PackedFloat32Array = PackedFloat32Array([500.0, 620.0, 760.0, 900.0])
@export var tier_sweet_spot_widths: PackedFloat32Array = PackedFloat32Array([260.0, 190.0, 140.0, 100.0])
@export var tier_required_hits: PackedInt32Array = PackedInt32Array([2, 3, 4, 5])
@export var qte_speed_per_chain_hit: float = 55.0

@export_category("Feedback")
@export var qte_feedback_duration: float = 0.14
@export var qte_shake_amount: float = 12.0

# --- INTERNAL STATE ---
enum State {
	IDLE,
	DIALOGUE_MODE_SELECT,
	PERFORMANCE_TITLECARD,
	DIALOGUE_INTRO,
	PERFORMANCE_INTRO,
	PERFORMANCE_ACTIVE,
	PERFORMANCE_OUTRO,
	QTE_ACTIVE,
	QTE_RESOLVING,
	DIALOGUE_OUTRO_WIN,
	DIALOGUE_OUTRO_LOSE,
	DIALOGUE_POST_ALL_TIERS
}

enum InteractionMode {
	AUTO_WEEKLY_PERFORMANCE,
	PERFORMANCE_ONLY,
	QTE_ONLY
}

enum BandStagePreset {
	CUSTOM,
	DUO_STAGE,
	TRIO_STAGE
}

var current_state: State = State.IDLE
@export var interaction_mode: InteractionMode = InteractionMode.PERFORMANCE_ONLY
@export var performance_band_stage_preset: BandStagePreset = BandStagePreset.CUSTOM
var current_tier_index: int = 0
var current_qte_hits: int = 0
var pending_qte_success: bool = false
var pending_qte_completed_tier: bool = false
var active_qte_speed: float = 0.0

# --- DYNAMIC UI REFERENCES ---
var ui_layer: CanvasLayer = null
var ui_root: Control = null
var scene_dimmer: ColorRect = null
var stage_backdrop: TextureRect = null
var performance_blackout_overlay: ColorRect = null
var performance_blackout_text: RichTextLabel = null
var dialogue_panel: Panel = null
var dialogue_text: RichTextLabel = null
var speaker_portrait: TextureRect = null
var band_member_portraits: Array[TextureRect] = []
var band_member_spotlights: Array[Polygon2D] = []
var lysander_spotlight: Polygon2D = null
var performance_sparkle_particles: Array[CPUParticles2D] = []
var performance_particle_layer_strengths: Array[float] = []
var performance_particle_layer_anchors: Array[Vector2] = []
var performance_particle_layer_drift_speeds: Array[Vector2] = []
var performance_particle_layer_phases: Array[float] = []
var performance_tracer_lines: Array[Line2D] = []
var performance_tracer_histories: Array = []
var performance_tracer_velocities: Array[Vector2] = []
var performance_tracer_phases: Array[float] = []
var performance_particle_texture: Texture2D = null
var dynamic_property_support_cache: Dictionary = {}
var mode_select_panel: Panel = null
var mode_select_label: RichTextLabel = null
var mode_performance_button: Button = null
var mode_qte_button: Button = null
var performance_close_button: Button = null
var performance_tip_button: Button = null
var performance_tip_fx_layer: Control = null
var qte_container: Control = null
var timing_bar: ColorRect = null
var sweet_spot: ColorRect = null
var cursor: ColorRect = null
var flash_rect: ColorRect = null
var feedback_timer: Timer = null

# --- QTE VARIABLES ---
var moving_right: bool = true
var cursor_is_in_sweet_spot: bool = false
var qte_base_position: Vector2 = Vector2.ZERO
var previous_sweet_spot_x: float = -1.0
var feedback_tween: Tween = null
var _skip_first_mouse_advance: bool = false
var performance_player: AudioStreamPlayer = null
var performance_music_base_db: float = 0.0
var performance_music_tween: Tween = null
var performance_lines: Array[String] = []
var performance_line_times: PackedFloat32Array = PackedFloat32Array()
var performance_current_line_index: int = -1
var performance_track_length: float = 0.0
var performance_track_title: String = ""
var performance_energy: float = 0.6
var portrait_base_scale: Vector2 = Vector2.ONE
var portrait_base_position: Vector2 = Vector2.ZERO
var portrait_default_texture: Texture2D = null
var band_member_base_positions: Array[Vector2] = []
var band_member_base_scales: Array[Vector2] = []
var band_member_base_modulates: Array[Color] = []
var performance_bus_index: int = -1
var performance_audio_level_smoothed: float = 0.0
var performance_audio_level_secondary: float = 0.0
var performance_time_accum: float = 0.0
var performance_blink_timer: float = 0.0
var performance_blink_elapsed: float = -1.0
var performance_pluck_impulse: float = 0.0
var performance_pluck_cooldown_timer: float = 0.0
var performance_last_live_intensity: float = 0.0
var performance_chorus_cooldown_timer: float = 0.0
var performance_flip_cooldown_timer: float = 0.0
var performance_facing_target_sign: float = 1.0
var performance_facing_visual_sign: float = 1.0
var performance_breakdown_low_timer: float = 0.0
var performance_breakdown_ready: bool = true
var performance_peak_high_timer: float = 0.0
var performance_peak_cycle_timer: float = 0.0
var performance_tip_boost_timer: float = 0.0
var performance_tip_boost_strength: float = 0.0
var performance_tip_cooldown_timer: float = 0.0
var performance_tip_gold_dirty: bool = false
var performance_tip_current_boost: float = 0.0
var performance_tip_reaction_timer: float = 0.0
var performance_tip_reaction_text: String = ""
var performance_twirl_cooldown_timer: float = 0.0
var performance_twirl_active: bool = false
var performance_twirl_elapsed: float = 0.0
var performance_lean_back_active: bool = false
var performance_lean_back_elapsed: float = 0.0
var performance_lean_back_direction: float = -1.0
var performance_member_accent_timers: Array[float] = []
var performance_member_accent_cooldown_timer: float = 0.0
var performance_member_last_accent_index: int = -1
var lyric_fade_tween: Tween = null
var performance_zoom_node: Control = null
var performance_zoom_base_scale: Vector2 = Vector2.ONE
var performance_zoom_base_position: Vector2 = Vector2.ZERO
var performance_zoom_tween: Tween = null
var stage_backdrop_tween: Tween = null
var scene_dimmer_tween: Tween = null
var performance_intro_tween: Tween = null
var performance_spotlight_tween: Tween = null
var performance_blackout_tween: Tween = null
var portrait_base_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
var tavern_music_player: AudioStreamPlayer = null
var tavern_music_previous_db: float = 0.0
var tavern_music_was_ducked: bool = false
var tavern_music_tween: Tween = null
const LYSANDER_WEEKLY_SETLIST_FLAG_PREFIX := "lysander_setlist_week_"

# --- VISUAL TUNING ---
const CURSOR_COLOR_DEFAULT: Color = Color(0.20, 0.90, 1.00, 1.00)
const CURSOR_COLOR_HOT: Color = Color(0.45, 1.00, 0.45, 1.00)
const CURSOR_COLOR_SUCCESS: Color = Color(0.55, 1.00, 0.55, 1.00)
const CURSOR_COLOR_FAIL: Color = Color(1.00, 0.35, 0.35, 1.00)

const SWEET_SPOT_COLOR_DEFAULT: Color = Color(0.80, 0.60, 0.20, 1.00)
const SWEET_SPOT_COLOR_HOT: Color = Color(1.00, 0.90, 0.35, 1.00)
const SWEET_SPOT_COLOR_FAIL: Color = Color(0.85, 0.30, 0.25, 1.00)

const FLASH_COLOR_SUCCESS: Color = Color(0.55, 1.00, 0.55, 0.70)
const FLASH_COLOR_FAIL: Color = Color(1.00, 0.35, 0.35, 0.70)
const DIALOGUE_PANEL_Z_INDEX := 10
const SPOTLIGHT_Z_INDEX := 22
const LYSANDER_SPOTLIGHT_Z_INDEX := 23
const BAND_MEMBER_Z_INDEX := 25
const PERFORMANCE_PARTICLE_Z_INDEX := 24
const SPEAKER_PORTRAIT_Z_INDEX := 30

# Purpose: Connects the button signal, builds the runtime UI, and applies initial layout.
# Inputs: None.
# Outputs: None.
# Side effects: Instantiates UI nodes, connects signals, randomizes RNG, and positions the UI correctly.
func _ready() -> void:
	randomize()
	pressed.connect(_on_lysander_pressed)
	_build_dynamic_ui()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	call_deferred("_layout_dynamic_ui")

# Purpose: Constructs the full dialogue/QTE UI entirely in code using a full-screen UI root.
# Inputs: None.
# Outputs: None.
# Side effects: Creates and configures a CanvasLayer, root Control, dialogue widgets, QTE visuals, and a timer.
func _build_dynamic_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 100
	ui_layer.hide()
	add_child(ui_layer)

	ui_root = Control.new()
	ui_root.anchor_left = 0.0
	ui_root.anchor_top = 0.0
	ui_root.anchor_right = 1.0
	ui_root.anchor_bottom = 1.0
	ui_root.offset_left = 0.0
	ui_root.offset_top = 0.0
	ui_root.offset_right = 0.0
	ui_root.offset_bottom = 0.0
	ui_root.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(ui_root)

	scene_dimmer = ColorRect.new()
	scene_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	scene_dimmer.color = Color(0.01, 0.008, 0.006, clampf(dialogue_dim_alpha, 0.0, 1.0))
	scene_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(scene_dimmer)

	stage_backdrop = TextureRect.new()
	stage_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	stage_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_backdrop.texture = performance_stage_backdrop_texture
	stage_backdrop.modulate = Color(1.0, 1.0, 1.0, 0.0)
	stage_backdrop.hide()
	ui_root.add_child(stage_backdrop)
	# Layer order: backdrop -> dimmer -> interactive UI (dialogue/portraits/buttons).
	ui_root.move_child(stage_backdrop, 0)
	ui_root.move_child(scene_dimmer, 1)

	performance_blackout_overlay = ColorRect.new()
	performance_blackout_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	performance_blackout_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	performance_blackout_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	performance_blackout_overlay.hide()
	ui_root.add_child(performance_blackout_overlay)

	performance_blackout_text = RichTextLabel.new()
	performance_blackout_text.anchor_left = 0.0
	performance_blackout_text.anchor_right = 1.0
	performance_blackout_text.anchor_top = 0.5
	performance_blackout_text.anchor_bottom = 0.5
	performance_blackout_text.offset_left = 120.0
	performance_blackout_text.offset_top = -96.0
	performance_blackout_text.offset_right = -120.0
	performance_blackout_text.offset_bottom = 96.0
	performance_blackout_text.bbcode_enabled = true
	performance_blackout_text.scroll_active = false
	performance_blackout_text.fit_content = false
	performance_blackout_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	performance_blackout_text.add_theme_font_size_override("normal_font_size", maxi(30, dialogue_font_size + 2))
	performance_blackout_text.hide()
	ui_root.add_child(performance_blackout_text)

	dialogue_panel = Panel.new()
	dialogue_panel.anchor_left = 0.0
	dialogue_panel.anchor_top = 0.0
	dialogue_panel.anchor_right = 0.0
	dialogue_panel.anchor_bottom = 0.0
	dialogue_panel.z_index = DIALOGUE_PANEL_Z_INDEX
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.10, 0.10, 0.92)
	panel_style.set_border_width_all(4)
	panel_style.border_color = Color(0.80, 0.60, 0.20, 1.00)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	dialogue_panel.add_theme_stylebox_override("panel", panel_style)
	ui_root.add_child(dialogue_panel)

	_build_performance_sparkle_particles()
	_build_performance_tracers()
	_build_band_member_portraits()
	if lysander_spotlight != null and is_instance_valid(lysander_spotlight):
		lysander_spotlight.queue_free()
	lysander_spotlight = Polygon2D.new()
	lysander_spotlight.z_index = LYSANDER_SPOTLIGHT_Z_INDEX
	var lysander_spotlight_material := CanvasItemMaterial.new()
	lysander_spotlight_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lysander_spotlight.material = lysander_spotlight_material
	lysander_spotlight.color = Color(1.0, 1.0, 1.0, 1.0)
	lysander_spotlight.modulate = Color(1.0, 1.0, 1.0, 0.0)
	lysander_spotlight.hide()
	ui_root.add_child(lysander_spotlight)

	speaker_portrait = TextureRect.new()
	speaker_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	speaker_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	speaker_portrait.z_index = SPEAKER_PORTRAIT_Z_INDEX
	speaker_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_portrait.texture = texture_normal
	portrait_default_texture = speaker_portrait.texture
	speaker_portrait.show()
	ui_root.add_child(speaker_portrait)

	dialogue_text = RichTextLabel.new()
	dialogue_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialogue_text.offset_left = dialogue_text_left_padding_with_portrait
	dialogue_text.offset_top = 24.0
	dialogue_text.offset_right = -28.0
	dialogue_text.offset_bottom = -24.0
	dialogue_text.bbcode_enabled = true
	dialogue_text.scroll_active = false
	dialogue_text.fit_content = false
	dialogue_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_text.add_theme_font_size_override("normal_font_size", dialogue_font_size)
	dialogue_text.add_theme_constant_override("line_separation", 8)
	dialogue_panel.add_child(dialogue_text)

	mode_select_panel = Panel.new()
	mode_select_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var mode_style := StyleBoxFlat.new()
	mode_style.bg_color = Color(0.10, 0.09, 0.08, 0.96)
	mode_style.set_border_width_all(3)
	mode_style.border_color = Color(0.80, 0.60, 0.20, 1.00)
	mode_style.corner_radius_top_left = 12
	mode_style.corner_radius_top_right = 12
	mode_style.corner_radius_bottom_left = 12
	mode_style.corner_radius_bottom_right = 12
	mode_select_panel.add_theme_stylebox_override("panel", mode_style)
	mode_select_panel.hide()
	ui_root.add_child(mode_select_panel)

	var mode_vbox := VBoxContainer.new()
	mode_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	mode_vbox.offset_left = 18.0
	mode_vbox.offset_top = 14.0
	mode_vbox.offset_right = -18.0
	mode_vbox.offset_bottom = -14.0
	mode_vbox.add_theme_constant_override("separation", 12)
	mode_select_panel.add_child(mode_vbox)

	mode_select_label = RichTextLabel.new()
	mode_select_label.fit_content = true
	mode_select_label.scroll_active = false
	mode_select_label.bbcode_enabled = true
	mode_select_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_select_label.add_theme_font_size_override("normal_font_size", 24)
	mode_vbox.add_child(mode_select_label)

	mode_performance_button = Button.new()
	mode_performance_button.text = "Performance Night"
	mode_performance_button.add_theme_font_size_override("font_size", 28)
	mode_performance_button.pressed.connect(_on_mode_performance_pressed)
	mode_vbox.add_child(mode_performance_button)

	mode_qte_button = Button.new()
	mode_qte_button.text = "Disc Trial"
	mode_qte_button.add_theme_font_size_override("font_size", 28)
	mode_qte_button.pressed.connect(_on_mode_qte_pressed)
	mode_vbox.add_child(mode_qte_button)

	performance_close_button = Button.new()
	performance_close_button.text = "Close"
	performance_close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	performance_close_button.add_theme_font_size_override("font_size", 24)
	performance_close_button.custom_minimum_size = Vector2(140.0, 58.0)
	performance_close_button.pressed.connect(_on_performance_close_pressed)
	performance_close_button.hide()
	ui_root.add_child(performance_close_button)

	performance_tip_button = Button.new()
	performance_tip_button.text = "Tip 25G"
	performance_tip_button.mouse_filter = Control.MOUSE_FILTER_STOP
	performance_tip_button.add_theme_font_size_override("font_size", 22)
	performance_tip_button.custom_minimum_size = Vector2(178.0, 58.0)
	performance_tip_button.pressed.connect(_on_performance_tip_pressed)
	performance_tip_button.hide()
	ui_root.add_child(performance_tip_button)

	performance_tip_fx_layer = Control.new()
	performance_tip_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	performance_tip_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	performance_tip_fx_layer.z_index = BAND_MEMBER_Z_INDEX + 2
	performance_tip_fx_layer.hide()
	ui_root.add_child(performance_tip_fx_layer)

	qte_container = Control.new()
	qte_container.anchor_left = 0.0
	qte_container.anchor_top = 0.0
	qte_container.anchor_right = 0.0
	qte_container.anchor_bottom = 0.0
	qte_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qte_container.hide()
	ui_root.add_child(qte_container)

	timing_bar = ColorRect.new()
	timing_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	timing_bar.color = Color(0.16, 0.16, 0.18, 1.0)
	qte_container.add_child(timing_bar)

	sweet_spot = ColorRect.new()
	sweet_spot.position = Vector2.ZERO
	sweet_spot.size = Vector2(base_sweet_spot_width, qte_bar_size.y)
	sweet_spot.custom_minimum_size = sweet_spot.size
	sweet_spot.color = SWEET_SPOT_COLOR_DEFAULT
	qte_container.add_child(sweet_spot)

	cursor = ColorRect.new()
	cursor.position = Vector2(0.0, -cursor_height_padding * 0.5)
	cursor.size = Vector2(cursor_width, qte_bar_size.y + cursor_height_padding)
	cursor.custom_minimum_size = cursor.size
	cursor.color = CURSOR_COLOR_DEFAULT
	qte_container.add_child(cursor)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = FLASH_COLOR_SUCCESS
	flash_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	flash_rect.hide()
	qte_container.add_child(flash_rect)

	feedback_timer = Timer.new()
	feedback_timer.one_shot = true
	feedback_timer.wait_time = qte_feedback_duration
	feedback_timer.timeout.connect(_on_feedback_timer_timeout)
	add_child(feedback_timer)

	performance_player = AudioStreamPlayer.new()
	performance_player.finished.connect(_on_performance_track_finished)
	add_child(performance_player)
	performance_music_base_db = performance_player.volume_db

# Purpose: Recalculates all runtime UI layout from the current viewport size.
# Inputs: None.
# Outputs: None.
# Side effects: Resizes the root UI and repositions the dialogue panel and QTE container.
func _layout_dynamic_ui() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	ui_root.position = Vector2.ZERO
	ui_root.size = viewport_size
	if stage_backdrop != null:
		stage_backdrop.texture = performance_stage_backdrop_texture
		stage_backdrop.pivot_offset = viewport_size * 0.5

	dialogue_panel.position = Vector2(
		dialogue_side_margin,
		viewport_size.y - dialogue_panel_height - dialogue_bottom_margin
	)
	dialogue_panel.size = Vector2(
		viewport_size.x - (dialogue_side_margin * 2.0),
		dialogue_panel_height
	)
	dialogue_panel.custom_minimum_size = dialogue_panel.size
	_apply_scene_dimmer_for_state(false)

	if speaker_portrait != null:
		speaker_portrait.size = speaker_portrait_size
		speaker_portrait.custom_minimum_size = speaker_portrait_size
		speaker_portrait.pivot_offset = speaker_portrait.size * 0.5
		var portrait_pos := Vector2(
			dialogue_panel.position.x + speaker_portrait_left_margin,
			dialogue_panel.position.y - speaker_portrait.size.y + speaker_portrait_panel_overlap
		)
		if _is_performance_stage_state():
			var member_size := _get_effective_band_member_size()
			var spacing := maxf(_get_effective_band_member_spacing(), member_size.x * 1.02)
			var offset := _get_effective_band_member_x_offset() + maxf(0.0, performance_band_member_gap_from_lysander)
			var total_members := band_member_portraits.size()
			var left_count := int(floor(float(total_members) * 0.5))
			var right_count := total_members - left_count
			var half_lysander := speaker_portrait.size.x * 0.5
			var half_member := member_size.x * 0.5
			var left_reach := half_lysander
			var right_reach := half_lysander
			if left_count > 0:
				left_reach += offset + half_member + (float(max(0, left_count - 1)) * spacing)
			if right_count > 0:
				right_reach += offset + half_member + (float(max(0, right_count - 1)) * spacing)
			var desired_center_x := viewport_size.x * 0.5
			if not performance_center_stage_lysander:
				desired_center_x = viewport_size.x * clampf(performance_stage_center_x_ratio, 0.20, 0.80)
			var stage_center_x := clampf(
				desired_center_x,
				20.0 + left_reach,
				viewport_size.x - 20.0 - right_reach
			)
			portrait_pos.x = stage_center_x - (speaker_portrait.size.x * 0.5)
			portrait_pos.y += performance_stage_y_offset
		speaker_portrait.position = portrait_pos
		if lysander_spotlight != null and is_instance_valid(lysander_spotlight):
			var beam_center_x := speaker_portrait.position.x + (speaker_portrait.size.x * 0.5)
			var top_y := performance_intro_spotlight_top_y_offset
			var spotlight_bottom_y := dialogue_panel.position.y + performance_band_member_panel_overlap + 28.0
			var beam_height := maxf(160.0, spotlight_bottom_y - top_y)
			_apply_spotlight_geometry(
				lysander_spotlight,
				beam_center_x,
				top_y,
				maxf(120.0, performance_intro_spotlight_width * 1.05),
				beam_height,
				performance_intro_lysander_spotlight_color
			)
	_layout_performance_sparkle_particles(viewport_size)
	_layout_performance_tracers(viewport_size)
	_layout_band_member_portraits(viewport_size)

	if mode_select_panel != null:
		var mode_size := Vector2(minf(viewport_size.x * 0.42, 760.0), 250.0)
		mode_select_panel.position = Vector2(
			(viewport_size.x - mode_size.x) * 0.5,
			maxf(40.0, dialogue_panel.position.y - mode_size.y - 24.0)
		)
		mode_select_panel.size = mode_size
		mode_select_panel.custom_minimum_size = mode_size

	if performance_close_button != null:
		var close_size := performance_close_button.custom_minimum_size
		performance_close_button.position = Vector2(
			viewport_size.x - dialogue_side_margin - close_size.x,
			maxf(22.0, dialogue_panel.position.y - close_size.y - 16.0)
		)
	if performance_tip_button != null:
		var tip_size := performance_tip_button.custom_minimum_size
		var tip_x := viewport_size.x - dialogue_side_margin - tip_size.x
		if performance_close_button != null:
			tip_x = performance_close_button.position.x - tip_size.x - 12.0
		performance_tip_button.position = Vector2(
			maxf(22.0, tip_x),
			maxf(22.0, dialogue_panel.position.y - tip_size.y - 16.0)
		)

	qte_base_position = Vector2(
		(viewport_size.x - qte_bar_size.x) * 0.5,
		((viewport_size.y - qte_bar_size.y) * 0.5) + qte_vertical_offset
	)

	qte_container.position = qte_base_position
	qte_container.size = qte_bar_size
	qte_container.custom_minimum_size = qte_bar_size

	timing_bar.size = qte_bar_size

	cursor.size = Vector2(cursor_width, qte_bar_size.y + cursor_height_padding)
	cursor.custom_minimum_size = cursor.size

	if current_state != State.QTE_ACTIVE and current_state != State.QTE_RESOLVING:
		qte_container.position = qte_base_position

	_refresh_speaker_portrait_visibility()

# Purpose: Refreshes the layout when the viewport size changes.
# Inputs: None.
# Outputs: None.
# Side effects: Reflows the dynamic UI to stay centered and readable after resize.
func _on_viewport_size_changed() -> void:
	_layout_dynamic_ui()


func _sync_layout_for_state() -> void:
	if ui_root == null or ui_layer == null:
		return
	if not ui_layer.visible:
		return
	_layout_dynamic_ui()
	_apply_scene_dimmer_for_state(true)


func _get_target_scene_dimmer_alpha() -> float:
	if _is_performance_stage_state():
		return clampf(maxf(dialogue_dim_alpha, performance_scene_dim_alpha), 0.0, 1.0)
	return clampf(dialogue_dim_alpha, 0.0, 1.0)


func _apply_scene_dimmer_for_state(animated: bool) -> void:
	if scene_dimmer == null:
		return
	var target_alpha := _get_target_scene_dimmer_alpha()
	var base := scene_dimmer.color
	var target := Color(base.r, base.g, base.b, target_alpha)
	if scene_dimmer_tween != null and scene_dimmer_tween.is_valid():
		scene_dimmer_tween.kill()
	if not animated:
		scene_dimmer.color = target
		return
	scene_dimmer_tween = create_tween()
	scene_dimmer_tween.set_trans(Tween.TRANS_SINE)
	scene_dimmer_tween.set_ease(Tween.EASE_OUT)
	scene_dimmer_tween.tween_property(scene_dimmer, "color", target, 0.24)


func _fade_stage_backdrop_in() -> void:
	if stage_backdrop == null:
		return
	if performance_stage_backdrop_texture == null:
		_fade_stage_backdrop_out(true)
		return

	stage_backdrop.texture = performance_stage_backdrop_texture
	stage_backdrop.show()
	stage_backdrop.modulate = Color(1.0, 1.0, 1.0, stage_backdrop.modulate.a)
	stage_backdrop.scale = Vector2(1.0, maxf(1.0, performance_stage_backdrop_unfurl_scale))

	if stage_backdrop_tween != null and stage_backdrop_tween.is_valid():
		stage_backdrop_tween.kill()
	stage_backdrop_tween = create_tween()
	stage_backdrop_tween.set_trans(Tween.TRANS_SINE)
	stage_backdrop_tween.set_ease(Tween.EASE_OUT)
	stage_backdrop_tween.parallel().tween_property(
		stage_backdrop,
		"modulate",
		Color(1.0, 1.0, 1.0, clampf(performance_stage_backdrop_alpha, 0.0, 1.0)),
		maxf(0.05, performance_stage_backdrop_fade_in_time)
	)
	stage_backdrop_tween.parallel().tween_property(
		stage_backdrop,
		"scale",
		Vector2.ONE,
		maxf(0.05, performance_stage_backdrop_fade_in_time)
	)


func _hide_stage_backdrop_now() -> void:
	if stage_backdrop == null:
		return
	stage_backdrop.scale = Vector2.ONE
	stage_backdrop.modulate = Color(1.0, 1.0, 1.0, 0.0)
	stage_backdrop.hide()


func _hide_blackout_titlecard_now() -> void:
	if performance_blackout_overlay != null:
		performance_blackout_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
		performance_blackout_overlay.hide()
	if performance_blackout_text != null:
		performance_blackout_text.modulate = Color(1.0, 1.0, 1.0, 0.0)
		performance_blackout_text.hide()


func _show_blackout_titlecard_and_start() -> void:
	if not performance_show_blackout_titlecard or str(performance_showman_intro_text).strip_edges() == "":
		_start_performance_night()
		return
	if performance_blackout_overlay == null or performance_blackout_text == null:
		_start_performance_night()
		return

	if performance_blackout_tween != null and performance_blackout_tween.is_valid():
		performance_blackout_tween.kill()

	performance_blackout_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	performance_blackout_overlay.show()
	performance_blackout_text.text = "[center][font_size=%d][color=#ffe1a8]%s[/color][/font_size][/center]" % [
		maxi(30, dialogue_font_size + 4),
		str(performance_showman_intro_text).strip_edges()
	]
	performance_blackout_text.modulate = Color(1.0, 1.0, 1.0, 0.0)
	performance_blackout_text.show()
	# Keep the blackout/title card above all runtime UI.
	ui_root.move_child(performance_blackout_overlay, ui_root.get_child_count() - 1)
	ui_root.move_child(performance_blackout_text, ui_root.get_child_count() - 1)

	performance_blackout_tween = create_tween()
	performance_blackout_tween.set_trans(Tween.TRANS_SINE)
	performance_blackout_tween.set_ease(Tween.EASE_OUT)
	performance_blackout_tween.parallel().tween_property(
		performance_blackout_overlay,
		"color",
		Color(0.0, 0.0, 0.0, 1.0),
		maxf(0.05, performance_blackout_fade_in_time)
	)
	performance_blackout_tween.parallel().tween_property(
		performance_blackout_text,
		"modulate",
		Color(1.0, 1.0, 1.0, 1.0),
		maxf(0.05, performance_blackout_fade_in_time)
	)
	performance_blackout_tween.tween_interval(maxf(0.1, performance_blackout_duration))
	performance_blackout_tween.tween_property(
		performance_blackout_overlay,
		"color",
		Color(0.0, 0.0, 0.0, 0.0),
		maxf(0.05, performance_blackout_fade_out_time)
	)
	performance_blackout_tween.parallel().tween_property(
		performance_blackout_text,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.0),
		maxf(0.05, performance_blackout_fade_out_time)
	)
	performance_blackout_tween.tween_callback(Callable(self, "_hide_blackout_titlecard_now"))
	performance_blackout_tween.tween_callback(Callable(self, "_start_performance_night"))


func _fade_stage_backdrop_out(immediate: bool = false) -> void:
	if stage_backdrop == null:
		return
	if stage_backdrop_tween != null and stage_backdrop_tween.is_valid():
		stage_backdrop_tween.kill()
	if immediate:
		_hide_stage_backdrop_now()
		return
	if not stage_backdrop.visible:
		return
	stage_backdrop_tween = create_tween()
	stage_backdrop_tween.set_trans(Tween.TRANS_SINE)
	stage_backdrop_tween.set_ease(Tween.EASE_OUT)
	stage_backdrop_tween.tween_property(
		stage_backdrop,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.0),
		maxf(0.05, performance_stage_backdrop_fade_out_time)
	)
	stage_backdrop_tween.tween_callback(Callable(self, "_hide_stage_backdrop_now"))


func _play_theatrical_intro_reveal() -> void:
	if dialogue_text == null:
		return
	if performance_intro_tween != null and performance_intro_tween.is_valid():
		performance_intro_tween.kill()

	var start_alpha := 0.0
	dialogue_text.modulate = Color(1.0, 1.0, 1.0, start_alpha)
	var base_panel_pos := dialogue_panel.position
	dialogue_panel.position = base_panel_pos + Vector2(0.0, 18.0)

	performance_intro_tween = create_tween()
	performance_intro_tween.set_trans(Tween.TRANS_SINE)
	performance_intro_tween.set_ease(Tween.EASE_OUT)
	performance_intro_tween.parallel().tween_property(
		dialogue_text,
		"modulate",
		Color(1.0, 1.0, 1.0, 1.0),
		maxf(0.08, performance_intro_reveal_time)
	)
	performance_intro_tween.parallel().tween_property(
		dialogue_panel,
		"position",
		base_panel_pos,
		maxf(0.08, performance_intro_reveal_time)
	)

# Purpose: Starts Lysander's interaction flow when the player presses the NPC button.
# Inputs: None.
# Outputs: None.
# Side effects: Clears focus/input state, shows the UI, and routes to tier intro or post-completion dialogue.
func _on_lysander_pressed() -> void:
	if current_state != State.IDLE:
		return

	_consume_current_input()
	_layout_dynamic_ui()
	ui_layer.show()
	qte_container.hide()
	_skip_first_mouse_advance = true
	_show_mode_select_dialogue()
	return


func _show_mode_select_dialogue() -> void:
	current_state = State.DIALOGUE_MODE_SELECT
	_sync_layout_for_state()
	_fade_stage_backdrop_out()
	_refresh_speaker_portrait_visibility()
	if mode_select_panel == null:
		return
	mode_select_panel.show()
	dialogue_text.text = "[font_size=%d][color=cyan]Lysander:[/color] Choose your evening: a full [color=gold]Performance Night[/color] set, or the [color=gold]Disc Trial[/color].[/font_size]" % [dialogue_font_size]

	var has_performance: bool = _has_valid_performance_setlist()
	var can_trial: bool = reward_discs.size() > 0

	if mode_performance_button != null:
		mode_performance_button.disabled = not has_performance
		mode_performance_button.tooltip_text = "" if has_performance else "No private performance setlist configured."
	if mode_qte_button != null:
		mode_qte_button.disabled = not can_trial
		mode_qte_button.tooltip_text = "" if can_trial else "No disc trial rewards configured."


func _hide_mode_select_dialogue() -> void:
	if mode_select_panel != null:
		mode_select_panel.hide()


func _on_mode_performance_pressed() -> void:
	_hide_mode_select_dialogue()
	if not _has_valid_performance_setlist():
		_show_performance_unavailable_dialogue()
		return
	if weekly_performance_requires_new_week and _has_performed_this_week():
		_show_performance_cooldown_dialogue()
		return
	_show_performance_intro_dialogue()


func _on_mode_qte_pressed() -> void:
	_hide_mode_select_dialogue()
	if _has_remaining_tiers():
		_show_intro_dialogue()
	else:
		_show_post_all_tiers_dialogue()


func _has_valid_performance_setlist() -> bool:
	return not _collect_setlist_entries().is_empty()

# Purpose: Handles accept-button input for dialogue advancement, QTE resolution, and closing.
# Inputs: event (InputEvent) - The raw input event delivered by the engine.
# Outputs: None.
# Side effects: Progresses the interaction state machine and consumes handled accept input.
func _input(event: InputEvent) -> void:
	if current_state == State.IDLE:
		return
	if current_state == State.DIALOGUE_MODE_SELECT:
		return

	if not _is_advance_input(event):
		return

	match current_state:
		State.DIALOGUE_INTRO:
			_consume_current_input()
			_start_qte()
		State.PERFORMANCE_INTRO:
			_consume_current_input()
			_start_performance_night()
		State.PERFORMANCE_TITLECARD:
			pass
		State.PERFORMANCE_OUTRO:
			_consume_current_input()
			_close_interaction()
		State.QTE_ACTIVE:
			_consume_current_input()
			_resolve_qte()
		State.DIALOGUE_OUTRO_WIN, State.DIALOGUE_OUTRO_LOSE, State.DIALOGUE_POST_ALL_TIERS:
			_consume_current_input()
			_close_interaction()
		State.QTE_RESOLVING, State.PERFORMANCE_ACTIVE:
			pass
		_:
			pass


func _is_advance_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.is_echo():
			return false
		return key_event.is_action_pressed("ui_accept")

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or mb.is_echo():
			return false
		if _skip_first_mouse_advance:
			_skip_first_mouse_advance = false
			return false
		return true

	return false


func _on_performance_close_pressed() -> void:
	if current_state == State.IDLE:
		return
	_close_interaction()


func _get_tip_cost() -> int:
	return maxi(1, performance_tip_gold_cost)


func _get_player_gold_amount() -> int:
	if CampaignManager == null:
		return 0
	if CampaignManager.has_method("get"):
		return int(CampaignManager.get("global_gold"))
	return int(CampaignManager.global_gold)


func _set_player_gold_amount(new_amount: int) -> void:
	if CampaignManager == null:
		return
	var safe_amount: int = maxi(0, new_amount)
	if CampaignManager.has_method("set"):
		CampaignManager.set("global_gold", safe_amount)
	else:
		CampaignManager.global_gold = safe_amount


func _update_tip_button_state() -> void:
	if performance_tip_button == null:
		return
	var cost: int = _get_tip_cost()
	var gold: int = _get_player_gold_amount()
	var showtime: bool = current_state == State.PERFORMANCE_ACTIVE
	var can_tip: bool = showtime and performance_tip_cooldown_timer <= 0.0 and gold >= cost
	performance_tip_button.disabled = not can_tip
	if not showtime:
		performance_tip_button.text = "Tip %dG" % cost
		return
	if gold < cost:
		performance_tip_button.text = "Need %dG" % cost
		return
	if performance_tip_cooldown_timer > 0.0:
		performance_tip_button.text = "Encore..."
		return
	performance_tip_button.text = "Tip %dG" % cost


func _get_current_tip_boost_value() -> float:
	if performance_tip_boost_timer <= 0.0:
		return 0.0
	var t: float = performance_tip_boost_timer / maxf(0.05, performance_tip_boost_duration)
	return clampf(performance_tip_boost_strength * (0.40 + (t * 0.60)), 0.0, 1.0)


func _get_tip_boost_normalized() -> float:
	return clampf(
		performance_tip_current_boost / maxf(0.05, performance_tip_boost_intensity),
		0.0,
		1.0
	)


func _show_tip_reaction_dialogue() -> void:
	if dialogue_text == null:
		return
	var shout: String = performance_tip_reaction_text.strip_edges()
	if shout == "":
		shout = "Encore!"
	dialogue_text.text = "[font_size=%d][color=cyan]Lysander - %s[/color][/font_size]\n\n[font_size=%d][color=#ffd873]%s[/color][/font_size]\n\n[font_size=%d][color=gray][i]Crowd energy surges![/i][/color][/font_size]" % [
		dialogue_font_size - 4,
		performance_track_title,
		dialogue_font_size + 2,
		shout,
		dialogue_font_size - 6
	]
	_animate_lyric_card_transition()


func _trigger_tip_band_reaction() -> void:
	var reaction_index: int = randi() % 3 # 0=cheer, 1=wink, 2=shout pose
	var visible_targets: Array[Control] = []
	if speaker_portrait != null and is_instance_valid(speaker_portrait) and speaker_portrait.visible:
		visible_targets.append(speaker_portrait)
	for member in band_member_portraits:
		if member != null and is_instance_valid(member) and member.visible:
			visible_targets.append(member)
	if visible_targets.is_empty():
		return

	if reaction_index == 0:
		for ctrl in visible_targets:
			var base_pos: Vector2 = ctrl.position
			var base_scale: Vector2 = ctrl.scale
			var t := create_tween()
			t.set_trans(Tween.TRANS_SINE)
			t.set_ease(Tween.EASE_OUT)
			t.tween_property(ctrl, "position", base_pos + Vector2(randf_range(-6.0, 6.0), -12.0), 0.10)
			t.parallel().tween_property(ctrl, "scale", base_scale * Vector2(1.04, 1.06), 0.10)
			t.tween_property(ctrl, "position", base_pos, 0.15)
			t.parallel().tween_property(ctrl, "scale", base_scale, 0.15)
	elif reaction_index == 1:
		var wink_target: Control = visible_targets[randi() % visible_targets.size()]
		var base_scale: Vector2 = wink_target.scale
		var t := create_tween()
		t.set_trans(Tween.TRANS_SINE)
		t.set_ease(Tween.EASE_OUT)
		t.tween_property(wink_target, "scale", base_scale * Vector2(1.06, 0.92), 0.08)
		t.tween_property(wink_target, "scale", base_scale, 0.10)
		t.tween_property(wink_target, "scale", base_scale * Vector2(1.03, 0.96), 0.06)
		t.tween_property(wink_target, "scale", base_scale, 0.08)
	else:
		for ctrl in visible_targets:
			var base_rot: float = ctrl.rotation
			var t := create_tween()
			t.set_trans(Tween.TRANS_SINE)
			t.set_ease(Tween.EASE_OUT)
			t.tween_property(ctrl, "rotation", base_rot + deg_to_rad(randf_range(-4.0, 4.0)), 0.11)
			t.tween_property(ctrl, "rotation", base_rot, 0.16)


func _update_tip_visual_upgrades() -> void:
	var boost: float = clampf(performance_tip_current_boost, 0.0, 1.0)
	var boost_norm: float = _get_tip_boost_normalized()
	if current_state != State.PERFORMANCE_ACTIVE or boost <= 0.001:
		for spotlight in band_member_spotlights:
			if spotlight == null or not is_instance_valid(spotlight):
				continue
			spotlight.visible = false
			spotlight.modulate.a = 0.0
		if lysander_spotlight != null and is_instance_valid(lysander_spotlight):
			lysander_spotlight.visible = false
			lysander_spotlight.modulate.a = 0.0
		return

	var band_alpha_peak: float = clampf(
		maxf(performance_intro_spotlight_alpha + performance_tip_spotlight_boost_alpha, performance_intro_spotlight_alpha),
		0.0,
		0.72
	)
	var band_alpha_target: float = lerpf(performance_intro_spotlight_alpha * 0.35, band_alpha_peak, boost_norm)
	for i in range(band_member_spotlights.size()):
		var spotlight: Polygon2D = band_member_spotlights[i]
		if spotlight == null or not is_instance_valid(spotlight):
			continue
		if i >= band_member_portraits.size() or not band_member_portraits[i].visible:
			spotlight.visible = false
			spotlight.modulate.a = 0.0
			continue
		spotlight.visible = true
		spotlight.modulate.a = lerpf(spotlight.modulate.a, band_alpha_target, 0.24)

	if lysander_spotlight != null and is_instance_valid(lysander_spotlight):
		lysander_spotlight.visible = true
		var ly_alpha_peak: float = clampf(
			maxf(performance_intro_lysander_spotlight_alpha, performance_tip_spotlight_boost_alpha + 0.40),
			0.0,
			0.90
		)
		var ly_alpha_target: float = lerpf(performance_intro_lysander_spotlight_alpha * 0.34, ly_alpha_peak, boost_norm)
		lysander_spotlight.modulate.a = lerpf(lysander_spotlight.modulate.a, ly_alpha_target, 0.24)


func _play_tip_throw_animation() -> void:
	if performance_tip_fx_layer == null or not is_instance_valid(performance_tip_fx_layer):
		return
	var throw_count: int = clampi(performance_tip_throw_count, 3, 18)
	var source: Vector2 = Vector2.ZERO
	if performance_tip_button != null and is_instance_valid(performance_tip_button):
		source = performance_tip_button.position + (performance_tip_button.size * 0.5)
	elif performance_close_button != null and is_instance_valid(performance_close_button):
		source = performance_close_button.position + (performance_close_button.size * 0.5)

	var targets: Array[Vector2] = []
	if speaker_portrait != null and is_instance_valid(speaker_portrait) and speaker_portrait.visible:
		targets.append(speaker_portrait.position + Vector2(speaker_portrait.size.x * 0.5, speaker_portrait.size.y * 0.56))
	for member in band_member_portraits:
		if member == null or not is_instance_valid(member) or not member.visible:
			continue
		targets.append(member.position + Vector2(member.size.x * 0.5, member.size.y * 0.56))
	if targets.is_empty():
		targets.append(source + Vector2(-120.0, -120.0))
		targets.append(source + Vector2(120.0, -90.0))

	performance_tip_fx_layer.show()
	for i in range(throw_count):
		var coin := Label.new()
		coin.text = "$"
		coin.add_theme_font_size_override("font_size", randi_range(18, 26))
		coin.modulate = Color(1.0, 0.86, 0.30, 0.95)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.scale = Vector2.ONE * randf_range(0.88, 1.16)
		coin.position = source + Vector2(randf_range(-16.0, 16.0), randf_range(-8.0, 8.0))
		performance_tip_fx_layer.add_child(coin)

		var target_index: int = randi() % targets.size()
		var target_pos: Vector2 = targets[target_index] + Vector2(randf_range(-34.0, 34.0), randf_range(-22.0, 28.0))
		var apex: Vector2 = ((coin.position + target_pos) * 0.5) + Vector2(randf_range(-58.0, 58.0), -randf_range(70.0, 150.0))
		var travel_up: float = randf_range(0.13, 0.20)
		var travel_down: float = randf_range(0.16, 0.26)
		var fade_time: float = travel_up + travel_down

		var t := create_tween()
		t.set_trans(Tween.TRANS_SINE)
		t.set_ease(Tween.EASE_OUT)
		t.tween_property(coin, "position", apex, travel_up)
		t.tween_property(coin, "position", target_pos, travel_down)
		t.parallel().tween_property(coin, "modulate:a", 0.0, fade_time)
		t.parallel().tween_property(coin, "scale", coin.scale * randf_range(0.70, 0.90), fade_time)
		t.tween_callback(Callable(coin, "queue_free"))


func _on_performance_tip_pressed() -> void:
	if current_state != State.PERFORMANCE_ACTIVE:
		return
	if performance_tip_cooldown_timer > 0.0:
		return
	var cost: int = _get_tip_cost()
	var current_gold: int = _get_player_gold_amount()
	if current_gold < cost:
		_update_tip_button_state()
		return
	_set_player_gold_amount(current_gold - cost)
	performance_tip_gold_dirty = true

	performance_tip_cooldown_timer = maxf(0.05, performance_tip_cooldown)
	var boost_duration: float = maxf(0.25, performance_tip_boost_duration)
	var boost_amount: float = clampf(performance_tip_boost_intensity, 0.02, 0.85)
	if performance_tip_boost_timer > 0.0:
		performance_tip_boost_strength = clampf(performance_tip_boost_strength + (boost_amount * 0.55), 0.02, 0.95)
		performance_tip_boost_timer = maxf(performance_tip_boost_timer, boost_duration)
	else:
		performance_tip_boost_strength = boost_amount
		performance_tip_boost_timer = boost_duration
	performance_tip_current_boost = _get_current_tip_boost_value()
	performance_tip_reaction_timer = 1.15
	if performance_tip_reaction_lines.is_empty():
		performance_tip_reaction_text = "The crowd erupts!"
	else:
		performance_tip_reaction_text = str(performance_tip_reaction_lines[randi() % performance_tip_reaction_lines.size()])
	performance_pluck_impulse = 1.0
	_trigger_tip_band_reaction()
	_play_tip_throw_animation()
	_show_tip_reaction_dialogue()
	_update_tip_button_state()


func _is_performance_stage_state() -> bool:
	return (
		current_state == State.PERFORMANCE_INTRO
		or current_state == State.PERFORMANCE_ACTIVE
		or current_state == State.PERFORMANCE_OUTRO
	)


func _get_band_member_limit() -> int:
	match performance_band_stage_preset:
		BandStagePreset.DUO_STAGE:
			return 2
		BandStagePreset.TRIO_STAGE:
			return 3
		_:
			return 999


func _get_effective_band_member_size() -> Vector2:
	match performance_band_stage_preset:
		BandStagePreset.DUO_STAGE:
			return Vector2(238.0, 348.0)
		BandStagePreset.TRIO_STAGE:
			return Vector2(220.0, 322.0)
		_:
			return performance_band_member_size


func _get_effective_band_member_x_offset() -> float:
	match performance_band_stage_preset:
		BandStagePreset.DUO_STAGE:
			return 44.0
		BandStagePreset.TRIO_STAGE:
			return 36.0
		_:
			return performance_band_member_x_offset


func _get_effective_band_member_spacing() -> float:
	match performance_band_stage_preset:
		BandStagePreset.DUO_STAGE:
			return 176.0
		BandStagePreset.TRIO_STAGE:
			return 158.0
		_:
			return performance_band_member_spacing


func _get_effective_band_member_y_step() -> float:
	match performance_band_stage_preset:
		BandStagePreset.DUO_STAGE:
			return 11.0
		BandStagePreset.TRIO_STAGE:
			return 8.0
		_:
			return performance_band_member_y_step


func _get_effective_band_member_alpha() -> float:
	return 1.0


func _get_effective_band_member_intensity_scale() -> float:
	match performance_band_stage_preset:
		BandStagePreset.DUO_STAGE:
			return 0.42
		BandStagePreset.TRIO_STAGE:
			return 0.36
		_:
			return performance_band_member_intensity_scale


func _get_effective_band_member_sway_scale() -> float:
	match performance_band_stage_preset:
		BandStagePreset.DUO_STAGE:
			return 0.52
		BandStagePreset.TRIO_STAGE:
			return 0.46
		_:
			return performance_band_member_sway_scale


func _get_effective_band_member_glow_strength() -> float:
	match performance_band_stage_preset:
		BandStagePreset.DUO_STAGE:
			return 0.075
		BandStagePreset.TRIO_STAGE:
			return 0.060
		_:
			return performance_band_member_glow_strength


func _build_band_member_portraits() -> void:
	if performance_spotlight_tween != null and performance_spotlight_tween.is_valid():
		performance_spotlight_tween.kill()
	for node in band_member_spotlights:
		if node != null and is_instance_valid(node):
			node.queue_free()
	band_member_spotlights.clear()
	for node in band_member_portraits:
		if node != null and is_instance_valid(node):
			node.queue_free()
	band_member_portraits.clear()
	band_member_base_positions.clear()
	band_member_base_scales.clear()
	band_member_base_modulates.clear()

	if ui_root == null:
		return

	var member_limit := _get_band_member_limit()
	var used_count := 0
	var member_alpha := clampf(_get_effective_band_member_alpha(), 0.0, 1.0)
	for tex in performance_band_member_textures:
		if used_count >= member_limit:
			break
		if tex == null:
			continue
		var member := TextureRect.new()
		member.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		member.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		member.mouse_filter = Control.MOUSE_FILTER_IGNORE
		member.texture = tex
		member.z_index = BAND_MEMBER_Z_INDEX
		member.modulate = Color(1.0, 1.0, 1.0, member_alpha)
		member.hide()

		var spotlight := Polygon2D.new()
		spotlight.z_index = SPOTLIGHT_Z_INDEX
		spotlight.color = Color(1.0, 1.0, 1.0, 1.0)
		spotlight.modulate = Color(1.0, 1.0, 1.0, 0.0)
		spotlight.hide()
		ui_root.add_child(spotlight)

		ui_root.add_child(member)
		band_member_spotlights.append(spotlight)
		band_member_portraits.append(member)
		band_member_base_positions.append(Vector2.ZERO)
		band_member_base_scales.append(Vector2.ONE)
		band_member_base_modulates.append(member.modulate)
		used_count += 1
	_sync_member_accent_buffers()


func _sync_member_accent_buffers() -> void:
	var needed: int = band_member_portraits.size()
	while performance_member_accent_timers.size() < needed:
		performance_member_accent_timers.append(0.0)
	while performance_member_accent_timers.size() > needed:
		performance_member_accent_timers.pop_back()


func _trigger_random_member_accent(force: bool = false) -> void:
	if current_state != State.PERFORMANCE_ACTIVE:
		return
	if performance_member_accent_cooldown_timer > 0.0:
		return
	if not force and randf() > clampf(performance_member_accent_chance, 0.0, 1.0):
		return

	var candidates: Array[int] = []
	for i in range(band_member_portraits.size()):
		var member := band_member_portraits[i]
		if member == null or not is_instance_valid(member) or not member.visible:
			continue
		if i < performance_member_accent_timers.size() and performance_member_accent_timers[i] > 0.0:
			continue
		candidates.append(i)
	if candidates.is_empty():
		return

	if candidates.size() > 1 and candidates.has(performance_member_last_accent_index):
		candidates.erase(performance_member_last_accent_index)
	if candidates.is_empty():
		return

	var chosen_index: int = candidates[randi() % candidates.size()]
	_sync_member_accent_buffers()
	if chosen_index >= 0 and chosen_index < performance_member_accent_timers.size():
		performance_member_accent_timers[chosen_index] = maxf(0.08, performance_member_accent_duration)
		performance_member_last_accent_index = chosen_index
		performance_member_accent_cooldown_timer = maxf(0.06, performance_member_accent_cooldown)


func _set_node_property_if_exists(target: Object, property_name: StringName, value: Variant) -> void:
	if target == null:
		return
	var cache_key: String = target.get_class() + ":" + str(property_name)
	var has_property: bool = false
	if dynamic_property_support_cache.has(cache_key):
		has_property = bool(dynamic_property_support_cache[cache_key])
	else:
		for prop in target.get_property_list():
			if prop is Dictionary and str(prop.get("name", "")) == str(property_name):
				has_property = true
				break
		dynamic_property_support_cache[cache_key] = has_property
	if has_property:
		target.set(property_name, value)


func _build_performance_sparkle_particles() -> void:
	for node in performance_sparkle_particles:
		if node != null and is_instance_valid(node):
			node.queue_free()
	performance_sparkle_particles.clear()
	performance_particle_layer_strengths.clear()
	performance_particle_layer_anchors.clear()
	performance_particle_layer_drift_speeds.clear()
	performance_particle_layer_phases.clear()
	dynamic_property_support_cache.clear()

	if ui_root == null:
		return
	if not performance_particles_enabled:
		return
	if performance_particle_texture == null:
		performance_particle_texture = _create_soft_particle_texture(24)

	var palette_count: int = maxi(1, performance_particle_colors.size())
	var emitters_per_color: int = 5
	var layer_count: int = palette_count * emitters_per_color
	var target_particle_budget: int = maxi(10, int(round(float(maxi(6, performance_particle_max_amount)) * 0.72)))
	var per_emitter_amount: int = maxi(4, int(round(float(target_particle_budget) / float(maxi(1, layer_count)))))
	for i in range(layer_count):
		var particles: CPUParticles2D = CPUParticles2D.new()
		particles.z_index = PERFORMANCE_PARTICLE_Z_INDEX
		particles.texture = performance_particle_texture
		var particle_material: CanvasItemMaterial = CanvasItemMaterial.new()
		particle_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		particles.material = particle_material
		particles.local_coords = false
		particles.one_shot = false
		particles.explosiveness = 0.0
		particles.randomness = 0.78
		particles.preprocess = 1.2 + randf_range(0.0, 3.5)
		particles.speed_scale = 1.2
		particles.amount = per_emitter_amount
		particles.lifetime = maxf(0.2, performance_particle_lifetime)
		particles.direction = Vector2(0.0, -1.0)
		particles.spread = 182.0
		particles.gravity = Vector2(0.0, -2.8)
		particles.modulate = Color(1.0, 1.0, 1.0, 0.0)
		particles.emitting = false

		# Keep optional properties guarded so this works across engine minor versions.
		_set_node_property_if_exists(particles, &"initial_velocity_min", 10.0 + float(i % emitters_per_color) * 1.2)
		_set_node_property_if_exists(particles, &"initial_velocity_max", 22.0 + float(i % emitters_per_color) * 3.0)
		_set_node_property_if_exists(particles, &"scale_amount_min", 0.13)
		_set_node_property_if_exists(particles, &"scale_amount_max", 0.34)
		_set_node_property_if_exists(particles, &"damping_min", 0.22)
		_set_node_property_if_exists(particles, &"damping_max", 1.1)
		_set_node_property_if_exists(particles, &"orbit_velocity_min", 0.0)
		_set_node_property_if_exists(particles, &"orbit_velocity_max", 0.0)
		_set_node_property_if_exists(particles, &"amount_ratio", 0.52)
		_set_node_property_if_exists(particles, &"emission_shape", CPUParticles2D.EMISSION_SHAPE_RECTANGLE)
		_set_node_property_if_exists(particles, &"emission_rect_extents", Vector2(52.0, 44.0))

		ui_root.add_child(particles)
		performance_sparkle_particles.append(particles)
		performance_particle_layer_strengths.append(0.0)
		var anchor: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-0.90, 0.82))
		if absf(anchor.x) < 0.10 and absf(anchor.y) < 0.10:
			anchor = Vector2(randf_range(-1.0, 1.0), randf_range(-0.90, 0.82))
		performance_particle_layer_anchors.append(anchor)
		performance_particle_layer_drift_speeds.append(
			Vector2(
				randf_range(0.85, 2.20),
				randf_range(0.75, 1.95)
			)
		)
		performance_particle_layer_phases.append(randf_range(0.0, TAU))


func _build_performance_tracers() -> void:
	for line in performance_tracer_lines:
		if line != null and is_instance_valid(line):
			line.queue_free()
	performance_tracer_lines.clear()
	performance_tracer_histories.clear()
	performance_tracer_velocities.clear()
	performance_tracer_phases.clear()

	if ui_root == null:
		return
	if not performance_tracer_enabled:
		return

	var tracer_count: int = clampi(performance_tracer_count + maxi(0, performance_tip_extra_tracer_count), 0, 30)
	var tracer_points: int = clampi(performance_tracer_points, 3, 28)
	for i in range(tracer_count):
		var line: Line2D = Line2D.new()
		line.z_index = PERFORMANCE_PARTICLE_Z_INDEX
		line.antialiased = true
		line.width = randf_range(1.0, 1.9)
		line.default_color = Color(1.0, 1.0, 1.0, 1.0)
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		var gradient := Gradient.new()
		gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
		gradient.add_point(0.70, Color(1.0, 1.0, 1.0, 0.58))
		gradient.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
		line.gradient = gradient
		line.modulate = Color(1.0, 1.0, 1.0, 0.0)
		line.hide()
		var points: PackedVector2Array = PackedVector2Array()
		for _p in range(tracer_points):
			points.append(Vector2.ZERO)
		line.points = points
		ui_root.add_child(line)

		var history: Array[Vector2] = []
		for _h in range(tracer_points):
			history.append(Vector2.ZERO)
		performance_tracer_lines.append(line)
		performance_tracer_histories.append(history)
		performance_tracer_velocities.append(Vector2(randf_range(-24.0, 24.0), randf_range(-20.0, 20.0)))
		performance_tracer_phases.append(randf_range(0.0, TAU))


func _create_soft_particle_texture(size_px: int) -> Texture2D:
	var side: int = maxi(8, size_px)
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var center: float = (float(side) - 1.0) * 0.5
	var max_dist: float = maxf(1.0, center)
	for y in range(side):
		for x in range(side):
			var dx: float = float(x) - center
			var dy: float = float(y) - center
			var dist: float = sqrt((dx * dx) + (dy * dy))
			var t: float = clampf(1.0 - (dist / max_dist), 0.0, 1.0)
			var alpha: float = pow(t, 1.9)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _get_particle_palette_color(index: int) -> Color:
	var count: int = performance_particle_colors.size()
	if count > 0:
		var safe_index: int = index % count
		if safe_index < 0:
			safe_index += count
		return performance_particle_colors[safe_index]
	return Color(1.0, 1.0, 1.0, 1.0)


func _layout_performance_sparkle_particles(viewport_size: Vector2) -> void:
	if performance_sparkle_particles.is_empty():
		return
	if dialogue_panel == null:
		return

	var stage_top: float = maxf(50.0, performance_intro_spotlight_top_y_offset + 110.0)
	var stage_bottom: float = dialogue_panel.position.y - 14.0
	if speaker_portrait != null and is_instance_valid(speaker_portrait):
		stage_top = maxf(50.0, speaker_portrait.position.y - 110.0)
		stage_bottom = minf(stage_bottom, speaker_portrait.position.y + (speaker_portrait.size.y * 0.88))
	var stage_height: float = clampf(stage_bottom - stage_top, 210.0, 420.0)
	var stage_width: float = clampf(viewport_size.x * 0.90, 760.0, 1750.0)
	var emitter_center: Vector2 = Vector2(viewport_size.x * 0.5, stage_top + (stage_height * 0.50))
	var extents: Vector2 = Vector2(stage_width * 0.5, stage_height * 0.5)
	var layer_count: int = performance_sparkle_particles.size()
	var spread_x: float = stage_width * 0.58
	var spread_y: float = stage_height * 0.48

	for i in range(layer_count):
		var particles: CPUParticles2D = performance_sparkle_particles[i]
		if particles == null or not is_instance_valid(particles):
			continue
		var anchor: Vector2 = Vector2.ZERO
		if i < performance_particle_layer_anchors.size():
			anchor = performance_particle_layer_anchors[i]
		var lane_center: Vector2 = emitter_center + Vector2(anchor.x * spread_x, anchor.y * spread_y)
		var lane_extents: Vector2 = Vector2(
			maxf(56.0, extents.x * (0.12 + absf(anchor.x) * 0.12)),
			maxf(56.0, extents.y * (0.34 + absf(anchor.y) * 0.24))
		)
		particles.position = lane_center
		_set_node_property_if_exists(particles, &"emission_rect_extents", lane_extents)


func _layout_performance_tracers(viewport_size: Vector2) -> void:
	if performance_tracer_lines.is_empty():
		return
	if dialogue_panel == null:
		return

	var stage_top: float = maxf(50.0, performance_intro_spotlight_top_y_offset + 110.0)
	var stage_bottom: float = dialogue_panel.position.y - 14.0
	if speaker_portrait != null and is_instance_valid(speaker_portrait):
		stage_top = maxf(50.0, speaker_portrait.position.y - 110.0)
		stage_bottom = minf(stage_bottom, speaker_portrait.position.y + (speaker_portrait.size.y * 0.88))
	var stage_height: float = clampf(stage_bottom - stage_top, 210.0, 420.0)
	var stage_width: float = clampf(viewport_size.x * 0.90, 760.0, 1750.0)
	var emitter_center: Vector2 = Vector2(viewport_size.x * 0.5, stage_top + (stage_height * 0.50))
	var min_y: float = stage_top + 8.0
	var max_y: float = maxf(min_y + 8.0, stage_bottom - 10.0)
	var min_x: float = emitter_center.x - (stage_width * 0.64)
	var max_x: float = emitter_center.x + (stage_width * 0.64)

	for i in range(performance_tracer_lines.size()):
		var line: Line2D = performance_tracer_lines[i]
		if line == null or not is_instance_valid(line):
			continue
		if i >= performance_tracer_histories.size():
			continue
		var history: Array = performance_tracer_histories[i]
		if history.is_empty():
			continue
		if history[0] == Vector2.ZERO:
			var start := Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
			for p in range(history.size()):
				history[p] = start
		else:
			for p in range(history.size()):
				var hp: Vector2 = history[p]
				history[p] = Vector2(clampf(hp.x, min_x, max_x), clampf(hp.y, min_y, max_y))
		line.points = PackedVector2Array(history)


func _set_performance_tracers_enabled(enabled: bool) -> void:
	for line in performance_tracer_lines:
		if line == null or not is_instance_valid(line):
			continue
		line.visible = enabled
		if not enabled:
			line.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _set_performance_particles_enabled(enabled: bool) -> void:
	if not enabled:
		for i in range(performance_particle_layer_strengths.size()):
			performance_particle_layer_strengths[i] = 0.0
	for particles in performance_sparkle_particles:
		if particles == null or not is_instance_valid(particles):
			continue
		particles.emitting = enabled
		if not enabled:
			particles.modulate.a = 0.0
		else:
			particles.modulate.a = maxf(particles.modulate.a, 0.01)
	_set_performance_tracers_enabled(enabled and performance_tracer_enabled)


func _update_performance_particles(live_intensity: float, delta: float) -> void:
	if performance_sparkle_particles.is_empty():
		return
	if dialogue_panel == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var stage_top: float = maxf(50.0, performance_intro_spotlight_top_y_offset + 110.0)
	var stage_bottom: float = dialogue_panel.position.y - 14.0
	if speaker_portrait != null and is_instance_valid(speaker_portrait):
		stage_top = maxf(50.0, speaker_portrait.position.y - 110.0)
		stage_bottom = minf(stage_bottom, speaker_portrait.position.y + (speaker_portrait.size.y * 0.88))
	var stage_height: float = clampf(stage_bottom - stage_top, 210.0, 420.0)
	var stage_width: float = clampf(viewport_size.x * 0.90, 760.0, 1750.0)
	var emitter_center: Vector2 = Vector2(viewport_size.x * 0.5, stage_top + (stage_height * 0.50))
	var extents: Vector2 = Vector2(stage_width * 0.5, stage_height * 0.5)
	var spread_x: float = stage_width * 0.58
	var spread_y: float = stage_height * 0.48

	var intensity: float = clampf(live_intensity, 0.0, 1.0)
	var response: float = pow(intensity, maxf(0.05, performance_particle_intensity_response))
	var base_alpha: float = clampf(performance_particle_base_alpha, 0.0, 1.0)
	var max_alpha: float = clampf(maxf(base_alpha, performance_particle_max_alpha), 0.0, 1.0)
	var spiral_speed: float = maxf(0.0, performance_particle_spiral_speed)
	var spiral_radius_x: float = maxf(0.0, performance_particle_spiral_radius_x)
	var spiral_radius_y: float = maxf(0.0, performance_particle_spiral_radius_y)
	var spiral_intensity_scale: float = maxf(0.0, performance_particle_spiral_intensity_scale)
	var layer_count: int = performance_sparkle_particles.size()

	for i in range(layer_count):
		var particles: CPUParticles2D = performance_sparkle_particles[i]
		if particles == null or not is_instance_valid(particles):
			continue

		var anchor: Vector2 = Vector2.ZERO
		if i < performance_particle_layer_anchors.size():
			anchor = performance_particle_layer_anchors[i]
		var drift_speed: Vector2 = Vector2(1.0, 1.0)
		if i < performance_particle_layer_drift_speeds.size():
			drift_speed = performance_particle_layer_drift_speeds[i]
		var phase: float = 0.0
		if i < performance_particle_layer_phases.size():
			phase = performance_particle_layer_phases[i]

		# Slowly meander each anchor so the whole field feels alive and less "set in place".
		anchor += Vector2(
			sin((performance_time_accum * 0.11) + phase * 0.91) * maxf(0.0, delta) * 0.09,
			cos((performance_time_accum * 0.13) + phase * 1.17) * maxf(0.0, delta) * 0.07
		)
		anchor.x = clampf(anchor.x, -1.0, 1.0)
		anchor.y = clampf(anchor.y, -0.95, 0.86)
		if i < performance_particle_layer_anchors.size():
			performance_particle_layer_anchors[i] = anchor

		var edge_penalty: float = clampf(anchor.length() * 0.06, 0.0, 0.09)
		var lane_floor: float = 0.30 + (response * 0.22)
		var lane_intensity_target: float = clampf((response * 1.26) - edge_penalty, lane_floor, 1.0)
		var lane_intensity: float = lane_intensity_target
		if i < performance_particle_layer_strengths.size():
			var current_strength: float = performance_particle_layer_strengths[i]
			var rise: float = maxf(0.05, performance_particle_strength_attack) * maxf(0.0, delta)
			var fall: float = maxf(0.05, performance_particle_strength_release) * maxf(0.0, delta)
			if lane_intensity_target >= current_strength:
				lane_intensity = move_toward(current_strength, lane_intensity_target, rise)
			else:
				lane_intensity = move_toward(current_strength, lane_intensity_target, fall)
			performance_particle_layer_strengths[i] = lane_intensity
		particles.emitting = true
		var tip_boost_norm: float = _get_tip_boost_normalized()
		var tip_density_boost: float = clampf(
			tip_boost_norm * maxf(0.0, performance_tip_particle_density_boost + 0.16),
			0.0,
			0.90
		)
		var amount_ratio: float = clampf(lerpf(0.44, 1.00, lane_intensity) + tip_density_boost, 0.10, 1.00)
		_set_node_property_if_exists(particles, &"amount_ratio", amount_ratio)
		particles.speed_scale = lerpf(1.05, 2.15, lane_intensity)
		particles.spread = lerpf(186.0, 152.0, lane_intensity)
		particles.gravity = Vector2(0.0, lerpf(-1.8, -5.9, lane_intensity))
		_set_node_property_if_exists(particles, &"initial_velocity_min", lerpf(17.0, 34.0, lane_intensity))
		_set_node_property_if_exists(particles, &"initial_velocity_max", lerpf(33.0, 60.0, lane_intensity))
		var beat_scale_pulse: float = 0.5 + (0.5 * sin((performance_time_accum * (3.4 + drift_speed.x * 0.6)) + phase))
		var size_boost: float = 1.0 + (lane_intensity * (0.20 + 0.28 * beat_scale_pulse))
		_set_node_property_if_exists(particles, &"scale_amount_min", 0.12 * size_boost)
		_set_node_property_if_exists(particles, &"scale_amount_max", 0.32 * (1.0 + lane_intensity * (0.40 + 0.35 * beat_scale_pulse)))

		var tint: Color = _get_particle_palette_color(i)
		var alpha_pulse_boost: float = 1.0 + (lane_intensity * 0.95) + (beat_scale_pulse * 0.28)
		var alpha: float = clampf(
			lerpf(base_alpha, max_alpha, lane_intensity) * alpha_pulse_boost * (1.0 + tip_boost_norm * 0.50),
			0.0,
			0.64
		)
		var luma: float = (tint.r + tint.g + tint.b) / 3.0
		var saturation_boost: float = 1.35 + (1.20 * lane_intensity)
		var value_boost: float = lerpf(1.02, 1.68, lane_intensity)
		var vivid_r: float = clampf((luma + (tint.r - luma) * saturation_boost) * value_boost, 0.0, 1.0)
		var vivid_g: float = clampf((luma + (tint.g - luma) * saturation_boost) * value_boost, 0.0, 1.0)
		var vivid_b: float = clampf((luma + (tint.b - luma) * saturation_boost) * value_boost, 0.0, 1.0)
		particles.modulate = Color(vivid_r, vivid_g, vivid_b, alpha)

		var lane_center: Vector2 = emitter_center + Vector2(anchor.x * spread_x, anchor.y * spread_y)
		var lane_extents: Vector2 = Vector2(
			maxf(56.0, extents.x * lerpf(0.12, 0.24, lane_intensity)),
			maxf(56.0, extents.y * lerpf(0.34, 0.72, lane_intensity))
		)

		var motion_phase: float = (performance_time_accum * maxf(0.08, spiral_speed)) + phase
		var spiral_strength: float = clampf(lane_intensity * spiral_intensity_scale, 0.0, 0.40)
		var lane_wander_strength: float = lerpf(1.35, 3.25, lane_intensity)
		var lane_seed: float = phase + float(i) * 0.47
		var swirl_gate_raw: float = sin(
			(performance_time_accum * (0.11 + drift_speed.x * 0.17))
			+ (phase * 2.31)
			+ (anchor.y * 3.0)
		)
		var swirl_gate: float = clampf(0.5 + (0.5 * swirl_gate_raw), 0.0, 1.0)
		var swirl_burst: float = clampf(swirl_gate * (0.04 + (lane_intensity * 0.12)), 0.0, 0.16)
		var orbit_mag: float = lerpf(0.0, 7.0, swirl_burst)
		var wander_x: float = (
			sin((performance_time_accum * (0.95 + drift_speed.x * 0.42)) + lane_seed * 0.63) * 92.0
			+ cos((performance_time_accum * (0.55 + drift_speed.x * 0.31)) + lane_seed * 1.11) * 70.0
			+ sin((performance_time_accum * (1.85 + drift_speed.x * 0.24)) + lane_seed * 2.07) * 38.0
		)
		var wander_y: float = (
			cos((performance_time_accum * (0.88 + drift_speed.y * 0.36)) + lane_seed * 0.91) * 58.0
			+ sin((performance_time_accum * (0.47 + drift_speed.y * 0.28)) + lane_seed * 1.73) * 46.0
			+ cos((performance_time_accum * (1.36 + drift_speed.y * 0.22)) + lane_seed * 2.39) * 28.0
		)
		var micro_x: float = sin((motion_phase * 1.27) + lane_seed * 0.8) * spiral_radius_x * spiral_strength * 0.75
		var micro_y: float = cos((motion_phase * 0.93) + lane_seed * 1.2) * spiral_radius_y * spiral_strength * 0.75
		particles.rotation = 0.0
		var min_y: float = stage_top + 8.0
		var max_y: float = maxf(min_y + 8.0, stage_bottom - 10.0)
		var min_x: float = emitter_center.x - (stage_width * 0.64)
		var max_x: float = emitter_center.x + (stage_width * 0.64)
		var target_position: Vector2 = lane_center + Vector2(
			(wander_x * lane_wander_strength) + micro_x,
			(wander_y * lane_wander_strength) + micro_y
		)
		particles.position = Vector2(
			clampf(target_position.x, min_x, max_x),
			clampf(target_position.y, min_y, max_y)
		)
		_set_node_property_if_exists(particles, &"emission_rect_extents", lane_extents)
		# Symmetric range gives per-particle swirl variation instead of whole-batch spinning.
		_set_node_property_if_exists(particles, &"orbit_velocity_min", -orbit_mag * 0.80)
		_set_node_property_if_exists(particles, &"orbit_velocity_max", orbit_mag * 0.80)

		var flow: Vector2 = Vector2(
			(cos((performance_time_accum * (0.95 + drift_speed.x * 0.42)) + lane_seed * 0.63) * (0.95 + drift_speed.x * 0.42) * 92.0)
			- (sin((performance_time_accum * (0.55 + drift_speed.x * 0.31)) + lane_seed * 1.11) * (0.55 + drift_speed.x * 0.31) * 70.0)
			+ (cos((performance_time_accum * (1.85 + drift_speed.x * 0.24)) + lane_seed * 2.07) * (1.85 + drift_speed.x * 0.24) * 38.0),
			-(sin((performance_time_accum * (0.88 + drift_speed.y * 0.36)) + lane_seed * 0.91) * (0.88 + drift_speed.y * 0.36) * 58.0)
			+ (cos((performance_time_accum * (0.47 + drift_speed.y * 0.28)) + lane_seed * 1.73) * (0.47 + drift_speed.y * 0.28) * 46.0)
			- (sin((performance_time_accum * (1.36 + drift_speed.y * 0.22)) + lane_seed * 2.39) * (1.36 + drift_speed.y * 0.22) * 28.0)
		)
		var up: Vector2 = Vector2(anchor.x * 0.35, -1.0).normalized()
		var swirl_mix: float = clampf(0.10 + (lane_intensity * 0.10) + (swirl_burst * 0.10), 0.08, 0.24)
		var orbit_tangent: Vector2 = Vector2(-up.y, up.x)
		if flow.length_squared() > 0.0001:
			var flow_dir: Vector2 = flow.normalized()
			var swirl_dir: Vector2 = (flow_dir + (orbit_tangent * swirl_burst * 0.35)).normalized()
			particles.direction = (up * (1.0 - swirl_mix) + swirl_dir * swirl_mix).normalized()
		else:
			particles.direction = up

	_update_performance_tracers(intensity, delta, stage_top, stage_bottom, emitter_center, stage_width)


func _update_performance_tracers(live_intensity: float, delta: float, stage_top: float, stage_bottom: float, emitter_center: Vector2, stage_width: float) -> void:
	if performance_tracer_lines.is_empty():
		return
	if not performance_tracer_enabled:
		return
	var min_y: float = stage_top + 8.0
	var max_y: float = maxf(min_y + 8.0, stage_bottom - 10.0)
	var min_x: float = emitter_center.x - (stage_width * 0.64)
	var max_x: float = emitter_center.x + (stage_width * 0.64)
	var intensity: float = clampf(live_intensity, 0.0, 1.0)
	var tracer_points: int = clampi(performance_tracer_points, 3, 28)
	var base_alpha: float = clampf(performance_tracer_base_alpha, 0.0, 1.0)
	var max_alpha: float = clampf(maxf(base_alpha, performance_tracer_max_alpha), 0.0, 1.0)
	var base_visible_count: int = clampi(performance_tracer_count, 0, performance_tracer_lines.size())
	var extra_count: int = maxi(0, performance_tip_extra_tracer_count)
	var tip_boost_norm: float = _get_tip_boost_normalized()
	var boosted_visible_count: int = clampi(base_visible_count + int(round(float(extra_count) * tip_boost_norm)), 0, performance_tracer_lines.size())

	for i in range(performance_tracer_lines.size()):
		var line: Line2D = performance_tracer_lines[i]
		if line == null or not is_instance_valid(line):
			continue
		if i >= boosted_visible_count:
			line.visible = false
			line.modulate.a = 0.0
			continue
		if i >= performance_tracer_histories.size():
			continue
		var history: Array = performance_tracer_histories[i]
		if history.is_empty():
			continue
		if history[0] == Vector2.ZERO:
			var seed_pos := Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
			for p in range(history.size()):
				history[p] = seed_pos

		var phase: float = 0.0
		if i < performance_tracer_phases.size():
			phase = performance_tracer_phases[i]
		var velocity: Vector2 = Vector2.ZERO
		if i < performance_tracer_velocities.size():
			velocity = performance_tracer_velocities[i]

		var pulse: float = 0.5 + (0.5 * sin((performance_time_accum * (3.2 + float(i % 3) * 0.2)) + phase))
		var target_velocity := Vector2(
			sin((performance_time_accum * (1.00 + float(i % 5) * 0.08)) + phase * 1.31) * lerpf(45.0, 150.0, intensity),
			cos((performance_time_accum * (0.82 + float(i % 4) * 0.07)) + phase * 1.77) * lerpf(36.0, 120.0, intensity)
		)
		var head_pos: Vector2 = history[0]
		var center_delta: Vector2 = emitter_center - head_pos
		var center_pull: Vector2 = center_delta.normalized() * maxf(0.0, center_delta.length() - (stage_width * 0.52)) * 0.20
		target_velocity += center_pull
		velocity = velocity.lerp(target_velocity, clampf(maxf(0.0, delta) * (1.8 + intensity * 1.4), 0.0, 1.0))
		var next_pos: Vector2 = head_pos + (velocity * maxf(0.0, delta))

		if next_pos.x < min_x or next_pos.x > max_x:
			velocity.x *= -0.72
			next_pos.x = clampf(next_pos.x, min_x, max_x)
		if next_pos.y < min_y or next_pos.y > max_y:
			velocity.y *= -0.72
			next_pos.y = clampf(next_pos.y, min_y, max_y)

		history.insert(0, next_pos)
		while history.size() > tracer_points:
			history.pop_back()

		if i < performance_tracer_velocities.size():
			performance_tracer_velocities[i] = velocity

		var tint: Color = _get_particle_palette_color(i)
		var luma: float = (tint.r + tint.g + tint.b) / 3.0
		var saturation_boost: float = 1.30 + (0.95 * intensity)
		var value_boost: float = lerpf(1.02, 1.56, intensity)
		var vivid_r: float = clampf((luma + (tint.r - luma) * saturation_boost) * value_boost, 0.0, 1.0)
		var vivid_g: float = clampf((luma + (tint.g - luma) * saturation_boost) * value_boost, 0.0, 1.0)
		var vivid_b: float = clampf((luma + (tint.b - luma) * saturation_boost) * value_boost, 0.0, 1.0)
		var alpha: float = clampf(
			lerpf(base_alpha, max_alpha, intensity) * (0.72 + pulse * 0.38) * (1.0 + tip_boost_norm * 0.55),
			0.0,
			0.56
		)

		line.visible = true
		line.width = lerpf(0.9, 2.0, intensity) * lerpf(0.90, 1.12, pulse) * (1.0 + tip_boost_norm * 0.16)
		line.modulate = Color(vivid_r, vivid_g, vivid_b, alpha)
		line.points = PackedVector2Array(history)


func _update_live_performance_scene_dimmer(live_intensity: float) -> void:
	if scene_dimmer == null:
		return
	var base_alpha: float = _get_target_scene_dimmer_alpha()
	var power: float = maxf(0.05, performance_scene_dim_intensity_power)
	var intensity: float = pow(clampf(live_intensity, 0.0, 1.0), power)
	var boost: float = maxf(0.0, performance_scene_dim_intensity_boost) * intensity
	var target_alpha: float = clampf(base_alpha + boost, 0.0, 1.0)
	var base_color: Color = scene_dimmer.color
	scene_dimmer.color = Color(base_color.r, base_color.g, base_color.b, target_alpha)


func _layout_band_member_portraits(viewport_size: Vector2) -> void:
	if band_member_portraits.is_empty() or speaker_portrait == null:
		return

	var member_size := _get_effective_band_member_size()
	var member_spacing := maxf(_get_effective_band_member_spacing(), member_size.x * 1.02)
	var member_x_offset := _get_effective_band_member_x_offset() + maxf(0.0, performance_band_member_gap_from_lysander)
	var member_y_step := _get_effective_band_member_y_step()
	var center_x := speaker_portrait.position.x + (speaker_portrait.size.x * 0.5)
	var half_lysander := speaker_portrait.size.x * 0.5
	var half_member := member_size.x * 0.5
	var start_y := dialogue_panel.position.y - member_size.y + performance_band_member_panel_overlap + performance_stage_y_offset
	var max_x := viewport_size.x - member_size.x - 20.0

	var total_members := band_member_portraits.size()
	var left_count := int(floor(float(total_members) * 0.5))
	var right_count := total_members - left_count
	var left_indices: Array[int] = []
	var right_indices: Array[int] = []
	for i in range(total_members):
		if i < left_count:
			left_indices.append(i)
		else:
			right_indices.append(i)

	for i in range(band_member_portraits.size()):
		var member := band_member_portraits[i]
		if member == null or not is_instance_valid(member):
			continue
		member.size = member_size
		member.custom_minimum_size = member_size

		var side := 1.0
		var rank := 0
		var side_count := right_count
		if i < left_count:
			side = -1.0
			rank = left_indices.find(i)
			side_count = left_count
		else:
			rank = right_indices.find(i)
			side_count = right_count
		if rank < 0:
			rank = 0

		# Spread each side from near Lysander to farther out, with small vertical staggering.
		var slot_offset := half_lysander + half_member + member_x_offset + (float(rank) * member_spacing)
		var px := clampf(center_x + (side * slot_offset) - half_member, 20.0, max_x)
		var vertical_center_shift := (float(rank) - (float(max(1, side_count - 1)) * 0.5))
		var py := start_y + (vertical_center_shift * member_y_step)
		member.position = Vector2(px, py)

		if i >= band_member_base_positions.size():
			band_member_base_positions.append(member.position)
			band_member_base_scales.append(member.scale)
			band_member_base_modulates.append(member.modulate)
		else:
			band_member_base_positions[i] = member.position
			band_member_base_scales[i] = member.scale
			band_member_base_modulates[i] = member.modulate

		if i < band_member_spotlights.size():
			var spotlight := band_member_spotlights[i]
			if spotlight != null and is_instance_valid(spotlight):
				var beam_width := maxf(80.0, performance_intro_spotlight_width)
				var top_y := performance_intro_spotlight_top_y_offset
				var spotlight_bottom_y := maxf(
					dialogue_panel.position.y + performance_band_member_panel_overlap + 24.0,
					member.position.y + (member.size.y * 0.86)
				)
				var beam_height := maxf(140.0, spotlight_bottom_y - top_y)
				var beam_center_x := member.position.x + (member.size.x * 0.5)
				_apply_spotlight_geometry(
					spotlight,
					beam_center_x,
					top_y,
					beam_width,
					beam_height,
					performance_intro_spotlight_color
				)


func _apply_spotlight_geometry(spotlight: Polygon2D, center_x: float, top_y: float, beam_width: float, beam_height: float, tint: Color) -> void:
	if spotlight == null or not is_instance_valid(spotlight):
		return
	var half_width := maxf(40.0, beam_width * 0.5)
	var height := maxf(120.0, beam_height)
	var tint_color := Color(clampf(tint.r, 0.0, 1.0), clampf(tint.g, 0.0, 1.0), clampf(tint.b, 0.0, 1.0), 1.0)
	spotlight.position = Vector2(center_x, top_y)
	spotlight.polygon = PackedVector2Array([
		Vector2(-half_width * 0.10, 0.0),
		Vector2(half_width * 0.10, 0.0),
		Vector2(half_width * 0.68, height * 0.60),
		Vector2(half_width * 1.00, height),
		Vector2(-half_width * 1.00, height),
		Vector2(-half_width * 0.68, height * 0.60)
	])
	spotlight.vertex_colors = PackedColorArray([
		Color(tint_color.r, tint_color.g, tint_color.b, 0.00),
		Color(tint_color.r, tint_color.g, tint_color.b, 0.00),
		Color(tint_color.r, tint_color.g, tint_color.b, 0.24),
		Color(tint_color.r, tint_color.g, tint_color.b, 0.00),
		Color(tint_color.r, tint_color.g, tint_color.b, 0.00),
		Color(tint_color.r, tint_color.g, tint_color.b, 0.24)
	])


func _refresh_speaker_portrait_visibility() -> void:
	if speaker_portrait == null:
		return

	if dialogue_panel != null:
		dialogue_panel.visible = current_state != State.PERFORMANCE_TITLECARD

	var show_portrait: bool = (
		current_state == State.DIALOGUE_INTRO
		or current_state == State.PERFORMANCE_ACTIVE
		or current_state == State.PERFORMANCE_OUTRO
		or current_state == State.DIALOGUE_OUTRO_WIN
		or current_state == State.DIALOGUE_OUTRO_LOSE
		or current_state == State.DIALOGUE_POST_ALL_TIERS
	)
	speaker_portrait.visible = show_portrait

	if dialogue_text != null:
		dialogue_text.offset_left = dialogue_text_left_padding_with_portrait if show_portrait else dialogue_text_left_padding_no_portrait

	var show_band: bool = (
		current_state == State.PERFORMANCE_ACTIVE
		or current_state == State.PERFORMANCE_OUTRO
	)
	for member in band_member_portraits:
		if member != null and is_instance_valid(member):
			member.visible = show_band

	if performance_close_button != null:
		var show_close: bool = (
			current_state == State.PERFORMANCE_INTRO
			or current_state == State.PERFORMANCE_ACTIVE
			or current_state == State.PERFORMANCE_OUTRO
		)
		performance_close_button.visible = show_close
	if performance_tip_button != null:
		var show_tip: bool = current_state == State.PERFORMANCE_ACTIVE
		performance_tip_button.visible = show_tip
	if performance_tip_fx_layer != null and is_instance_valid(performance_tip_fx_layer):
		performance_tip_fx_layer.visible = current_state == State.PERFORMANCE_ACTIVE
	_update_tip_button_state()


func _get_week_token() -> int:
	if CampaignManager == null:
		return 0
	# Performance rotation resets per cleared story level.
	# CampaignManager.camp_request_progress_level increments only when a level is cleared.
	if CampaignManager.has_method("get"):
		return int(CampaignManager.get("camp_request_progress_level"))
	return int(CampaignManager.max_unlocked_index)


func _get_week_flag_key() -> String:
	return LYSANDER_WEEKLY_SETLIST_FLAG_PREFIX + str(_get_week_token())


func _has_performed_this_week() -> bool:
	if CampaignManager == null:
		return false
	if not CampaignManager.encounter_flags is Dictionary:
		return false
	return bool(CampaignManager.encounter_flags.get(_get_week_flag_key(), false))


func _mark_performed_this_week() -> void:
	if CampaignManager == null:
		return
	if not CampaignManager.encounter_flags is Dictionary:
		CampaignManager.encounter_flags = {}
	CampaignManager.encounter_flags[_get_week_flag_key()] = true
	if CampaignManager.has_method("save_current_progress"):
		CampaignManager.save_current_progress()


func _collect_setlist_entries() -> Array:
	# Dedicated private setlist for Performance Night.
	# Uses the same disc mechanics as jukebox authoring (track_title / track_lyrics / unlocked_music_track),
	# but does NOT depend on player jukebox unlock ownership.
	var entries: Array = []
	var seen_paths: Dictionary = {}

	for disc in performance_setlist_discs:
		if disc == null or disc.unlocked_music_track == null:
			continue
		var track_path := str(disc.unlocked_music_track.resource_path).strip_edges()
		if track_path != "" and seen_paths.has(track_path):
			continue
		var title: String = str(disc.track_title).strip_edges()
		if title == "":
			title = str(disc.item_name).strip_edges()
		if title == "":
			title = "Lysander Setlist"
		entries.append({
			"title": title,
			"stream": disc.unlocked_music_track,
			"lyrics": str(disc.track_lyrics),
			"track_path": track_path
		})
		if track_path != "":
			seen_paths[track_path] = true

	return entries


func _infer_track_energy(title: String, lyrics: String) -> float:
	var lower_title := title.to_lower()
	var lower_lyrics := lyrics.to_lower()
	var energy: float = 0.55

	if lower_title.find("villain") != -1 or lower_title.find("duelist") != -1:
		energy += 0.20
	if lower_title.find("hero") != -1 or lower_title.find("epic") != -1:
		energy += 0.15
	if lower_title.find("rustic") != -1 or lower_title.find("overworld") != -1:
		energy -= 0.10
	if lower_lyrics.find("fire") != -1 or lower_lyrics.find("storm") != -1:
		energy += 0.10

	return clampf(energy, 0.25, 1.0)


func _select_weekly_setlist_entry() -> Dictionary:
	var entries: Array = _collect_setlist_entries()
	if entries.is_empty():
		return {}
	var week: int = max(0, _get_week_token())
	var idx: int = week % entries.size()
	return entries[idx]


func _should_start_weekly_performance() -> bool:
	var entry: Dictionary = _select_weekly_setlist_entry()
	if entry.is_empty():
		return false

	match interaction_mode:
		InteractionMode.QTE_ONLY:
			return false
		InteractionMode.PERFORMANCE_ONLY:
			return true
		InteractionMode.AUTO_WEEKLY_PERFORMANCE:
			if not weekly_performance_requires_new_week:
				return true
			return not _has_performed_this_week()
		_:
			return false


func _show_performance_intro_dialogue() -> void:
	var entry: Dictionary = _select_weekly_setlist_entry()
	if entry.is_empty():
		_show_performance_unavailable_dialogue()
		return

	current_state = State.PERFORMANCE_TITLECARD
	_sync_layout_for_state()
	_fade_stage_backdrop_out(true)
	_refresh_speaker_portrait_visibility()
	performance_track_title = str(entry.get("title", "Lysander Setlist"))
	dialogue_text.text = ""
	_show_blackout_titlecard_and_start()


func _show_performance_cooldown_dialogue() -> void:
	current_state = State.PERFORMANCE_OUTRO
	_sync_layout_for_state()
	_fade_stage_backdrop_out()
	_refresh_speaker_portrait_visibility()
	dialogue_text.text = "[font_size=%d][color=cyan]Lysander:[/color] Tonight's set is already done. Clear another level and I'll play a new piece.[/font_size]\n\n[font_size=%d][color=gray][i]%s[/i][/color][/font_size]" % [
		dialogue_font_size,
		dialogue_font_size - 10,
		performance_close_hint_text
	]


func _show_performance_unavailable_dialogue() -> void:
	current_state = State.PERFORMANCE_OUTRO
	_sync_layout_for_state()
	_fade_stage_backdrop_out()
	_refresh_speaker_portrait_visibility()
	dialogue_text.text = "[font_size=%d][color=cyan]Lysander:[/color] The stage is closed tonight. No private setlist is prepared yet.[/font_size]\n\n[font_size=%d][color=gray][i]%s[/i][/color][/font_size]" % [
		dialogue_font_size,
		dialogue_font_size - 10,
		performance_close_hint_text
	]


func _start_performance_night() -> void:
	var entry: Dictionary = _select_weekly_setlist_entry()
	if entry.is_empty():
		_close_interaction()
		return

	var stream: AudioStream = entry.get("stream")
	if stream == null or performance_player == null:
		_close_interaction()
		return

	performance_track_title = str(entry.get("title", "Lysander Setlist"))
	var lyrics_raw: String = str(entry.get("lyrics", ""))
	performance_energy = _infer_track_energy(performance_track_title, lyrics_raw)
	performance_lines.clear()
	performance_line_times = PackedFloat32Array()
	performance_current_line_index = -1
	performance_track_length = max(1.0, stream.get_length())

	for raw_line in lyrics_raw.split("\n"):
		var line := raw_line.strip_edges()
		if line != "":
			performance_lines.append(line)

	var line_count: int = performance_lines.size()
	performance_line_times.resize(line_count)
	for i in range(line_count):
		var t := (float(i) / float(max(1, line_count))) * performance_track_length
		performance_line_times[i] = t

	current_state = State.PERFORMANCE_INTRO
	_sync_layout_for_state()
	_fade_stage_backdrop_in()
	_refresh_speaker_portrait_visibility()
	_mark_performed_this_week()

	if speaker_portrait != null:
		if performance_lysander_texture != null:
			speaker_portrait.texture = performance_lysander_texture
		elif portrait_default_texture != null:
			speaker_portrait.texture = portrait_default_texture
		portrait_base_scale = speaker_portrait.scale
		portrait_base_position = speaker_portrait.position
		portrait_base_modulate = speaker_portrait.modulate

	_lock_stage_portrait_baseline_for_intro()

	_duck_tavern_music_for_performance()
	_prepare_performance_visual_state()
	await _play_band_member_intro_stagger()
	await _play_lysander_intro_fade()
	if current_state != State.PERFORMANCE_INTRO or ui_layer == null or not ui_layer.visible:
		return

	current_state = State.PERFORMANCE_ACTIVE
	_sync_layout_for_state()
	_refresh_speaker_portrait_visibility()
	_fade_out_intro_spotlights()
	_set_performance_particles_enabled(performance_particles_enabled)

	performance_player.stop()
	performance_player.stream = stream
	performance_bus_index = AudioServer.get_bus_index(performance_player.bus)
	performance_audio_level_smoothed = 0.0
	performance_audio_level_secondary = 0.0
	if performance_music_tween != null and performance_music_tween.is_valid():
		performance_music_tween.kill()
	performance_player.volume_db = performance_music_fade_in_start_db
	performance_player.play()
	if performance_music_fade_in_time <= 0.01:
		performance_player.volume_db = performance_music_base_db
	else:
		performance_music_tween = create_tween()
		performance_music_tween.set_trans(Tween.TRANS_SINE)
		performance_music_tween.set_ease(Tween.EASE_OUT)
		performance_music_tween.tween_property(
			performance_player,
			"volume_db",
			performance_music_base_db,
			maxf(0.05, performance_music_fade_in_time)
		)
	if performance_lines.is_empty():
		dialogue_text.text = "[font_size=%d][color=cyan]Lysander - %s[/color][/font_size]\n\n[font_size=%d][color=gray][i](Instrumental set - no lyrics)[/i][/color][/font_size]" % [
			dialogue_font_size - 4,
			performance_track_title,
			dialogue_font_size
		]
	else:
		_update_performance_lyrics()


func _play_band_member_intro_stagger() -> void:
	if band_member_portraits.is_empty():
		return
	if ui_root == null or not is_instance_valid(ui_root):
		return

	# Re-anchor all stage portraits to deterministic baseline transforms before reveal.
	_lock_stage_portrait_baseline_for_intro()

	var fade_time := maxf(0.04, performance_band_intro_fade_time)
	var stagger_time := maxf(0.0, performance_band_intro_stagger_time)

	for i in range(band_member_portraits.size()):
		var member := band_member_portraits[i]
		if member == null or not is_instance_valid(member):
			continue
		var spotlight: Polygon2D = null
		if i < band_member_spotlights.size():
			spotlight = band_member_spotlights[i]

		var base_mod := Color(1.0, 1.0, 1.0, clampf(_get_effective_band_member_alpha(), 0.0, 1.0))
		if i < band_member_base_modulates.size():
			base_mod = band_member_base_modulates[i]

		member.visible = true
		member.modulate = Color(base_mod.r, base_mod.g, base_mod.b, 0.0)
		if spotlight != null and is_instance_valid(spotlight):
			if _member_spotlight_overlaps_lysander(member):
				spotlight.visible = false
				spotlight.modulate.a = 0.0
			else:
				spotlight.visible = true
				spotlight.modulate = Color(1.0, 1.0, 1.0, 0.0)

		var intro_tween := create_tween()
		intro_tween.set_trans(Tween.TRANS_SINE)
		intro_tween.set_ease(Tween.EASE_OUT)
		intro_tween.parallel().tween_property(member, "modulate:a", base_mod.a, fade_time)
		if spotlight != null and is_instance_valid(spotlight) and spotlight.visible:
			var spot_alpha := clampf(performance_intro_spotlight_alpha, 0.0, 1.0)
			intro_tween.parallel().tween_property(spotlight, "modulate:a", spot_alpha, fade_time)
		await intro_tween.finished

		if stagger_time > 0.0 and i < band_member_portraits.size() - 1:
			await get_tree().create_timer(stagger_time).timeout


func _member_spotlight_overlaps_lysander(member: TextureRect) -> bool:
	if member == null or not is_instance_valid(member):
		return false
	if speaker_portrait == null or not is_instance_valid(speaker_portrait):
		return false
	var member_center_x := member.position.x + (member.size.x * 0.5)
	var lysander_center_x := speaker_portrait.position.x + (speaker_portrait.size.x * 0.5)
	var overlap_threshold := maxf(36.0, speaker_portrait.size.x * 0.45)
	return absf(member_center_x - lysander_center_x) <= overlap_threshold


func _fade_out_intro_spotlights() -> void:
	if performance_spotlight_tween != null and performance_spotlight_tween.is_valid():
		performance_spotlight_tween.kill()
	performance_spotlight_tween = create_tween()
	performance_spotlight_tween.set_trans(Tween.TRANS_SINE)
	performance_spotlight_tween.set_ease(Tween.EASE_IN_OUT)
	var fade_time := maxf(0.05, performance_intro_spotlight_fade_out_time)
	var has_visible_spotlight := false
	for spotlight in band_member_spotlights:
		if spotlight == null or not is_instance_valid(spotlight) or not spotlight.visible:
			continue
		has_visible_spotlight = true
		performance_spotlight_tween.parallel().tween_property(spotlight, "modulate:a", 0.0, fade_time)
	if lysander_spotlight != null and is_instance_valid(lysander_spotlight) and lysander_spotlight.visible:
		has_visible_spotlight = true
		performance_spotlight_tween.parallel().tween_property(lysander_spotlight, "modulate:a", 0.0, fade_time)
	if has_visible_spotlight:
		performance_spotlight_tween.tween_interval(fade_time)
	performance_spotlight_tween.tween_callback(Callable(self, "_hide_intro_spotlights_now"))


func _hide_intro_spotlights_now() -> void:
	for spotlight in band_member_spotlights:
		if spotlight == null or not is_instance_valid(spotlight):
			continue
		spotlight.hide()
		spotlight.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if lysander_spotlight != null and is_instance_valid(lysander_spotlight):
		lysander_spotlight.hide()
		lysander_spotlight.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _lock_stage_portrait_baseline_for_intro() -> void:
	# Keep intro starts visually stable across repeated performances.
	_layout_dynamic_ui()

	if speaker_portrait != null and is_instance_valid(speaker_portrait):
		speaker_portrait.scale = Vector2.ONE
		speaker_portrait.pivot_offset = speaker_portrait.size * 0.5
		speaker_portrait.position = Vector2(round(speaker_portrait.position.x), round(speaker_portrait.position.y))
		portrait_base_scale = speaker_portrait.scale
		portrait_base_position = speaker_portrait.position
		portrait_base_modulate = speaker_portrait.modulate

	for i in range(band_member_portraits.size()):
		var member := band_member_portraits[i]
		if member == null or not is_instance_valid(member):
			continue
		member.scale = Vector2.ONE
		member.position = Vector2(round(member.position.x), round(member.position.y))

		if i >= band_member_base_positions.size():
			band_member_base_positions.append(member.position)
			band_member_base_scales.append(member.scale)
			band_member_base_modulates.append(member.modulate)
		else:
			band_member_base_positions[i] = member.position
			band_member_base_scales[i] = member.scale
			band_member_base_modulates[i] = member.modulate


func _play_lysander_intro_fade() -> void:
	if speaker_portrait == null or not is_instance_valid(speaker_portrait):
		return
	var base_mod := portrait_base_modulate if portrait_base_modulate.a > 0.0 else Color(1.0, 1.0, 1.0, 1.0)
	speaker_portrait.visible = true
	speaker_portrait.modulate = Color(base_mod.r, base_mod.g, base_mod.b, 0.0)
	if lysander_spotlight != null and is_instance_valid(lysander_spotlight):
		lysander_spotlight.visible = true
		lysander_spotlight.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var fade_time := maxf(0.05, performance_lysander_intro_fade_time)
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(speaker_portrait, "modulate:a", base_mod.a, fade_time)
	if lysander_spotlight != null and is_instance_valid(lysander_spotlight):
		var spot_alpha := clampf(performance_intro_lysander_spotlight_alpha, 0.0, 1.0)
		t.parallel().tween_property(lysander_spotlight, "modulate:a", spot_alpha, fade_time)
	await t.finished


func _snap_stage_to_baseline_pose() -> void:
	if speaker_portrait != null and is_instance_valid(speaker_portrait):
		speaker_portrait.scale = portrait_base_scale
		speaker_portrait.position = portrait_base_position
		speaker_portrait.rotation = 0.0
		speaker_portrait.modulate = portrait_base_modulate
	for i in range(band_member_portraits.size()):
		var member := band_member_portraits[i]
		if member == null or not is_instance_valid(member):
			continue
		if i < band_member_base_positions.size():
			member.position = band_member_base_positions[i]
		if i < band_member_base_scales.size():
			member.scale = band_member_base_scales[i]
		if i < band_member_base_modulates.size():
			member.modulate = band_member_base_modulates[i]
		member.rotation = 0.0


func _play_finale_group_bow() -> void:
	var targets: Array[CanvasItem] = []
	if speaker_portrait != null and is_instance_valid(speaker_portrait) and speaker_portrait.visible:
		targets.append(speaker_portrait)
	for member in band_member_portraits:
		if member == null or not is_instance_valid(member) or not member.visible:
			continue
		targets.append(member)
	if targets.is_empty():
		return

	var base_positions: Array[Vector2] = []
	for node in targets:
		if node is Control:
			var ctrl := node as Control
			base_positions.append(ctrl.position)
		else:
			base_positions.append(Vector2.ZERO)

	var bow_down_tween := create_tween()
	bow_down_tween.set_trans(Tween.TRANS_SINE)
	bow_down_tween.set_ease(Tween.EASE_OUT)
	var bow_duration: float = maxf(0.05, performance_finale_bow_duration)
	var bow_angle: float = deg_to_rad(maxf(0.0, performance_finale_bow_angle_degrees))
	var bow_offset := Vector2(maxf(0.0, performance_finale_bow_shift_x), maxf(0.0, performance_finale_bow_shift_y))
	for node in targets:
		if node is Control:
			var ctrl := node as Control
			ctrl.pivot_offset = Vector2(ctrl.size.x * 0.5, ctrl.size.y * 0.92)
			bow_down_tween.parallel().tween_property(ctrl, "rotation", bow_angle, bow_duration)
			bow_down_tween.parallel().tween_property(ctrl, "position", ctrl.position + bow_offset, bow_duration)
	await bow_down_tween.finished

	var bow_hold: float = maxf(0.0, performance_finale_bow_hold_time)
	if bow_hold > 0.0:
		await get_tree().create_timer(bow_hold).timeout

	var bow_up_tween := create_tween()
	bow_up_tween.set_trans(Tween.TRANS_SINE)
	bow_up_tween.set_ease(Tween.EASE_IN_OUT)
	var bow_return_duration: float = maxf(0.05, performance_finale_bow_return_duration)
	for i in range(targets.size()):
		var node: CanvasItem = targets[i]
		if node is Control:
			var ctrl := node as Control
			var base_pos: Vector2 = Vector2.ZERO
			if i < base_positions.size():
				base_pos = base_positions[i]
			bow_up_tween.parallel().tween_property(ctrl, "rotation", 0.0, bow_return_duration)
			bow_up_tween.parallel().tween_property(ctrl, "position", base_pos, bow_return_duration)
	await bow_up_tween.finished


func _on_performance_track_finished() -> void:
	if current_state != State.PERFORMANCE_ACTIVE:
		return
	current_state = State.PERFORMANCE_OUTRO
	_sync_layout_for_state()
	_refresh_speaker_portrait_visibility()
	_restore_tavern_music_after_performance()
	_set_performance_particles_enabled(false)
	_snap_stage_to_baseline_pose()
	var bow_delay: float = maxf(0.0, performance_finale_bow_delay)
	if bow_delay > 0.0:
		await get_tree().create_timer(bow_delay).timeout
	if current_state != State.PERFORMANCE_OUTRO or ui_layer == null or not ui_layer.visible:
		return
	await _play_finale_group_bow()
	if current_state != State.PERFORMANCE_OUTRO or ui_layer == null or not ui_layer.visible:
		return
	dialogue_text.text = "[font_size=%d][color=cyan]Lysander:[/color] And that was tonight's set. Thank you for listening.[/font_size]\n\n[font_size=%d][color=gray][i]%s[/i][/color][/font_size]" % [
		dialogue_font_size,
		dialogue_font_size - 10,
		performance_close_hint_text
	]


func _update_performance_lyrics() -> void:
	if current_state != State.PERFORMANCE_ACTIVE:
		return
	if performance_player == null:
		return
	if performance_lines.is_empty():
		return

	var pos: float = performance_player.get_playback_position()
	var next_index: int = performance_current_line_index
	for i in range(performance_lines.size()):
		if pos >= performance_line_times[i]:
			next_index = i
		else:
			break

	if next_index == performance_current_line_index:
		return

	performance_current_line_index = clampi(next_index, 0, performance_lines.size() - 1)
	var current_line: String = performance_lines[performance_current_line_index]
	var next_line: String = ""
	if performance_current_line_index + 1 < performance_lines.size():
		next_line = performance_lines[performance_current_line_index + 1]

	dialogue_text.text = "[font_size=%d][color=cyan]Lysander - %s[/color][/font_size]\n\n[font_size=%d][color=gold]%s[/color][/font_size]\n\n[font_size=%d][color=gray]%s[/color][/font_size]" % [
		dialogue_font_size - 4,
		performance_track_title,
		dialogue_font_size + 2,
		current_line,
		dialogue_font_size - 6,
		next_line
	]
	_animate_lyric_card_transition()


func _resolve_tavern_music_player() -> AudioStreamPlayer:
	if tavern_music_player != null and is_instance_valid(tavern_music_player):
		return tavern_music_player
	var root := get_tree().current_scene
	if root == null:
		return null
	var direct := root.get_node_or_null("TavernMusic")
	if direct is AudioStreamPlayer:
		tavern_music_player = direct as AudioStreamPlayer
		return tavern_music_player
	var matches := root.find_children("TavernMusic", "AudioStreamPlayer", true, false)
	if matches.size() > 0 and matches[0] is AudioStreamPlayer:
		tavern_music_player = matches[0] as AudioStreamPlayer
		return tavern_music_player
	return null


func _duck_tavern_music_for_performance() -> void:
	var music := _resolve_tavern_music_player()
	if music == null:
		return
	if tavern_music_tween != null and tavern_music_tween.is_valid():
		tavern_music_tween.kill()
	tavern_music_previous_db = music.volume_db
	tavern_music_was_ducked = true
	tavern_music_tween = create_tween()
	tavern_music_tween.set_trans(Tween.TRANS_SINE)
	tavern_music_tween.set_ease(Tween.EASE_OUT)
	tavern_music_tween.tween_property(
		music,
		"volume_db",
		tavern_music_duck_db,
		maxf(0.01, tavern_music_fade_out_time)
	)


func _restore_tavern_music_after_performance() -> void:
	if not tavern_music_was_ducked:
		return
	var music := _resolve_tavern_music_player()
	tavern_music_was_ducked = false
	if music == null:
		return
	if tavern_music_tween != null and tavern_music_tween.is_valid():
		tavern_music_tween.kill()
	tavern_music_tween = create_tween()
	tavern_music_tween.set_trans(Tween.TRANS_SINE)
	tavern_music_tween.set_ease(Tween.EASE_OUT)
	tavern_music_tween.tween_property(
		music,
		"volume_db",
		tavern_music_previous_db,
		maxf(0.01, tavern_music_fade_in_time)
	)


func _prepare_performance_visual_state() -> void:
	performance_time_accum = 0.0
	performance_blink_elapsed = -1.0
	performance_pluck_impulse = 0.0
	performance_pluck_cooldown_timer = 0.0
	performance_last_live_intensity = 0.0
	performance_chorus_cooldown_timer = 0.0
	performance_flip_cooldown_timer = 0.0
	performance_facing_target_sign = 1.0
	performance_facing_visual_sign = 1.0
	performance_breakdown_low_timer = 0.0
	performance_breakdown_ready = true
	performance_peak_high_timer = 0.0
	performance_peak_cycle_timer = 0.0
	performance_tip_boost_timer = 0.0
	performance_tip_boost_strength = 0.0
	performance_tip_cooldown_timer = 0.0
	performance_tip_current_boost = 0.0
	performance_tip_reaction_timer = 0.0
	performance_tip_reaction_text = ""
	performance_twirl_cooldown_timer = 0.0
	performance_twirl_active = false
	performance_twirl_elapsed = 0.0
	performance_lean_back_active = false
	performance_lean_back_elapsed = 0.0
	performance_lean_back_direction = -1.0
	performance_member_accent_cooldown_timer = 0.0
	performance_member_last_accent_index = -1
	_sync_member_accent_buffers()
	for i in range(performance_member_accent_timers.size()):
		performance_member_accent_timers[i] = 0.0
	if lyric_fade_tween != null and lyric_fade_tween.is_valid():
		lyric_fade_tween.kill()
	if dialogue_text != null:
		dialogue_text.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if performance_tip_fx_layer != null and is_instance_valid(performance_tip_fx_layer):
		for child in performance_tip_fx_layer.get_children():
			child.queue_free()
		performance_tip_fx_layer.hide()
	_update_tip_button_state()
	_set_performance_particles_enabled(false)
	for i in range(band_member_portraits.size()):
		var member := band_member_portraits[i]
		if member == null or not is_instance_valid(member):
			continue
		if i >= band_member_base_positions.size():
			band_member_base_positions.append(member.position)
			band_member_base_scales.append(member.scale)
			band_member_base_modulates.append(member.modulate)
		else:
			band_member_base_positions[i] = member.position
			band_member_base_scales[i] = member.scale
			band_member_base_modulates[i] = member.modulate
	performance_zoom_node = _resolve_performance_zoom_node()
	if performance_zoom_node != null:
		performance_zoom_base_scale = performance_zoom_node.scale
		performance_zoom_base_position = performance_zoom_node.position
		if performance_zoom_node is Control:
			var zoom_ctrl := performance_zoom_node as Control
			zoom_ctrl.pivot_offset = zoom_ctrl.size * 0.5
	_schedule_next_performance_blink()


func _reset_performance_visual_state() -> void:
	if lyric_fade_tween != null and lyric_fade_tween.is_valid():
		lyric_fade_tween.kill()
	if performance_intro_tween != null and performance_intro_tween.is_valid():
		performance_intro_tween.kill()
	if performance_spotlight_tween != null and performance_spotlight_tween.is_valid():
		performance_spotlight_tween.kill()
	if performance_zoom_tween != null and performance_zoom_tween.is_valid():
		performance_zoom_tween.kill()
	_hide_intro_spotlights_now()
	_set_performance_particles_enabled(false)
	_apply_scene_dimmer_for_state(false)
	if performance_zoom_node != null and is_instance_valid(performance_zoom_node):
		performance_zoom_node.scale = performance_zoom_base_scale
		performance_zoom_node.position = performance_zoom_base_position
	if speaker_portrait != null:
		speaker_portrait.scale = portrait_base_scale
		speaker_portrait.position = portrait_base_position
		speaker_portrait.modulate = portrait_base_modulate
		speaker_portrait.rotation = 0.0
		if portrait_default_texture != null:
			speaker_portrait.texture = portrait_default_texture
	for i in range(band_member_portraits.size()):
		var member := band_member_portraits[i]
		if member == null or not is_instance_valid(member):
			continue
		if i < band_member_base_positions.size():
			member.position = band_member_base_positions[i]
		if i < band_member_base_scales.size():
			member.scale = band_member_base_scales[i]
		if i < band_member_base_modulates.size():
			member.modulate = band_member_base_modulates[i]
	if dialogue_text != null:
		dialogue_text.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if performance_tip_fx_layer != null and is_instance_valid(performance_tip_fx_layer):
		for child in performance_tip_fx_layer.get_children():
			child.queue_free()
		performance_tip_fx_layer.hide()
	if performance_tip_button != null:
		performance_tip_button.hide()
		performance_tip_button.disabled = true
	performance_lean_back_active = false
	performance_lean_back_elapsed = 0.0
	performance_twirl_active = false
	performance_twirl_elapsed = 0.0
	performance_member_accent_cooldown_timer = 0.0
	performance_member_last_accent_index = -1
	_sync_member_accent_buffers()
	for i in range(performance_member_accent_timers.size()):
		performance_member_accent_timers[i] = 0.0
	performance_tip_boost_timer = 0.0
	performance_tip_boost_strength = 0.0
	performance_tip_cooldown_timer = 0.0
	performance_tip_current_boost = 0.0
	performance_tip_reaction_timer = 0.0
	performance_tip_reaction_text = ""
	performance_zoom_node = null


func _start_breakdown_twirl() -> void:
	performance_lean_back_active = false
	performance_lean_back_elapsed = 0.0
	performance_twirl_active = true
	performance_twirl_elapsed = 0.0
	performance_twirl_cooldown_timer = maxf(0.1, performance_twirl_cooldown)
	performance_breakdown_ready = false
	performance_breakdown_low_timer = 0.0
	performance_peak_high_timer = 0.0
	performance_peak_cycle_timer = 0.0


func _start_lean_back_pose() -> void:
	performance_twirl_active = false
	performance_twirl_elapsed = 0.0
	performance_lean_back_active = true
	performance_lean_back_elapsed = 0.0
	performance_lean_back_direction = -1.0 if performance_facing_target_sign >= 0.0 else 1.0
	performance_twirl_cooldown_timer = maxf(0.1, performance_twirl_cooldown)
	performance_breakdown_ready = false
	performance_breakdown_low_timer = 0.0
	performance_peak_high_timer = 0.0
	performance_peak_cycle_timer = 0.0


func _start_peak_showman_move() -> void:
	var lean_chance := clampf(performance_lean_back_chance, 0.0, 1.0)
	if randf() < lean_chance:
		_start_lean_back_pose()
	else:
		_start_breakdown_twirl()
	_trigger_random_member_accent(true)


func _resolve_performance_zoom_node() -> Control:
	var root := get_tree().current_scene
	if root == null:
		return null
	var direct := root.get_node_or_null("TavernBackground")
	if direct is Control:
		return direct as Control
	var matches := root.find_children("TavernBackground", "Control", true, false)
	if matches.size() > 0 and matches[0] is Control:
		return matches[0] as Control
	return null


func _schedule_next_performance_blink() -> void:
	var min_interval := maxf(0.2, performance_blink_min_interval)
	var max_interval := maxf(min_interval, performance_blink_max_interval)
	performance_blink_timer = randf_range(min_interval, max_interval)


func _try_trigger_chorus_pulse(live_intensity: float, delta_intensity: float) -> void:
	if performance_chorus_cooldown_timer > 0.0:
		return
	if live_intensity < performance_chorus_threshold:
		return
	if delta_intensity < 0.03:
		return
	if performance_zoom_node == null or not is_instance_valid(performance_zoom_node):
		return

	performance_chorus_cooldown_timer = maxf(0.1, performance_chorus_cooldown)
	if performance_zoom_tween != null and performance_zoom_tween.is_valid():
		performance_zoom_tween.kill()

	var zoom_scale := performance_zoom_base_scale * (1.0 + maxf(0.001, performance_chorus_zoom_strength))
	performance_zoom_tween = create_tween()
	performance_zoom_tween.set_trans(Tween.TRANS_SINE)
	performance_zoom_tween.set_ease(Tween.EASE_OUT)
	performance_zoom_tween.tween_property(
		performance_zoom_node,
		"scale",
		zoom_scale,
		maxf(0.03, performance_chorus_zoom_in_time)
	)
	performance_zoom_tween.tween_property(
		performance_zoom_node,
		"scale",
		performance_zoom_base_scale,
		maxf(0.04, performance_chorus_zoom_out_time)
	)


func _animate_lyric_card_transition() -> void:
	if dialogue_text == null:
		return
	if lyric_fade_tween != null and lyric_fade_tween.is_valid():
		lyric_fade_tween.kill()
	dialogue_text.modulate = Color(1.0, 1.0, 1.0, 0.20)
	lyric_fade_tween = create_tween()
	lyric_fade_tween.set_trans(Tween.TRANS_SINE)
	lyric_fade_tween.set_ease(Tween.EASE_OUT)
	lyric_fade_tween.tween_property(
		dialogue_text,
		"modulate",
		Color(1.0, 1.0, 1.0, 1.0),
		maxf(0.04, performance_lyric_fade_time)
	)

# Purpose: Drives the live cursor motion while the QTE is active and updates "inside zone" visuals.
# Inputs: delta (float) - Frame time step in seconds.
# Outputs: None.
# Side effects: Moves the cursor, flips direction at bar edges, and updates cursor/sweet-spot colors.
func _process(delta: float) -> void:
	if current_state == State.PERFORMANCE_ACTIVE:
		if performance_tip_reaction_timer <= 0.0:
			_update_performance_lyrics()
		if speaker_portrait != null and performance_player != null:
			var live_intensity: float = _sample_performance_intensity(delta)
			performance_time_accum += maxf(0.0, delta)
			performance_chorus_cooldown_timer = maxf(0.0, performance_chorus_cooldown_timer - delta)
			performance_pluck_cooldown_timer = maxf(0.0, performance_pluck_cooldown_timer - delta)
			performance_flip_cooldown_timer = maxf(0.0, performance_flip_cooldown_timer - delta)
			performance_twirl_cooldown_timer = maxf(0.0, performance_twirl_cooldown_timer - delta)
			performance_member_accent_cooldown_timer = maxf(0.0, performance_member_accent_cooldown_timer - delta)
			performance_tip_cooldown_timer = maxf(0.0, performance_tip_cooldown_timer - delta)
			var had_tip_reaction: bool = performance_tip_reaction_timer > 0.0
			performance_tip_reaction_timer = maxf(0.0, performance_tip_reaction_timer - delta)
			if had_tip_reaction and performance_tip_reaction_timer <= 0.0:
				performance_current_line_index = -1
				_update_performance_lyrics()
			if performance_tip_boost_timer > 0.0:
				performance_tip_boost_timer = maxf(0.0, performance_tip_boost_timer - delta)
				performance_tip_current_boost = _get_current_tip_boost_value()
				live_intensity = clampf(live_intensity + performance_tip_current_boost, 0.0, 1.0)
			else:
				performance_tip_current_boost = 0.0
				performance_tip_boost_strength = 0.0
			if performance_tip_reaction_timer > 0.0:
				_show_tip_reaction_dialogue()
			var delta_intensity := live_intensity - performance_last_live_intensity
			performance_last_live_intensity = live_intensity
			_update_tip_button_state()
			_update_performance_particles(live_intensity, delta)
			_update_tip_visual_upgrades()
			_update_live_performance_scene_dimmer(live_intensity)
			_try_trigger_chorus_pulse(live_intensity, delta_intensity)

			# Occasional showman turns (left/right facing) while performing.
			if not performance_twirl_active and not performance_lean_back_active and performance_flip_cooldown_timer <= 0.0:
				var flip_chance: float = maxf(0.0, performance_flip_chance_per_second) * maxf(0.0, delta)
				if randf() < flip_chance:
					performance_facing_target_sign *= -1.0
					performance_flip_cooldown_timer = maxf(0.1, performance_flip_min_interval)

			var face_lerp := clampf(maxf(0.0, performance_flip_turn_smooth) * maxf(0.0, delta), 0.0, 1.0)
			performance_facing_visual_sign = lerpf(performance_facing_visual_sign, performance_facing_target_sign, face_lerp)

			# Breakdown detection: if intensity stays low for a short window, trigger a dramatic twirl.
			if not performance_twirl_active and not performance_lean_back_active:
				if live_intensity >= performance_twirl_sustain_threshold:
					performance_peak_high_timer += maxf(0.0, delta)
					performance_peak_cycle_timer += maxf(0.0, delta)
				else:
					performance_peak_high_timer = 0.0
					performance_peak_cycle_timer = 0.0

				var trigger_from_intense_peak := (
					performance_twirl_cooldown_timer <= 0.0
					and live_intensity >= performance_twirl_intense_threshold
					and delta_intensity >= performance_twirl_intense_delta_min
				)
				var trigger_from_sustained_peak := (
					performance_twirl_cooldown_timer <= 0.0
					and performance_peak_high_timer >= maxf(0.08, performance_twirl_sustain_hold_time)
					and delta_intensity >= 0.015
				)
				var trigger_from_peak_cycle := false
				if performance_twirl_cooldown_timer <= 0.0 \
				and performance_peak_cycle_timer >= maxf(0.25, performance_twirl_peak_interval):
					performance_peak_cycle_timer = 0.0
					trigger_from_peak_cycle = randf() < clampf(performance_twirl_peak_chance, 0.0, 1.0)
				if trigger_from_intense_peak or trigger_from_sustained_peak or trigger_from_peak_cycle:
					_start_peak_showman_move()
					performance_peak_high_timer = 0.0
				elif live_intensity <= performance_breakdown_threshold:
					performance_breakdown_low_timer += maxf(0.0, delta)
				else:
					performance_breakdown_low_timer = 0.0
					if live_intensity >= performance_breakdown_rearm_intensity:
						performance_breakdown_ready = true

				if performance_breakdown_ready \
				and performance_twirl_cooldown_timer <= 0.0 \
				and performance_breakdown_low_timer >= maxf(0.08, performance_breakdown_hold_time):
					_start_peak_showman_move()

			if performance_pluck_cooldown_timer <= 0.0 and live_intensity >= performance_pluck_threshold and delta_intensity > 0.025:
				performance_pluck_impulse = 1.0
				performance_pluck_cooldown_timer = maxf(0.05, performance_pluck_cooldown)
			performance_pluck_impulse = maxf(0.0, performance_pluck_impulse - (delta * 5.2))

			if performance_blink_elapsed >= 0.0:
				performance_blink_elapsed += delta
				if performance_blink_elapsed >= maxf(0.04, performance_blink_duration):
					performance_blink_elapsed = -1.0
					_schedule_next_performance_blink()
			else:
				performance_blink_timer -= delta
				if performance_blink_timer <= 0.0:
					performance_blink_elapsed = 0.0

			var t: float = performance_player.get_playback_position()
			var beat_freq: float = lerpf(1.0, 2.4, live_intensity)
			var pulse_amp: float = lerpf(0.004, 0.020, live_intensity)
			var sway_amp: float = lerpf(0.5, 1.8, live_intensity)
			var pulse := 1.0 + sin(t * TAU * beat_freq) * pulse_amp
			var micro := sin(t * TAU * (beat_freq * 0.5 + 0.7)) * (pulse_amp * 0.5)
			var breath := sin(performance_time_accum * TAU * maxf(0.05, performance_breath_speed)) * performance_breath_amount
			var blink_squash := 1.0
			if performance_blink_elapsed >= 0.0:
				var blink_t := clampf(performance_blink_elapsed / maxf(0.04, performance_blink_duration), 0.0, 1.0)
				blink_squash = 1.0 - (sin(blink_t * PI) * 0.09)
			var pluck_boost := performance_pluck_impulse * maxf(0.0, performance_pluck_scale_boost)
			var pluck_kick := performance_pluck_impulse * maxf(0.0, performance_pluck_kick_px)

			# Twirl is an in-place body-spin illusion (width squash + horizontal sign flip),
			# not a circular orbit rotation.
			var twirl_x_mult: float = 1.0
			var twirl_y_mult: float = 1.0
			if performance_twirl_active:
				performance_twirl_elapsed += maxf(0.0, delta)
				var twirl_t := clampf(performance_twirl_elapsed / maxf(0.05, performance_twirl_duration), 0.0, 1.0)
				# End the twirl on a neutral full-width frame to avoid end-pop/snap.
				var turns := float(maxi(1, int(ceili(absf(performance_twirl_spin_degrees) / 360.0))))
				var phase := twirl_t * TAU * turns
				var raw_x := cos(phase)
				var min_width := 0.10
				twirl_x_mult = sign(raw_x) * maxf(min_width, absf(raw_x))
				twirl_y_mult = 1.0 + ((1.0 - absf(raw_x)) * 0.09)
				if twirl_t >= 1.0:
					performance_twirl_active = false
					performance_twirl_elapsed = 0.0
			var lean_back_offset := Vector2.ZERO
			var lean_back_rotation := 0.0
			var lean_back_y_mult := 1.0
			if performance_lean_back_active:
				performance_lean_back_elapsed += maxf(0.0, delta)
				var lean_t := clampf(performance_lean_back_elapsed / maxf(0.05, performance_lean_back_duration), 0.0, 1.0)
				var pose := sin(lean_t * PI)
				var back_dir := performance_lean_back_direction
				lean_back_rotation = deg_to_rad(maxf(0.0, performance_lean_back_angle_degrees)) * back_dir * pose
				lean_back_offset = Vector2(
					maxf(0.0, performance_lean_back_push_px) * back_dir * pose,
					-maxf(0.0, performance_lean_back_lift_px) * pose
				)
				var max_stretch := maxf(1.0, performance_lean_back_scale_y)
				lean_back_y_mult = 1.0 + ((max_stretch - 1.0) * pose)
				if lean_t >= 1.0:
					performance_lean_back_active = false
					performance_lean_back_elapsed = 0.0

			var scale_x: float = (pulse + micro + breath + pluck_boost) * performance_facing_visual_sign * twirl_x_mult
			var scale_y: float = ((pulse + breath * 0.45 + (pluck_boost * 0.35)) * blink_squash) * twirl_y_mult * lean_back_y_mult
			speaker_portrait.scale = portrait_base_scale * Vector2(scale_x, scale_y)
			speaker_portrait.position = portrait_base_position + Vector2(
				sin(t * TAU * 0.28) * sway_amp,
				-pluck_kick * 0.35
			) + lean_back_offset
			speaker_portrait.rotation = lean_back_rotation
			var glow := clampf(live_intensity * maxf(0.0, performance_rune_glow_strength), 0.0, 0.35)
			speaker_portrait.modulate = Color(
				1.0,
				1.0 + (glow * 0.20),
				1.0 + glow,
				1.0
			)

			var band_intensity_scale := maxf(0.05, _get_effective_band_member_intensity_scale())
			var band_sway_scale := maxf(0.0, _get_effective_band_member_sway_scale())
			var band_glow_strength := maxf(0.0, _get_effective_band_member_glow_strength())
			var accent_duration: float = maxf(0.08, performance_member_accent_duration)
			var accent_scale_boost: float = maxf(1.0, performance_member_accent_scale)
			var accent_forward_px: float = maxf(0.0, performance_member_accent_forward_px)
			var accent_lift_px: float = maxf(0.0, performance_member_accent_lift_px)
			for i in range(band_member_portraits.size()):
				var member := band_member_portraits[i]
				if member == null or not is_instance_valid(member) or not member.visible:
					continue
				if i >= band_member_base_positions.size() or i >= band_member_base_scales.size():
					continue

				var phase := float(i + 1) * 0.37
				var band_intensity := clampf(live_intensity * band_intensity_scale, 0.0, 1.0)
				var band_pulse := 1.0 + sin((t + phase) * TAU * (beat_freq * 0.78)) * (pulse_amp * 0.45)
				var band_breath := sin((performance_time_accum + phase) * TAU * maxf(0.05, performance_breath_speed)) * (performance_breath_amount * 0.75)
				var band_sway := sin((t * TAU * 0.22) + phase) * (sway_amp * band_sway_scale) * (0.92 + float(i) * 0.08)
				var band_pluck_boost := pluck_boost * 0.35
				var band_pluck_kick := pluck_kick * 0.20
				var accent_pose: float = 0.0
				if i < performance_member_accent_timers.size():
					var timer: float = maxf(0.0, performance_member_accent_timers[i] - delta)
					performance_member_accent_timers[i] = timer
					if timer > 0.0:
						var accent_t: float = 1.0 - clampf(timer / accent_duration, 0.0, 1.0)
						accent_pose = sin(accent_t * PI)
				var center_x: float = portrait_base_position.x + (speaker_portrait.size.x * 0.5)
				var member_center_x: float = band_member_base_positions[i].x + (member.size.x * 0.5)
				var accent_side: float = sign(member_center_x - center_x)
				if absf(accent_side) < 0.01:
					accent_side = -1.0 if i % 2 == 0 else 1.0
				var accent_offset := Vector2(
					accent_side * accent_forward_px * accent_pose,
					-accent_lift_px * accent_pose
				)
				var accent_scale_mult: float = lerpf(1.0, accent_scale_boost, accent_pose)

				member.scale = band_member_base_scales[i] * Vector2(
					(band_pulse + band_breath + band_pluck_boost) * accent_scale_mult,
					(band_pulse + (band_breath * 0.40)) * lerpf(1.0, 1.02, accent_pose)
				)
				member.position = band_member_base_positions[i] + Vector2(band_sway, -band_pluck_kick) + accent_offset
				if i < band_member_base_modulates.size():
					var base_mod := band_member_base_modulates[i]
					var band_glow := clampf(band_intensity * band_glow_strength, 0.0, 0.22)
					member.modulate = Color(
						base_mod.r,
						base_mod.g + (band_glow * 0.10),
						base_mod.b + band_glow,
						base_mod.a
					)
		return

	if current_state != State.QTE_ACTIVE:
		return

	var max_cursor_x: float = qte_bar_size.x - cursor.size.x

	if moving_right:
		cursor.position.x += active_qte_speed * delta
		if cursor.position.x >= max_cursor_x:
			cursor.position.x = max_cursor_x
			moving_right = false
	else:
		cursor.position.x -= active_qte_speed * delta
		if cursor.position.x <= 0.0:
			cursor.position.x = 0.0
			moving_right = true

	_apply_cursor_zone_feedback()

# Purpose: Shows the current tier's challenge dialogue before the combo QTE begins.
# Inputs: None.
# Outputs: None.
# Side effects: Sets state and updates the dialogue panel text.
func _show_intro_dialogue() -> void:
	current_state = State.DIALOGUE_INTRO
	_fade_stage_backdrop_out()
	_refresh_speaker_portrait_visibility()

	var tier_number: int = current_tier_index + 1
	var tier_total: int = _get_total_tiers()
	var intro_line: String = "Ah, a traveler. Music is the purest expression of focus. Can you match my tempo?"

	if current_tier_index > 0:
		intro_line = "Back again? Good. The next phrase bites harder than the last. Keep your nerve and follow the pulse."

	dialogue_text.text = "[font_size=%d][color=cyan]Lysander:[/color] %s[/font_size]\n\n[font_size=%d][color=gold]Disc Trial %d / %d[/color][/font_size]\n\n[font_size=%d][color=gray][i](Press SPACE or click to continue)[/i][/color][/font_size]" % [
		dialogue_font_size,
		intro_line,
		dialogue_font_size - 2,
		tier_number,
		tier_total,
		dialogue_font_size - 10
	]

# Purpose: Shows the final repeat dialogue after all reward tiers have been completed.
# Inputs: None.
# Outputs: None.
# Side effects: Sets state and updates the dialogue panel text without starting the QTE.
func _show_post_all_tiers_dialogue() -> void:
	current_state = State.DIALOGUE_POST_ALL_TIERS
	_fade_stage_backdrop_out()
	_refresh_speaker_portrait_visibility()
	dialogue_text.text = "[font_size=%d][color=cyan]Lysander:[/color] Hear that? The room still remembers every rhythm we forged together. You've taken the full set now—what remains is not reward, but style.[/font_size]\n\n[font_size=%d][color=gray][i](Press SPACE or click to close)[/i][/color][/font_size]" % [
		dialogue_font_size,
		dialogue_font_size - 10
	]

# Purpose: Transitions from intro dialogue into the active combo QTE for the current reward tier.
# Inputs: None.
# Outputs: None.
# Side effects: Resets combo progress and starts the first press in the tier sequence.
func _start_qte() -> void:
	current_state = State.QTE_ACTIVE
	_refresh_speaker_portrait_visibility()
	current_qte_hits = 0
	pending_qte_success = false
	pending_qte_completed_tier = false
	previous_sweet_spot_x = -1.0
	_prepare_next_qte_press()

# Purpose: Updates the active QTE prompt so the player can read current combo progress.
# Inputs: None.
# Outputs: None.
# Side effects: Rewrites the dialogue panel text while the QTE is active.
func _update_qte_prompt() -> void:
	var required_hits: int = _get_current_tier_required_hits()
	var next_hit_number: int = current_qte_hits + 1
	var tier_number: int = current_tier_index + 1
	var tier_total: int = _get_total_tiers()

	dialogue_text.text = "[font_size=%d][color=cyan]Lysander:[/color] Focus...[/font_size]\n\n[font_size=%d][color=gold]Disc Trial %d / %d  |  Beat %d / %d[/color][/font_size]\n\n[font_size=%d][color=gray][i](Press SPACE or click when the blue line is inside the Gold zone!)[/i][/color][/font_size]" % [
		dialogue_font_size,
		dialogue_font_size - 2,
		tier_number,
		tier_total,
		next_hit_number,
		required_hits,
		dialogue_font_size - 10
	]

# Purpose: Prepares the next press in the combo chain for the active tier.
# Inputs: None.
# Outputs: None.
# Side effects: Resets visuals, reapplies current difficulty, randomizes the sweet spot, and restarts cursor motion.
func _prepare_next_qte_press() -> void:
	_reset_qte_visuals()
	_apply_current_tier_sweet_spot()
	_randomize_sweet_spot()

	active_qte_speed = _get_current_tier_speed() + (float(current_qte_hits) * qte_speed_per_chain_hit)

	var start_from_left: bool = randf() < 0.5
	if start_from_left:
		cursor.position = Vector2(0.0, -cursor_height_padding * 0.5)
		moving_right = true
	else:
		cursor.position = Vector2(qte_bar_size.x - cursor.size.x, -cursor_height_padding * 0.5)
		moving_right = false

	qte_container.position = qte_base_position
	qte_container.show()

	_update_qte_prompt()

# Purpose: Finalizes the player's current timing input and determines whether the combo continues, wins, or fails.
# Inputs: None.
# Outputs: None.
# Side effects: Locks progression, stores current hit result, plays feedback, and starts the resolution timer.
func _resolve_qte() -> void:
	current_state = State.QTE_RESOLVING
	pending_qte_success = _is_cursor_in_sweet_spot()
	pending_qte_completed_tier = false

	if pending_qte_success:
		var required_hits: int = _get_current_tier_required_hits()
		var projected_hits: int = current_qte_hits + 1
		pending_qte_completed_tier = projected_hits >= required_hits

	_play_qte_hit_feedback(pending_qte_success)

	feedback_timer.stop()
	feedback_timer.wait_time = qte_feedback_duration
	feedback_timer.start()

# Purpose: Applies a flash/shake burst so the player's button press feels immediate and readable.
# Inputs: was_successful (bool) - Whether the cursor landed inside the sweet spot.
# Outputs: None.
# Side effects: Changes colors, animates the QTE bar position, and fades in/out a flash overlay.
func _play_qte_hit_feedback(was_successful: bool) -> void:
	if feedback_tween != null and feedback_tween.is_valid():
		feedback_tween.kill()

	if was_successful:
		cursor.color = CURSOR_COLOR_SUCCESS
		sweet_spot.color = SWEET_SPOT_COLOR_HOT
		flash_rect.color = FLASH_COLOR_SUCCESS
	else:
		cursor.color = CURSOR_COLOR_FAIL
		sweet_spot.color = SWEET_SPOT_COLOR_FAIL
		flash_rect.color = FLASH_COLOR_FAIL

	flash_rect.modulate = Color(1.0, 1.0, 1.0, 0.85)
	flash_rect.show()

	feedback_tween = create_tween()
	feedback_tween.set_trans(Tween.TRANS_SINE)
	feedback_tween.set_ease(Tween.EASE_OUT)

	for _i in range(4):
		var shake_offset: Vector2 = Vector2(
			randf_range(-qte_shake_amount, qte_shake_amount),
			randf_range(-qte_shake_amount * 0.30, qte_shake_amount * 0.30)
		)
		feedback_tween.tween_property(qte_container, "position", qte_base_position + shake_offset, 0.02)

	feedback_tween.tween_property(qte_container, "position", qte_base_position, 0.03)
	feedback_tween.parallel().tween_property(flash_rect, "modulate", Color(1.0, 1.0, 1.0, 0.0), qte_feedback_duration)

# Purpose: Converts the stored press result into either combo continuation, tier completion, or failure dialogue.
# Inputs: None.
# Outputs: None.
# Side effects: Advances combo count, continues the chain, or ends the interaction branch.
func _on_feedback_timer_timeout() -> void:
	if pending_qte_success:
		current_qte_hits += 1

		if pending_qte_completed_tier:
			qte_container.hide()
			_show_win_dialogue()
		else:
			_continue_qte_chain()
	else:
		qte_container.hide()
		_show_lose_dialogue()

# Purpose: Continues the QTE after a successful intermediate hit that did not yet clear the tier.
# Inputs: None.
# Outputs: None.
# Side effects: Returns the interaction to QTE_ACTIVE and starts the next combo step.
func _continue_qte_chain() -> void:
	current_state = State.QTE_ACTIVE
	_prepare_next_qte_press()

# Purpose: Shows the success dialogue, grants exactly one disc for the current tier, and advances progression.
# Inputs: None.
# Outputs: None.
# Side effects: Adds one reward to inventory, increments current_tier_index, and updates dialogue text.
func _show_win_dialogue() -> void:
	current_state = State.DIALOGUE_OUTRO_WIN
	_refresh_speaker_portrait_visibility()

	var awarded_name: String = fallback_reward_name
	var tier_to_award: int = current_tier_index
	var required_hits: int = _get_current_tier_required_hits()

	if tier_to_award < reward_discs.size():
		var reward_disc_for_tier: ConsumableData = reward_discs[tier_to_award]
		if reward_disc_for_tier != null:
			awarded_name = reward_disc_for_tier.item_name
			if CampaignManager.has_method("add_item_to_inventory"):
				CampaignManager.add_item_to_inventory(reward_disc_for_tier)

	current_tier_index += 1

	if _has_remaining_tiers():
		dialogue_text.text = "[font_size=%d][color=cyan]Lysander:[/color] Cleanly struck. You held the phrase for %d beats and earned another composition.[/font_size]\n\n[font_size=%d][color=gold][i]Obtained: %s![/i][/color][/font_size]\n\n[font_size=%d][color=gray][i](Press SPACE or click to close)[/i][/color][/font_size]" % [
			dialogue_font_size,
			required_hits,
			dialogue_font_size - 2,
			awarded_name,
			dialogue_font_size - 10
		]
	else:
		dialogue_text.text = "[font_size=%d][color=cyan]Lysander:[/color] Flawless. You carried the final phrase to its end, and the last disc is yours.[/font_size]\n\n[font_size=%d][color=gold][i]Obtained: %s![/i][/color][/font_size]\n\n[font_size=%d][color=gray][i](Press SPACE or click to close)[/i][/color][/font_size]" % [
			dialogue_font_size,
			dialogue_font_size - 2,
			awarded_name,
			dialogue_font_size - 10
		]

# Purpose: Shows the failure dialogue so the player can retry the same tier after missing during the combo.
# Inputs: None.
# Outputs: None.
# Side effects: Sets the loss state and updates dialogue text with combo progress.
func _show_lose_dialogue() -> void:
	current_state = State.DIALOGUE_OUTRO_LOSE
	_refresh_speaker_portrait_visibility()

	var tier_number: int = current_tier_index + 1
	var tier_total: int = _get_total_tiers()
	var required_hits: int = _get_current_tier_required_hits()

	dialogue_text.text = "[font_size=%d][color=cyan]Lysander:[/color] You broke the phrase. You held %d of %d beats, but the next disc stays with me until the rhythm is unbroken.[/font_size]\n\n[font_size=%d][color=gold]Current Trial: %d / %d[/color][/font_size]\n\n[font_size=%d][color=gray][i](Press SPACE or click to close)[/i][/color][/font_size]" % [
		dialogue_font_size,
		current_qte_hits,
		required_hits,
		dialogue_font_size - 2,
		tier_number,
		tier_total,
		dialogue_font_size - 10
	]

# Purpose: Applies the sweet-spot width for the active tier before random placement.
# Inputs: None.
# Outputs: None.
# Side effects: Resizes the sweet spot to match the current difficulty tier.
func _apply_current_tier_sweet_spot() -> void:
	var active_width: float = _get_current_tier_width()
	sweet_spot.size = Vector2(active_width, qte_bar_size.y)
	sweet_spot.custom_minimum_size = sweet_spot.size

# Purpose: Randomizes the sweet spot location so each QTE press is a fresh timing challenge.
# Inputs: None.
# Outputs: None.
# Side effects: Moves the sweet spot horizontally within the timing bar while avoiding the
#	start edge and positions too close to the previous sweet spot.
func _randomize_sweet_spot() -> void:
	var min_x: float = sweet_spot_left_padding
	var max_x: float = qte_bar_size.x - sweet_spot.size.x - sweet_spot_right_padding

	if max_x < min_x:
		min_x = 0.0
		max_x = maxf(0.0, qte_bar_size.x - sweet_spot.size.x)

	var chosen_x: float = min_x

	if previous_sweet_spot_x < 0.0:
		chosen_x = randf_range(min_x, max_x)
	else:
		var found_far_enough: bool = false

		for _attempt in range(sweet_spot_random_retry_count):
			var candidate_x: float = randf_range(min_x, max_x)
			if absf(candidate_x - previous_sweet_spot_x) >= min_sweet_spot_move_distance:
				chosen_x = candidate_x
				found_far_enough = true
				break

		if not found_far_enough:
			if previous_sweet_spot_x < ((min_x + max_x) * 0.5):
				chosen_x = max_x
			else:
				chosen_x = min_x

	sweet_spot.position.x = chosen_x
	sweet_spot.position.y = 0.0
	previous_sweet_spot_x = chosen_x

# Purpose: Updates the cursor/sweet-spot colors when the cursor enters or exits the scoring zone.
# Inputs: None.
# Outputs: None.
# Side effects: Changes UI colors to provide immediate "you're on target" feedback.
func _apply_cursor_zone_feedback() -> void:
	var is_inside_now: bool = _is_cursor_in_sweet_spot()

	if is_inside_now == cursor_is_in_sweet_spot:
		return

	cursor_is_in_sweet_spot = is_inside_now

	if is_inside_now:
		cursor.color = CURSOR_COLOR_HOT
		sweet_spot.color = SWEET_SPOT_COLOR_HOT
	else:
		cursor.color = CURSOR_COLOR_DEFAULT
		sweet_spot.color = SWEET_SPOT_COLOR_DEFAULT

# Purpose: Evaluates whether the cursor center currently overlaps the sweet spot bounds.
# Inputs: None.
# Outputs: bool - True if the cursor center is inside the sweet spot, otherwise false.
# Side effects: None.
func _is_cursor_in_sweet_spot() -> bool:
	var cursor_center: float = cursor.position.x + (cursor.size.x * 0.5)
	var spot_start: float = sweet_spot.position.x
	var spot_end: float = sweet_spot.position.x + sweet_spot.size.x
	return cursor_center >= spot_start and cursor_center <= spot_end

# Purpose: Returns whether there are still unearned reward tiers remaining.
# Inputs: None.
# Outputs: bool - True if another tier reward is available, otherwise false.
# Side effects: None.
func _has_remaining_tiers() -> bool:
	return current_tier_index < _get_total_tiers()

# Purpose: Returns how many reward tiers exist based on the configured disc array.
# Inputs: None.
# Outputs: int - The total number of reward tiers.
# Side effects: None.
func _get_total_tiers() -> int:
	return reward_discs.size()

# Purpose: Returns the active cursor speed for the current tier.
# Inputs: None.
# Outputs: float - The current tier's QTE cursor speed.
# Side effects: None.
func _get_current_tier_speed() -> float:
	if tier_speeds.size() == 0:
		return base_qte_speed

	if current_tier_index < tier_speeds.size():
		return tier_speeds[current_tier_index]

	return tier_speeds[tier_speeds.size() - 1]

# Purpose: Returns the active sweet-spot width for the current tier.
# Inputs: None.
# Outputs: float - The current tier's sweet-spot width.
# Side effects: None.
func _get_current_tier_width() -> float:
	if tier_sweet_spot_widths.size() == 0:
		return base_sweet_spot_width

	if current_tier_index < tier_sweet_spot_widths.size():
		return tier_sweet_spot_widths[current_tier_index]

	return tier_sweet_spot_widths[tier_sweet_spot_widths.size() - 1]

# Purpose: Returns how many successful presses are required to clear the current tier.
# Inputs: None.
# Outputs: int - The required successful hit count for the active tier.
# Side effects: None.
func _get_current_tier_required_hits() -> int:
	if tier_required_hits.size() == 0:
		return 1

	var required_hits: int

	if current_tier_index < tier_required_hits.size():
		required_hits = tier_required_hits[current_tier_index]
	else:
		required_hits = tier_required_hits[tier_required_hits.size() - 1]

	if required_hits < 1:
		required_hits = 1

	return required_hits

# Purpose: Restores the QTE visuals to a clean neutral state before starting a new press.
# Inputs: None.
# Outputs: None.
# Side effects: Resets bar position, colors, overlays, and transient resolution flags.
func _reset_qte_visuals() -> void:
	if feedback_tween != null and feedback_tween.is_valid():
		feedback_tween.kill()

	feedback_timer.stop()
	qte_container.position = qte_base_position
	cursor_is_in_sweet_spot = false
	pending_qte_success = false
	pending_qte_completed_tier = false

	sweet_spot.color = SWEET_SPOT_COLOR_DEFAULT
	cursor.color = CURSOR_COLOR_DEFAULT

	flash_rect.hide()
	flash_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _sample_performance_intensity(delta: float) -> float:
	if performance_player == null:
		return clampf(performance_energy, 0.0, 1.0)
	if performance_bus_index < 0:
		return clampf(performance_energy, 0.0, 1.0)

	var left_db := AudioServer.get_bus_peak_volume_left_db(performance_bus_index, 0)
	var right_db := AudioServer.get_bus_peak_volume_right_db(performance_bus_index, 0)
	var peak_db := maxf(left_db, right_db)
	var target := clampf(pow(db_to_linear(peak_db), 0.60), 0.0, 1.0)

	var attack_lerp := 1.0 - exp(-maxf(0.0, performance_bob_attack) * maxf(0.0, delta))
	var release_lerp := 1.0 - exp(-maxf(0.0, performance_bob_release) * maxf(0.0, delta))
	if target >= performance_audio_level_smoothed:
		performance_audio_level_smoothed = lerpf(performance_audio_level_smoothed, target, attack_lerp)
	else:
		performance_audio_level_smoothed = lerpf(performance_audio_level_smoothed, target, release_lerp)

	# Second low-pass pass to remove twitchy spikes from transients.
	var secondary_lerp := 1.0 - exp(-3.2 * maxf(0.0, delta))
	performance_audio_level_secondary = lerpf(
		performance_audio_level_secondary,
		performance_audio_level_smoothed,
		secondary_lerp
	)

	# Clamp the animation window so it reacts, but never goes wild.
	return clampf(
		performance_audio_level_secondary,
		performance_bob_min_intensity,
		performance_bob_max_intensity
	)

# Purpose: Consumes the current interaction input so it cannot propagate back into the button.
# Inputs: None.
# Outputs: None.
# Side effects: Removes keyboard focus from this TextureButton and marks the current input handled.
func _consume_current_input() -> void:
	release_focus()
	get_viewport().set_input_as_handled()

# Purpose: Closes the interaction UI and restores Lysander to a stable idle-ready state.
# Inputs: None.
# Outputs: None.
# Side effects: Hides UI, resets transient QTE visuals and combo progress, and returns the state machine to IDLE.
func _close_interaction() -> void:
	_consume_current_input()
	_reset_qte_visuals()
	_hide_mode_select_dialogue()
	_restore_tavern_music_after_performance()
	if performance_blackout_tween != null and performance_blackout_tween.is_valid():
		performance_blackout_tween.kill()
	_hide_blackout_titlecard_now()
	_fade_stage_backdrop_out(true)
	_reset_performance_visual_state()
	if performance_player != null:
		if performance_music_tween != null and performance_music_tween.is_valid():
			performance_music_tween.kill()
		performance_player.stop()
		performance_player.volume_db = performance_music_base_db

	current_qte_hits = 0
	active_qte_speed = 0.0
	previous_sweet_spot_x = -1.0
	_skip_first_mouse_advance = false
	performance_bus_index = -1
	performance_audio_level_smoothed = 0.0
	performance_audio_level_secondary = 0.0
	performance_pluck_impulse = 0.0
	performance_last_live_intensity = 0.0
	if performance_tip_gold_dirty and CampaignManager != null and CampaignManager.has_method("save_current_progress"):
		CampaignManager.save_current_progress()
	performance_tip_gold_dirty = false

	ui_layer.hide()
	qte_container.hide()
	current_state = State.IDLE
