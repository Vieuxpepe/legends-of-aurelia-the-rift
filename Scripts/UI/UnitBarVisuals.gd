extends RefCounted
class_name UnitBarVisuals
## Shared StyleBoxFlat presets for overhead tactical bars on `Unit` (HP, EXP, poise).

# Shared overhead unit-card layout tokens (kept centralized so HUD tuning propagates project-wide).
const OVERHEAD_HP_SCALE: float = 0.68
const OVERHEAD_EXP_SCALE: float = 0.58
const OVERHEAD_BAR_VISUAL_WIDTH_PX: float = 72.0
const OVERHEAD_HP_HEIGHT_PX: float = 22.0
const OVERHEAD_EXP_HEIGHT_PX: float = 16.0
const OVERHEAD_EXP_WIDTH_RATIO: float = 0.84
const OVERHEAD_TOP_MARGIN_PX: float = 112.0
const OVERHEAD_HEAD_GAP_PX: float = 3.0
const OVERHEAD_HEAD_CLEARANCE_HEIGHT_FACTOR: float = 0.06
const OVERHEAD_EXP_GAP_PX: float = 2.0


static func overhead_hp_scale() -> Vector2:
	return Vector2(OVERHEAD_HP_SCALE, OVERHEAD_HP_SCALE)


static func overhead_exp_scale() -> Vector2:
	return Vector2(OVERHEAD_EXP_SCALE, OVERHEAD_EXP_SCALE)


static func overhead_bar_visual_width_px() -> float:
	return OVERHEAD_BAR_VISUAL_WIDTH_PX


static func overhead_hp_height_px() -> float:
	return OVERHEAD_HP_HEIGHT_PX


static func overhead_exp_height_px() -> float:
	return OVERHEAD_EXP_HEIGHT_PX


static func overhead_exp_width_ratio() -> float:
	return OVERHEAD_EXP_WIDTH_RATIO


static func overhead_top_margin_px() -> float:
	return OVERHEAD_TOP_MARGIN_PX


static func overhead_head_gap_px() -> float:
	return OVERHEAD_HEAD_GAP_PX


static func overhead_head_clearance_height_factor() -> float:
	return OVERHEAD_HEAD_CLEARANCE_HEIGHT_FACTOR


static func overhead_exp_gap_px() -> float:
	return OVERHEAD_EXP_GAP_PX


static func _radius(sb: StyleBoxFlat, r: float) -> void:
	sb.set_corner_radius_all(r)


static func hp_track() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.045, 0.052, 0.068, 0.96)
	s.border_color = Color(0.28, 0.34, 0.42, 0.92)
	s.set_border_width_all(1)
	_radius(s, 6.0)
	s.content_margin_left = 2
	s.content_margin_right = 2
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 1)
	return s


static func hp_fill() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.22, 0.88, 0.48, 1.0)
	s.border_color = Color(0.04, 0.42, 0.18, 0.94)
	s.set_border_width_all(1)
	_radius(s, 5.0)
	s.shadow_color = Color(0.15, 0.85, 0.42, 0.48)
	s.shadow_size = 5
	s.shadow_offset = Vector2(0, 0)
	return s


## Trailing “lost HP” strip behind the main fill (transparent track so only one chrome ring shows).
static func hp_delay_fill() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.95, 0.32, 0.24, 0.9)
	s.border_color = Color(0.55, 0.12, 0.08, 0.55)
	s.set_border_width_all(1)
	_radius(s, 5.0)
	s.shadow_color = Color(0.85, 0.2, 0.12, 0.35)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 0)
	return s


static func exp_track() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.085, 0.065, 0.92)
	s.border_color = Color(0.48, 0.4, 0.26, 0.82)
	s.set_border_width_all(1)
	_radius(s, 5.0)
	s.content_margin_left = 2
	s.content_margin_right = 2
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	s.shadow_color = Color(0, 0, 0, 0.42)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 1)
	return s


static func exp_fill() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.96, 0.74, 0.22, 1.0)
	s.border_color = Color(0.52, 0.34, 0.06, 0.95)
	s.set_border_width_all(1)
	_radius(s, 4.0)
	s.shadow_color = Color(0.92, 0.55, 0.08, 0.45)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 0)
	return s


static func poise_track() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.065, 0.065, 0.072, 0.91)
	s.border_color = Color(0.4, 0.4, 0.45, 0.78)
	s.set_border_width_all(1)
	_radius(s, 3.0)
	s.content_margin_left = 1
	s.content_margin_right = 1
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	return s


static func poise_fill() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.98, 0.58, 0.12, 1.0)
	s.border_color = Color(0.58, 0.28, 0.04, 0.92)
	s.set_border_width_all(1)
	_radius(s, 2.0)
	s.shadow_color = Color(1.0, 0.48, 0.05, 0.35)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 0)
	return s
