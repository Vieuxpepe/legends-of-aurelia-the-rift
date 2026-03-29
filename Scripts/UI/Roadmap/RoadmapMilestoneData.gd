extends Resource
class_name RoadmapMilestoneData

@export var phase: String = "MILESTONE 01"
@export var title: String = "Roadmap Item"
@export var eta: String = "UPCOMING"
@export_enum("COMPLETED", "IN_PROGRESS", "PLANNED") var status: String = "PLANNED"
@export_multiline var summary: String = ""
@export_range(0.0, 1.0, 0.01) var progress_to_next: float = 0.0
