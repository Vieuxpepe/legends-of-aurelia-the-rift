extends Resource
class_name SupportData

@export var partner_name: String = "" # Who is this conversation with? (e.g., "Stranger")

@export_group("Rank C")
@export var points_for_c: int = 10
@export_multiline var c_dialogue: Array[String] = []

@export_group("Rank B")
@export var points_for_b: int = 25
@export_multiline var b_dialogue: Array[String] = []

@export_group("Rank A")
@export var points_for_a: int = 45
@export_multiline var a_dialogue: Array[String] = []
