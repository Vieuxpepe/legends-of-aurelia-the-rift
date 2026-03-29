# Builds locked mock co-op command detachment lists from campaign roster (same ordering as BattleField.load_campaign_data spawn loop).
# Command IDs match BattleField.get_relationship_id (custom avatar → "Avatar"; others → unit_name).
class_name MockCoopDetachmentAssignment
extends RefCounted

const RULE_FIRST_HALF_LOCAL_CEIL_LOCKED: String = "first_half_local_ceil_locked"


static func command_unit_id_from_roster_entry(unit_dict: Dictionary) -> String:
	var un: String = str(unit_dict.get("unit_name", unit_dict.get("name", ""))).strip_edges()
	var av_name: String = str(CampaignManager.custom_avatar.get("name", "")).strip_edges()
	var av_unit: String = str(CampaignManager.custom_avatar.get("unit_name", "")).strip_edges()
	if un != "" and ((av_name != "" and un == av_name) or (av_unit != "" and un == av_unit)):
		return "Avatar"
	if un == "":
		return ""
	return un


static func command_unit_id_from_dragon(dragon: Dictionary) -> String:
	var dn: String = str(dragon.get("name", "Dragon")).strip_edges()
	return dn if dn != "" else "Dragon"


static func build_ordered_command_unit_ids_from_campaign() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for u in CampaignManager.get_available_roster():
		var id: String = command_unit_id_from_roster_entry(u)
		if id != "":
			out.append(id)
	for dragon in DragonManager.player_dragons:
		if int(dragon.get("stage", 0)) >= 3:
			out.append(command_unit_id_from_dragon(dragon))
	return out


static func display_label_for_command_unit_id(command_id: String) -> String:
	var key: String = str(command_id).strip_edges()
	if key == "Avatar":
		return CampaignManager.get_player_display_name("Commander")
	return key


## Payload fragment for expedition launch + battle handoff (JSON-serializable arrays).
static func build_handoff_payload_dict() -> Dictionary:
	var ordered: PackedStringArray = build_ordered_command_unit_ids_from_campaign()
	var n: int = ordered.size()
	var k: int = MockCoopBattleContext.mock_coop_local_command_slot_count(n)
	var ord_arr: Array = []
	var loc_arr: Array = []
	var par_arr: Array = []
	for i in range(n):
		var s: String = str(ordered[i])
		ord_arr.append(s)
		if i < k:
			loc_arr.append(s)
		else:
			par_arr.append(s)
	return {
		"rule": RULE_FIRST_HALF_LOCAL_CEIL_LOCKED,
		"ordered_command_unit_ids": ord_arr,
		"local_command_unit_ids": loc_arr,
		"partner_command_unit_ids": par_arr,
	}
