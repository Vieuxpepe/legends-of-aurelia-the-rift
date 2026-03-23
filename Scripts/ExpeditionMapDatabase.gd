class_name ExpeditionMapDatabase
extends RefCounted

# Lightweight, data-driven map catalog used by tavern/cartographer and world map.
## Max expedition entries shown at the Cartographer counter at once (subset of progression-eligible maps). Clamped to >= 1 in getter.
static var cartographer_max_visible_offers: int = 2

static var expedition_maps: Array[Dictionary] = [
	{
		"id": "exp_map_shattered_sanctum",
		"display_name": "Shattered Sanctum Survey",
		"description": "A torn chart of collapsed sanctum routes. Opens a sanctioned expedition path.",
		"world_map_contract_label": "Cartographer Contract",
		"world_map_hazard_pitch": "Charted Hazard: Broken sanctum routes and unstable ruins.",
		"price": 320,
		"rarity": "Rare",
		"coop_enabled": true,
		"consumable": false,
		## If false, expedition cannot be relaunched after a successful clear (completion tracked in CampaignManager).
		"repeatable": true,
		"world_node_id": "ExpeditionNodeShatteredSanctum",
		"battle_scene_path": "res://Scenes/Levels/Level3.tscn",
		"battle_id": "shattered_sanctum_expedition",
		## Machine id for future battle hooks; copied to CampaignManager while an expedition run is active.
		"expedition_modifier_id": "unstable_sanctum_routing",
		## Player-facing contract modifier line (Cartographer, world map, battle log).
		"expedition_modifier_summary": "Survey contract — unstable sanctum routing; expect broken sight lines and partial cover.",
		"recommended_level": 3,
		"danger_tier": 2,
		"reward_tags": ["relics", "sanctum", "cooperative_route"],
		## Cartographer survey lines; one is chosen at random on first expedition clear and persisted (CampaignManager).
		"outcome_annotations": [
			"Route verified",
			"Sanctum unstable",
			"Relics stripped",
			"Patrol presence confirmed",
			"Unsafe for standard passage"
		]
	}
]

static func get_all_maps() -> Array[Dictionary]:
	return expedition_maps.duplicate(true)

static func get_map_by_id(map_id: String) -> Dictionary:
	var key: String = str(map_id).strip_edges()
	if key == "":
		return {}

	for entry in expedition_maps:
		if str(entry.get("id", "")) == key:
			return entry.duplicate(true)

	return {}

static func get_cartographer_max_visible_offers() -> int:
	return maxi(1, int(cartographer_max_visible_offers))

## Progression-eligible expedition maps (recommended_level gate). Full set before Cartographer rotation (CampaignManager).
static func get_cartographer_eligible_maps(current_level_index: int = 0) -> Array[Dictionary]:
	var stock: Array[Dictionary] = []
	var unlock_threshold: int = max(1, int(current_level_index) + 1)

	for entry in expedition_maps:
		var rec_level: int = int(entry.get("recommended_level", 1))
		if rec_level <= unlock_threshold:
			stock.append(entry.duplicate(true))

	if stock.is_empty():
		for entry in expedition_maps:
			stock.append(entry.duplicate(true))

	return stock

## Legacy name: same as get_cartographer_eligible_maps (rotation applied in CampaignManager.get_expedition_cartographer_shop_entries).
static func get_cartographer_stock(current_level_index: int = 0) -> Array[Dictionary]:
	return get_cartographer_eligible_maps(current_level_index)

static func get_world_node_requirements() -> Dictionary:
	var requirements: Dictionary = {}
	for entry in expedition_maps:
		var world_node_id: String = str(entry.get("world_node_id", "")).strip_edges()
		var map_id: String = str(entry.get("id", "")).strip_edges()
		if world_node_id == "" or map_id == "":
			continue
		requirements[world_node_id] = map_id
	return requirements

static func build_world_map_short_title(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	var contract: String = str(entry.get("world_map_contract_label", "Cartographer Contract")).strip_edges()
	var disp: String = str(entry.get("display_name", "Expedition")).strip_edges()
	if contract == "":
		return disp
	if disp == "":
		return contract
	return "%s: %s" % [contract, disp]

static func build_world_map_tooltip_text(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	var lines: PackedStringArray = []
	var head: String = build_world_map_short_title(entry)
	if head != "":
		lines.append(head)
	var hazard: String = str(entry.get("world_map_hazard_pitch", "")).strip_edges()
	if hazard != "":
		lines.append(hazard)
	var mod_line: String = build_expedition_modifier_ui_line(entry)
	if mod_line != "":
		lines.append(mod_line)
	var desc: String = str(entry.get("description", "")).strip_edges()
	if desc != "":
		lines.append(desc)
	lines.append("Not a main story objective — chart purchased from the Grand Tavern Cartographer.")
	return "\n".join(lines)

static func build_world_map_hover_announcement(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	var short_t: String = build_world_map_short_title(entry)
	var hazard: String = str(entry.get("world_map_hazard_pitch", "")).strip_edges()
	if hazard != "":
		return "%s — %s" % [short_t, hazard]
	return short_t

static func is_entry_repeatable(entry: Dictionary) -> bool:
	if entry.is_empty():
		return true
	return bool(entry.get("repeatable", true))

static func get_expedition_modifier_id(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	return str(entry.get("expedition_modifier_id", "")).strip_edges()

## Single-line UI / combat log text from DB fields (empty if no modifier data).
static func build_expedition_modifier_ui_line(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	var mid: String = get_expedition_modifier_id(entry)
	var summ: String = str(entry.get("expedition_modifier_summary", "")).strip_edges()
	if summ != "":
		if mid != "":
			return "Contract modifier (%s): %s" % [mid, summ]
		return "Contract modifier: %s" % summ
	if mid != "":
		return "Contract modifier: %s" % mid.replace("_", " ")
	return ""

static func append_expedition_modifier_hover_suffix(entry: Dictionary) -> String:
	var line: String = build_expedition_modifier_ui_line(entry)
	if line == "":
		return ""
	var short: String = str(entry.get("expedition_modifier_summary", "")).strip_edges()
	if short != "" and short.length() > 72:
		short = short.left(69) + "..."
	if short != "":
		return " — %s" % short
	var mid: String = get_expedition_modifier_id(entry)
	if mid != "":
		return " — %s" % mid.replace("_", " ")
	return ""

static func get_outcome_annotation_pool(entry: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if entry.is_empty():
		return out
	var raw: Variant = entry.get("outcome_annotations", [])
	if typeof(raw) != TYPE_ARRAY:
		return out
	for v in raw:
		var s: String = str(v).strip_edges()
		if s != "":
			out.append(s)
	return out

## Extra line for tooltip when the expedition has been cleared (world map builds base text first).
static func append_completion_tooltip_line(entry: Dictionary, completed: bool) -> String:
	if entry.is_empty() or not completed:
		return ""
	if is_entry_repeatable(entry):
		return "\nStatus: Cleared — repeatable contract."
	return "\nStatus: Contract fulfilled."

## Short suffix for hover announcement after base expedition text.
static func append_completion_hover_suffix(entry: Dictionary, completed: bool) -> String:
	if entry.is_empty() or not completed:
		return ""
	if is_entry_repeatable(entry):
		return " — Cleared (repeatable)."
	return " — Contract fulfilled."

static func append_outcome_annotation_tooltip_line(note: String) -> String:
	var n: String = str(note).strip_edges()
	if n == "":
		return ""
	return "\nSurvey: %s" % n

static func append_outcome_annotation_hover_suffix(note: String) -> String:
	var n: String = str(note).strip_edges()
	if n == "":
		return ""
	return " — Survey: %s" % n

## One owned-chart block for the Grand Tavern Cartographer ledger (plain text; RichTextLabel-safe).
static func build_cartographer_ledger_entry(map_id: String, completed: bool, outcome_note: String = "") -> String:
	var key: String = str(map_id).strip_edges()
	var entry: Dictionary = get_map_by_id(key) if key != "" else {}
	var title: String = ""
	if entry.is_empty():
		title = "Unknown chart (%s)" % key
	else:
		title = build_world_map_short_title(entry)
		if title == "":
			title = str(entry.get("display_name", key)).strip_edges()
		if title == "":
			title = key
	var hazard_line: String = ""
	if not entry.is_empty():
		var h: String = str(entry.get("world_map_hazard_pitch", "")).strip_edges()
		if h != "":
			hazard_line = "\n  " + h
	var run_status: String = "Completed" if completed else "Not completed"
	var contract_kind: String = "Repeatable" if (entry.is_empty() or is_entry_repeatable(entry)) else "One-time"
	var base: String = "• %s%s\n  Run status: %s | Contract: %s" % [title, hazard_line, run_status, contract_kind]
	var mod_ui: String = build_expedition_modifier_ui_line(entry)
	if mod_ui != "":
		base += "\n  %s" % mod_ui
	if completed:
		var on: String = str(outcome_note).strip_edges()
		if on != "":
			return base + "\n  Survey: %s" % on
	return base

