extends RefCounted

## Shared promotion rules and data mutation so Camp + Battle stay in parity.
## UI/cinematic presentation stays owned by the caller.

const UnitTraitsLib = preload("res://Scripts/Core/UnitTraitsDisplay.gd")


static func get_promotion_options(current_class: Resource) -> Array[Resource]:
	var out: Array[Resource] = []
	if current_class == null:
		return out
	var raw_options: Variant = current_class.get("promotion_options")
	if not (raw_options is Array):
		return out
	for opt in raw_options:
		if opt is Resource:
			out.append(opt)
	return out


static func can_unit_promote(unit_level: int, current_class: Resource) -> bool:
	if unit_level < 1:
		return false
	return not get_promotion_options(current_class).is_empty()


static func build_promotion_gains(advanced_class: Resource) -> Dictionary:
	if advanced_class == null:
		return {
			"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0
		}
	return {
		"hp": advanced_class.get("promo_hp_bonus") if advanced_class.get("promo_hp_bonus") != null else 0,
		"str": advanced_class.get("promo_str_bonus") if advanced_class.get("promo_str_bonus") != null else 0,
		"mag": advanced_class.get("promo_mag_bonus") if advanced_class.get("promo_mag_bonus") != null else 0,
		"def": advanced_class.get("promo_def_bonus") if advanced_class.get("promo_def_bonus") != null else 0,
		"res": advanced_class.get("promo_res_bonus") if advanced_class.get("promo_res_bonus") != null else 0,
		"spd": advanced_class.get("promo_spd_bonus") if advanced_class.get("promo_spd_bonus") != null else 0,
		"agi": advanced_class.get("promo_agi_bonus") if advanced_class.get("promo_agi_bonus") != null else 0
	}


static func resolve_current_class_from_unit_node(unit: Node2D) -> Resource:
	if unit == null:
		return null
	var cls: Variant = unit.get("active_class_data")
	return cls if cls is Resource else null


static func resolve_current_class_from_roster_unit(unit_data: Dictionary) -> Resource:
	var cls: Variant = unit_data.get("class_data")
	if cls is Resource:
		return cls
	if cls is String and ResourceLoader.exists(cls):
		var loaded: Resource = load(cls)
		unit_data["class_data"] = loaded
		return loaded
	return null


static func apply_promotion_to_unit_node(unit: Node2D, advanced_class: Resource, apply_stat_gains_cb: Callable = Callable()) -> Dictionary:
	if unit == null or advanced_class == null:
		return {}
	var old_class_name: String = str(unit.get("unit_class_name", "")).strip_edges()
	var new_class_name: String = str(advanced_class.get("job_name", "Advanced Class")).strip_edges()
	if new_class_name == "":
		new_class_name = "Advanced Class"
	var gains: Dictionary = build_promotion_gains(advanced_class)
	var new_sprite_tex: Texture2D = advanced_class.get("promoted_battle_sprite")
	var new_portrait_tex: Texture2D = advanced_class.get("promoted_portrait")

	UnitTraitsLib.grant_rookie_legacy_on_promotion(unit, old_class_name)
	UnitTraitsLib.grant_tier_class_legacy_on_promotion(unit, old_class_name, advanced_class)

	unit.active_class_data = advanced_class
	unit.unit_class_name = new_class_name
	unit.level = 1
	unit.experience = 0
	if advanced_class.get("move_range") != null:
		unit.move_range = int(advanced_class.move_range)
	if advanced_class.get("move_type") != null:
		unit.set("move_type", int(advanced_class.move_type))

	if apply_stat_gains_cb.is_valid():
		apply_stat_gains_cb.call(unit, gains)
	else:
		_apply_stat_gains_to_unit_node(unit, gains)

	unit.set("is_promoted", true)
	if unit.has_method("apply_promotion_aura"):
		unit.apply_promotion_aura()

	if new_sprite_tex != null:
		if unit.get("data") != null:
			unit.data.unit_sprite = new_sprite_tex
		var map_sprite = unit.get_node_or_null("Sprite")
		if map_sprite == null:
			map_sprite = unit.get_node_or_null("Sprite2D")
		if map_sprite != null:
			map_sprite.texture = new_sprite_tex

	if new_portrait_tex != null and unit.get("data") != null:
		unit.data.portrait = new_portrait_tex

	return {
		"old_class_name": old_class_name,
		"new_class_name": new_class_name,
		"gains": gains,
		"new_sprite_tex": new_sprite_tex,
		"new_portrait_tex": new_portrait_tex
	}


static func apply_promotion_to_roster_unit(unit_data: Dictionary, advanced_class: Resource) -> Dictionary:
	if unit_data.is_empty() or advanced_class == null:
		return {}
	var current_class: Resource = resolve_current_class_from_roster_unit(unit_data)
	var old_class_name: String = str(unit_data.get("unit_class", "")).strip_edges()
	if old_class_name == "" and current_class != null and current_class.get("job_name") != null:
		old_class_name = str(current_class.job_name).strip_edges()
	var new_class_name: String = str(advanced_class.get("job_name", "Advanced Class")).strip_edges()
	if new_class_name == "":
		new_class_name = "Advanced Class"
	var gains: Dictionary = build_promotion_gains(advanced_class)
	var new_sprite_tex: Texture2D = advanced_class.get("promoted_battle_sprite")
	var new_portrait_tex: Texture2D = advanced_class.get("promoted_portrait")

	_grant_rookie_legacy_to_roster_dict(unit_data, old_class_name)
	_grant_tier_legacy_to_roster_dict(unit_data, old_class_name, advanced_class)

	unit_data["class_data"] = advanced_class
	unit_data["unit_class"] = new_class_name
	unit_data["level"] = 1
	unit_data["experience"] = 0
	if advanced_class.get("move_range") != null:
		unit_data["move_range"] = int(advanced_class.move_range)
	if advanced_class.get("move_type") != null:
		unit_data["move_type"] = int(advanced_class.move_type)
	_apply_stat_gains_to_roster_dict(unit_data, gains)
	unit_data["is_promoted"] = true

	if new_sprite_tex != null:
		unit_data["battle_sprite"] = new_sprite_tex
		if unit_data.get("data") is Resource:
			unit_data["data"].unit_sprite = new_sprite_tex
	if new_portrait_tex != null:
		unit_data["portrait"] = new_portrait_tex
		if unit_data.get("data") is Resource:
			unit_data["data"].portrait = new_portrait_tex

	return {
		"old_class_name": old_class_name,
		"new_class_name": new_class_name,
		"gains": gains,
		"new_sprite_tex": new_sprite_tex,
		"new_portrait_tex": new_portrait_tex
	}


static func _apply_stat_gains_to_unit_node(unit: Node2D, gains: Dictionary) -> void:
	var hp_gain: int = int(gains.get("hp", 0))
	unit.max_hp += hp_gain
	unit.current_hp += hp_gain
	unit.strength += int(gains.get("str", 0))
	unit.magic += int(gains.get("mag", 0))
	unit.defense += int(gains.get("def", 0))
	unit.resistance += int(gains.get("res", 0))
	unit.speed += int(gains.get("spd", 0))
	unit.agility += int(gains.get("agi", 0))


static func _apply_stat_gains_to_roster_dict(unit_data: Dictionary, gains: Dictionary) -> void:
	var hp_gain: int = int(gains.get("hp", 0))
	unit_data["max_hp"] = int(unit_data.get("max_hp", 0)) + hp_gain
	unit_data["current_hp"] = int(unit_data.get("current_hp", 0)) + hp_gain
	unit_data["strength"] = int(unit_data.get("strength", 0)) + int(gains.get("str", 0))
	unit_data["magic"] = int(unit_data.get("magic", 0)) + int(gains.get("mag", 0))
	unit_data["defense"] = int(unit_data.get("defense", 0)) + int(gains.get("def", 0))
	unit_data["resistance"] = int(unit_data.get("resistance", 0)) + int(gains.get("res", 0))
	unit_data["speed"] = int(unit_data.get("speed", 0)) + int(gains.get("spd", 0))
	unit_data["agility"] = int(unit_data.get("agility", 0)) + int(gains.get("agi", 0))


static func _grant_rookie_legacy_to_roster_dict(unit_data: Dictionary, old_class_name: String) -> void:
	var old_job: String = old_class_name.strip_edges()
	if not UnitTraitsLib.ROOKIE_JOB_NAMES.has(old_job):
		return
	var legacy_id: String = UnitTraitsLib.legacy_id_for_rookie_job(old_job)
	if legacy_id == "":
		return
	var rookie_legacies: Array = _ensure_array_field(unit_data, "rookie_legacies")
	if not rookie_legacies.has(legacy_id):
		rookie_legacies.append(legacy_id)
	var line: String = str(UnitTraitsLib.ROOKIE_LEGACY_TRAIT_LINES.get(old_job, "")).strip_edges()
	if line == "":
		return
	var traits: Array = _ensure_array_field(unit_data, "traits")
	if not traits.has(line):
		traits.append(line)


static func _grant_tier_legacy_to_roster_dict(unit_data: Dictionary, old_class_name: String, new_class: Resource) -> void:
	var old_job: String = old_class_name.strip_edges()
	if old_job == "":
		return
	var path: String = str(new_class.resource_path)
	if path.find("AscendedClass") != -1:
		_grant_promoted_legacy_to_roster_dict(unit_data, old_job)
	elif path.find("PromotedClass") != -1:
		if UnitTraitsLib.ROOKIE_JOB_NAMES.has(old_job):
			return
		_grant_base_legacy_to_roster_dict(unit_data, old_job)


static func _grant_base_legacy_to_roster_dict(unit_data: Dictionary, old_job: String) -> void:
	if not UnitTraitsLib.BASE_CLASS_JOB_NAMES.has(old_job):
		return
	var base_legacies: Array = _ensure_array_field(unit_data, "base_class_legacies")
	var id: String = "base_" + _tier_job_slug(old_job)
	if not base_legacies.has(id):
		base_legacies.append(id)
	var line: String = str(UnitTraitsLib.BASE_LEGACY_TRAIT_LINES.get(old_job, "")).strip_edges()
	if line == "":
		line = "Legacy - %s: Training in this role still shapes your instincts in battle." % old_job
	var traits: Array = _ensure_array_field(unit_data, "traits")
	if not traits.has(line):
		traits.append(line)


static func _grant_promoted_legacy_to_roster_dict(unit_data: Dictionary, old_job: String) -> void:
	if not UnitTraitsLib.PROMOTED_LEGACY_TRAIT_LINES.has(old_job):
		return
	var promoted_legacies: Array = _ensure_array_field(unit_data, "promoted_class_legacies")
	var id: String = "promoted_" + _tier_job_slug(old_job)
	if not promoted_legacies.has(id):
		promoted_legacies.append(id)
	var line: String = str(UnitTraitsLib.PROMOTED_LEGACY_TRAIT_LINES.get(old_job, "")).strip_edges()
	if line == "":
		return
	var traits: Array = _ensure_array_field(unit_data, "traits")
	if not traits.has(line):
		traits.append(line)


static func _tier_job_slug(job_name: String) -> String:
	return job_name.strip_edges().to_lower().replace(" ", "_")


static func _ensure_array_field(dict_ref: Dictionary, key: String) -> Array:
	var existing: Variant = dict_ref.get(key, null)
	if existing is Array:
		return existing as Array
	dict_ref[key] = []
	return dict_ref[key] as Array
