# CampDialogueController.gd
# Dialogue panel UI, branching choices, pair scene line playback, close/continue behavior.

class_name CampDialogueController
extends RefCounted

const CAMP_PAIR_SCENE_TRIGGER_DB = preload("res://Scripts/Narrative/CampPairSceneTriggerDB.gd")
const CAMP_DIRECT_TALK_PROGRESSION_DB = preload("res://Scripts/Narrative/CampDirectTalkProgressionDB.gd")
const PAIR_LISTEN_RADIUS: float = 120.0

var _explore: Node2D
var _ctx: CampContext
var _requests: CampRequestController
var _ambient_for_pacing: CampAmbientDirector = null

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

var _dialogue_panel_tween: Tween = null

var direct_conversation_active: bool = false
var direct_conversations_shown_this_visit: Dictionary = {}
var _direct_conv_data: Dictionary = {}
var _direct_conv_walker: Node = null
var _direct_conv_main_lines: Array = []
var _direct_conv_main_idx: int = 0
var _direct_conv_response_lines: Array = []
var _direct_conv_response_idx: int = 0
var _direct_conv_in_response: bool = false
var _direct_conv_choices: Array = []
var _direct_conv_waiting_choice: bool = false
var _direct_conv_selected_choice: Dictionary = {}


func _init(explore: Node2D, ctx: CampContext, requests: CampRequestController) -> void:
	_explore = explore
	_ctx = ctx
	_requests = requests


func bind_pacing_ambient(ambient: CampAmbientDirector) -> void:
	_ambient_for_pacing = ambient


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


func _kill_dialogue_panel_tween() -> void:
	if _dialogue_panel_tween != null and is_instance_valid(_dialogue_panel_tween):
		_dialogue_panel_tween.kill()
	_dialogue_panel_tween = null


func apply_dialogue_panel_visible(on: bool) -> void:
	if dialogue_panel == null:
		return
	_kill_dialogue_panel_tween()
	if on:
		if dialogue_panel.visible and dialogue_panel.modulate.a >= 0.995 and dialogue_panel.scale.distance_to(Vector2.ONE) < 0.008:
			return
		var intro: bool = not dialogue_panel.visible
		dialogue_panel.visible = true
		if intro:
			dialogue_panel.modulate.a = 0.0
			dialogue_panel.scale = Vector2(0.97, 0.97)
			var psz: Vector2 = dialogue_panel.size
			if psz.x < 4.0 or psz.y < 4.0:
				psz = dialogue_panel.get_combined_minimum_size()
			dialogue_panel.pivot_offset = psz * 0.5
			_dialogue_panel_tween = _explore.create_tween()
			_dialogue_panel_tween.set_parallel(true)
			_dialogue_panel_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_dialogue_panel_tween.tween_property(dialogue_panel, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			dialogue_panel.modulate.a = 1.0
			dialogue_panel.scale = Vector2.ONE
	else:
		if not dialogue_panel.visible:
			dialogue_panel.modulate.a = 1.0
			dialogue_panel.scale = Vector2.ONE
			dialogue_panel.pivot_offset = Vector2.ZERO
			return
		_dialogue_panel_tween = _explore.create_tween()
		_dialogue_panel_tween.tween_property(dialogue_panel, "modulate:a", 0.0, 0.09)
		_dialogue_panel_tween.tween_callback(func() -> void:
			dialogue_panel.visible = false
			dialogue_panel.modulate.a = 1.0
			dialogue_panel.scale = Vector2.ONE
			dialogue_panel.pivot_offset = Vector2.ZERO
		)


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
	apply_dialogue_panel_visible(false)
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
		score += _ctx.visit_theme_score_adjust(s, "pair_listen")
		if _ambient_for_pacing != null:
			var now_pl: float = Time.get_ticks_msec() / 1000.0
			score += _ambient_for_pacing.adjust_pair_listen_score(s, a_name, b_name, now_pl)
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
	apply_dialogue_panel_visible(true)
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
	apply_dialogue_panel_visible(true)


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
	if _ambient_for_pacing != null:
		_ambient_for_pacing.on_pair_listen_completed(scene)
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
	apply_dialogue_panel_visible(false)
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
	if direct_conversation_active:
		end_direct_conversation(false)
		return
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
	apply_dialogue_panel_visible(false)
	hide_request_buttons()


func on_dialogue_close_pressed() -> void:
	if pair_scene_active:
		advance_pair_scene()
		return
	if direct_conversation_active:
		if _direct_conv_waiting_choice:
			return
		advance_direct_conversation()
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
		apply_dialogue_panel_visible(true)
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
	apply_dialogue_panel_visible(true)


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
	apply_dialogue_panel_visible(true)


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
	apply_dialogue_panel_visible(true)


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
	apply_dialogue_panel_visible(true)


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
	apply_dialogue_panel_visible(true)


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
	apply_dialogue_panel_visible(true)


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
	apply_dialogue_panel_visible(true)


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
	apply_dialogue_panel_visible(true)
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
	apply_dialogue_panel_visible(true)
	pending_lore_id = str(lore.get("id", "")).strip_edges()


func show_idle_talk(walker_node: Node, unit_name: String, unit_data: Variant) -> void:
	var line: String = CampExploreDialogueDB.get_line_for_unit(unit_data, unit_name)
	var prog_follow: String = CAMP_DIRECT_TALK_PROGRESSION_DB.get_idle_followup(unit_name)
	if prog_follow != "":
		line += "\n\n" + prog_follow
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
	apply_dialogue_panel_visible(true)


func reset_pair_scene_visit_flags() -> void:
	pair_scenes_shown_this_visit.clear()


func reset_direct_conversation_visit_flags() -> void:
	direct_conversations_shown_this_visit.clear()


func get_direct_conversation_visit_snapshot() -> Dictionary:
	return {"visit_consumed": direct_conversations_shown_this_visit.duplicate()}


func start_direct_conversation(walker_node: Node, conv: Dictionary) -> void:
	if conv.is_empty():
		return
	_direct_conv_data = conv
	_direct_conv_walker = walker_node
	_direct_conv_choices = []
	var cv: Variant = conv.get("choices", [])
	if cv is Array:
		_direct_conv_choices = (cv as Array).duplicate()
	_direct_conv_main_lines = _build_direct_main_lines(conv)
	_direct_conv_main_idx = 0
	_direct_conv_response_lines.clear()
	_direct_conv_response_idx = 0
	_direct_conv_in_response = false
	_direct_conv_waiting_choice = false
	_direct_conv_selected_choice = {}
	direct_conversation_active = true
	dialogue_active = true
	if interact_prompt:
		interact_prompt.visible = false
	apply_dialogue_panel_visible(true)
	hide_request_buttons()
	show_direct_conversation_line()


func _build_direct_main_lines(conv: Dictionary) -> Array:
	var script_arr: Array = []
	var sv: Variant = conv.get("script", [])
	if sv is Array:
		for item in sv as Array:
			script_arr.append(item)
	var choices_arr: Array = []
	var chv: Variant = conv.get("choices", [])
	if chv is Array:
		choices_arr = chv as Array
	if choices_arr.is_empty():
		return script_arr
	var ba: int = int(conv.get("branch_at", -1))
	if ba < 0 or script_arr.is_empty():
		return script_arr
	var last: int = mini(ba, script_arr.size() - 1)
	var out: Array = []
	for i in range(last + 1):
		out.append(script_arr[i])
	return out


func _display_name_for_direct_speaker(raw: String) -> String:
	var r: String = str(raw).strip_edges()
	if r.to_lower() == "commander" and CampaignManager:
		var n: String = str(CampaignManager.custom_avatar.get("unit_name", "Commander")).strip_edges()
		return n if n != "" else "Commander"
	return r


func _apply_direct_line_portrait(raw_speaker: String) -> void:
	if dialogue_portrait == null:
		return
	var low: String = str(raw_speaker).strip_edges().to_lower()
	if low == "commander":
		var p: Variant = CampaignManager.custom_avatar.get("portrait", null) if CampaignManager else null
		dialogue_portrait.texture = p if p is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
		return
	var wn: Node = _ctx.find_walker_by_name(str(raw_speaker).strip_edges())
	if wn == null and _direct_conv_walker is CampRosterWalker:
		if (_direct_conv_walker as CampRosterWalker).unit_name == str(raw_speaker).strip_edges():
			wn = _direct_conv_walker
	if wn is CampRosterWalker:
		var rd: Dictionary = (wn as CampRosterWalker).unit_data
		var tv: Variant = rd.get("portrait", null)
		dialogue_portrait.texture = tv if tv is Texture2D else null
		dialogue_portrait.visible = dialogue_portrait.texture != null
	else:
		dialogue_portrait.texture = null
		dialogue_portrait.visible = false


func show_direct_conversation_line() -> void:
	var line: Dictionary = {}
	if not _direct_conv_in_response:
		if _direct_conv_main_idx < 0 or _direct_conv_main_idx >= _direct_conv_main_lines.size():
			return
		line = _direct_conv_main_lines[_direct_conv_main_idx] as Dictionary
	else:
		if _direct_conv_response_idx < 0 or _direct_conv_response_idx >= _direct_conv_response_lines.size():
			return
		line = _direct_conv_response_lines[_direct_conv_response_idx] as Dictionary
	var raw_sp: String = str(line.get("speaker", "")).strip_edges()
	if dialogue_name:
		dialogue_name.text = _display_name_for_direct_speaker(raw_sp)
	if dialogue_text:
		dialogue_text.text = str(line.get("text", "")).strip_edges()
	_apply_direct_line_portrait(raw_sp)
	hide_request_buttons()
	if dialogue_close_btn:
		dialogue_close_btn.visible = not _direct_conv_waiting_choice
		var at_last_main: bool = (not _direct_conv_in_response) and _direct_conv_main_lines.size() > 0 and _direct_conv_main_idx >= _direct_conv_main_lines.size() - 1
		var at_last_resp: bool = _direct_conv_in_response and _direct_conv_response_lines.size() > 0 and _direct_conv_response_idx >= _direct_conv_response_lines.size() - 1
		var has_branch: bool = not _direct_conv_choices.is_empty()
		if _direct_conv_in_response and at_last_resp:
			dialogue_close_btn.text = "Close"
		elif not _direct_conv_in_response and at_last_main and not has_branch:
			dialogue_close_btn.text = "Close"
		else:
			dialogue_close_btn.text = "Continue"
	apply_dialogue_panel_visible(true)


func advance_direct_conversation() -> void:
	if not direct_conversation_active or _direct_conv_waiting_choice:
		return
	if not _direct_conv_in_response:
		if _direct_conv_main_lines.is_empty():
			end_direct_conversation(true)
			return
		if _direct_conv_main_idx < _direct_conv_main_lines.size() - 1:
			_direct_conv_main_idx += 1
			show_direct_conversation_line()
			return
		if not _direct_conv_choices.is_empty():
			_present_direct_conversation_choices()
			return
		end_direct_conversation(true)
		return
	if _direct_conv_response_lines.is_empty():
		end_direct_conversation(true)
		return
	if _direct_conv_response_idx < _direct_conv_response_lines.size() - 1:
		_direct_conv_response_idx += 1
		show_direct_conversation_line()
		return
	end_direct_conversation(true)


func _present_direct_conversation_choices() -> void:
	if choice_container == null:
		end_direct_conversation(false)
		return
	_direct_conv_waiting_choice = true
	if dialogue_close_btn:
		dialogue_close_btn.visible = false
	for c in choice_container.get_children():
		c.queue_free()
	for i in range(_direct_conv_choices.size()):
		var ch: Dictionary = _direct_conv_choices[i] if i < _direct_conv_choices.size() else {}
		var btn: Button = Button.new()
		btn.text = str(ch.get("text", "…")).strip_edges()
		if btn.text.is_empty():
			btn.text = "…"
		var idx: int = i
		btn.pressed.connect(on_direct_conversation_choice_pressed.bind(idx))
		choice_container.add_child(btn)
	choice_container.visible = true
	if accept_btn and accept_btn.get_parent():
		accept_btn.get_parent().visible = false


func on_direct_conversation_choice_pressed(choice_index: int) -> void:
	if not direct_conversation_active or not _direct_conv_waiting_choice:
		return
	if choice_index < 0 or choice_index >= _direct_conv_choices.size():
		return
	_direct_conv_selected_choice = _direct_conv_choices[choice_index] as Dictionary
	hide_branching_choices()
	_direct_conv_waiting_choice = false
	var resp_v: Variant = _direct_conv_selected_choice.get("response", [])
	var resp: Array = resp_v if resp_v is Array else []
	if resp.is_empty():
		end_direct_conversation(true)
		return
	_direct_conv_in_response = true
	_direct_conv_response_lines = resp.duplicate()
	_direct_conv_response_idx = 0
	show_direct_conversation_line()


func apply_direct_conversation_effects(choice: Dictionary, primary_unit: String) -> void:
	if not CampaignManager or choice.is_empty():
		return
	var fx_v: Variant = choice.get("effects", {})
	if not (fx_v is Dictionary):
		return
	var fx: Dictionary = fx_v as Dictionary
	var delta: int = int(fx.get("add_avatar_relationship", 0))
	if delta != 0 and primary_unit.strip_edges() != "":
		CampaignManager.add_avatar_relationship(primary_unit, delta, "camp_direct_conversation")


func end_direct_conversation(completed: bool) -> void:
	if not direct_conversation_active:
		return
	var conv: Dictionary = _direct_conv_data
	var conv_id: String = str(conv.get("id", "")).strip_edges()
	var primary: String = str(conv.get("primary_unit", "")).strip_edges()
	if completed:
		var top_fx: Dictionary = conv.get("effects_on_complete", {}) if conv.get("effects_on_complete") is Dictionary else {}
		if not _direct_conv_selected_choice.is_empty():
			apply_direct_conversation_effects(_direct_conv_selected_choice, primary)
		elif _direct_conv_choices.is_empty() and CampaignManager and primary != "":
			var d: int = int(top_fx.get("add_avatar_relationship", 0))
			if d != 0:
				CampaignManager.add_avatar_relationship(primary, d, "camp_direct_conversation")
		if CampaignManager and primary != "":
			CampaignManager.apply_camp_direct_progression_effects(primary, top_fx)
		if bool(conv.get("once_ever", false)) and CampaignManager and conv_id != "":
			CampaignManager.mark_camp_memory_scene_seen(conv_id)
		if bool(conv.get("once_per_visit", false)) and conv_id != "":
			direct_conversations_shown_this_visit[conv_id] = true
	hide_branching_choices()
	direct_conversation_active = false
	_direct_conv_waiting_choice = false
	dialogue_active = false
	_direct_conv_data = {}
	_direct_conv_walker = null
	_direct_conv_main_lines.clear()
	_direct_conv_main_idx = 0
	_direct_conv_response_lines.clear()
	_direct_conv_response_idx = 0
	_direct_conv_in_response = false
	_direct_conv_choices.clear()
	_direct_conv_selected_choice = {}
	current_walker = null
	for w in _ctx.walker_nodes:
		if w is CampRosterWalker:
			(w as CampRosterWalker).set_wander_paused(false)
	apply_dialogue_panel_visible(false)
	if dialogue_close_btn:
		dialogue_close_btn.text = "Close"
	hide_request_buttons()


func begin_dialogue_session(walker_node: Node) -> void:
	dialogue_active = true
	current_walker = walker_node
	pending_lore_id = ""
	pending_pair_scene_id = ""
	for w in _ctx.walker_nodes:
		if w is CampRosterWalker:
			(w as CampRosterWalker).set_wander_paused(true)
