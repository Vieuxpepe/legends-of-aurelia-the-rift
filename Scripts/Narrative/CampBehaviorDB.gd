class_name CampBehaviorDB

const DEFAULT_PROFILE: Dictionary = {
	"preferred_zones": ["fire", "bench", "supply"],
	"secondary_zones": ["wagon"],
	"movement_frequency": 0.5,
	"idle_style": "neutral",
}

const PROFILES: Dictionary = {
	"Kaelen": {
		"preferred_zones": ["watch_post"],
		"secondary_zones": [],
		"movement_frequency": 1.0,
		"idle_style": "look_out",
	},
	"Nyx": {
		"preferred_zones": ["tree_line", "wagon", "supply"],
		"secondary_zones": ["fire", "bench"],
		"movement_frequency": 0.6,
		"idle_style": "look_out",
	},
	"Liora": {
		"preferred_zones": ["infirmary", "shrine", "fire"],
		"secondary_zones": ["bench"],
		"movement_frequency": 0.5,
		"idle_style": "pray_quietly",
	},
	"Branik": {
		"preferred_zones": ["cook_area", "fire", "supply"],
		"secondary_zones": ["bench"],
		"movement_frequency": 0.4,
		"idle_style": "warm_hands",
	},
	"Sorrel": {
		"preferred_zones": ["map_table", "bench"],
		"secondary_zones": ["fire", "shrine"],
		"movement_frequency": 0.5,
		"idle_style": "read_notes",
	},
	"Hest \"Sparks\"": {
		"preferred_zones": ["workbench", "supply"],
		"secondary_zones": ["wagon", "fire"],
		"movement_frequency": 0.7,
		"idle_style": "tinker_small",
	},
	"Tamsin Reed": {
		"preferred_zones": ["infirmary", "fire"],
		"secondary_zones": ["bench"],
		"movement_frequency": 0.5,
		"idle_style": "check_gear",
	},
	"Oren Pike": {
		"preferred_zones": ["workbench", "supply", "wall"],
		"secondary_zones": ["wagon"],
		"movement_frequency": 0.4,
		"idle_style": "inspect_wall",
	},
	"Mira Ashdown": {
		"preferred_zones": ["tree_line"],
		"secondary_zones": ["fire"],
		"movement_frequency": 0.5,
		"idle_style": "look_out",
	},
	"Sister Meris": {
		"preferred_zones": ["shrine", "map_table"],
		"secondary_zones": ["bench", "infirmary"],
		"movement_frequency": 0.4,
		"idle_style": "read_notes",
	},
	"Darian": {
		"preferred_zones": ["fire", "bench", "wagon"],
		"secondary_zones": ["map_table"],
		"movement_frequency": 0.6,
		"idle_style": "neutral",
	},
	"Celia": {
		"preferred_zones": ["watch_post", "bench", "supply"],
		"secondary_zones": ["wall", "infirmary"],
		"movement_frequency": 0.7,
		"idle_style": "check_gear",
	},
	"Rufus": {
		"preferred_zones": ["workbench", "supply", "fire"],
		"secondary_zones": ["bench", "wagon"],
		"movement_frequency": 0.5,
		"idle_style": "tinker_small",
	},
	"Inez": {
		"preferred_zones": ["tree_line", "wall", "supply"],
		"secondary_zones": ["wagon"],
		"movement_frequency": 0.5,
		"idle_style": "look_out",
	},
	"Tariq": {
		"preferred_zones": ["map_table", "bench", "wagon"],
		"secondary_zones": ["workbench", "shrine"],
		"movement_frequency": 0.5,
		"idle_style": "read_notes",
	},
	"Pell Rowan": {
		"preferred_zones": ["watch_post", "workbench", "supply"],
		"secondary_zones": ["wall", "bench"],
		"movement_frequency": 0.8,
		"idle_style": "check_gear",
	},
	"Brother Alden": {
		"preferred_zones": ["infirmary", "fire", "watch_post"],
		"secondary_zones": ["shrine", "bench"],
		"movement_frequency": 0.4,
		"idle_style": "pray_quietly",
	},
	"Garrick Vale": {
		"preferred_zones": ["watch_post", "wall", "map_table"],
		"secondary_zones": ["wagon", "supply"],
		"movement_frequency": 0.5,
		"idle_style": "look_out",
	},
	"Sabine Varr": {
		"preferred_zones": ["wall", "watch_post", "supply"],
		"secondary_zones": ["bench"],
		"movement_frequency": 0.5,
		"idle_style": "inspect_wall",
	},
	"Yselle Maris": {
		"preferred_zones": ["fire", "bench", "wagon"],
		"secondary_zones": ["map_table"],
		"movement_frequency": 0.6,
		"idle_style": "neutral",
	},
	"Corvin Ash": {
		"preferred_zones": ["wagon", "shrine", "bench"],
		"secondary_zones": ["map_table", "tree_line"],
		"movement_frequency": 0.45,
		"idle_style": "read_notes",
	},
	"Veska Moor": {
		"preferred_zones": ["wall", "watch_post", "workbench"],
		"secondary_zones": ["supply"],
		"movement_frequency": 0.45,
		"idle_style": "inspect_wall",
	},
	"Ser Hadrien": {
		"preferred_zones": ["shrine", "watch_post", "tree_line"],
		"secondary_zones": ["wall"],
		"movement_frequency": 0.3,
		"idle_style": "pray_quietly",
	},
	"Maela Thorn": {
		"preferred_zones": ["watch_post", "tree_line", "wagon"],
		"secondary_zones": ["wall", "bench"],
		"movement_frequency": 0.9,
		"idle_style": "look_out",
	},
}

static func get_profile(unit_name: String) -> Dictionary:
	var key: String = str(unit_name).strip_edges()
	if key.is_empty():
		return DEFAULT_PROFILE.duplicate()
	var p: Variant = PROFILES.get(key, null)
	if p is Dictionary:
		return (p as Dictionary).duplicate()
	return DEFAULT_PROFILE.duplicate()
