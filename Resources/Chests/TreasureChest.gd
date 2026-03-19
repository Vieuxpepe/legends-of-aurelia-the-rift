extends Node2D
class_name TreasureChest

signal opened(node: Node2D, opener: Node2D)

@export var object_name: String = "Treasure Chest"
@export var is_locked: bool = true
@export var loot_table: Array[Resource] = []

# Necessary for the UI panel checks
var current_hp: int = 1 
var max_hp: int = 1
var unit_name: String = ""

@onready var sprite = $Sprite2D
@onready var open_sound = $OpenSound

func _ready() -> void:
	unit_name = object_name
	sprite.position = Vector2(32, 32)

func open_chest(opener: Node2D) -> void:
	emit_signal("opened", self, opener)
	is_locked = false
	
func play_open_effect() -> void:
	is_locked = false # Ensure it is marked as unlocked
	
	if open_sound.stream != null:
		open_sound.play()
		
	var tween = create_tween()
	# Fade out and scale up slightly for a satisfying "pop"
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(self, "scale", Vector2(1.2, 1.2), 0.5)
	
	# Wait for the animation and sound to finish before deleting the node
	await tween.finished
	if open_sound.playing:
		await open_sound.finished
		
	queue_free()	
