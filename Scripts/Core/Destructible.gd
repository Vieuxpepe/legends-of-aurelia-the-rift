extends Node2D
class_name Destructible

signal died(node: Node2D, killer: Node2D)

@export var object_name: String = "Wooden Crate"
@export var max_hp: int = 15

@export var min_gold_drop: int = 0
@export var max_gold_drop: int = 0
@export var drop_loot: Array[Resource] = []

@export var death_sound: AudioStream

# FE-ish feedback tuning
@export var hit_flash_time: float = 0.08
@export var hit_shake_px: float = 3.0
@export var hit_shake_time: float = 0.10
@export var death_fade_time: float = 0.22
@export var death_scale_time: float = 0.18

var current_hp: int
var _dying: bool = false

# Stats placeholders (so it works with your existing combat logic)
var strength: int = 0
var magic: int = 0
var defense: int = 0
var resistance: int = 0
var speed: int = -50
var agility: int = -50
var equipped_weapon = null
var unit_name: String = ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var death_sound_player: AudioStreamPlayer = $DeathSound

func _ready() -> void:
	current_hp = max_hp
	unit_name = object_name
	sprite.position = Vector2(32, 32)
	sprite.modulate = Color.WHITE
	sprite.visible = true

func take_damage(amount: int, attacker: Node = null) -> void:
	if _dying:
		return

	amount = max(0, amount)
	current_hp -= amount

	_play_hit_feedback()

	if current_hp <= 0:
		_dying = true
		emit_signal("died", self, attacker)
		await _play_death_feedback()
		queue_free()

func _play_hit_feedback() -> void:
	# Flash
	var flash := create_tween()
	flash.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), hit_flash_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flash.tween_property(sprite, "modulate", Color.WHITE, hit_flash_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Micro shake (local)
	var start_pos: Vector2 = position
	var dx: float = randf_range(-hit_shake_px, hit_shake_px)
	var dy: float = randf_range(-hit_shake_px, hit_shake_px)

	var shake := create_tween()
	shake.tween_property(self, "position", start_pos + Vector2(dx, dy), hit_shake_time * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shake.tween_property(self, "position", start_pos, hit_shake_time * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _play_death_feedback() -> void:
	# Hide sprite *after* a tiny death anim feels better than instantly.
	var death := create_tween().set_parallel(true)

	# Fade out
	death.tween_property(sprite, "modulate:a", 0.0, death_fade_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Shrink slightly (break effect)
	death.tween_property(sprite, "scale", sprite.scale * 0.75, death_scale_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	await death.finished

	# Sound after visual pop (or swap order if you prefer)
	if death_sound != null and death_sound_player != null:
		death_sound_player.stream = death_sound
		death_sound_player.pitch_scale = randf_range(0.9, 1.1)
		death_sound_player.play()
		await death_sound_player.finished
