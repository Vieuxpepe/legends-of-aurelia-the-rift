extends Node2D
class_name GridCursor

@onready var sprite: Sprite2D = $Sprite2D

enum CursorState { DEFAULT, MOVE, ATTACK, INVALID, INSPECT, CONFIRM }

@export var base_scale: Vector2 = Vector2(1.0, 1.0)
@export var tile_size: Vector2 = Vector2(64, 64)
@export var tile_center_nudge: Vector2 = Vector2.ZERO
@export var pulse_amount: float = 0.08
@export var bob_pixels: float = 1.6
@export var pulse_time: float = 0.62
@export var render_z_default: int = 96
@export var render_z_boosted: int = 122
@export var frame_margin_px: float = 1.0



var _tween: Tween = null
var _state: CursorState = CursorState.DEFAULT
var _base_pos: Vector2 = Vector2.ZERO
var _effective_scale: Vector2 = Vector2.ONE
var _size_mult: float = 1.0
var _high_contrast: bool = false
var _occluded: bool = false
var _frame_color: Color = Color(1.0, 1.0, 1.0, 0.92)
var _frame_shadow_color: Color = Color(0.05, 0.04, 0.03, 0.58)
var _frame_border_px: float = 2.0
var _sprite_tint: Color = Color.WHITE

func _ready() -> void:
	# Keep cursor centered on the hovered tile even if old scene offsets exist.
	sprite.offset = Vector2.ZERO
	sprite.position = (tile_size * 0.5) + tile_center_nudge
	z_as_relative = false
	z_index = render_z_default
	_base_pos = sprite.position
	_refresh_visual_profile()
	sprite.scale = _effective_scale
	_play_idle_anim()
	queue_redraw()

func set_state(state: CursorState) -> void:
	if state == _state:
		return
	_state = state

	_kill_tween()
	_refresh_visual_profile()
	queue_redraw()

	match _state:
		CursorState.DEFAULT:
			_play_idle_anim()
		CursorState.MOVE:
			_play_idle_anim(0.43, 0.13, 2.2)
		CursorState.ATTACK:
			_play_idle_anim(0.34, 0.17, 2.8)
		CursorState.INVALID:
			_play_idle_anim(0.74, 0.045, 1.1)
		CursorState.INSPECT:
			_play_idle_anim(0.50, 0.11, 2.0)
		CursorState.CONFIRM:
			_play_confirm_pop()

func set_state_by_name(name: String) -> void:
	match name.to_upper():
		"MOVE":
			set_state(CursorState.MOVE)
		"ATTACK":
			set_state(CursorState.ATTACK)
		"INVALID":
			set_state(CursorState.INVALID)
		"INSPECT":
			set_state(CursorState.INSPECT)
		"CONFIRM":
			set_state(CursorState.CONFIRM)
		_:
			set_state(CursorState.DEFAULT)

func set_occluded(is_occluded: bool) -> void:
	if _occluded == is_occluded:
		return
	_occluded = is_occluded
	z_index = render_z_boosted if _occluded else render_z_default
	_refresh_visual_profile()
	queue_redraw()

func apply_accessibility(size_multiplier: float, high_contrast: bool) -> void:
	var clamped_mult := clampf(size_multiplier, 0.75, 1.8)
	var changed := not is_equal_approx(_size_mult, clamped_mult) or _high_contrast != high_contrast
	_size_mult = clamped_mult
	_high_contrast = high_contrast
	if changed:
		_refresh_visual_profile()
		_play_idle_anim()
		queue_redraw()

func snap_to_grid(world_pos: Vector2) -> void:
	# Optional: keep your cursor crisp by snapping to whole pixels.
	# If your grid is 16/32 px, you can also snap to tile centers here.
	global_position = world_pos.round()

func _play_idle_anim(time: float = pulse_time, pulse: float = pulse_amount, bob: float = bob_pixels) -> void:
	_kill_tween()

	var s_up: Vector2 = _effective_scale * (1.0 + pulse)
	var s_down: Vector2 = _effective_scale
	var y_up: Vector2 = _base_pos + Vector2(0, -bob)
	var y_down: Vector2 = _base_pos

	_tween = create_tween()
	_tween.set_loops()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)

	# Scale
	_tween.tween_property(sprite, "scale", s_up, time)
	_tween.parallel().tween_property(sprite, "position", y_up, time)
	_tween.parallel().tween_property(sprite, "modulate:a", maxf(_sprite_tint.a - 0.08, 0.42), time)

	_tween.tween_property(sprite, "scale", s_down, time)
	_tween.parallel().tween_property(sprite, "position", y_down, time)
	_tween.parallel().tween_property(sprite, "modulate:a", _sprite_tint.a, time)

func _play_confirm_pop() -> void:
	_kill_tween()

	sprite.modulate = _sprite_tint

	var s_pop: Vector2 = _effective_scale * 1.22
	var s_back: Vector2 = _effective_scale

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

func _refresh_visual_profile() -> void:
	_effective_scale = base_scale * _size_mult
	var outline_base: float = 1.55
	var tint: Color = Color.WHITE
	var frame: Color = Color(0.84, 0.82, 0.77, 0.34)
	var shadow: Color = Color(0.05, 0.04, 0.03, 0.44)
	match _state:
		CursorState.MOVE:
			tint = Color(0.62, 0.97, 1.0, 0.95)
			frame = Color(0.56, 0.94, 1.0, 0.42)
			outline_base = 1.7
		CursorState.ATTACK:
			tint = Color(1.0, 0.48, 0.40, 0.96)
			frame = Color(1.0, 0.36, 0.30, 0.46)
			outline_base = 1.95
		CursorState.INVALID:
			tint = Color(0.88, 0.84, 0.78, 0.65)
			frame = Color(0.80, 0.74, 0.66, 0.36)
			outline_base = 1.45
		CursorState.INSPECT:
			tint = Color(1.0, 0.90, 0.42, 0.95)
			frame = Color(1.0, 0.88, 0.34, 0.42)
			outline_base = 1.75
		CursorState.CONFIRM:
			tint = Color(1.0, 0.96, 0.70, 0.98)
			frame = Color(1.0, 0.94, 0.64, 0.50)
			outline_base = 2.0
		_:
			tint = Color(0.96, 0.95, 0.92, 0.92)
			frame = Color(0.84, 0.82, 0.77, 0.34)
			outline_base = 1.55

	if _high_contrast:
		tint = Color(minf(tint.r + 0.08, 1.0), minf(tint.g + 0.08, 1.0), minf(tint.b + 0.08, 1.0), maxf(tint.a, 0.96))
		frame = Color(minf(frame.r + 0.08, 1.0), minf(frame.g + 0.08, 1.0), minf(frame.b + 0.08, 1.0), 1.0)
		shadow = Color(0.0, 0.0, 0.0, 0.90)
		outline_base += 1.2

	if _occluded:
		frame.a = minf(frame.a + 0.08, 1.0)
		tint.a = minf(tint.a + 0.06, 1.0)
		outline_base += 1.0

	_sprite_tint = tint
	_frame_color = frame
	_frame_shadow_color = shadow
	_frame_border_px = outline_base
	sprite.modulate = _sprite_tint
	sprite.scale = _effective_scale

func _draw() -> void:
	var inset := frame_margin_px
	var rect := Rect2(Vector2(inset, inset), tile_size - Vector2(inset * 2.0, inset * 2.0))
	if _high_contrast or _occluded:
		var shadow_rect := rect.grow(1.1)
		draw_rect(shadow_rect, _frame_shadow_color, false, _frame_border_px + 0.8)
	draw_rect(rect, _frame_color, false, _frame_border_px)
	if _high_contrast:
		draw_rect(rect.grow(-3.0), Color(0.04, 0.04, 0.04, 0.75), false, maxf(1.5, _frame_border_px * 0.42))
