extends Control

@export_file("*.tscn") var next_scene_path: String = "res://Scenes/main_menu.tscn"
@export var logo_texture: Texture2D
@export var studio_name: String = "ROOKTIDE GAMES"
@export var studio_tagline: String = "Forging tactical legends."
@export var fade_in_seconds: float = 0.8
@export var hold_seconds: float = 1.2
@export var fade_out_seconds: float = 0.7
@export var allow_skip: bool = true
@export var minimum_skip_delay: float = 0.25
@export_group("Scene Handoff")
@export var use_soft_scene_handoff: bool = true
@export var handoff_fade_out_seconds: float = 0.70
@export var handoff_fade_in_seconds: float = 0.95
@export var handoff_hold_black_seconds: float = 0.10
@export var handoff_from_black_no_flash: bool = true
@export_group("Atmosphere")
@export var sparkles_enabled: bool = true
@export var sparkles_count: int = 22
@export var sparkles_min_speed: float = 4.0
@export var sparkles_max_speed: float = 12.0
@export var sparkles_min_size: int = 1
@export var sparkles_max_size: int = 3
@export var sparkles_alpha_min: float = 0.25
@export var sparkles_alpha_max: float = 0.90
@export var sparkles_tint: Color = Color(0.92, 0.84, 0.52, 1.0)

@onready var logo_rect: TextureRect = $Center/Logo
@onready var title_label: Label = $Center/Title
@onready var tagline_label: Label = $Center/Tagline
@onready var skip_hint: Label = $SkipHint
@onready var sting_player: AudioStreamPlayer = $StingPlayer
@onready var backdrop: ColorRect = $Backdrop

var _intro_tween: Tween = null
var _elapsed: float = 0.0
var _is_leaving: bool = false
var _sparkle_layer: Control = null
var _sparkles: Array[ColorRect] = []
var _sparkle_velocity: Array[Vector2] = []
var _sparkle_base_alpha: Array[float] = []
var _sparkle_phase: Array[float] = []
var _sparkle_twinkle_speed: Array[float] = []
var _sparkle_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _handoff_black_rect: ColorRect = null

func _ready() -> void:
	if sting_player != null:
		sting_player.bus = "SFX"
	_sparkle_rng.randomize()
	if logo_texture != null and logo_rect != null:
		logo_rect.texture = logo_texture
	if title_label != null:
		title_label.text = studio_name
	if tagline_label != null:
		tagline_label.text = studio_tagline
	_setup_visual_state()
	_spawn_sparkles()
	_play_intro()
	if sting_player != null and sting_player.stream != null:
		sting_player.play()

func _process(delta: float) -> void:
	_elapsed += delta
	_update_sparkles(delta)

func _unhandled_input(event: InputEvent) -> void:
	if not allow_skip:
		return
	if _elapsed < minimum_skip_delay:
		return
	if event is InputEventKey and event.pressed:
		_go_next_scene()
		return
	if event is InputEventMouseButton and event.pressed:
		_go_next_scene()
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_go_next_scene()

func _setup_visual_state() -> void:
	if logo_rect != null:
		logo_rect.modulate.a = 0.0
		logo_rect.scale = Vector2(0.96, 0.96)
	if title_label != null:
		title_label.modulate.a = 0.0
		title_label.add_theme_font_size_override("font_size", 56)
		title_label.add_theme_color_override("font_color", Color(0.95, 0.79, 0.28, 1.0))
		title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		title_label.add_theme_constant_override("outline_size", 3)
	if tagline_label != null:
		tagline_label.modulate.a = 0.0
		tagline_label.add_theme_font_size_override("font_size", 24)
		tagline_label.add_theme_color_override("font_color", Color(0.83, 0.90, 0.98, 0.95))
		tagline_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		tagline_label.add_theme_constant_override("outline_size", 2)
	if skip_hint != null:
		skip_hint.visible = allow_skip
		skip_hint.modulate.a = 0.0
		skip_hint.add_theme_font_size_override("font_size", 18)
		skip_hint.add_theme_color_override("font_color", Color(0.78, 0.75, 0.70, 0.78))
		skip_hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		skip_hint.add_theme_constant_override("outline_size", 1)

func _play_intro() -> void:
	_intro_tween = create_tween()
	_intro_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if logo_rect != null:
		_intro_tween.tween_property(logo_rect, "modulate:a", 1.0, fade_in_seconds)
		_intro_tween.parallel().tween_property(logo_rect, "scale", Vector2.ONE, fade_in_seconds)
	if title_label != null:
		_intro_tween.parallel().tween_property(title_label, "modulate:a", 1.0, fade_in_seconds * 0.88)
	if tagline_label != null:
		_intro_tween.parallel().tween_property(tagline_label, "modulate:a", 1.0, fade_in_seconds)
	if skip_hint != null:
		_intro_tween.parallel().tween_property(skip_hint, "modulate:a", 0.9, fade_in_seconds * 1.1)
	_intro_tween.tween_interval(hold_seconds)
	if logo_rect != null:
		_intro_tween.tween_property(logo_rect, "modulate:a", 0.0, fade_out_seconds).set_ease(Tween.EASE_IN)
	if title_label != null:
		_intro_tween.parallel().tween_property(title_label, "modulate:a", 0.0, fade_out_seconds).set_ease(Tween.EASE_IN)
	if tagline_label != null:
		_intro_tween.parallel().tween_property(tagline_label, "modulate:a", 0.0, fade_out_seconds).set_ease(Tween.EASE_IN)
	if skip_hint != null:
		_intro_tween.parallel().tween_property(skip_hint, "modulate:a", 0.0, fade_out_seconds * 0.8).set_ease(Tween.EASE_IN)
	_intro_tween.tween_callback(_go_next_scene)

func _go_next_scene() -> void:
	if _is_leaving:
		return
	_is_leaving = true
	if _intro_tween != null:
		_intro_tween.kill()
	if next_scene_path.is_empty():
		next_scene_path = "res://Scenes/main_menu.tscn"
	# Hard no-flash path: force black fade-out, then black fade-in across scene swap.
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
		# Prefer persistent autoload overlay to avoid 1-frame clear-color flashes between scenes.
		if Engine.has_singleton("SceneTransition") and SceneTransition.has_method("change_scene_from_black"):
			SceneTransition.change_scene_from_black(
				next_scene_path,
				0.0,
				handoff_hold_black_seconds
			)
			return
		# Fallback: manual handoff metadata + direct change.
		get_tree().change_scene_to_file(next_scene_path)
	)

func _spawn_sparkles() -> void:
	if not sparkles_enabled:
		return
	var count: int = maxi(0, sparkles_count)
	if count <= 0:
		return
	_sparkle_layer = Control.new()
	_sparkle_layer.name = "SparkleLayer"
	_sparkle_layer.layout_mode = 1
	_sparkle_layer.anchors_preset = Control.PRESET_FULL_RECT
	_sparkle_layer.anchor_right = 1.0
	_sparkle_layer.anchor_bottom = 1.0
	_sparkle_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparkle_layer.z_index = 1
	add_child(_sparkle_layer)
	if backdrop != null:
		move_child(_sparkle_layer, get_child_count() - 1)
		move_child(backdrop, 0)
	if has_node("Center"):
		var center_node: Node = get_node("Center")
		move_child(center_node, get_child_count() - 1)
	if has_node("SkipHint"):
		var skip_node: Node = get_node("SkipHint")
		move_child(skip_node, get_child_count() - 1)
	if sting_player != null:
		move_child(sting_player, get_child_count() - 1)

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
		var vel := Vector2(
			_sparkle_rng.randf_range(-6.0, 6.0),
			_sparkle_rng.randf_range(sparkles_min_speed, maxf(sparkles_min_speed, sparkles_max_speed))
		)
		_sparkle_velocity.append(vel)
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
