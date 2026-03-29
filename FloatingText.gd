# FloatingText.gd
# Combat floaters: tiered motion (crit / heal / miss), arc rise, vertical stack via BattleField,
# soft shadow + outline, long-line first-word emphasis (BBCode), HP-chunk brightness.
# Parent mounts from BattleField._mount_floating_combat_text (level root, high z).

extends Node2D
class_name FloatingCombatText

enum Tier { NORMAL, CRIT, HEAL, MISS }

@onready var label: RichTextLabel = $Label

@export var text_to_show: String = ""
@export var text_color: Color = Color.DARK_RED
## Set from [method BattleField.spawn_loot_text] meta when relevant.
@export var tier: Tier = Tier.NORMAL
## -1 = skip ratio-based polish; else 0..1 = damage or heal portion of max HP.
@export var hp_chunk_ratio: float = -1.0

@export var rise_px: float = 44.0
@export var rise_time: float = 0.38
@export var hold_time: float = 0.18
@export var fade_time: float = 0.22
@export var scatter_amount: float = 18.0
## Extra lift for quadratic arc mid-point (world pixels).
@export var arc_lift_px: float = 22.0

@export var text_scale: float = 2.4
@export var outline_size: int = 3
@export var font_size: int = 22

@export var pop_in_scale_start: float = 0.55
@export var pop_in_duration: float = 0.12

const FIRST_WORD_LENGTH_THRESHOLD: int = 12
const MINT_OUTLINE := Color(0.48, 0.95, 0.78, 1.0)
const BIG_HIT_RATIO: float = 0.18
const BOUNCE_PEAK: float = 1.06

var _tween: Tween = null


func _ready() -> void:
	set_as_top_level(true)
	z_as_relative = false
	z_index = 4096
	scale = Vector2.ONE * text_scale
	label.scale = Vector2.ONE
	_apply_tier_preset()
	_build_label_content()
	call_deferred("_play")


func _apply_tier_preset() -> void:
	match tier:
		Tier.CRIT:
			rise_px = 58.0
			rise_time = 0.34
			scatter_amount = 24.0
			pop_in_scale_start = 0.4
			pop_in_duration = 0.09
			arc_lift_px = 30.0
		Tier.HEAL:
			rise_px = 34.0
			rise_time = 0.5
			scatter_amount = 12.0
			pop_in_scale_start = 0.74
			pop_in_duration = 0.15
			arc_lift_px = 16.0
			hold_time = 0.2
		Tier.MISS:
			rise_px = 20.0
			rise_time = 0.52
			scatter_amount = 6.0
			pop_in_scale_start = 1.0
			pop_in_duration = 0.0
			arc_lift_px = 10.0
			fade_time = 0.26
		_:
			pass


func _ratio_brightness_mod() -> float:
	if hp_chunk_ratio < 0.0:
		return 0.0
	return clampf(hp_chunk_ratio, 0.0, 1.0) * 0.42


func _heal_ratio_tint() -> Color:
	if tier != Tier.HEAL or hp_chunk_ratio < 0.0:
		return text_color
	return text_color.lerp(Color(0.85, 1.0, 0.95, 1.0), clampf(hp_chunk_ratio, 0.0, 1.0) * 0.35)


func _damage_ratio_tint() -> Color:
	if tier != Tier.NORMAL and tier != Tier.CRIT:
		return text_color
	if hp_chunk_ratio < 0.0:
		return text_color
	return text_color.lightened(_ratio_brightness_mod())


func _outline_color_for_tier() -> Color:
	if tier == Tier.HEAL:
		return MINT_OUTLINE.lerp(Color(0.2, 0.55, 0.42, 1.0), clampf(_ratio_brightness_mod() * 0.5, 0.0, 1.0))
	if tier == Tier.MISS:
		return Color(0.25, 0.25, 0.3, 1.0)
	var base_outline := Color(0.02, 0.02, 0.05, 1.0)
	if tier == Tier.CRIT or (tier == Tier.NORMAL and hp_chunk_ratio >= BIG_HIT_RATIO):
		var ratio_for_outline := hp_chunk_ratio
		if ratio_for_outline < 0.0:
			ratio_for_outline = 0.5
		return base_outline.lerp(Color(0.45, 0.1, 0.08, 1.0), clampf(ratio_for_outline, 0.0, 1.0) * 0.55)
	return base_outline


func _escape_open_brackets(s: String) -> String:
	var out := ""
	for i in s.length():
		var ch: String = s.substr(i, 1)
		if ch == "[":
			out += "[["
		else:
			out += ch
	return out


func _build_bbcode_body(raw: String) -> String:
	var first_boost: bool = raw.length() > FIRST_WORD_LENGTH_THRESHOLD
	var sp: int = raw.find(" ")
	if first_boost and sp > 0:
		var head: String = _escape_open_brackets(raw.substr(0, sp))
		var tail: String = _escape_open_brackets(raw.substr(sp))
		var big: int = maxi(font_size + 5, int(round(float(font_size) * 1.22)))
		return "[font_size=%d][b]%s[/b][/font_size]%s" % [big, head, tail]
	return _escape_open_brackets(raw)


func _build_label_content() -> void:
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var oc: Color = _outline_color_for_tier()
	var body: String = _build_bbcode_body(text_to_show)
	var display: Color = text_color
	if tier == Tier.HEAL:
		display = _heal_ratio_tint()
	elif tier == Tier.NORMAL or tier == Tier.CRIT:
		display = _damage_ratio_tint()
	modulate = display
	var oc_str: String = "#%02x%02x%02x%02x" % [
		int(clampf(oc.r * 255.0, 0.0, 255.0)),
		int(clampf(oc.g * 255.0, 0.0, 255.0)),
		int(clampf(oc.b * 255.0, 0.0, 255.0)),
		int(clampf(oc.a * 255.0, 0.0, 255.0)),
	]
	# Godot parses [outline_size] / [outline_color], not a combined [outline] tag.
	body = "[outline_size=%d][outline_color=%s]%s[/outline_color][/outline_size]" % [outline_size, oc_str, body]
	label.text = body
	label.add_theme_font_size_override("normal_font_size", font_size)
	# Soft shadow (second offset feel via theme)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.52))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)


static func _bezier_quad(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return p0 * u * u + p1 * 2.0 * u * t + p2 * t * t


func _should_peak_bounce() -> bool:
	if tier == Tier.CRIT:
		return true
	if tier == Tier.MISS or tier == Tier.HEAL:
		return false
	return hp_chunk_ratio >= BIG_HIT_RATIO


func _play() -> void:
	_kill_tween()
	var start_pos: Vector2 = global_position
	start_pos += Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
	global_position = start_pos
	modulate.a = 1.0

	var drift_x: float = randf_range(-scatter_amount, scatter_amount)
	var end_pos: Vector2 = start_pos + Vector2(drift_x, -rise_px)
	var mid: Vector2 = (start_pos + end_pos) * 0.5 + Vector2(randf_range(-10.0, 10.0), -arc_lift_px)

	if tier == Tier.MISS:
		await _play_miss_motion(start_pos)
	else:
		_tween = create_tween()
		_tween.set_parallel(true)
		_tween.tween_method(func(tt: float):
			global_position = _bezier_quad(start_pos, mid, end_pos, tt)
		, 0.0, 1.0, rise_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if pop_in_scale_start < 0.999 and pop_in_duration > 0.0:
			scale = Vector2.ONE * text_scale * pop_in_scale_start
			_tween.tween_property(self, "scale", Vector2.ONE * text_scale, pop_in_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			scale = Vector2.ONE * text_scale
		await _tween.finished
		_tween = null

	if _should_peak_bounce():
		_tween = create_tween()
		var peak: Vector2 = Vector2.ONE * text_scale * BOUNCE_PEAK
		_tween.tween_property(self, "scale", peak, 0.055).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", Vector2.ONE * text_scale, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await _tween.finished
		_tween = null

	_tween = create_tween()
	_tween.tween_interval(hold_time)
	_tween.tween_property(self, "modulate:a", 0.0, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(queue_free)


func _play_miss_motion(start_pos: Vector2) -> void:
	var dur: float = rise_time * 1.05
	_tween = create_tween()
	_tween.set_parallel(true)
	scale = Vector2.ONE * text_scale * 0.92
	_tween.tween_property(self, "scale", Vector2.ONE * text_scale, pop_in_duration + 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(tt: float):
		var shake: float = sin(tt * TAU * 9.5) * 5.5 * (1.0 - tt * 0.85)
		global_position = start_pos + Vector2(shake, -tt * rise_px * 0.65)
	, 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _tween.finished
	_tween = null


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
