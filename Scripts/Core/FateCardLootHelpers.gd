extends RefCounted

const FateCardCatalog = preload("res://Scripts/FateCardCatalog.gd")
const FateCardLootData = preload("res://Resources/FateCardLootData.gd")

const GAMBLER_STATE_KEY: String = "tavern_gambler"
const CARD_LOOT_RESOURCE_DIR: String = "res://Resources/FateCardLoot/"
const DEFAULT_ENEMY_CARD_DROP_CHANCE: float = 0.03
const ELITE_ENEMY_CARD_DROP_CHANCE: float = 0.08
const BOSS_ENEMY_CARD_DROP_CHANCE: float = 0.14


static func is_fate_card_loot(item: Resource) -> bool:
	return item is FateCardLootData and str((item as FateCardLootData).card_id).strip_edges() != ""


static func roll_enemy_fate_card_drop(enemy_unit: Node2D) -> FateCardLootData:
	var missing_ids: Array[String] = _get_missing_card_ids()
	if missing_ids.is_empty():
		return null
	var chance: float = _compute_enemy_drop_chance(enemy_unit)
	if randf() > chance:
		return null
	var picked_id: String = _pick_weighted_card_id(missing_ids)
	if picked_id == "":
		return null
	return _load_fate_card_loot_resource(picked_id)


static func apply_fate_card_unlock(item: Resource, save_now: bool = true) -> Dictionary:
	if not is_fate_card_loot(item):
		return {"unlocked": false, "duplicate": false, "card_id": "", "card_name": ""}
	var loot: FateCardLootData = item as FateCardLootData
	var card_id: String = str(loot.card_id).strip_edges()
	var card: Dictionary = FateCardCatalog.get_card(card_id)
	if card.is_empty():
		return {"unlocked": false, "duplicate": false, "card_id": card_id, "card_name": card_id}
	if CampaignManager == null:
		return {"unlocked": false, "duplicate": false, "card_id": card_id, "card_name": str(card.get("name", card_id))}
	if not (CampaignManager.npc_relationships is Dictionary):
		CampaignManager.npc_relationships = {}

	var state: Dictionary = {}
	var raw_state: Variant = CampaignManager.npc_relationships.get(GAMBLER_STATE_KEY, {})
	if raw_state is Dictionary:
		state = (raw_state as Dictionary).duplicate(true)
	if state.is_empty():
		state = {
			"cards_owned_ids": _normalize_owned_card_ids([]),
			"cards_active_slots": ["", "", ""],
			"cards_active_ids": []
		}

	var owned_ids: Array[String] = _normalize_owned_card_ids(state.get("cards_owned_ids", []))
	if owned_ids.has(card_id):
		return {"unlocked": false, "duplicate": true, "card_id": card_id, "card_name": str(card.get("name", card_id))}

	owned_ids.append(card_id)
	state["cards_owned_ids"] = owned_ids
	if not state.has("cards_active_slots") or not (state.get("cards_active_slots") is Array):
		state["cards_active_slots"] = ["", "", ""]
	if not state.has("cards_active_ids") or not (state.get("cards_active_ids") is Array):
		state["cards_active_ids"] = []
	CampaignManager.npc_relationships[GAMBLER_STATE_KEY] = state
	if save_now and CampaignManager.has_method("save_current_progress"):
		CampaignManager.save_current_progress()
	return {"unlocked": true, "duplicate": false, "card_id": card_id, "card_name": str(card.get("name", card_id))}


static func get_fate_card_loot_label(item: Resource) -> String:
	if not is_fate_card_loot(item):
		return "Fate Card"
	var loot: FateCardLootData = item as FateCardLootData
	var name: String = str(loot.card_name).strip_edges()
	if name == "":
		var card: Dictionary = FateCardCatalog.get_card(str(loot.card_id))
		name = str(card.get("name", loot.card_id)).strip_edges()
	return name if name != "" else "Fate Card"


static func _compute_enemy_drop_chance(enemy_unit: Node2D) -> float:
	if enemy_unit == null:
		return DEFAULT_ENEMY_CARD_DROP_CHANCE
	var chance: float = DEFAULT_ENEMY_CARD_DROP_CHANCE
	var inferred_boss: bool = false
	var inferred_elite: bool = false
	var raw_name: Variant = enemy_unit.get("unit_name")
	var name_lc: String = str(raw_name if raw_name != null else "").to_lower()
	for token in ["boss", "duke", "lord", "adjudicator", "witness", "preceptor", "auditor", "captain"]:
		if name_lc.find(token) != -1:
			inferred_boss = true
			break
	if not inferred_boss and name_lc.find("elite") != -1:
		inferred_elite = true
	var tags_raw: Variant = enemy_unit.get("unit_tags")
	if tags_raw is Array:
		for tag_v in tags_raw as Array:
			var tag_lc: String = str(tag_v).to_lower()
			if tag_lc.find("boss") != -1:
				inferred_boss = true
			elif tag_lc.find("elite") != -1:
				inferred_elite = true
	var raw_level: Variant = enemy_unit.get("level")
	var lvl: int = int(raw_level if raw_level != null else 1)
	var level_bonus: float = clampf((float(lvl) - 1.0) * 0.002, 0.0, 0.03)
	if inferred_boss:
		chance = BOSS_ENEMY_CARD_DROP_CHANCE
	elif inferred_elite:
		chance = ELITE_ENEMY_CARD_DROP_CHANCE
	else:
		chance = DEFAULT_ENEMY_CARD_DROP_CHANCE
	return clampf(chance + level_bonus, 0.0, 0.30)


static func _pick_weighted_card_id(card_ids: Array[String]) -> String:
	if card_ids.is_empty():
		return ""
	var total_weight: float = 0.0
	var weighted: Array[Dictionary] = []
	for cid in card_ids:
		var card: Dictionary = FateCardCatalog.get_card(cid)
		if card.is_empty():
			continue
		var rarity: String = str(card.get("rarity", "common")).to_lower()
		var w: float = 1.0
		match rarity:
			"rare":
				w = 0.70
			"epic":
				w = 0.48
			"legendary":
				w = 0.30
			_:
				w = 1.0
		total_weight += w
		weighted.append({"id": cid, "w": w})
	if weighted.is_empty():
		return card_ids[0]
	var roll: float = randf() * total_weight
	var acc: float = 0.0
	for entry in weighted:
		acc += float(entry.get("w", 0.0))
		if roll <= acc:
			return str(entry.get("id", ""))
	return str(weighted[weighted.size() - 1].get("id", ""))


static func _get_missing_card_ids() -> Array[String]:
	var owned: Array[String] = _normalize_owned_card_ids(_read_owned_card_ids())
	var missing: Array[String] = []
	for card_any in FateCardCatalog.get_all_cards():
		var card: Dictionary = card_any
		var cid: String = str(card.get("id", "")).strip_edges()
		if cid == "":
			continue
		if not owned.has(cid):
			missing.append(cid)
	return missing


static func _read_owned_card_ids() -> Variant:
	if CampaignManager == null:
		return []
	if not (CampaignManager.npc_relationships is Dictionary):
		return []
	var raw_state: Variant = CampaignManager.npc_relationships.get(GAMBLER_STATE_KEY, {})
	if raw_state is Dictionary:
		return (raw_state as Dictionary).get("cards_owned_ids", [])
	return []


static func _normalize_owned_card_ids(raw_ids: Variant) -> Array[String]:
	var catalog_ids: Dictionary = {}
	for card_any in FateCardCatalog.get_all_cards():
		var card: Dictionary = card_any
		var cid: String = str(card.get("id", "")).strip_edges()
		if cid != "":
			catalog_ids[cid] = true
	var normalized: Array[String] = []
	if raw_ids is Array:
		for id_v in raw_ids as Array:
			var cid: String = str(id_v).strip_edges()
			if cid == "" or not catalog_ids.has(cid):
				continue
			if not normalized.has(cid):
				normalized.append(cid)
	if normalized.is_empty():
		var starter: String = FateCardCatalog.STARTER_CARD_ID.strip_edges()
		if starter != "":
			normalized.append(starter)
	return normalized


static func _load_fate_card_loot_resource(card_id: String) -> FateCardLootData:
	var clean_id: String = card_id.strip_edges().to_lower()
	if clean_id == "":
		return null
	var res_path: String = CARD_LOOT_RESOURCE_DIR + clean_id + ".tres"
	if ResourceLoader.exists(res_path):
		var base: FateCardLootData = load(res_path) as FateCardLootData
		if base != null:
			if CampaignManager != null and CampaignManager.has_method("duplicate_item"):
				var dup: Resource = CampaignManager.duplicate_item(base)
				if dup is FateCardLootData:
					return dup as FateCardLootData
			return base.duplicate(true) as FateCardLootData
	return _build_runtime_fallback_loot(clean_id)


static func _build_runtime_fallback_loot(card_id: String) -> FateCardLootData:
	var card: Dictionary = FateCardCatalog.get_card(card_id)
	if card.is_empty():
		return null
	var loot := FateCardLootData.new()
	loot.card_id = card_id
	loot.card_name = str(card.get("name", card_id))
	loot.card_rarity = str(card.get("rarity", "common"))
	loot.item_name = "Fate Card: " + loot.card_name
	loot.description = "Permanent Fate Deck unlock.\nUnlocks card: " + loot.card_name + "."
	loot.rarity = "Mythic"
	var portrait_path: String = str(card.get("portrait_path", "")).strip_edges()
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		loot.icon = load(portrait_path) as Texture2D
	return loot
