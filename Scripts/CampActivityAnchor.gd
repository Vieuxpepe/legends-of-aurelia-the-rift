# Optional child of CampBehaviorZone: authored spot for spawn, solo motion, and social staging.
class_name CampActivityAnchor
extends Node2D

@export var anchor_role: String = ""
@export var activity_tags: String = ""
@export var facing_dir: Vector2 = Vector2.ZERO
@export var face_mode: String = ""
@export var preferred_idle_styles: Array[String] = []
@export var preferred_behavior_families: Array[String] = []
@export var occupancy_radius: float = 14.0
@export var weight: float = 1.0
@export var sit_like: bool = false
@export var kneel_like: bool = false
@export var work_like: bool = false
@export var fire_like: bool = false
@export var lookout_like: bool = false


func _enter_tree() -> void:
	add_to_group("camp_activity_anchor")
