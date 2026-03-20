class_name CampBehaviorZone
extends Node2D
## Optional children: CampActivityAnchor nodes for spawn, solo, and social staging.

@export var zone_type: String = ""
@export var capacity: int = 2
@export var radius: float = 32.0
@export var weight: float = 1.0
@export var role_tags: Array[String] = []
@export var preferred_time_blocks: Array[String] = []
@export var social_heat: float = 0.0
@export var idle_style_override: String = ""
@export var face_mode: String = "center" # "center" or "outward"
@export var facing_dir: Vector2 = Vector2.RIGHT

func _enter_tree() -> void:
	add_to_group("camp_behavior_zone")
