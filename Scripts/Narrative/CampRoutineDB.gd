class_name CampRoutineDB

const ROUTINES: Dictionary = {
	"Kaelen": [
		{
			"id": "kaelen_watch_post_dawn",
			"priority": 10,
			"when": {
				"time_block": "dawn",
			},
			"preferred_zones": ["watch_post"],
			"secondary_zones": ["wall"],
			"movement_frequency": 1.0,
			"idle_style": "look_out",
		},
	],
	"Tamsin Reed": [
		{
			"id": "tamsin_infirmary_day",
			"priority": 8,
			"when": {
				"time_block": "day",
			},
			"preferred_zones": ["infirmary", "bench"],
			"secondary_zones": ["fire", "bench"],
			"movement_frequency": 0.78,
			"idle_style": "check_gear",
		},
	],
	"Sorrel": [
		{
			"id": "sorrel_map_table_evening",
			"priority": 7,
			"when": {
				"time_block": "night",
			},
			"preferred_zones": ["map_table"],
			"secondary_zones": ["shrine", "bench", "fire"],
			"movement_frequency": 0.68,
			"idle_style": "read_notes",
		},
	],
	"Branik": [
		{
			"id": "branik_cookfire_evening",
			"priority": 6,
			"when": {
				"time_block": "night",
			},
			"preferred_zones": ["cook_area", "fire"],
			"secondary_zones": ["supply", "bench"],
			"movement_frequency": 0.62,
			"idle_style": "warm_hands",
		},
	],
	"Darian": [
		{
			"id": "darian_fire_night",
			"priority": 6,
			"when": { "time_block": "night" },
			"preferred_zones": ["fire", "bench", "wagon"],
			"secondary_zones": ["map_table"],
			"movement_frequency": 0.6,
			"idle_style": "neutral",
		},
	],
	"Celia": [
		{
			"id": "celia_watch_dawn",
			"priority": 7,
			"when": { "time_block": "dawn" },
			"preferred_zones": ["watch_post", "bench", "supply"],
			"secondary_zones": ["wall", "infirmary", "map_table"],
			"movement_frequency": 0.78,
			"idle_style": "check_gear",
		},
	],
	"Rufus": [
		{
			"id": "rufus_workbench_day",
			"priority": 6,
			"when": { "time_block": "day" },
			"preferred_zones": ["workbench", "supply", "fire"],
			"secondary_zones": ["bench", "wagon"],
			"movement_frequency": 0.5,
			"idle_style": "tinker_small",
		},
	],
	"Inez": [
		{
			"id": "inez_tree_line_night",
			"priority": 6,
			"when": { "time_block": "night" },
			"preferred_zones": ["tree_line", "wall", "supply"],
			"secondary_zones": ["wagon"],
			"movement_frequency": 0.5,
			"idle_style": "look_out",
		},
		{
			"id": "inez_watch_dawn_scout",
			"priority": 6,
			"when": { "time_block": "dawn" },
			"preferred_zones": ["watch_post", "tree_line", "wall"],
			"secondary_zones": ["bench"],
			"movement_frequency": 0.58,
			"idle_style": "look_out",
		},
	],
	"Tariq": [
		{
			"id": "tariq_map_table_day",
			"priority": 6,
			"when": { "time_block": "day" },
			"preferred_zones": ["map_table", "bench", "wagon"],
			"secondary_zones": ["workbench", "shrine", "fire"],
			"movement_frequency": 0.62,
			"idle_style": "read_notes",
		},
	],
	"Nyx": [
		{
			"id": "nyx_workbench_day",
			"priority": 7,
			"when": { "time_block": "day" },
			"preferred_zones": ["workbench", "bench", "map_table"],
			"secondary_zones": ["fire", "wall"],
			"movement_frequency": 0.74,
			"idle_style": "inspect_wall",
		},
	],
	"Hest \"Sparks\"": [
		{
			"id": "hest_workbench_day",
			"priority": 7,
			"when": { "time_block": "day" },
			"preferred_zones": ["workbench", "supply", "fire"],
			"secondary_zones": ["bench", "map_table"],
			"movement_frequency": 0.72,
			"idle_style": "tinker_small",
		},
	],
	"Liora": [
		{
			"id": "liora_infirmary_day_active",
			"priority": 7,
			"when": { "time_block": "day" },
			"preferred_zones": ["infirmary", "shrine", "bench"],
			"secondary_zones": ["fire", "map_table"],
			"movement_frequency": 0.58,
			"idle_style": "pray_quietly",
		},
	],
	"Mira Ashdown": [
		{
			"id": "mira_tree_night_watch",
			"priority": 7,
			"when": { "time_block": "night" },
			"preferred_zones": ["tree_line", "watch_post", "bench"],
			"secondary_zones": ["wagon", "fire"],
			"movement_frequency": 0.55,
			"idle_style": "look_out",
		},
		{
			"id": "mira_watch_dawn_observe",
			"priority": 6,
			"when": { "time_block": "dawn" },
			"preferred_zones": ["watch_post", "tree_line", "bench"],
			"secondary_zones": ["infirmary"],
			"movement_frequency": 0.52,
			"idle_style": "look_out",
		},
	],
	"Pell Rowan": [
		{
			"id": "pell_watch_dawn",
			"priority": 8,
			"when": { "time_block": "dawn" },
			"preferred_zones": ["watch_post", "workbench", "supply"],
			"secondary_zones": ["wall", "bench"],
			"movement_frequency": 0.8,
			"idle_style": "check_gear",
		},
		{
			"id": "pell_workbench_day_drill",
			"priority": 7,
			"when": { "time_block": "day" },
			"preferred_zones": ["workbench", "watch_post", "supply"],
			"secondary_zones": ["wall", "bench"],
			"movement_frequency": 0.76,
			"idle_style": "check_gear",
		},
	],
	"Oren Pike": [
		{
			"id": "oren_wall_day_repairs",
			"priority": 7,
			"when": { "time_block": "day" },
			"preferred_zones": ["wall", "workbench", "supply"],
			"secondary_zones": ["wagon"],
			"movement_frequency": 0.52,
			"idle_style": "inspect_wall",
		},
	],
	"Sister Meris": [
		{
			"id": "meris_shrine_day_audit",
			"priority": 6,
			"when": { "time_block": "day" },
			"preferred_zones": ["shrine", "map_table", "bench"],
			"secondary_zones": ["infirmary", "wall"],
			"movement_frequency": 0.42,
			"idle_style": "read_notes",
		},
		{
			"id": "meris_shrine_night_vigil",
			"priority": 5,
			"when": { "time_block": "night" },
			"preferred_zones": ["shrine", "wall", "bench"],
			"secondary_zones": ["infirmary"],
			"movement_frequency": 0.36,
			"idle_style": "read_notes",
		},
	],
	"Brother Alden": [
		{
			"id": "brother_alden_infirmary_day",
			"priority": 5,
			"when": { "time_block": "day" },
			"preferred_zones": ["infirmary", "fire", "watch_post"],
			"secondary_zones": ["shrine", "bench", "fire"],
			"movement_frequency": 0.5,
			"idle_style": "pray_quietly",
		},
	],
	"Garrick Vale": [
		{
			"id": "garrick_watch_day",
			"priority": 6,
			"when": { "time_block": "day" },
			"preferred_zones": ["watch_post", "wall", "map_table"],
			"secondary_zones": ["wagon", "supply", "map_table"],
			"movement_frequency": 0.6,
			"idle_style": "look_out",
		},
	],
	"Sabine Varr": [
		{
			"id": "sabine_wall_night",
			"priority": 6,
			"when": { "time_block": "night" },
			"preferred_zones": ["wall", "watch_post", "supply"],
			"secondary_zones": ["bench", "watch_post"],
			"movement_frequency": 0.58,
			"idle_style": "inspect_wall",
		},
	],
	"Yselle Maris": [
		{
			"id": "yselle_fire_night",
			"priority": 5,
			"when": { "time_block": "night" },
			"preferred_zones": ["fire", "bench", "wagon"],
			"secondary_zones": ["map_table"],
			"movement_frequency": 0.6,
			"idle_style": "neutral",
		},
	],
	"Corvin Ash": [
		{
			"id": "corvin_wagon_night",
			"priority": 5,
			"when": { "time_block": "night" },
			"preferred_zones": ["wagon", "shrine", "bench"],
			"secondary_zones": ["map_table", "tree_line"],
			"movement_frequency": 0.45,
			"idle_style": "read_notes",
		},
		{
			"id": "corvin_map_day_annotation",
			"priority": 5,
			"when": { "time_block": "day" },
			"preferred_zones": ["map_table", "shrine", "wagon"],
			"secondary_zones": ["bench", "tree_line"],
			"movement_frequency": 0.42,
			"idle_style": "read_notes",
		},
	],
	"Veska Moor": [
		{
			"id": "veska_wall_day",
			"priority": 5,
			"when": { "time_block": "day" },
			"preferred_zones": ["wall", "watch_post", "workbench"],
			"secondary_zones": ["supply"],
			"movement_frequency": 0.45,
			"idle_style": "inspect_wall",
		},
		{
			"id": "veska_watch_night_rotation",
			"priority": 5,
			"when": { "time_block": "night" },
			"preferred_zones": ["watch_post", "wall", "supply"],
			"secondary_zones": ["bench"],
			"movement_frequency": 0.42,
			"idle_style": "inspect_wall",
		},
	],
	"Ser Hadrien": [
		{
			"id": "hadrien_shrine_night",
			"priority": 4,
			"when": { "time_block": "night" },
			"preferred_zones": ["shrine", "watch_post", "tree_line"],
			"secondary_zones": ["wall"],
			"movement_frequency": 0.3,
			"idle_style": "pray_quietly",
		},
		{
			"id": "hadrien_watch_dawn_oath",
			"priority": 4,
			"when": { "time_block": "dawn" },
			"preferred_zones": ["watch_post", "shrine", "wall"],
			"secondary_zones": ["tree_line"],
			"movement_frequency": 0.32,
			"idle_style": "pray_quietly",
		},
	],
	"Maela Thorn": [
		{
			"id": "maela_roam_dawn",
			"priority": 7,
			"when": { "time_block": "dawn" },
			"preferred_zones": ["watch_post", "tree_line", "wagon"],
			"secondary_zones": ["wall", "bench"],
			"movement_frequency": 0.9,
			"idle_style": "look_out",
		},
		{
			"id": "maela_wall_day_pacing",
			"priority": 6,
			"when": { "time_block": "day" },
			"preferred_zones": ["wall", "watch_post", "tree_line"],
			"secondary_zones": ["bench", "wagon"],
			"movement_frequency": 0.84,
			"idle_style": "look_out",
		},
	],
}

static func get_best_routine(unit_name: String, context: Dictionary) -> Dictionary:
	var key: String = str(unit_name).strip_edges()
	if key.is_empty():
		return {}
	var all_for_unit: Variant = ROUTINES.get(key, null)
	if not (all_for_unit is Array):
		return {}
	var routines: Array = all_for_unit
	var best: Dictionary = {}
	var best_priority: int = -2147483648
	for r in routines:
		if not (r is Dictionary):
			continue
		var rd: Dictionary = r
		if not _routine_matches_context(rd, context):
			continue
		var prio: int = int(rd.get("priority", 0))
		if prio > best_priority:
			best_priority = prio
			best = rd
	return best

static func _routine_matches_context(routine: Dictionary, context: Dictionary) -> bool:
	var cond: Variant = routine.get("when", {})
	if not (cond is Dictionary):
		return true
	var when_dict: Dictionary = cond
	for k in when_dict.keys():
		var expected: Variant = when_dict.get(k)
		if not context.has(k):
			return false
		var actual: Variant = context.get(k)
		if str(actual) != str(expected):
			return false
	return true

