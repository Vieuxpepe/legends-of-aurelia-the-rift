extends Node2D

const HALF_CELL := 32.0

var _glow_inner: Polygon2D
var _glow_outer: Polygon2D
var _glow_ring: Polygon2D
var _asp: AnimatedSprite2D

var _pulse_t: float = 0.0
var _phase_a: float = 0.0
var _phase_b: float = 0.0
var _phase_c: float = 0.0
var _phase_d: float = 0.0


func _ready() -> void:
	_phase_a = randf() * TAU
	_phase_b = randf() * TAU
	_phase_c = randf() * TAU
	_phase_d = randf() * TAU

	_setup_underglow()
	_asp = $AnimatedSprite2D
	if _asp != null and _asp.sprite_frames != null:
		_asp.play("default")
		_asp.modulate = Color(1.22, 0.68, 0.55, 1.0)

	set_process(true)


func _rect_poly(half_ext: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half_ext, -half_ext),
		Vector2(half_ext, -half_ext),
		Vector2(half_ext, half_ext),
		Vector2(-half_ext, half_ext),
	])


func _setup_underglow() -> void:
	_glow_outer = Polygon2D.new()
	_glow_outer.name = "GlowOuter"
	_glow_outer.z_index = -3
	_glow_outer.polygon = _rect_poly(HALF_CELL + 16.0)
	_glow_outer.color = Color(0.55, 0.0, 0.08, 0.18)
	var outer_mat := CanvasItemMaterial.new()
	outer_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_outer.material = outer_mat
	add_child(_glow_outer)

	_glow_inner = Polygon2D.new()
	_glow_inner.name = "GlowInner"
	_glow_inner.z_index = -2
	_glow_inner.polygon = _rect_poly(HALF_CELL + 2.0)
	_glow_inner.color = Color(0.48, 0.0, 0.06, 0.72)
	add_child(_glow_inner)

	_glow_ring = Polygon2D.new()
	_glow_ring.name = "GlowRing"
	_glow_ring.z_index = -1
	_glow_ring.polygon = _rect_poly(HALF_CELL + 6.0)
	_glow_ring.color = Color(0.82, 0.04, 0.12, 0.34)
	var ring_mat := CanvasItemMaterial.new()
	ring_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_ring.material = ring_mat
	add_child(_glow_ring)


func _process(delta: float) -> void:
	_pulse_t += delta

	var w := 0.5 + 0.5 * sin(_pulse_t * 4.1 + _phase_a)
	if _glow_inner != null:
		_glow_inner.modulate = Color(1.0, 0.88 + 0.12 * w, 0.88 + 0.12 * w, lerpf(0.38, 0.98, w))

	var w2 := 0.5 + 0.5 * sin(_pulse_t * 2.7 + _phase_b)
	if _glow_outer != null:
		_glow_outer.modulate = Color(1.0, 1.0, 1.0, lerpf(0.12, 0.42, w2))

	var w3 := 0.5 + 0.5 * sin(_pulse_t * 3.4 + _phase_c)
	if _glow_ring != null:
		_glow_ring.modulate = Color(1.0, 0.9 + 0.1 * w3, 0.9, lerpf(0.22, 0.95, w3))
		var s: float = lerpf(0.92, 1.14, w3)
		_glow_ring.scale = Vector2(s, s)

	if _asp != null:
		var w4 := 0.5 + 0.5 * sin(_pulse_t * 5.0 + _phase_d)
		_asp.modulate = Color(lerpf(1.05, 1.35, w4), lerpf(0.58, 0.72, w4), lerpf(0.48, 0.62, w4), lerpf(0.92, 1.0, w4))
