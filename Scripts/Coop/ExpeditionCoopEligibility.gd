class_name ExpeditionCoopEligibility
extends RefCounted

## Pure expedition co-op gate checks (DB + CampaignManager). No session state.

static func is_expedition_registered(map_id: String) -> bool:
	var key: String = str(map_id).strip_edges()
	if key == "":
		return false
	return not ExpeditionMapDatabase.get_map_by_id(key).is_empty()

static func is_coop_enabled_for_map(map_id: String) -> bool:
	var key: String = str(map_id).strip_edges()
	if key == "":
		return false
	var entry: Dictionary = ExpeditionMapDatabase.get_map_by_id(key)
	if entry.is_empty():
		return false
	return bool(entry.get("coop_enabled", false))

## Local player owns the map and DB marks it co-op capable (reuses CampaignManager).
static func local_owns_coop_eligible_expedition(map_id: String) -> bool:
	return CampaignManager.can_use_expedition_for_coop(str(map_id).strip_edges())

## Both sides must own the same chart for a shared contract (remote list from transport/guest payload).
static func can_start_coop_expedition(local_map_id: String, remote_owned_map_ids: Array) -> bool:
	return CampaignManager.can_start_coop_expedition_with_remote(str(local_map_id).strip_edges(), remote_owned_map_ids)
