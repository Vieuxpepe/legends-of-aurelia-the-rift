# ==============================================================================
# Script Name: scene_transition.gd
# Purpose: Autoload scene transition with fade-to-black, optional audio ducking, and safe scene change.
# Overall Goal: Provide a single, reliable way to change scenes with visual/audio polish and no stuck states.
# Project Fit: Called as SceneTransition.change_scene_to_file(path) from camp, world map, battle, menus.
# Dependencies: None (autoload).
# AI/Code Reviewer Guidance:
#   - Entry: change_scene_to_file(target_scene_path). fade_in_from_black() for scenes that load under black.
#   - Safety: Path validation, re-entrancy guard, error recovery so overlay and _busy never get stuck.
#   - Process when paused: CanvasLayer process_mode keeps transition animating during pause.
# ==============================================================================

extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

@export var fade_out_time: float = 0.4
@export var fade_in_time: float = 0.35
@export var hold_black_time: float = 0.08
@export var from_black_post_load_hold_frames: int = 2

@export var transition_color: Color = Color.BLACK
@export var pause_tree_during_black: bool = false
@export var block_input_during_transition: bool = true
@export var fade_audio: bool = true
@export var audio_fade_time: float = 0.2

## Minimum duration for fade tweens so very short values don't break visually.
const MIN_FADE_TIME: float = 0.05

var _busy: bool = false

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	layer = 1000
	RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0, 1.0))
	if not color_rect:
		push_error("SceneTransition: ColorRect missing; transition will no-op.")
		return
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.color = transition_color
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.modulate.a = 0.0

## Returns true while a transition is in progress. Use to avoid double-triggering.
func is_busy() -> bool:
	return _busy

## Changes to target scene with fade-out, optional hold, scene change, then fade-in. Safe if path invalid or change fails.
func change_scene_to_file(
	target_scene_path: String,
	override_fade_out_time: float = -1.0,
	override_fade_in_time: float = -1.0,
	override_hold_black_time: float = -1.0
) -> void:
	if _busy:
		return
	var path_clean: String = target_scene_path.strip_edges()
	if path_clean.is_empty():
		push_warning("SceneTransition: empty path, ignoring.")
		return
	if not _is_valid_scene_path(path_clean):
		push_error("SceneTransition: invalid or missing scene: " + path_clean)
		return
	_busy = true

	if not color_rect:
		_busy = false
		return
	if block_input_during_transition:
		color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var local_fade_out: float = fade_out_time if override_fade_out_time < 0.0 else override_fade_out_time
	var local_fade_in: float = fade_in_time if override_fade_in_time < 0.0 else override_fade_in_time
	var local_hold_black: float = hold_black_time if override_hold_black_time < 0.0 else override_hold_black_time

	# Fade to black
	await _fade_alpha(1.0, local_fade_out)

	if local_hold_black > 0.0:
		await get_tree().create_timer(local_hold_black).timeout

	var was_paused: bool = get_tree().paused
	if pause_tree_during_black:
		get_tree().paused = true

	# Scene switch; engine may push errors if path fails
	var err: Error = get_tree().change_scene_to_file(path_clean)
	if err != OK:
		get_tree().paused = was_paused
		push_error("SceneTransition: change_scene_to_file failed: " + path_clean + " (error " + str(err) + ")")
		_reset_after_failure()
		return

	if pause_tree_during_black:
		get_tree().paused = was_paused

	# Fade back in (tween persists across scene change; overlay is on autoload)
	await _fade_alpha(0.0, local_fade_in)

	if block_input_during_transition:
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

## Call from a scene that loads while overlay is black (e.g. after direct change_scene) to fade in. Idempotent.
func fade_in_from_black() -> void:
	if not color_rect or color_rect.modulate.a < 0.01:
		_busy = false
		if block_input_during_transition and color_rect:
			color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	await _fade_alpha(0.0, fade_in_time)
	if block_input_during_transition and color_rect:
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

## Switches scenes assuming the current scene is already black (or near-black),
## skipping the initial fade-out to avoid flash-like handoffs.
func change_scene_from_black(
	target_scene_path: String,
	override_fade_in_time: float = -1.0,
	override_hold_black_time: float = -1.0
) -> void:
	if _busy:
		return
	var path_clean: String = target_scene_path.strip_edges()
	if path_clean.is_empty():
		push_warning("SceneTransition: empty path, ignoring.")
		return
	if not _is_valid_scene_path(path_clean):
		push_error("SceneTransition: invalid or missing scene: " + path_clean)
		return
	_busy = true
	if not color_rect:
		_busy = false
		return
	if block_input_during_transition:
		color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var local_fade_in: float = fade_in_time if override_fade_in_time < 0.0 else override_fade_in_time
	var local_hold_black: float = hold_black_time if override_hold_black_time < 0.0 else override_hold_black_time

	# Force full black first (no visible flash pulse).
	color_rect.color = transition_color
	color_rect.visible = true
	color_rect.modulate.a = 1.0

	if local_hold_black > 0.0:
		await get_tree().create_timer(local_hold_black).timeout

	var err: Error = get_tree().change_scene_to_file(path_clean)
	if err != OK:
		push_error("SceneTransition: change_scene_to_file failed: " + path_clean + " (error " + str(err) + ")")
		_reset_after_failure()
		return

	# Keep black for a couple frames after scene swap to hide any load-time clear-color flash.
	var hold_frames: int = maxi(0, from_black_post_load_hold_frames)
	for _i in range(hold_frames):
		await get_tree().process_frame

	# If fade-in is zero/negative, keep black and let destination scene call fade_in_from_black().
	if local_fade_in <= 0.001:
		_busy = false
		return

	await _fade_alpha(0.0, local_fade_in)
	if block_input_during_transition:
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func _is_valid_scene_path(path: String) -> bool:
	if path.is_empty():
		return false
	if not path.ends_with(".tscn") and not path.ends_with(".scn"):
		return false
	return ResourceLoader.exists(path)

func _reset_after_failure() -> void:
	await _fade_alpha(0.0, maxf(MIN_FADE_TIME, fade_in_time * 0.5))
	if block_input_during_transition:
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func _fade_alpha(target_a: float, time_sec: float) -> void:
	if not color_rect:
		return
	color_rect.color = transition_color
	var duration: float = maxf(MIN_FADE_TIME, time_sec)

	var audio_tween: Tween = null
	var bus_idx: int = AudioServer.get_bus_index("Master")
	var start_db: float = AudioServer.get_bus_volume_db(bus_idx)
	var end_db: float = -20.0 if target_a >= 1.0 else 0.0

	if fade_audio:
		audio_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		audio_tween.tween_method(
			func(v: float) -> void: AudioServer.set_bus_volume_db(bus_idx, v),
			start_db, end_db, minf(audio_fade_time, duration)
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(color_rect, "modulate:a", target_a, duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
