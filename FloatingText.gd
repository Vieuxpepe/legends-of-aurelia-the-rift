# FloatingText.gd
# Short-lived floating combat/feedback text: pop-in, rise, hold, fade, then free.
# Used by BattleField.spawn_loot_text() and direct instantiation (text_to_show, text_color, global_position).
# Preserves: set_as_top_level(true), Label child ($Label), exports text_to_show / text_color.

extends Node2D
class_name FloatingCombatText

@onready var label: Label = $Label

@export var text_to_show: String = ""
@export var text_color: Color = Color.DARK_RED

@export var rise_px: float = 44.0
@export var rise_time: float = 0.38
@export var hold_time: float = 0.18
@export var fade_time: float = 0.22
@export var scatter_amount: float = 18.0

@export var text_scale: float = 2.4
@export var outline_size: int = 3
@export var font_size: int = 22

## Pop-in: scale from this value to 1.0 over the first part of the rise. 0 = no pop.
@export var pop_in_scale_start: float = 0.55
@export var pop_in_duration: float = 0.12

var _tween: Tween = null

func _ready() -> void:
	set_as_top_level(true)
	label.text = text_to_show
	modulate = text_color
	label.scale = Vector2.ONE * text_scale
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_font_size_override("font_size", font_size)
	call_deferred("_play")

func _play() -> void:
	_kill_tween()

	var start_pos: Vector2 = global_position
	start_pos += Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
	global_position = start_pos

	var drift_x: float = randf_range(-scatter_amount, scatter_amount)
	var end_pos: Vector2 = start_pos + Vector2(drift_x, -rise_px)

	modulate.a = 1.0
	_tween = create_tween()

	# Pop-in (scale) and rise (position) run together for a snappy read
	if pop_in_scale_start > 0.0 and pop_in_duration > 0.0:
		scale = Vector2.ONE * pop_in_scale_start
		_tween.tween_property(self, "scale", Vector2.ONE, pop_in_duration)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "global_position", end_pos, rise_time)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	_tween.tween_interval(hold_time)
	_tween.tween_property(self, "modulate:a", 0.0, fade_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	_tween.tween_callback(queue_free)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
