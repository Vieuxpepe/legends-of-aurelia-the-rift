class_name CampBehaviorZone
extends Node2D

@export var zone_type: String = ""
@export var capacity: int = 2
@export var radius: float = 32.0
@export var weight: float = 1.0
@export var face_mode: String = "center" # "center" or "outward"
@export var facing_dir: Vector2 = Vector2.RIGHT

func _enter_tree() -> void:
	add_to_group("camp_behavior_zone")
