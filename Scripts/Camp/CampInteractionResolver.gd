# CampInteractionResolver.gd
# Resolves which interaction opens for a walker (same priority order as legacy _open_dialogue).

class_name CampInteractionResolver
extends RefCounted

var _explore: Node2D
var _ctx: CampContext
var _dialogue: CampDialogueController
var _requests: CampRequestController


func _init(explore: Node2D, ctx: CampContext, dialogue: CampDialogueController, requests: CampRequestController) -> void:
	_explore = explore
	_ctx = ctx
	_dialogue = dialogue
	_requests = requests


func get_camp_request_status() -> String:
	return _requests.get_camp_request_status()


## Mirrors `open_dialogue` resolution without opening UI or mutating request state (except reads).
func peek_walker_interaction_kind(walker_node: Node) -> String:
	if walker_node == null or not (walker_node is CampRosterWalker):
		return "none"
	var cm: Variant = CampaignManager
	var w: CampRosterWalker = walker_node as CampRosterWalker
	var unit_name: String = w.unit_name
	var unit_data: Variant = w.unit_data.get("data", null)
	var status: String = get_camp_request_status()
	var giver: String = str(cm.camp_request_giver_name).strip_edges() if cm else ""
	if status == "failed" and unit_name == giver:
		return "request_failed"
	if status == "ready_to_turn_in" and unit_name == giver:
		return "request_turn_in"
	if status == "active" and unit_name == giver and cm and str(cm.camp_request_type) == CampRequestDB.TYPE_ITEM_DELIVERY:
		var have: int = _requests.count_camp_request_items(_requests.get_camp_request_item_identifier())
		if have >= int(cm.camp_request_target_amount):
			return "request_turn_in"
	if status == "active" and unit_name == giver:
		return "request_progress"
	if status == "active" and cm and str(cm.camp_request_type) == CampRequestDB.TYPE_TALK_TO_UNIT:
		var target: String = str(cm.camp_request_target_name).strip_edges()
		if unit_name == target and int(cm.camp_request_progress) == 0:
			var payload_chk: Dictionary = cm.camp_request_payload if cm.camp_request_payload is Dictionary else {}
			if payload_chk.get("branching_check") == true:
				return "request_branching"
			return "request_target_talk"
	if status != "active" and status != "ready_to_turn_in" and status != "failed" and CampaignManager and unit_name != "":
		var tier: String = CampaignManager.get_avatar_relationship_tier(unit_name)
		for scene_tier in ["close", "trusted"]:
			var scene: Dictionary = CampRequestContentDB.get_special_camp_scene(unit_name, scene_tier)
			if not scene.is_empty() and not scene.get("lines", []).is_empty():
				var tier_ok: bool = (scene_tier == "close" and tier in ["close", "bonded"]) or (scene_tier == "trusted" and tier in ["trusted", "close", "bonded"])
				if tier_ok and not (scene.get("one_time", true) and CampaignManager.has_seen_special_scene(unit_name, scene_tier)):
					return "special_scene"
		if not CampaignManager.get_available_pair_scene_for_unit(unit_name).is_empty():
			return "pair_snippet"
		if not CampaignManager.get_available_camp_lore(unit_name).is_empty():
			return "lore"
	if _requests.offer_giver_name == unit_name:
		return "request_offer"
	return "idle_talk"


func get_interact_prompt_primary_line(nearest: Node, eligible_pair: Dictionary) -> String:
	if nearest != null and would_single_walker_priority(nearest):
		var kind: String = peek_walker_interaction_kind(nearest)
		match kind:
			"request_failed":
				return "E  Hear them out"
			"request_turn_in":
				return "E  Turn in"
			"request_progress":
				return "E  Quest update"
			"request_target_talk", "request_branching":
				return "E  Quest: speak"
			"special_scene":
				return "E  Talk"
			"pair_snippet":
				return "E  Talk"
			"lore":
				return "E  Talk"
			"request_offer":
				return "E  Request offered"
			_:
				return "E  Talk"
	if not eligible_pair.is_empty():
		return "E  Listen"
	if nearest != null:
		return "E  Talk"
	return ""


func would_single_walker_priority(nearest: Node) -> bool:
	if nearest == null or not (nearest is CampRosterWalker):
		return false
	var unit_name: String = (nearest as CampRosterWalker).unit_name
	var status: String = get_camp_request_status()
	var giver: String = str(CampaignManager.camp_request_giver_name).strip_edges() if CampaignManager else ""
	if status == "failed" and unit_name == giver:
		return true
	if status == "ready_to_turn_in" and unit_name == giver:
		return true
	if status == "active" and unit_name == giver:
		return true
	if status == "active" and CampaignManager and str(CampaignManager.camp_request_type) == CampRequestDB.TYPE_ITEM_DELIVERY and unit_name == giver:
		return true
	if status == "active" and CampaignManager and str(CampaignManager.camp_request_type) == CampRequestDB.TYPE_TALK_TO_UNIT:
		var target: String = str(CampaignManager.camp_request_target_name).strip_edges()
		if unit_name == target:
			return true
	if status != "active" and status != "ready_to_turn_in" and status != "failed" and CampaignManager and unit_name != "":
		var tier: String = CampaignManager.get_avatar_relationship_tier(unit_name)
		for scene_tier in ["close", "trusted"]:
			var scene: Dictionary = CampRequestContentDB.get_special_camp_scene(unit_name, scene_tier)
			if not scene.is_empty() and not scene.get("lines", []).is_empty():
				var tier_ok: bool = (scene_tier == "close" and tier in ["close", "bonded"]) or (scene_tier == "trusted" and tier in ["trusted", "close", "bonded"])
				if tier_ok and not (scene.get("one_time", true) and CampaignManager.has_seen_special_scene(unit_name, scene_tier)):
					return true
		if CampaignManager.get_available_pair_scene_for_unit(unit_name).is_empty() == false:
			return true
		if CampaignManager.get_available_camp_lore(unit_name).is_empty() == false:
			return true
	if _requests.offer_giver_name == unit_name:
		return true
	return false


func open_dialogue(walker_node: Node) -> void:
	var cm: Variant = CampaignManager
	_dialogue.begin_dialogue_session(walker_node)
	var unit_name: String = "Unit"
	var unit_data: Variant = null
	if walker_node is CampRosterWalker:
		var w: CampRosterWalker = walker_node as CampRosterWalker
		unit_name = w.unit_name
		unit_data = w.unit_data.get("data", null)
	var status: String = get_camp_request_status()
	var giver: String = str(cm.camp_request_giver_name).strip_edges() if cm else ""
	if status == "failed" and unit_name == giver:
		_dialogue.show_failed_reaction(walker_node, unit_name, giver)
		_requests.clear_camp_request_state()
		_requests.update_request_markers()
		return
	if status == "ready_to_turn_in" and unit_name == giver:
		_dialogue.show_turn_in_panel(walker_node, unit_name, unit_data)
		return
	if status == "active" and unit_name == giver and str(cm.camp_request_type) == CampRequestDB.TYPE_ITEM_DELIVERY:
		var have: int = _requests.count_camp_request_items(_requests.get_camp_request_item_identifier())
		if have >= cm.camp_request_target_amount:
			CampaignManager.camp_request_status = "ready_to_turn_in"
			_requests.update_request_markers()
			_dialogue.show_turn_in_panel(walker_node, unit_name, unit_data)
			return
	if status == "active" and unit_name == giver:
		_dialogue.show_progress_panel(walker_node, unit_name, unit_data)
		return
	if status == "active" and str(cm.camp_request_type) == CampRequestDB.TYPE_TALK_TO_UNIT:
		var target: String = str(cm.camp_request_target_name).strip_edges()
		if unit_name == target and int(cm.camp_request_progress) == 0:
			var payload: Dictionary = cm.camp_request_payload if cm.camp_request_payload is Dictionary else {}
			if payload.get("branching_check") == true:
				_dialogue.start_branching_check(walker_node, unit_name, unit_data, giver)
				return
			CampaignManager.camp_request_progress = 1
			CampaignManager.camp_request_status = "ready_to_turn_in"
			_requests.update_request_markers()
			_dialogue.show_talk_complete_return(walker_node, unit_name, giver)
			return
	if status != "active" and status != "ready_to_turn_in" and status != "failed" and CampaignManager and unit_name != "":
		var tier: String = CampaignManager.get_avatar_relationship_tier(unit_name)
		for scene_tier in ["close", "trusted"]:
			var scene: Dictionary = CampRequestContentDB.get_special_camp_scene(unit_name, scene_tier)
			if scene.is_empty() or scene.get("lines", []).is_empty():
				continue
			var tier_ok: bool = (scene_tier == "close" and tier in ["close", "bonded"]) or (scene_tier == "trusted" and tier in ["trusted", "close", "bonded"])
			if not tier_ok:
				continue
			if scene.get("one_time", true) and CampaignManager.has_seen_special_scene(unit_name, scene_tier):
				continue
			_dialogue.show_special_camp_scene(walker_node, unit_name, unit_data, scene, scene_tier)
			return
	if CampaignManager:
		var pair_scene: Dictionary = CampaignManager.get_available_pair_scene_for_unit(unit_name)
		if not pair_scene.is_empty():
			var other_name: String = unit_name
			var a_name: String = str(pair_scene.get("unit_a", "")).strip_edges()
			var b_name: String = str(pair_scene.get("unit_b", "")).strip_edges()
			if unit_name == a_name and b_name != "":
				other_name = "%s & %s" % [unit_name, b_name]
			elif unit_name == b_name and a_name != "":
				other_name = "%s & %s" % [unit_name, a_name]
			_dialogue.show_pair_scene_snippet(walker_node, unit_name, other_name, pair_scene)
			return
	if CampaignManager:
		var lore: Dictionary = CampaignManager.get_available_camp_lore(unit_name)
		if not lore.is_empty():
			_dialogue.show_lore_snippet(walker_node, unit_name, lore)
			return
	if _requests.offer_giver_name == unit_name and _requests.pending_offer.is_empty():
		var roster_names: Array = []
		for w in _ctx.walker_nodes:
			if w is CampRosterWalker:
				roster_names.append((w as CampRosterWalker).unit_name)
		var item_names: Array = _requests.get_requestable_item_names()
		var giver_tier: String = CampaignManager.get_avatar_relationship_tier(unit_name) if CampaignManager else ""
		var personal_eligible: bool = CampaignManager.is_personal_quest_eligible(unit_name) if CampaignManager else false
		_requests.pending_offer = CampRequestDB.get_offer(unit_name, CampRequestDB.get_personality(unit_data, unit_name), roster_names, item_names, status == "active" or status == "ready_to_turn_in", giver_tier, personal_eligible)
		_requests.offer_is_personal = str(_requests.pending_offer.get("request_depth", "")).strip_edges().to_lower() == "personal"
	if not _requests.pending_offer.is_empty() and _requests.offer_giver_name == unit_name:
		_dialogue.show_offer_panel(walker_node, unit_name, unit_data, _requests.pending_offer)
		return
	_dialogue.show_idle_talk(walker_node, unit_name, unit_data)
