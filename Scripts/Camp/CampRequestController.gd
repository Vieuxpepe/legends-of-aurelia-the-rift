# CampRequestController.gd
# Camp request persistence, offer selection inputs, markers, accept/decline/turn-in, inventory helpers.

class_name CampRequestController
extends RefCounted

var _explore: Node2D
var _ctx: CampContext

var offer_giver_name: String = ""
var offer_is_personal: bool = false
var pending_offer: Dictionary = {}


func _init(explore: Node2D, ctx: CampContext) -> void:
	_explore = explore
	_ctx = ctx


func get_camp_request_status() -> String:
	if not CampaignManager:
		return ""
	return str(CampaignManager.camp_request_status).strip_edges().to_lower()


func clear_camp_request_state() -> void:
	if not CampaignManager:
		return
	var was_personal: bool = false
	var giver: String = str(CampaignManager.camp_request_giver_name).strip_edges()
	if CampaignManager.camp_request_payload is Dictionary and giver != "":
		was_personal = str(CampaignManager.camp_request_payload.get("request_depth", "")).strip_edges().to_lower() == "personal"
	CampaignManager.camp_request_status = ""
	CampaignManager.camp_request_giver_name = ""
	CampaignManager.camp_request_type = ""
	CampaignManager.camp_request_title = ""
	CampaignManager.camp_request_description = ""
	CampaignManager.camp_request_target_name = ""
	CampaignManager.camp_request_target_amount = 0
	CampaignManager.camp_request_progress = 0
	CampaignManager.camp_request_reward_gold = 0
	CampaignManager.camp_request_reward_affinity = 0
	CampaignManager.camp_request_payload = {}
	if was_personal and giver != "":
		CampaignManager.set_personal_quest_active(giver, false)


func get_camp_request_item_identifier() -> String:
	if not CampaignManager:
		return ""
	var payload: Dictionary = CampaignManager.camp_request_payload if CampaignManager.camp_request_payload is Dictionary else {}
	var stored: Variant = payload.get("item_display_name", null)
	if stored != null and str(stored).strip_edges() != "":
		return str(stored).strip_edges()
	return str(CampaignManager.camp_request_target_name).strip_edges()


func validate_camp_request_roster() -> void:
	var status: String = get_camp_request_status()
	if status != "active" and status != "ready_to_turn_in" and status != "failed":
		return
	var names: Array = []
	for w in _ctx.walker_nodes:
		if w is CampRosterWalker:
			names.append((w as CampRosterWalker).unit_name)
	var giver: String = str(CampaignManager.camp_request_giver_name).strip_edges()
	if giver != "" and giver not in names:
		clear_camp_request_state()
		return
	if status == "failed":
		return
	if str(CampaignManager.camp_request_type) == CampRequestDB.TYPE_TALK_TO_UNIT:
		var target: String = str(CampaignManager.camp_request_target_name).strip_edges()
		if target != "" and target not in names:
			clear_camp_request_state()


func update_request_markers() -> void:
	var cm: Variant = CampaignManager
	var status: String = get_camp_request_status()
	var giver: String = str(cm.camp_request_giver_name).strip_edges() if cm else ""
	var req_type: String = str(cm.camp_request_type).strip_edges() if cm else ""
	var target_name: String = str(cm.camp_request_target_name).strip_edges() if cm else ""
	var has_active_or_ready: bool = (status == "active" or status == "ready_to_turn_in" or status == "failed")
	for w in _ctx.walker_nodes:
		if not (w is CampRosterWalker):
			continue
		var walker: CampRosterWalker = w as CampRosterWalker
		if status == "ready_to_turn_in" and walker.unit_name == giver:
			walker.request_marker = "turn_in"
		elif status == "failed" and walker.unit_name == giver:
			walker.request_marker = "request_failed"
		elif status == "active" and req_type == CampRequestDB.TYPE_TALK_TO_UNIT and target_name != "" and walker.unit_name == target_name:
			walker.request_marker = "request_target"
		elif status == "active" and giver != "" and walker.unit_name == giver:
			walker.request_marker = "request_progress"
		elif not has_active_or_ready and offer_giver_name != "" and walker.unit_name == offer_giver_name:
			walker.request_marker = "offer_personal" if offer_is_personal else "offer"
		else:
			walker.request_marker = "none"


func add_giver_to_recent(giver_name: String) -> void:
	if not CampaignManager or giver_name.is_empty():
		return
	var recent_list: Array = CampaignManager.camp_request_recent_givers.duplicate()
	if giver_name in recent_list:
		recent_list.erase(giver_name)
	recent_list.push_front(giver_name)
	while recent_list.size() > 3:
		recent_list.pop_back()
	CampaignManager.camp_request_recent_givers = recent_list


func get_requestable_item_names() -> Array:
	var out: Array = []
	if not ItemDatabase:
		return out
	for item in ItemDatabase.master_item_pool:
		if item == null:
			continue
		var name_str: String = get_item_display_name_camp(item)
		if name_str == "Unknown" or name_str.is_empty():
			continue
		if item is MaterialData or item is ConsumableData:
			out.append(name_str)
	return out


func get_item_display_name_camp(item: Variant) -> String:
	if item == null:
		return "Unknown"
	var wn: Variant = item.get("weapon_name")
	if wn != null and str(wn).strip_edges() != "":
		return str(wn).strip_edges()
	var iname: Variant = item.get("item_name")
	if iname != null and str(iname).strip_edges() != "":
		return str(iname).strip_edges()
	return "Unknown"


func count_camp_request_items(item_name: String) -> int:
	var total: int = 0
	for item in CampaignManager.global_inventory:
		if item != null and get_item_display_name_camp(item) == item_name:
			total += 1
	for unit_data in CampaignManager.player_roster:
		var inv_raw: Variant = unit_data.get("inventory", [])
		var inv: Array = inv_raw if inv_raw is Array else []
		for item in inv:
			if item != null and get_item_display_name_camp(item) == item_name:
				total += 1
	return total


func remove_camp_request_items(item_name: String, amount: int) -> int:
	var removed: int = 0
	for i in range(CampaignManager.global_inventory.size() - 1, -1, -1):
		if removed >= amount:
			break
		var item: Variant = CampaignManager.global_inventory[i]
		if item != null and get_item_display_name_camp(item) == item_name:
			CampaignManager.global_inventory.remove_at(i)
			removed += 1
	for unit_data in CampaignManager.player_roster:
		if removed >= amount:
			break
		var inv_raw: Variant = unit_data.get("inventory", [])
		var inv: Array = inv_raw if inv_raw is Array else []
		for i in range(inv.size() - 1, -1, -1):
			if removed >= amount:
				break
			var item: Variant = inv[i]
			if item != null and get_item_display_name_camp(item) == item_name:
				if unit_data.get("equipped_weapon") == item:
					unit_data["equipped_weapon"] = null
				inv.remove_at(i)
				removed += 1
	return removed


func on_accept_pressed(current_walker: Node, dialogue_text: Control) -> void:
	if pending_offer.is_empty() or not CampaignManager or current_walker == null:
		return
	CampaignManager.camp_request_status = "active"
	var unit_name_accept: String = (current_walker as CampRosterWalker).unit_name if current_walker is CampRosterWalker else ""
	CampaignManager.camp_request_giver_name = unit_name_accept
	CampaignManager.camp_request_type = str(pending_offer.get("type", ""))
	CampaignManager.camp_request_title = str(pending_offer.get("title", ""))
	CampaignManager.camp_request_description = str(pending_offer.get("description", ""))
	CampaignManager.camp_request_target_name = str(pending_offer.get("target_name", ""))
	CampaignManager.camp_request_target_amount = int(pending_offer.get("target_amount", 0))
	CampaignManager.camp_request_progress = 0
	CampaignManager.camp_request_reward_gold = int(pending_offer.get("reward_gold", 0))
	CampaignManager.camp_request_reward_affinity = int(pending_offer.get("reward_affinity", 0))
	var payload: Dictionary = pending_offer.get("payload", {}).duplicate()
	if CampaignManager.camp_request_type == CampRequestDB.TYPE_ITEM_DELIVERY:
		payload["item_display_name"] = CampaignManager.camp_request_target_name
	payload["request_depth"] = str(pending_offer.get("request_depth", "normal")).strip_edges().to_lower()
	CampaignManager.camp_request_payload = payload
	if payload.get("request_depth") == "personal" and CampaignManager and unit_name_accept != "":
		CampaignManager.set_personal_quest_active(unit_name_accept, true)
	var unit_data_accept: Variant = (current_walker as CampRosterWalker).unit_data.get("data", null) if current_walker is CampRosterWalker else null
	var personality_accept: String = CampRequestDB.get_personality(unit_data_accept, unit_name_accept)
	var accepted_line: String = CampRequestDB.get_line("accepted", personality_accept, pending_offer, 0, unit_name_accept)
	add_giver_to_recent(unit_name_accept)
	offer_giver_name = ""
	pending_offer = {}
	update_request_markers()
	if dialogue_text is RichTextLabel:
		var rtl: RichTextLabel = dialogue_text as RichTextLabel
		rtl.bbcode_enabled = false
		rtl.text = accepted_line
	elif dialogue_text is Label:
		(dialogue_text as Label).text = accepted_line


func on_decline_pressed(current_walker: Node, dialogue_text: Control) -> void:
	if current_walker == null:
		pending_offer = {}
		return
	var unit_name_decline: String = (current_walker as CampRosterWalker).unit_name if current_walker is CampRosterWalker else ""
	var unit_data_decline: Variant = (current_walker as CampRosterWalker).unit_data.get("data", null) if current_walker is CampRosterWalker else null
	var personality_decline: String = CampRequestDB.get_personality(unit_data_decline, unit_name_decline)
	var declined_line: String = CampRequestDB.get_line("declined", personality_decline, pending_offer, 0, unit_name_decline)
	if CampaignManager and unit_name_decline != "":
		CampaignManager.camp_request_unit_next_eligible_level[unit_name_decline] = CampaignManager.camp_request_progress_level + 1
	add_giver_to_recent(unit_name_decline)
	pending_offer = {}
	if dialogue_text is RichTextLabel:
		var rtl_d: RichTextLabel = dialogue_text as RichTextLabel
		rtl_d.bbcode_enabled = false
		rtl_d.text = declined_line
	elif dialogue_text is Label:
		(dialogue_text as Label).text = declined_line


## Returns false if dialogue should close (failure / invalid); true if turn-in completed and UI updated.
func apply_turn_in(current_walker: Node, dialogue_text: Control) -> bool:
	if not CampaignManager:
		return false
	var req_type: String = CampaignManager.camp_request_type
	var target_name: String = get_camp_request_item_identifier()
	var target_amount: int = CampaignManager.camp_request_target_amount
	if req_type == CampRequestDB.TYPE_ITEM_DELIVERY:
		var have: int = count_camp_request_items(target_name)
		if have < target_amount:
			return false
		var removed: int = remove_camp_request_items(target_name, target_amount)
		if removed < target_amount:
			return false
	var giver_name: String = str(CampaignManager.camp_request_giver_name).strip_edges()
	var completed_before: int = int(CampaignManager.camp_requests_completed_by_unit.get(giver_name, 0))
	var reward_g: int = CampaignManager.camp_request_reward_gold
	var reward_a: int = CampaignManager.camp_request_reward_affinity
	var first_time_bonus: int = 15 if completed_before == 0 else 0
	reward_g += first_time_bonus
	CampaignManager.global_gold += reward_g
	if giver_name != "":
		CampaignManager.camp_request_unit_next_eligible_level[giver_name] = CampaignManager.camp_request_progress_level + 2
		CampaignManager.camp_requests_completed_by_unit[giver_name] = completed_before + 1
	var unit_name_turnin: String = ""
	var personality_turnin: String = "neutral"
	if current_walker is CampRosterWalker:
		var w: CampRosterWalker = current_walker as CampRosterWalker
		unit_name_turnin = w.unit_name
		var ud: Variant = w.unit_data.get("data", null)
		personality_turnin = CampRequestDB.get_personality(ud, unit_name_turnin)
	var is_branching: bool = false
	var request_depth: String = "normal"
	if CampaignManager.camp_request_payload is Dictionary:
		is_branching = CampaignManager.camp_request_payload.get("branching_check") == true
		request_depth = str(CampaignManager.camp_request_payload.get("request_depth", "normal")).strip_edges().to_lower()
	if giver_name != "":
		CampaignManager.record_avatar_request_completed(giver_name, is_branching, request_depth)
		if request_depth == "personal":
			CampaignManager.mark_personal_quest_completed(giver_name)
	var completed_data: Dictionary = {"type": CampaignManager.camp_request_type, "request_depth": request_depth}
	var completed_line: String = CampRequestDB.get_line("completed", personality_turnin, completed_data, completed_before + 1, unit_name_turnin)
	var reward_feedback: String = "Received %d gold." % reward_g
	if first_time_bonus > 0:
		reward_feedback += " (First-time bonus: +%d gold.)" % first_time_bonus
	if reward_a > 0:
		reward_feedback += " Favor noted."
	if giver_name != "":
		reward_feedback += " Relationship improved with %s." % giver_name
	if dialogue_text is RichTextLabel:
		var rtl_t: RichTextLabel = dialogue_text as RichTextLabel
		rtl_t.bbcode_enabled = false
		rtl_t.text = completed_line + "\n\n" + reward_feedback
	elif dialogue_text is Label:
		(dialogue_text as Label).text = completed_line + "\n\n" + reward_feedback
	clear_camp_request_state()
	update_request_markers()
	return true
