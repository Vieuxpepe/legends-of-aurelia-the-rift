extends Node2D
class_name GridCursor

@onready var sprite: Sprite2D = $Sprite2D

enum CursorState { DEFAULT, HOVER_UNIT, INVALID, CONFIRM }

@export var base_scale: Vector2 = Vector2(0.10, 0.10)
@export var pulse_amount: float = 0.12 # 6% scale pulse (small looks better)
@export var bob_pixels: float = 2.0    # subtle y-bob
@export var pulse_time: float = 0.55



var _tween: Tween = null
var _state: CursorState = CursorState.DEFAULT
var _base_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	sprite.scale = base_scale
	sprite.modulate.a = 1.0
	_base_pos = sprite.position
	_play_idle_anim()

func set_state(state: CursorState) -> void:
	if state == _state:
		return
	_state = state

	_kill_tween()

	match _state:
		CursorState.DEFAULT:
			sprite.modulate = Color(1, 1, 1, 1)
			_play_idle_anim()
		CursorState.HOVER_UNIT:
			# Slightly brighter + a bit faster
			sprite.modulate = Color(1, 1, 1, 1)
			_play_idle_anim(0.45, 0.08, 2.5)
		CursorState.INVALID:
			# Dim it (no hard red required)
			sprite.modulate = Color(1, 1, 1, 0.55)
			_play_idle_anim(0.65, 0.04, 1.5)
		CursorState.CONFIRM:
			_play_confirm_pop()

func snap_to_grid(world_pos: Vector2) -> void:
	# Optional: keep your cursor crisp by snapping to whole pixels.
	# If your grid is 16/32 px, you can also snap to tile centers here.
	global_position = world_pos.round()

func _play_idle_anim(time: float = pulse_time, pulse: float = pulse_amount, bob: float = bob_pixels) -> void:
	_kill_tween()

	var s_up: Vector2 = base_scale * (1.0 + pulse)
	var s_down: Vector2 = base_scale
	var y_up: Vector2 = _base_pos + Vector2(0, -bob)
	var y_down: Vector2 = _base_pos

	_tween = create_tween()
	_tween.set_loops()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)

	# Scale
	_tween.tween_property(sprite, "scale", s_up, time)
	_tween.parallel().tween_property(sprite, "position", y_up, time)
	_tween.parallel().tween_property(sprite, "modulate:a", 0.88, time)

	_tween.tween_property(sprite, "scale", s_down, time)
	_tween.parallel().tween_property(sprite, "position", y_down, time)
	_tween.parallel().tween_property(sprite, "modulate:a", 1.0, time)

func _play_confirm_pop() -> void:
	_kill_tween()

	sprite.modulate = Color(1, 1, 1, 1)

	var s_pop: Vector2 = base_scale * 1.18
	var s_back: Vector2 = base_scale

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_BACK)
	_tween.set_ease(Tween.EASE_OUT)

	_tween.tween_property(sprite, "scale", s_pop, 0.10)
	_tween.tween_property(sprite, "scale", s_back, 0.12)

	# Return to idle after the pop
	_tween.finished.connect(func() -> void:
		if is_instance_valid(self):
			set_state(CursorState.DEFAULT)
	)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	# Reset bob baseline to avoid drift if state switches mid-loop
	sprite.position = _base_pos
