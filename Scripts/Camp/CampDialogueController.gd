# CampDialogueController.gd
# Dialogue panel UI, branching choices, pair scene line playback, close/continue behavior.

class_name CampDialogueController
extends RefCounted

const CAMP_PAIR_SCENE_TRIGGER_DB = preload("res://Scripts/Narrative/CampPairSceneTriggerDB.gd")
const PAIR_LISTEN_RADIUS: float = 120.0

var _explore: Node2D
var _ctx: CampContext
var _requests: CampRequestController

var dialogue_panel: PanelContainer
var dialogue_name: Label
var dialogue_portrait: TextureRect
var dialogue_text: Label
var dialogue_close_btn: Button
var accept_btn: Button
var decline_btn: Button
var turn_in_btn: Button
var interact_prompt: Label

var dialogue_active: bool = false
var current_walker: Node = null
var branching_active: bool = false
var branching_data: Dictionary = {}
var branching_choices: Array = []
var branching_giver: String = ""
var choice_container: HBoxContainer = null
var pending_lore_id: String = ""
var pending_pair_scene_id: String = ""

var pair_scene_active: bool = false
var pair_scene_lines: Array = []
var pair_scene_index: int = 0
var pair_scene_data: Dictionary = {}
var pair_scene_walker_a: Node = null
var pair_scene_walker_b: Node = null
var pair_scenes_shown_this_visit: Dictionary = {}


func _init(explore: Node2D, ctx: CampContext, requests: CampRequestController) -> void:
	_explore = explore
	_ctx = ctx
	_requests = requests


func bind_dialogue_nodes(
	panel: PanelContainer,
	name_lbl: Label,
	portrait: TextureRect,
	text_lbl: Label,
	close_btn: Button,
	accept_b: Button,
	decline_b: Button,
	turn_in_b: Button,
	prompt: Label
) -> void:
	dialogue_panel = panel
	dialogue_name = name_lbl
	dialogue_portrait = portrait
	dialogue_text = text_lbl
	dialogue_close_btn = close_btn
	accept_btn = accept_b
	decline_btn = decline_b
	turn_in_btn = turn_in_b
	interact_prompt = prompt


func setup_branching_choice_container() -> void:
	if dialogue_panel == null:
		return
	var vbox: Node = dialogue_panel.get_node_or_null("VBox")
	if vbox == null:
		return
	choice_container = HBoxContainer.new()
	choice_container.name = "ChoiceContainer"
	choice_container.visible = false
	vbox.add_child(choice_container)


func hide_request_buttons() -> void:
	if accept_btn:
		accept_btn.visible = false
	if decline_btn:
		decline_btn.visible = false
	if turn_in_btn:
		turn_in_btn.visible = false
	if dialogue_close_btn:
		dialogue_close_btn.visible = true


func hide_branching_choices() -> void:
	if choice_container == null:
		return
	for c in choice_container.get_children():
		c.queue_free()
	choice_container.visible = false
	if accept_btn and accept_btn.get_parent():
		accept_btn.get_parent().visible = true
	if dialogue_close_btn:
		dialogue_close_btn.visible = true


func hide_dialogue_visual() -> void:
	if dialogue_panel:
		dialogue_panel.visible = false
	hide_request_buttons()


func get_eligible_pair_scene() -> Dictionary:
	var player: Node2D = _explore.get("player") as Node2D
	if player == null:
		return {}
	var context: Dictionary = _ctx.build_camp_context_dict()
	var best: Dictionary = {}
	var best_score: float = -99999.0
	for scene in CAMP_PAIR_SCENE_TRIGGER_DB.get_all_trigger_scenes():
		if not (scene is Dictionary):
			continue
		var s: Dictionary = scene
		if not CAMP_PAIR_SCENE_TRIGGER_DB.when_matches(s, context):
			continue
		var a_name: String = str(s.get("unit_a", "")).strip_edges()
		var b_name: String = str(s.get("unit_b", "")).strip_edges()
		if a_name.is_empty() or b_name.is_empty():
			continue
		if not _ctx.content_condition_matches(s, a_name, b_name):
			continue
		var min_familiarity: int = int(s.get("min_familiarity", 0))
		if _ctx.get_pair_familiarity(a_name, b_name) < min_familiarity:
			continue
		if bool(s.get("once_ever", false)):
			var sid_ever: String = str(s.get("id", "")).strip_edges()
			if sid_ever != "" and CampaignManager and CampaignManager.has_seen_camp_memory_scene(sid_ever):
				continue
		var w_a: Node = _ctx.find_walker_by_name(a_name)
		var w_b: Node = _ctx.find_walker_by_name(b_name)
		if w_a == null or w_b == null or w_a == w_b:
			continue
		var pair_radius: float = float(s.get("pair_radius", CAMP_PAIR_SCENE_TRIGGER_DB.PAIR_LISTEN_RADIUS_DEFAULT)) * 1.08
		if not _ctx.are_walkers_near_each_other(w_a, w_b, pair_radius):
			continue
		if s.has("zone_type"):
			var zt: String = str(s.get("zone_type", "")).strip_edges()
			if zt != "" and not _ctx.is_walker_near_zone(w_a, zt) and not _ctx.is_walker_near_zone(w_b, zt):
				continue
		var mid: Vector2 = (w_a.global_position + w_b.global_position) * 0.5
		var dist_sq_player: float = minf(
			player.global_position.distance_squared_to(w_a.global_position),
			minf(
				player.global_position.distance_squared_to(w_b.global_position),
				player.global_position.distance_squared_to(mid)
			)
		)
		if dist_sq_player > PAIR_LISTEN_RADIUS * PAIR_LISTEN_RADIUS:
			continue
		if s.get("once_per_visit", false):
			var sid: String = str(s.get("id", "")).strip_edges()
			if sid != "" and pair_scenes_shown_this_visit.get(sid, false):
				continue
		var prio: float = float(s.get("priority", 0))
		var score: float = _ctx.score_with_relationship_bias(prio, s, a_name, b_name)
		if score > best_score:
			best_score = score
			best = { "scene": s, "walker_a": w_a, "walker_b": w_b }
	return best


func start_pair_scene(data: Dictionary) -> void:
	var scene: Dictionary = data.get("scene", {})
	var lines: Array = scene.get("lines", [])
	if lines.is_empty():
		return
	pair_scene_active = true
	dialogue_active = true
	pair_scene_lines = lines
	pair_scene_index = 0
	pair_scene_data = scene
	pair_scene_walker_a = data.get("walker_a", null)
	pair_scene_walker_b = data.get("walker_b", null)
	for w in _ctx.walker_nodes:
		if w is CampRosterWalker:
			(w as CampRosterWalker).set_wander_paused(true)
	if interact_prompt:
		interact_prompt.visible = false
	if dialogue_panel:
		dialogue_panel.visible = true
	show_pair_scene_line()


func show_pair_scene_line() -> void:
	if pair_scene_index < 0 or pair_scene_index >= pair_scene_lines.size():
		return
	var line: Dictionary = pair_scene_lines[pair_scene_index]
	var speaker: String = str(line.get("speaker", "")).strip_edges()
	var text: String = str(line.get("text", "")).strip_edges()
	if dialogue_name:
		dialogue_name.text = speaker
	if dialogue_text:
		dialogue_text.text = text
	var walker_for_portrait: Node = null
	if pair_scene_walker_a != null and pair_scene_walker_a is CampRosterWalker and (pair_scene_walker_a as CampRosterWalker).unit_name == speaker:
		walker_for_portrait = pair_scene_walker_a
	elif pair_scene_walker_b != null and pair_scene_walker_b is CampRosterWalker and (pair_scene_walker_b as CampRosterWalker).unit_name == speaker:
		walker_for_portrait = pair_scene_walker_b
	if dialogue_portrait and walker_for_portrait is CampRosterWalker:
		var roster_entry: Dictionary = (walker_for_portrait as CampRosterWalker).unit_data
		var tex: Variant = roster_entry.get("portrait", null)
		dialogue_portrait.texture = tex if tex is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	else:
		if dialogue_portrait:
			dialogue_portrait.visible = false
	hide_request_buttons()
	if dialogue_close_btn:
		dialogue_close_btn.visible = true
		dialogue_close_btn.text = "Continue" if pair_scene_index < pair_scene_lines.size() - 1 else "Close"
	if dialogue_panel:
		dialogue_panel.visible = true


func advance_pair_scene() -> void:
	pair_scene_index += 1
	if pair_scene_index >= pair_scene_lines.size():
		end_pair_scene()
		return
	show_pair_scene_line()


func end_pair_scene() -> void:
	var scene: Dictionary = pair_scene_data
	if scene.get("once_per_visit", false):
		var sid: String = str(scene.get("id", "")).strip_edges()
		if sid != "":
			pair_scenes_shown_this_visit[sid] = true
	record_pair_scene_completion(scene)
	pair_scene_active = false
	dialogue_active = false
	pair_scene_lines.clear()
	pair_scene_index = 0
	pair_scene_data = {}
	pair_scene_walker_a = null
	pair_scene_walker_b = null
	for w in _ctx.walker_nodes:
		if w is CampRosterWalker:
			(w as CampRosterWalker).set_wander_paused(false)
	if dialogue_panel:
		dialogue_panel.visible = false
	hide_request_buttons()
	if dialogue_close_btn:
		dialogue_close_btn.text = "Close"


func record_pair_scene_completion(scene: Dictionary) -> void:
	if not CampaignManager:
		return
	var sid: String = str(scene.get("id", "")).strip_edges()
	var a_name: String = str(scene.get("unit_a", "")).strip_edges()
	var b_name: String = str(scene.get("unit_b", "")).strip_edges()
	var stats: Dictionary = _ctx.get_pair_stats(a_name, b_name)
	var familiarity: int = int(stats.get("familiarity", 0)) + int(scene.get("grants_familiarity", 1))
	var tension: int = int(stats.get("tension", 0)) + int(scene.get("grants_tension", 0))
	stats["familiarity"] = maxi(0, familiarity)
	stats["tension"] = maxi(0, tension)
	stats["last_visit_spoke"] = int(CampaignManager.get_camp_visit_index())
	_ctx.set_pair_stats(a_name, b_name, stats)
	if sid != "":
		CampaignManager.mark_camp_memory_scene_seen(sid)


func close_dialogue() -> void:
	dialogue_active = false
	current_walker = null
	branching_active = false
	hide_branching_choices()
	if pending_lore_id.strip_edges() != "" and CampaignManager:
		CampaignManager.mark_camp_lore_seen(pending_lore_id)
	pending_lore_id = ""
	if pending_pair_scene_id.strip_edges() != "" and CampaignManager:
		CampaignManager.mark_pair_scene_seen(pending_pair_scene_id)
	pending_pair_scene_id = ""
	for w in _ctx.walker_nodes:
		if w is CampRosterWalker:
			(w as CampRosterWalker).set_wander_paused(false)
	if dialogue_panel:
		dialogue_panel.visible = false
	hide_request_buttons()


func on_dialogue_close_pressed() -> void:
	if pair_scene_active:
		advance_pair_scene()
		return
	close_dialogue()


func start_branching_check(walker_node: Node, unit_name: String, unit_data: Variant, giver: String) -> void:
	var payload: Dictionary = CampaignManager.camp_request_payload if CampaignManager and CampaignManager.camp_request_payload is Dictionary else {}
	var style: String = str(payload.get("challenge_style", "")).strip_edges().to_lower()
	var personality: String = CampRequestDB.get_personality(unit_data, unit_name)
	var state: String = CampRequestContentDB.get_challenge_state_for_personality(personality)
	var data: Dictionary = CampRequestContentDB.get_branching_data(style, state)
	if data.is_empty() or not data.has("choices") or (data["choices"] as Array).is_empty():
		CampaignManager.camp_request_progress = 1
		CampaignManager.camp_request_status = "ready_to_turn_in"
		_requests.update_request_markers()
		if dialogue_name:
			dialogue_name.text = unit_name
		if dialogue_portrait and walker_node is CampRosterWalker:
			var roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data
			var tex: Variant = roster_entry.get("portrait", null)
			dialogue_portrait.texture = tex if tex is Texture2D else null
			dialogue_portrait.visible = dialogue_portrait.texture != null
		if dialogue_text:
			dialogue_text.text = "Done. Return to %s to complete the request." % giver
		hide_request_buttons()
		if dialogue_close_btn:
			dialogue_close_btn.visible = true
		if dialogue_panel:
			dialogue_panel.visible = true
		return
	branching_active = true
	branching_data = data
	branching_choices = (data["choices"] as Array).duplicate()
	branching_giver = giver
	if dialogue_name:
		dialogue_name.text = unit_name
	if dialogue_portrait and walker_node is CampRosterWalker:
		var roster_entry2: Dictionary = (walker_node as CampRosterWalker).unit_data
		var tex2: Variant = roster_entry2.get("portrait", null)
		dialogue_portrait.texture = tex2 if tex2 is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	if dialogue_text:
		dialogue_text.text = str(data.get("opening_line", "")).strip_edges()
	if accept_btn and accept_btn.get_parent():
		accept_btn.get_parent().visible = false
	if dialogue_close_btn:
		dialogue_close_btn.visible = false
	if choice_container == null:
		return
	for c in choice_container.get_children():
		c.queue_free()
	var choices: Array = branching_choices
	for i in range(choices.size()):
		var choice: Dictionary = choices[i] if i < choices.size() else {}
		var btn: Button = Button.new()
		btn.text = str(choice.get("text", "…")).strip_edges()
		if btn.text.is_empty():
			btn.text = "…"
		var idx: int = i
		btn.pressed.connect(on_branching_choice_pressed.bind(idx))
		choice_container.add_child(btn)
	choice_container.visible = true
	if dialogue_panel:
		dialogue_panel.visible = true


func on_branching_choice_pressed(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= branching_choices.size():
		return
	var choice: Dictionary = branching_choices[choice_index]
	var result_line: String = str(choice.get("result_line", "")).strip_edges()
	var outcome: String = str(choice.get("outcome", "fail")).strip_edges().to_lower()
	if dialogue_text:
		dialogue_text.text = result_line
	hide_branching_choices()
	if outcome == "success":
		CampaignManager.camp_request_progress = 1
		CampaignManager.camp_request_status = "ready_to_turn_in"
		_requests.update_request_markers()
		if dialogue_text:
			dialogue_text.text = result_line + "\n\nReturn to %s to complete the request." % branching_giver
	else:
		CampaignManager.camp_request_status = "failed"
		if branching_giver != "":
			CampaignManager.record_avatar_branching_failure(branching_giver)
		_requests.update_request_markers()
	branching_active = false
	if accept_btn and accept_btn.get_parent():
		accept_btn.get_parent().visible = false
	if dialogue_close_btn:
		dialogue_close_btn.visible = true


func show_special_camp_scene(walker_node: Node, unit_name: String, _unit_data: Variant, scene: Dictionary, scene_tier: String) -> void:
	if scene.get("one_time", true) and CampaignManager:
		CampaignManager.mark_special_scene_seen(unit_name, scene_tier)
	var lines_arr: Array = scene.get("lines", [])
	var text: String = ""
	for i in range(lines_arr.size()):
		if i > 0:
			text += "\n\n"
		text += str(lines_arr[i]).strip_edges()
	if text.is_empty():
		text = "..."
	if dialogue_name:
		dialogue_name.text = unit_name
	if dialogue_portrait and walker_node is CampRosterWalker:
		var roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data
		var tex: Variant = roster_entry.get("portrait", null)
		dialogue_portrait.texture = tex if tex is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	if dialogue_text:
		dialogue_text.text = text
	hide_request_buttons()
	if dialogue_close_btn:
		dialogue_close_btn.visible = true
	if dialogue_panel:
		dialogue_panel.visible = true


func show_offer_panel(walker_node: Node, unit_name: String, unit_data: Variant, pending_offer: Dictionary) -> void:
	if dialogue_name:
		dialogue_name.text = unit_name
	if dialogue_portrait:
		var roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data if walker_node is CampRosterWalker else {}
		var tex: Variant = roster_entry.get("portrait", null)
		dialogue_portrait.texture = tex if tex is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	var personality: String = CampRequestDB.get_personality(unit_data, unit_name)
	var line: String = CampRequestDB.get_line("offer", personality, pending_offer, 0, unit_name)
	var title: String = str(pending_offer.get("title", "")).strip_edges()
	var desc: String = str(pending_offer.get("description", "")).strip_edges()
	var reward_g: int = int(pending_offer.get("reward_gold", 0))
	if dialogue_text:
		dialogue_text.text = line + "\n\n" + title + "\n" + desc + "\n\nReward: %d gold. (Favor noted when completed.)" % reward_g
	if dialogue_close_btn:
		dialogue_close_btn.visible = false
	if accept_btn:
		accept_btn.visible = true
	if decline_btn:
		decline_btn.visible = true
	if turn_in_btn:
		turn_in_btn.visible = false
	if dialogue_panel:
		dialogue_panel.visible = true


func show_progress_panel(walker_node: Node, unit_name: String, unit_data: Variant) -> void:
	if dialogue_name:
		dialogue_name.text = unit_name
	if dialogue_portrait:
		var roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data if walker_node is CampRosterWalker else {}
		var tex: Variant = roster_entry.get("portrait", null)
		dialogue_portrait.texture = tex if tex is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	var personality: String = CampRequestDB.get_personality(unit_data, unit_name)
	var depth_str: String = "normal"
	if CampaignManager.camp_request_payload is Dictionary:
		depth_str = str(CampaignManager.camp_request_payload.get("request_depth", "normal"))
	var data: Dictionary = {
		"type": CampaignManager.camp_request_type,
		"target_name": CampaignManager.camp_request_target_name,
		"target_amount": CampaignManager.camp_request_target_amount,
		"request_depth": depth_str,
	}
	var line: String = CampRequestDB.get_line("in_progress", personality, data, 0, unit_name)
	if CampaignManager.camp_request_type == CampRequestDB.TYPE_ITEM_DELIVERY:
		var have: int = _requests.count_camp_request_items(_requests.get_camp_request_item_identifier())
		var need: int = CampaignManager.camp_request_target_amount
		line += "\n\nProgress: %d / %d" % [have, need]
	if dialogue_text:
		dialogue_text.text = line
	hide_request_buttons()
	if dialogue_close_btn:
		dialogue_close_btn.visible = true
	if dialogue_panel:
		dialogue_panel.visible = true


func show_turn_in_panel(walker_node: Node, unit_name: String, unit_data: Variant) -> void:
	if dialogue_name:
		dialogue_name.text = unit_name
	if dialogue_portrait:
		var roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data if walker_node is CampRosterWalker else {}
		var tex: Variant = roster_entry.get("portrait", null)
		dialogue_portrait.texture = tex if tex is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	var personality: String = CampRequestDB.get_personality(unit_data, unit_name)
	var depth_str: String = "normal"
	if CampaignManager.camp_request_payload is Dictionary:
		depth_str = str(CampaignManager.camp_request_payload.get("request_depth", "normal"))
	var data: Dictionary = {
		"type": CampaignManager.camp_request_type,
		"request_depth": depth_str,
	}
	var line: String = CampRequestDB.get_line("ready_to_turn_in", personality, data, 0, unit_name)
	if dialogue_text:
		dialogue_text.text = line
	if dialogue_close_btn:
		dialogue_close_btn.visible = false
	if accept_btn:
		accept_btn.visible = false
	if decline_btn:
		decline_btn.visible = false
	if turn_in_btn:
		turn_in_btn.visible = true
	if dialogue_panel:
		dialogue_panel.visible = true


func show_failed_reaction(walker_node: Node, unit_name: String, giver: String) -> void:
	var failed_line: String = CampRequestContentDB.get_failed_reaction_line(giver)
	if giver != "":
		failed_line += "\n\nRelationship worsened with %s." % giver
	if dialogue_name:
		dialogue_name.text = unit_name
	if dialogue_portrait and walker_node is CampRosterWalker:
		var roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data
		var tex: Variant = roster_entry.get("portrait", null)
		dialogue_portrait.texture = tex if tex is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	if dialogue_text:
		dialogue_text.text = failed_line
	hide_request_buttons()
	hide_branching_choices()
	if dialogue_close_btn:
		dialogue_close_btn.visible = true
	if dialogue_panel:
		dialogue_panel.visible = true


func show_talk_complete_return(walker_node: Node, unit_name: String, giver: String) -> void:
	if dialogue_name:
		dialogue_name.text = unit_name
	if dialogue_portrait:
		var roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data if walker_node is CampRosterWalker else {}
		var tex: Variant = roster_entry.get("portrait", null)
		dialogue_portrait.texture = tex if tex is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	if dialogue_text:
		dialogue_text.text = "Done. Return to %s to complete the request." % giver
	hide_request_buttons()
	if dialogue_close_btn:
		dialogue_close_btn.visible = true
	if dialogue_panel:
		dialogue_panel.visible = true


func show_pair_scene_snippet(walker_node: Node, unit_name: String, other_title: String, pair_scene: Dictionary) -> void:
	if dialogue_name:
		dialogue_name.text = other_title
	if dialogue_portrait and walker_node is CampRosterWalker:
		var pair_roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data
		var pair_tex: Variant = pair_roster_entry.get("portrait", null)
		dialogue_portrait.texture = pair_tex if pair_tex is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	if dialogue_text:
		dialogue_text.text = str(pair_scene.get("text", "")).strip_edges()
	hide_request_buttons()
	hide_branching_choices()
	if dialogue_close_btn:
		dialogue_close_btn.visible = true
	if dialogue_panel:
		dialogue_panel.visible = true
	pending_pair_scene_id = str(pair_scene.get("id", "")).strip_edges()


func show_lore_snippet(walker_node: Node, unit_name: String, lore: Dictionary) -> void:
	if dialogue_name:
		dialogue_name.text = unit_name
	if dialogue_portrait and walker_node is CampRosterWalker:
		var lore_roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data
		var lore_tex: Variant = lore_roster_entry.get("portrait", null)
		dialogue_portrait.texture = lore_tex if lore_tex is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	if dialogue_text:
		dialogue_text.text = str(lore.get("text", "")).strip_edges()
	hide_request_buttons()
	hide_branching_choices()
	if dialogue_close_btn:
		dialogue_close_btn.visible = true
	if dialogue_panel:
		dialogue_panel.visible = true
	pending_lore_id = str(lore.get("id", "")).strip_edges()


func show_idle_talk(walker_node: Node, unit_name: String, unit_data: Variant) -> void:
	var line: String = CampExploreDialogueDB.get_line_for_unit(unit_data, unit_name)
	if CampaignManager and unit_name != "":
		var tier: String = CampaignManager.get_avatar_relationship_tier(unit_name)
		if tier != "":
			line += "\n\nBond: " + tier.capitalize()
	if dialogue_name:
		dialogue_name.text = unit_name
	if dialogue_portrait:
		var roster_entry: Dictionary = (walker_node as CampRosterWalker).unit_data if walker_node is CampRosterWalker else {}
		var tex: Variant = roster_entry.get("portrait", null)
		dialogue_portrait.texture = tex if tex is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	if dialogue_text:
		dialogue_text.text = line
	hide_request_buttons()
	if dialogue_close_btn:
		dialogue_close_btn.visible = true
	if dialogue_panel:
		dialogue_panel.visible = true


func reset_pair_scene_visit_flags() -> void:
	pair_scenes_shown_this_visit.clear()


func begin_dialogue_session(walker_node: Node) -> void:
	dialogue_active = true
	current_walker = walker_node
	pending_lore_id = ""
	pending_pair_scene_id = ""
	for w in _ctx.walker_nodes:
		if w is CampRosterWalker:
			(w as CampRosterWalker).set_wander_paused(true)
