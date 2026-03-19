# CampAmbientDirector.gd
# Ambient rumors, micro-barks, chatter, and spontaneous social logic (legacy _update_rumor + helpers).

class_name CampAmbientDirector
extends RefCounted

const CAMP_RUMOR_DB = preload("res://Scripts/Narrative/CampRumorDB.gd")
const CAMP_MICRO_BARK_DB = preload("res://Scripts/Narrative/CampMicroBarkDB.gd")
const CAMP_AMBIENT_CHATTER_DB = preload("res://Scripts/Narrative/CampAmbientChatterDB.gd")
const CAMP_AMBIENT_SOCIAL_DB = preload("res://Scripts/Narrative/CampAmbientSocialDB.gd")


var _explore: Node2D
var _ctx: CampContext
var _bubble: CampBubbleController
var _dialogue: CampDialogueController

var _rumor_shown_this_visit: Dictionary = {}
var _micro_bark_shown_this_visit: Dictionary = {}
var _rumor_hide_at: float = 0.0
var _rumor_cooldown_until: float = 0.0
const RUMOR_OVERHEAR_RADIUS: float = 160.0
const RUMOR_DISPLAY_DURATION: float = 3.6
const RUMOR_COOLDOWN: float = 2.3
const RUMOR_NEARBY_UNITS_RADIUS: float = 140.0
const CHATTER_ATTEMPT_INTERVAL_MIN: float = 2.6
const CHATTER_ATTEMPT_INTERVAL_MAX: float = 4.4
const CHATTER_LINE_DURATION: float = 2.6
const CHATTER_MEETUP_TIMEOUT: float = 4.8
const CHATTER_SOCIAL_SETTLE_BEAT: float = 0.06
const SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MIN: float = 3.4
const SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MAX: float = 5.8
const SPONTANEOUS_SOCIAL_LINE_DURATION: float = 2.2
const SPONTANEOUS_SOCIAL_COOLDOWN: float = 1.2
const SPONTANEOUS_SOCIAL_FOLLOW_HOLD_MIN: float = 0.65
const SPONTANEOUS_SOCIAL_FOLLOW_HOLD_MAX: float = 1.25
const SPONTANEOUS_SOCIAL_MEETUP_TIMEOUT: float = 4.8
const SPONTANEOUS_SOCIAL_SETTLE_BEAT: float = 0.05
const SPONTANEOUS_SOCIAL_FORMATION_RADIUS: float = 34.0
const SPONTANEOUS_SOCIAL_OBSERVER_RADIUS: float = 132.0
const SPONTANEOUS_SOCIAL_MAX_OBSERVERS: int = 2
const CHATTER_SOCIAL_PAIR_OFFSET: float = 16.0
const SPONTANEOUS_SOCIAL_PAIR_OFFSET: float = 18.0
const AMBIENT_RECENT_SPEAKER_MAX: int = 4
const AMBIENT_RECENT_EVENT_MAX: int = 6
const AMBIENT_RECENT_SPEAKER_PENALTY: float = 1.1
const AMBIENT_RECENT_EVENT_PENALTY: float = 1.7
const AMBIENT_TEXT_BONUS_CHAR_STEP: float = 26.0
const AMBIENT_TEXT_BONUS_PER_STEP: float = 0.22
const AMBIENT_LINE_DURATION_MIN: float = 1.8
const AMBIENT_LINE_DURATION_MAX: float = 6.2

var _chatter_active: bool = false
var _chatter_lines: Array = []
var _chatter_index: int = 0
var _chatter_walker_a: Node = null
var _chatter_walker_b: Node = null
var _chatter_current_until: float = 0.0
var _chatter_shown_this_visit: Dictionary = {}
var _chatter_next_attempt_time: float = 0.0
var _chatter_entry: Dictionary = {}
var _chatter_meetup_started_at: float = 0.0
var _chatter_social_settle_until: float = 0.0
var _chatter_familiarity_awarded_this_visit: Dictionary = {}
var _spontaneous_social_active: bool = false
var _spontaneous_social_entry: Dictionary = {}
var _spontaneous_social_participants: Array = []
var _spontaneous_social_speaker: CampRosterWalker = null
var _spontaneous_social_lines: Array = []
var _spontaneous_social_index: int = 0
var _spontaneous_social_current_until: float = 0.0
var _spontaneous_social_next_attempt_time: float = 0.0
var _spontaneous_social_meetup_started_at: float = 0.0
var _spontaneous_social_settle_until: float = 0.0
var _spontaneous_social_shown_this_visit: Dictionary = {}
var _ambient_line_last_variant_by_event: Dictionary = {}
var _ambient_recent_speakers: Array[String] = []
var _ambient_recent_event_keys: Array[String] = []
var _social_hold_walkers: Array = []
var _social_hold_release_at: float = 0.0


func _init(explore: Node2D, ctx: CampContext, bubble: CampBubbleController, dialogue: CampDialogueController) -> void:
	_explore = explore
	_ctx = ctx
	_bubble = bubble
	_dialogue = dialogue


func reset_visit_state() -> void:
	_rumor_shown_this_visit.clear()
	_micro_bark_shown_this_visit.clear()
	_chatter_shown_this_visit.clear()
	_chatter_familiarity_awarded_this_visit.clear()
	_spontaneous_social_shown_this_visit.clear()
	_ambient_line_last_variant_by_event.clear()
	_chatter_active = false
	_chatter_meetup_started_at = 0.0
	_chatter_social_settle_until = 0.0
	_spontaneous_social_active = false
	_spontaneous_social_entry = {}
	_spontaneous_social_participants.clear()
	_spontaneous_social_speaker = null
	_spontaneous_social_lines.clear()
	_spontaneous_social_index = 0
	_spontaneous_social_current_until = 0.0
	_spontaneous_social_meetup_started_at = 0.0
	_spontaneous_social_settle_until = 0.0
	_ambient_recent_speakers.clear()
	_ambient_recent_event_keys.clear()
	_release_post_social_hold()
	_bubble.hide_ambient_bubble()


func _player_node() -> Node2D:
	return _explore.get("player") as Node2D


func prime_attempt_timers_after_ready(now_time: float) -> void:
	_chatter_next_attempt_time = now_time + randf_range(CHATTER_ATTEMPT_INTERVAL_MIN, CHATTER_ATTEMPT_INTERVAL_MAX)
	_spontaneous_social_next_attempt_time = now_time + randf_range(SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MIN, SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MAX)


func update_rumor(_delta: float) -> void:
	var player: Node2D = _player_node()
	if player == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	_update_social_hold(now)
	var pending_social_meetup: bool = false
	if _chatter_active:
		if now >= _chatter_current_until:
			_advance_ambient_chatter()
		return
	if _chatter_lines.size() > 0 and _chatter_walker_a is CampRosterWalker and _chatter_walker_b is CampRosterWalker:
		var wa2: CampRosterWalker = _chatter_walker_a as CampRosterWalker
		var wb2: CampRosterWalker = _chatter_walker_b as CampRosterWalker
		var ready_a: bool = wa2.has_reached_social_target()
		var ready_b: bool = wb2.has_reached_social_target()
		if ready_a and ready_b:
			wa2.face_toward(wb2.global_position)
			wb2.face_toward(wa2.global_position)
			if _chatter_social_settle_until <= 0.0:
				wa2.play_social_settle_beat()
				wb2.play_social_settle_beat()
				_chatter_social_settle_until = now + CHATTER_SOCIAL_SETTLE_BEAT
			if now < _chatter_social_settle_until:
				return
			var entry_local: Dictionary = _chatter_entry
			if entry_local.get("once_per_visit", false):
				var cid2: String = str(entry_local.get("id", "")).strip_edges()
				if cid2 != "":
					_chatter_shown_this_visit[cid2] = true
			_chatter_active = true
			_chatter_meetup_started_at = 0.0
			_chatter_social_settle_until = 0.0
			_show_ambient_chatter_line()
		elif _chatter_meetup_started_at > 0.0 and now - _chatter_meetup_started_at >= CHATTER_MEETUP_TIMEOUT:
			_cancel_pending_ambient_chatter()
		else:
			pending_social_meetup = true
	if _spontaneous_social_active:
		if now >= _spontaneous_social_current_until:
			_advance_spontaneous_social()
		return
	if _spontaneous_social_lines.size() > 0 and not _spontaneous_social_participants.is_empty():
		var all_ready: bool = true
		for p in _spontaneous_social_participants:
			if not (p is CampRosterWalker) or not is_instance_valid(p) or not (p as CampRosterWalker).has_reached_social_target():
				all_ready = false
				break
		if all_ready:
			if _spontaneous_social_settle_until <= 0.0:
				for p2 in _spontaneous_social_participants:
					if p2 is CampRosterWalker and is_instance_valid(p2):
						(p2 as CampRosterWalker).play_social_settle_beat()
				_spontaneous_social_settle_until = now + SPONTANEOUS_SOCIAL_SETTLE_BEAT
			if now < _spontaneous_social_settle_until:
				return
			if bool(_spontaneous_social_entry.get("once_per_visit", false)):
				var sid_ready: String = str(_spontaneous_social_entry.get("id", "")).strip_edges()
				if sid_ready != "":
					_spontaneous_social_shown_this_visit[sid_ready] = true
			_spontaneous_social_active = true
			_spontaneous_social_meetup_started_at = 0.0
			_spontaneous_social_settle_until = 0.0
			_show_spontaneous_social_line()
		elif _spontaneous_social_meetup_started_at > 0.0 and now - _spontaneous_social_meetup_started_at >= SPONTANEOUS_SOCIAL_MEETUP_TIMEOUT:
			_cancel_pending_spontaneous_social()
		else:
			pending_social_meetup = true
	if _dialogue.dialogue_active or _dialogue.pair_scene_active:
		return
	var bubble_active: bool = _bubble.ambient_speech_bubble != null and _bubble.ambient_speech_bubble.visible and is_instance_valid(_bubble.get_ambient_bubble_speaker())
	var fallback_label_active: bool = _bubble.rumor_label != null and _bubble.rumor_label.visible
	if bubble_active or fallback_label_active:
		if now >= _rumor_hide_at:
			_bubble.hide_ambient_bubble()
			_rumor_cooldown_until = now + RUMOR_COOLDOWN
		return
	if not pending_social_meetup:
		if now >= _chatter_next_attempt_time:
			var candidate: Dictionary = _get_eligible_ambient_chatter()
			if candidate.is_empty():
				_chatter_next_attempt_time = now + randf_range(CHATTER_ATTEMPT_INTERVAL_MIN, CHATTER_ATTEMPT_INTERVAL_MAX)
			else:
				_start_ambient_chatter(candidate)
			return
		if now >= _spontaneous_social_next_attempt_time:
			var spontaneous: Dictionary = _get_best_spontaneous_social_candidate()
			if spontaneous.is_empty():
				_spontaneous_social_next_attempt_time = now + randf_range(SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MIN, SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MAX)
			else:
				_start_spontaneous_social(spontaneous)
			return
	if now < _rumor_cooldown_until:
		return
	var micro_bark: Dictionary = _get_eligible_micro_bark()
	if not micro_bark.is_empty():
		var mb_text: String = _get_entry_text_with_variants(micro_bark, "micro")
		if mb_text == "":
			return
		var mb_speaker: String = str(micro_bark.get("speaker", "")).strip_edges()
		var micro_speaker_walker: CampRosterWalker = _ctx.get_walker_by_name(mb_speaker)
		_record_ambient_history("micro", micro_bark, mb_speaker)
		_bubble.show_ambient_bubble(mb_text, micro_speaker_walker, mb_speaker)
		var mid: String = str(micro_bark.get("id", "")).strip_edges()
		if mid != "" and micro_bark.get("once_per_visit", false):
			_micro_bark_shown_this_visit[mid] = true
		_rumor_hide_at = now + _get_dynamic_ambient_duration(mb_text, 2, RUMOR_DISPLAY_DURATION - 0.6)
		return
	var rumor: Dictionary = _get_eligible_rumor()
	if rumor.is_empty():
		return
	var r_text: String = _get_entry_text_with_variants(rumor, "rumor")
	if r_text == "":
		return
	var r_speaker: String = str(rumor.get("speaker", "")).strip_edges()
	var rumor_speaker_walker: CampRosterWalker = _ctx.get_walker_by_name(r_speaker)
	_record_ambient_history("rumor", rumor, r_speaker)
	_bubble.show_ambient_bubble(r_text, rumor_speaker_walker, r_speaker)
	var rid: String = str(rumor.get("id", "")).strip_edges()
	if rid != "" and rumor.get("once_per_visit", false):
		_rumor_shown_this_visit[rid] = true
	_rumor_hide_at = now + _get_dynamic_ambient_duration(r_text, 1, RUMOR_DISPLAY_DURATION)

func _get_eligible_rumor() -> Dictionary:
	var player: Node2D = _player_node()
	if player == null:
		return {}
	var context: Dictionary = _ctx.build_camp_context_dict()
	var best: Dictionary = {}
	var best_score: float = -99999.0
	for r in CAMP_RUMOR_DB.get_all_rumors():
		if not (r is Dictionary):
			continue
		var rumor: Dictionary = r
		if rumor.get("once_per_visit", false):
			var rid: String = str(rumor.get("id", "")).strip_edges()
			if rid != "" and _rumor_shown_this_visit.get(rid, false):
				continue
		if not CAMP_RUMOR_DB.when_matches(rumor, context):
			continue
		var speaker: String = str(rumor.get("speaker", "")).strip_edges()
		if speaker.is_empty():
			continue
		var listener: String = str(rumor.get("listener", "")).strip_edges()
		if not _ctx.content_condition_matches(rumor, speaker, listener):
			continue
		if listener != "":
			var listener_walker: Node = _ctx.find_walker_by_name(listener)
			if listener_walker == null:
				continue
			if not _ctx.pair_memory_matches(rumor, speaker, listener):
				continue
		var speaker_walker: Node = null
		for w in _ctx.walker_nodes:
			if not is_instance_valid(w) or not (w is CampRosterWalker):
				continue
			if (w as CampRosterWalker).unit_name == speaker:
				speaker_walker = w
				break
		if speaker_walker == null:
			continue
		var radius: float = float(rumor.get("radius", CAMP_RUMOR_DB.RUMOR_DEFAULT_RADIUS))
		if player.global_position.distance_squared_to(speaker_walker.global_position) > radius * radius:
			continue
		if rumor.has("zone_type"):
			var zt: String = str(rumor.get("zone_type", "")).strip_edges()
			if zt != "" and not _ctx.is_walker_near_zone(speaker_walker, zt):
				continue
		if rumor.has("nearby_units"):
			var names: Array = rumor.get("nearby_units", [])
			var all_nearby_found: bool = true
			for n in names:
				var want: String = str(n).strip_edges()
				if want.is_empty():
					continue
				var found: bool = false
				for w2 in _ctx.walker_nodes:
					if not is_instance_valid(w2) or w2 == speaker_walker or not (w2 is CampRosterWalker):
						continue
					if (w2 as CampRosterWalker).unit_name != want:
						continue
					if speaker_walker.global_position.distance_squared_to(w2.global_position) <= RUMOR_NEARBY_UNITS_RADIUS * RUMOR_NEARBY_UNITS_RADIUS:
						found = true
						break
				if not found:
					all_nearby_found = false
					break
			if not all_nearby_found:
				continue
		var score: float = float(rumor.get("priority", 0))
		if listener != "":
			score = _ctx.score_with_relationship_bias(score, rumor, speaker, listener)
		score += _ctx.visit_theme_score_adjust(rumor, "rumor")
		score -= _get_recent_history_penalty("rumor", rumor, speaker)
		if score > best_score:
			best_score = score
			best = rumor
	return best

func _record_chatter_completion(entry: Dictionary) -> void:
	if not CampaignManager:
		return
	var a_name: String = str(entry.get("unit_a", "")).strip_edges()
	var b_name: String = str(entry.get("unit_b", "")).strip_edges()
	if a_name == "" or b_name == "":
		return
	var key: String = _ctx.make_pair_key(a_name, b_name)
	var stats: Dictionary = _ctx.get_pair_stats(a_name, b_name)
	stats["last_visit_spoke"] = int(CampaignManager.get_camp_visit_index())
	if not _chatter_familiarity_awarded_this_visit.get(key, false):
		stats["familiarity"] = maxi(0, int(stats.get("familiarity", 0)) + 1)
		_chatter_familiarity_awarded_this_visit[key] = true
	_ctx.set_pair_stats(a_name, b_name, stats)

func _get_eligible_ambient_chatter() -> Dictionary:
	var player: Node2D = _player_node()
	if player == null:
		return {}
	var context: Dictionary = _ctx.build_camp_context_dict()
	var best: Dictionary = {}
	var best_score: float = -99999.0
	for entry_variant in CAMP_AMBIENT_CHATTER_DB.get_all_chatters():
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if entry.get("once_per_visit", false):
			var cid: String = str(entry.get("id", "")).strip_edges()
			if cid != "" and _chatter_shown_this_visit.get(cid, false):
				continue
		if not CAMP_AMBIENT_CHATTER_DB.when_matches(entry, context):
			continue
		var a_name: String = str(entry.get("unit_a", "")).strip_edges()
		var b_name: String = str(entry.get("unit_b", "")).strip_edges()
		if a_name == "" or b_name == "":
			continue
		var w_a: Node = _ctx.find_walker_by_name(a_name)
		var w_b: Node = _ctx.find_walker_by_name(b_name)
		if w_a == null or w_b == null or w_a == w_b:
			continue
		if not (w_a is CampRosterWalker) or not (w_b is CampRosterWalker):
			continue
		if not (w_a as CampRosterWalker).is_available_for_chatter():
			continue
		if not (w_b as CampRosterWalker).is_available_for_chatter():
			continue
		if entry.has("zone_type"):
			var zt: String = str(entry.get("zone_type", "")).strip_edges()
			if zt != "" and not _ctx.is_walker_near_zone(w_a, zt) and not _ctx.is_walker_near_zone(w_b, zt):
				continue
		var pair_radius: float = float(entry.get("pair_radius", CAMP_AMBIENT_CHATTER_DB.AMBIENT_CHATTER_DEFAULT_PAIR_RADIUS)) * 1.12
		var approach_radius: float = float(entry.get("approach_radius", pair_radius)) * 1.2
		var dist_sq: float = w_a.global_position.distance_squared_to(w_b.global_position)
		if dist_sq > approach_radius * approach_radius:
			continue
		var mid: Vector2 = (w_a.global_position + w_b.global_position) * 0.5
		var overhear_radius: float = float(entry.get("overhear_radius", RUMOR_OVERHEAR_RADIUS))
		var dist_sq_player: float = minf(
			player.global_position.distance_squared_to(w_a.global_position),
			minf(
				player.global_position.distance_squared_to(w_b.global_position),
				player.global_position.distance_squared_to(mid)
			)
		)
		if dist_sq_player > overhear_radius * overhear_radius:
			continue
		var score: float = _ctx.score_with_relationship_bias(float(entry.get("priority", 0)), entry, a_name, b_name)
		score += _ctx.visit_theme_score_adjust(entry, "chatter")
		score -= _get_recent_history_penalty("chatter", entry, a_name)
		if score > best_score:
			best_score = score
			best = { "entry": entry, "walker_a": w_a, "walker_b": w_b }
	return best

func _start_ambient_chatter(data: Dictionary) -> void:
	_release_post_social_hold()
	var entry: Dictionary = data.get("entry", {})
	var lines: Array = _get_chatter_line_sequence(entry)
	if lines.is_empty():
		return
	_chatter_entry = entry
	_chatter_lines = lines
	_chatter_index = 0
	_chatter_walker_a = data.get("walker_a", null)
	_chatter_walker_b = data.get("walker_b", null)
	_chatter_social_settle_until = 0.0
	if _chatter_walker_a is CampRosterWalker and _chatter_walker_b is CampRosterWalker:
		var wa: CampRosterWalker = _chatter_walker_a as CampRosterWalker
		var wb: CampRosterWalker = _chatter_walker_b as CampRosterWalker
		var mid: Vector2 = (wa.global_position + wb.global_position) * 0.5
		var offset: Vector2 = (wa.global_position - wb.global_position)
		if offset.length() < 0.01:
			offset = Vector2(1, 0)
		offset = offset.normalized()
		var meet_a: Vector2 = mid + offset * CHATTER_SOCIAL_PAIR_OFFSET
		var meet_b: Vector2 = mid - offset * CHATTER_SOCIAL_PAIR_OFFSET
		wa.begin_social_move(meet_a)
		wb.begin_social_move(meet_b)
		_chatter_meetup_started_at = Time.get_ticks_msec() / 1000.0
	else:
		_chatter_meetup_started_at = 0.0
	_chatter_active = false

func _show_ambient_chatter_line() -> void:
	if _chatter_index < 0 or _chatter_index >= _chatter_lines.size():
		return
	_clear_chatter_speaking_state()
	var line: Dictionary = _chatter_lines[_chatter_index]
	var speaker: String = str(line.get("speaker", "")).strip_edges()
	var text: String = str(line.get("text", "")).strip_edges()
	var now: float = Time.get_ticks_msec() / 1000.0
	_chatter_current_until = now + _get_dynamic_ambient_duration(text, 2, CHATTER_LINE_DURATION)
	var speaker_walker: CampRosterWalker = null
	var other_walker: CampRosterWalker = null
	if _chatter_walker_a is CampRosterWalker and (_chatter_walker_a as CampRosterWalker).unit_name == speaker:
		speaker_walker = _chatter_walker_a as CampRosterWalker
		if _chatter_walker_b is CampRosterWalker:
			other_walker = _chatter_walker_b as CampRosterWalker
	elif _chatter_walker_b is CampRosterWalker and (_chatter_walker_b as CampRosterWalker).unit_name == speaker:
		speaker_walker = _chatter_walker_b as CampRosterWalker
		if _chatter_walker_a is CampRosterWalker:
			other_walker = _chatter_walker_a as CampRosterWalker
	if speaker_walker != null:
		if other_walker != null:
			speaker_walker.face_toward(other_walker.global_position)
			other_walker.face_toward(speaker_walker.global_position)
		speaker_walker.begin_speaking()
		if other_walker != null:
			other_walker.begin_listening()
	_record_ambient_history("chatter", _chatter_entry, speaker, _chatter_index == 0)
	_bubble.show_ambient_bubble(text, speaker_walker, speaker)

func _advance_ambient_chatter() -> void:
	_chatter_index += 1
	if _chatter_index >= _chatter_lines.size():
		_end_ambient_chatter()
		return
	_show_ambient_chatter_line()

func _end_ambient_chatter() -> void:
	_clear_chatter_speaking_state()
	var hold_min: float = float(_chatter_entry.get("follow_hold_min", SPONTANEOUS_SOCIAL_FOLLOW_HOLD_MIN))
	var hold_max: float = float(_chatter_entry.get("follow_hold_max", SPONTANEOUS_SOCIAL_FOLLOW_HOLD_MAX))
	_record_chatter_completion(_chatter_entry)
	var release_candidates: Array = []
	if _chatter_walker_a is CampRosterWalker:
		release_candidates.append(_chatter_walker_a)
	if _chatter_walker_b is CampRosterWalker:
		release_candidates.append(_chatter_walker_b)
	_chatter_active = false
	_chatter_lines.clear()
	_chatter_index = 0
	_chatter_entry = {}
	_chatter_meetup_started_at = 0.0
	_chatter_social_settle_until = 0.0
	_start_post_social_hold(release_candidates, hold_min, hold_max)
	_chatter_walker_a = null
	_chatter_walker_b = null
	_bubble.hide_ambient_bubble()
	var now: float = Time.get_ticks_msec() / 1000.0
	_chatter_next_attempt_time = now + randf_range(CHATTER_ATTEMPT_INTERVAL_MIN, CHATTER_ATTEMPT_INTERVAL_MAX)

func _clear_chatter_speaking_state() -> void:
	if _chatter_walker_a is CampRosterWalker:
		var wa: CampRosterWalker = _chatter_walker_a as CampRosterWalker
		wa.end_speaking()
		wa.end_listening()
	if _chatter_walker_b is CampRosterWalker:
		var wb: CampRosterWalker = _chatter_walker_b as CampRosterWalker
		wb.end_speaking()
		wb.end_listening()

func _cancel_pending_ambient_chatter() -> void:
	_clear_chatter_speaking_state()
	_chatter_active = false
	_chatter_lines.clear()
	_chatter_index = 0
	_chatter_entry = {}
	_chatter_meetup_started_at = 0.0
	_chatter_social_settle_until = 0.0
	if _chatter_walker_a is CampRosterWalker:
		(_chatter_walker_a as CampRosterWalker).end_social_move()
	if _chatter_walker_b is CampRosterWalker:
		(_chatter_walker_b as CampRosterWalker).end_social_move()
	_chatter_walker_a = null
	_chatter_walker_b = null
	_bubble.hide_ambient_bubble()
	var now: float = Time.get_ticks_msec() / 1000.0
	_chatter_next_attempt_time = now + randf_range(CHATTER_ATTEMPT_INTERVAL_MIN, CHATTER_ATTEMPT_INTERVAL_MAX)

func _update_social_hold(now: float) -> void:
	if _social_hold_release_at <= 0.0:
		return
	if now < _social_hold_release_at:
		return
	_release_post_social_hold()

func _start_post_social_hold(walkers: Array, min_duration: float = SPONTANEOUS_SOCIAL_FOLLOW_HOLD_MIN, max_duration: float = SPONTANEOUS_SOCIAL_FOLLOW_HOLD_MAX) -> void:
	_release_post_social_hold()
	for node in walkers:
		if not (node is CampRosterWalker):
			continue
		var walker: CampRosterWalker = node as CampRosterWalker
		if not is_instance_valid(walker):
			continue
		if walker in _social_hold_walkers:
			continue
		walker.begin_social_move(walker.global_position)
		_social_hold_walkers.append(walker)
	if _social_hold_walkers.is_empty():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var min_d: float = maxf(0.2, min_duration)
	var max_d: float = maxf(min_d, max_duration)
	_social_hold_release_at = now + randf_range(min_d, max_d)

func _release_post_social_hold() -> void:
	for node in _social_hold_walkers:
		if node is CampRosterWalker and is_instance_valid(node):
			(node as CampRosterWalker).end_social_move()
	_social_hold_walkers.clear()
	_social_hold_release_at = 0.0

func _pick_visit_non_repeat_index(event_key: String, option_count: int) -> int:
	if option_count <= 0:
		return -1
	if option_count == 1:
		return 0
	var key: String = str(event_key).strip_edges()
	if key == "":
		return randi() % option_count
	var last_index: int = int(_ambient_line_last_variant_by_event.get(key, -1))
	var idx: int = randi() % option_count
	if idx == last_index:
		idx = (idx + 1 + int(randi() % (option_count - 1))) % option_count
	_ambient_line_last_variant_by_event[key] = idx
	return idx

func _get_chatter_line_sequence(entry: Dictionary) -> Array:
	var variants: Array = []
	var base_lines: Variant = entry.get("lines", [])
	if base_lines is Array and not (base_lines as Array).is_empty():
		variants.append((base_lines as Array))
	var alt_variants_v: Variant = entry.get("line_variants", [])
	if alt_variants_v is Array:
		for seq_v in alt_variants_v:
			if seq_v is Array and not (seq_v as Array).is_empty():
				variants.append(seq_v as Array)
	if variants.is_empty():
		return []
	var entry_id: String = str(entry.get("id", "")).strip_edges()
	var key: String = "chatter:%s" % entry_id if entry_id != "" else ""
	var idx: int = _pick_visit_non_repeat_index(key, variants.size())
	if idx < 0:
		return []
	var chosen: Variant = variants[idx]
	if chosen is Array:
		return (chosen as Array).duplicate(true)
	return []

func _get_best_spontaneous_social_candidate() -> Dictionary:
	var context: Dictionary = _ctx.build_camp_context_dict()
	var best: Dictionary = {}
	var best_score: float = -99999.0
	for entry_variant in CAMP_AMBIENT_SOCIAL_DB.get_all_entries():
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if entry.get("once_per_visit", false):
			var sid: String = str(entry.get("id", "")).strip_edges()
			if sid != "" and bool(_spontaneous_social_shown_this_visit.get(sid, false)):
				continue
		if not CAMP_AMBIENT_SOCIAL_DB.when_matches(entry, context):
			continue
		var kind: String = str(entry.get("kind", "passing_remark")).strip_edges().to_lower()
		var candidate: Dictionary = {}
		match kind:
			"small_cluster", "opportunistic_cluster":
				candidate = _build_spontaneous_cluster_candidate(entry)
			_:
				candidate = _build_spontaneous_passing_candidate(entry)
		if candidate.is_empty():
			continue
		var speaker_name: String = str(entry.get("speaker", "")).strip_edges()
		var score: float = float(candidate.get("score", float(entry.get("priority", 0))))
		score += _ctx.visit_theme_score_adjust(entry, "social")
		score -= _get_recent_history_penalty("social", entry, speaker_name)
		if score > best_score:
			best_score = score
			best = candidate
	return best

func _build_spontaneous_passing_candidate(entry: Dictionary) -> Dictionary:
	var player: Node2D = _player_node()
	if player == null:
		return {}
	var speaker_name: String = str(entry.get("speaker", "")).strip_edges()
	var listener_name: String = str(entry.get("listener", "")).strip_edges()
	if speaker_name == "":
		return {}
	var speaker_node: Node = _ctx.find_walker_by_name(speaker_name)
	if not (speaker_node is CampRosterWalker):
		return {}
	var speaker_walker: CampRosterWalker = speaker_node as CampRosterWalker
	if not speaker_walker.is_available_for_social():
		return {}
	var listener_walker: CampRosterWalker = null
	if listener_name != "":
		var listener_node: Node = _ctx.find_walker_by_name(listener_name)
		if not (listener_node is CampRosterWalker):
			return {}
		listener_walker = listener_node as CampRosterWalker
		if listener_walker == speaker_walker:
			return {}
		if not listener_walker.is_available_for_social():
			return {}
		if not _ctx.pair_memory_matches(entry, speaker_name, listener_name):
			return {}
	if not _ctx.content_condition_matches(entry, speaker_name, listener_name):
		return {}
	if entry.has("zone_type"):
		var zt: String = str(entry.get("zone_type", "")).strip_edges()
		if zt != "":
			var speaker_near: bool = _ctx.is_walker_near_zone(speaker_walker, zt)
			var listener_near: bool = listener_walker != null and _ctx.is_walker_near_zone(listener_walker, zt)
			if not speaker_near and not listener_near:
				return {}
	var pair_radius: float = float(entry.get("pair_radius", CAMP_AMBIENT_SOCIAL_DB.SOCIAL_DEFAULT_PAIR_RADIUS))
	if listener_walker != null and not _ctx.are_walkers_near_each_other(speaker_walker, listener_walker, pair_radius):
		return {}
	var center: Vector2 = speaker_walker.global_position
	if listener_walker != null:
		center = (speaker_walker.global_position + listener_walker.global_position) * 0.5
	var overhear_radius: float = float(entry.get("radius", CAMP_AMBIENT_SOCIAL_DB.SOCIAL_DEFAULT_RADIUS))
	if player.global_position.distance_squared_to(center) > overhear_radius * overhear_radius:
		return {}
	var lines: Array = _get_spontaneous_social_sequence(entry)
	if lines.is_empty():
		return {}
	var score: float = float(entry.get("priority", 0))
	if listener_walker != null:
		score = _ctx.score_with_relationship_bias(score, entry, speaker_name, listener_name)
	var participants: Array = [speaker_walker]
	if listener_walker != null:
		participants.append(listener_walker)
	var observers: Array = _collect_passing_observers(entry, participants, center)
	for observer in observers:
		participants.append(observer)
	score += float(observers.size()) * 0.12
	return {
		"kind": "passing_remark",
		"entry": entry,
		"score": score,
		"participants": participants,
		"speaker_walker": speaker_walker,
		"lines": lines,
	}

func _build_spontaneous_cluster_candidate(entry: Dictionary) -> Dictionary:
	var player: Node2D = _player_node()
	if player == null:
		return {}
	var required_units: Array = entry.get("required_units", [])
	if required_units.size() < 2:
		return {}
	var participants: Array = []
	for unit_name_variant in required_units:
		var unit_name: String = str(unit_name_variant).strip_edges()
		if unit_name == "":
			return {}
		var node: Node = _ctx.find_walker_by_name(unit_name)
		if not (node is CampRosterWalker):
			return {}
		var walker: CampRosterWalker = node as CampRosterWalker
		if not walker.is_available_for_social():
			return {}
		participants.append(walker)
	var speaker_name: String = str(entry.get("speaker", "")).strip_edges()
	if speaker_name == "":
		speaker_name = str(required_units[0]).strip_edges()
	var speaker_walker: CampRosterWalker = _ctx.get_walker_by_name(speaker_name)
	if speaker_walker == null or speaker_walker not in participants:
		return {}
	if not _ctx.content_condition_matches(entry, speaker_name):
		return {}
	var lines: Array = _get_spontaneous_social_sequence(entry)
	if lines.is_empty():
		return {}
	var cluster_radius: float = float(entry.get("cluster_radius", CAMP_AMBIENT_SOCIAL_DB.SOCIAL_DEFAULT_CLUSTER_RADIUS))
	var center_seed: Vector2 = _get_social_group_center(participants)
	if entry.has("zone_type"):
		var zt: String = str(entry.get("zone_type", "")).strip_edges()
		if zt != "":
			var any_near_zone: bool = false
			for p in participants:
				if _ctx.is_walker_near_zone(p, zt):
					any_near_zone = true
					break
			if not any_near_zone:
				return {}
	var optional_units_v: Variant = entry.get("optional_units", [])
	var optional_candidates: Array = []
	if optional_units_v is Array:
		var recruit_radius: float = float(entry.get("observer_radius", maxf(cluster_radius * 1.15, SPONTANEOUS_SOCIAL_OBSERVER_RADIUS)))
		for unit_name_variant2 in optional_units_v:
			var optional_name: String = str(unit_name_variant2).strip_edges()
			if optional_name == "":
				continue
			var optional_walker: CampRosterWalker = _ctx.get_walker_by_name(optional_name)
			if optional_walker == null or optional_walker in participants:
				continue
			if not optional_walker.is_available_for_social():
				continue
			var dist_sq: float = optional_walker.global_position.distance_squared_to(center_seed)
			if dist_sq > recruit_radius * recruit_radius:
				continue
			optional_candidates.append({ "walker": optional_walker, "dist_sq": dist_sq })
		optional_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("dist_sq", 0.0)) < float(b.get("dist_sq", 0.0))
		)
	var min_participants: int = maxi(3, int(entry.get("min_participants", required_units.size())))
	var max_participants: int = maxi(min_participants, int(entry.get("max_participants", min_participants)))
	for candidate in optional_candidates:
		if participants.size() >= max_participants:
			break
		participants.append(candidate.get("walker"))
	if participants.size() < min_participants:
		return {}
	var center: Vector2 = _get_social_group_center(participants)
	for p in participants:
		if (p as CampRosterWalker).global_position.distance_squared_to(center) > cluster_radius * cluster_radius:
			return {}
	var overhear_radius: float = float(entry.get("radius", CAMP_AMBIENT_SOCIAL_DB.SOCIAL_DEFAULT_RADIUS))
	if player.global_position.distance_squared_to(center) > overhear_radius * overhear_radius:
		return {}
	var score: float = float(entry.get("priority", 0))
	var pair_count: int = 0
	for p in participants:
		var walker2: CampRosterWalker = p as CampRosterWalker
		if walker2 == speaker_walker:
			continue
		score += _ctx.get_pair_social_bias(speaker_walker.unit_name, walker2.unit_name)
		pair_count += 1
	if pair_count > 0:
		score /= float(pair_count + 1)
	return {
		"kind": "small_cluster",
		"entry": entry,
		"score": score,
		"participants": participants,
		"speaker_walker": speaker_walker,
		"lines": lines,
	}

func _start_spontaneous_social(data: Dictionary) -> void:
	_release_post_social_hold()
	var entry: Dictionary = data.get("entry", {})
	var lines: Array = data.get("lines", [])
	if lines.is_empty():
		lines = _get_spontaneous_social_sequence(entry)
	if lines.is_empty():
		return
	var participants: Array = _get_valid_social_participants(data.get("participants", []))
	if participants.is_empty():
		return
	var speaker_node: Node = data.get("speaker_walker", null)
	var speaker_walker: CampRosterWalker = null
	if speaker_node is CampRosterWalker:
		speaker_walker = speaker_node as CampRosterWalker
	_spontaneous_social_active = false
	_spontaneous_social_entry = entry
	_spontaneous_social_participants = participants.duplicate()
	_spontaneous_social_speaker = speaker_walker
	_spontaneous_social_lines = lines.duplicate(true)
	_spontaneous_social_index = 0
	_spontaneous_social_current_until = 0.0
	_spontaneous_social_meetup_started_at = Time.get_ticks_msec() / 1000.0
	_spontaneous_social_settle_until = 0.0
	_apply_spontaneous_social_formation(_spontaneous_social_participants, speaker_walker)

func _end_spontaneous_social() -> void:
	var participants: Array = _spontaneous_social_participants.duplicate()
	_clear_spontaneous_social_speaking_state()
	var hold_chance: float = clampf(float(_spontaneous_social_entry.get("follow_hold_chance", 0.45)), 0.0, 1.0)
	var hold_min: float = float(_spontaneous_social_entry.get("follow_hold_min", SPONTANEOUS_SOCIAL_FOLLOW_HOLD_MIN))
	var hold_max: float = float(_spontaneous_social_entry.get("follow_hold_max", SPONTANEOUS_SOCIAL_FOLLOW_HOLD_MAX))
	if participants.size() >= 2 and randf() < hold_chance:
		_start_post_social_hold(participants, hold_min, hold_max)
	else:
		for p in participants:
			if p is CampRosterWalker and is_instance_valid(p):
				(p as CampRosterWalker).end_social_move()
	_spontaneous_social_active = false
	_spontaneous_social_entry = {}
	_spontaneous_social_participants.clear()
	_spontaneous_social_speaker = null
	_spontaneous_social_lines.clear()
	_spontaneous_social_index = 0
	_spontaneous_social_current_until = 0.0
	_spontaneous_social_meetup_started_at = 0.0
	_spontaneous_social_settle_until = 0.0
	_bubble.hide_ambient_bubble()
	var now: float = Time.get_ticks_msec() / 1000.0
	_rumor_cooldown_until = maxf(_rumor_cooldown_until, now + SPONTANEOUS_SOCIAL_COOLDOWN)
	_spontaneous_social_next_attempt_time = now + randf_range(SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MIN, SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MAX)


func _get_dynamic_ambient_duration(text: String, participant_count: int, base_duration: float) -> float:
	var line_text: String = str(text).strip_edges()
	var extra_steps: float = maxf(0.0, float(line_text.length() - 32) / AMBIENT_TEXT_BONUS_CHAR_STEP)
	var participant_bonus: float = float(maxi(0, participant_count - 1)) * 0.12
	return clampf(base_duration + extra_steps * AMBIENT_TEXT_BONUS_PER_STEP + participant_bonus, AMBIENT_LINE_DURATION_MIN, AMBIENT_LINE_DURATION_MAX)

func _push_recent_string(history: Array, value: String, max_size: int) -> void:
	var key: String = str(value).strip_edges()
	if key == "":
		return
	if key in history:
		history.erase(key)
	history.push_front(key)
	while history.size() > max_size:
		history.pop_back()

func _get_ambient_entry_key(event_type: String, entry: Dictionary, fallback_speaker: String = "") -> String:
	var entry_id: String = str(entry.get("id", "")).strip_edges()
	if entry_id != "":
		return "%s:%s" % [event_type, entry_id]
	var speaker: String = str(fallback_speaker).strip_edges()
	if speaker == "":
		speaker = str(entry.get("speaker", "")).strip_edges()
	if speaker == "":
		speaker = str(entry.get("unit_a", "")).strip_edges()
	if speaker == "":
		speaker = "unknown"
	return "%s:%s" % [event_type, speaker]

func _get_recent_history_penalty(event_type: String, entry: Dictionary, speaker_name: String = "") -> float:
	var penalty: float = 0.0
	var event_key: String = _get_ambient_entry_key(event_type, entry, speaker_name)
	var event_index: int = _ambient_recent_event_keys.find(event_key)
	if event_index >= 0:
		penalty += maxf(0.3, AMBIENT_RECENT_EVENT_PENALTY - float(event_index) * 0.3)
	var speaker: String = str(speaker_name).strip_edges()
	if speaker != "":
		var speaker_index: int = _ambient_recent_speakers.find(speaker)
		if speaker_index >= 0:
			penalty += maxf(0.15, AMBIENT_RECENT_SPEAKER_PENALTY - float(speaker_index) * 0.25)
	return penalty

func _record_ambient_history(event_type: String, entry: Dictionary, speaker_name: String = "", record_event: bool = true) -> void:
	var speaker: String = str(speaker_name).strip_edges()
	if speaker != "":
		_push_recent_string(_ambient_recent_speakers, speaker, AMBIENT_RECENT_SPEAKER_MAX)
	if record_event:
		_push_recent_string(_ambient_recent_event_keys, _get_ambient_entry_key(event_type, entry, speaker_name), AMBIENT_RECENT_EVENT_MAX)

func _get_entry_text_with_variants(entry: Dictionary, event_type: String) -> String:
	var options: Array = []
	var base_text: String = str(entry.get("text", "")).strip_edges()
	if base_text != "":
		options.append(base_text)
	var variants_v: Variant = entry.get("text_variants", [])
	if variants_v is Array:
		for option_v in variants_v:
			var option_text: String = str(option_v).strip_edges()
			if option_text != "":
				options.append(option_text)
	if options.is_empty():
		return ""
	var entry_id: String = str(entry.get("id", "")).strip_edges()
	var key: String = "%s:text:%s" % [event_type, entry_id] if entry_id != "" else ""
	var idx: int = _pick_visit_non_repeat_index(key, options.size())
	if idx < 0 or idx >= options.size():
		return ""
	return str(options[idx]).strip_edges()

func _normalize_spontaneous_line(raw_line: Variant, fallback_speaker: String) -> Dictionary:
	if raw_line is Dictionary:
		var d: Dictionary = raw_line
		var speaker: String = str(d.get("speaker", fallback_speaker)).strip_edges()
		var text: String = str(d.get("text", "")).strip_edges()
		if text == "":
			return {}
		return { "speaker": speaker, "text": text }
	var simple_text: String = str(raw_line).strip_edges()
	if simple_text == "":
		return {}
	return { "speaker": str(fallback_speaker).strip_edges(), "text": simple_text }

func _get_spontaneous_social_sequence(entry: Dictionary) -> Array:
	var fallback_speaker: String = str(entry.get("speaker", "")).strip_edges()
	var variants: Array = []
	var sequence_variants: Variant = entry.get("line_sequences", [])
	if sequence_variants is Array:
		for seq_v in sequence_variants:
			if not (seq_v is Array):
				continue
			var seq_norm: Array = []
			for raw_line in (seq_v as Array):
				var line_dict: Dictionary = _normalize_spontaneous_line(raw_line, fallback_speaker)
				if not line_dict.is_empty():
					seq_norm.append(line_dict)
			if not seq_norm.is_empty():
				variants.append(seq_norm)
	var lines_v: Variant = entry.get("lines", [])
	if lines_v is Array:
		for raw_variant in (lines_v as Array):
			var line_single: Dictionary = _normalize_spontaneous_line(raw_variant, fallback_speaker)
			if not line_single.is_empty():
				variants.append([line_single])
	var line_variants_v: Variant = entry.get("line_variants", [])
	if line_variants_v is Array:
		for variant_v in (line_variants_v as Array):
			if variant_v is Array:
				var seq_variant: Array = []
				for raw_line2 in (variant_v as Array):
					var line_dict2: Dictionary = _normalize_spontaneous_line(raw_line2, fallback_speaker)
					if not line_dict2.is_empty():
						seq_variant.append(line_dict2)
				if not seq_variant.is_empty():
					variants.append(seq_variant)
			else:
				var line_variant_dict: Dictionary = _normalize_spontaneous_line(variant_v, fallback_speaker)
				if not line_variant_dict.is_empty():
					variants.append([line_variant_dict])
	if variants.is_empty():
		return []
	var entry_id: String = str(entry.get("id", "")).strip_edges()
	var key: String = "spont_seq:%s" % entry_id if entry_id != "" else ""
	var idx: int = _pick_visit_non_repeat_index(key, variants.size())
	if idx < 0 or idx >= variants.size():
		return []
	var chosen: Variant = variants[idx]
	if chosen is Array:
		return (chosen as Array).duplicate(true)
	return []

func _get_valid_social_participants(participants: Array) -> Array:
	var out: Array = []
	for p in participants:
		if not (p is CampRosterWalker) or not is_instance_valid(p):
			continue
		if p in out:
			continue
		out.append(p)
	return out

func _get_social_group_center(participants: Array) -> Vector2:
	var valid: Array = _get_valid_social_participants(participants)
	if valid.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for p in valid:
		center += (p as CampRosterWalker).global_position
	return center / float(valid.size())

func _apply_spontaneous_social_formation(participants: Array, speaker_walker: CampRosterWalker = null) -> void:
	var valid: Array = _get_valid_social_participants(participants)
	if valid.is_empty():
		return
	var center: Vector2 = _get_social_group_center(valid)
	if valid.size() == 1:
		(valid[0] as CampRosterWalker).begin_social_move((valid[0] as CampRosterWalker).global_position)
		return
	if valid.size() == 2:
		var a: CampRosterWalker = valid[0] as CampRosterWalker
		var b: CampRosterWalker = valid[1] as CampRosterWalker
		var dir: Vector2 = a.global_position - b.global_position
		if dir.length() < 0.01:
			dir = Vector2.RIGHT
		dir = dir.normalized()
		var midpoint: Vector2 = (a.global_position + b.global_position) * 0.5
		a.begin_social_move(midpoint + dir * SPONTANEOUS_SOCIAL_PAIR_OFFSET)
		b.begin_social_move(midpoint - dir * SPONTANEOUS_SOCIAL_PAIR_OFFSET)
		return
	var ordered: Array = valid.duplicate()
	if speaker_walker != null and speaker_walker in ordered:
		ordered.erase(speaker_walker)
		ordered.push_front(speaker_walker)
	var count: int = ordered.size()
	var radius: float = SPONTANEOUS_SOCIAL_FORMATION_RADIUS + float(maxi(0, count - 3)) * 4.0
	for i in range(count):
		var walker: CampRosterWalker = ordered[i] as CampRosterWalker
		var angle: float = -PI * 0.5 + TAU * float(i) / float(count)
		var target: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		walker.begin_social_move(target)

func _get_social_participant_by_name(participants: Array, unit_name: String) -> CampRosterWalker:
	var key: String = str(unit_name).strip_edges()
	if key == "":
		return null
	for p in participants:
		if not (p is CampRosterWalker) or not is_instance_valid(p):
			continue
		var walker: CampRosterWalker = p as CampRosterWalker
		if walker.unit_name == key:
			return walker
	return null

func _clear_spontaneous_social_speaking_state() -> void:
	for p in _spontaneous_social_participants:
		if not (p is CampRosterWalker) or not is_instance_valid(p):
			continue
		var walker: CampRosterWalker = p as CampRosterWalker
		walker.end_speaking()
		walker.end_listening()

func _show_spontaneous_social_line() -> void:
	if _spontaneous_social_index < 0 or _spontaneous_social_index >= _spontaneous_social_lines.size():
		return
	_clear_spontaneous_social_speaking_state()
	var line: Dictionary = _spontaneous_social_lines[_spontaneous_social_index]
	var speaker_name: String = str(line.get("speaker", "")).strip_edges()
	var text: String = str(line.get("text", "")).strip_edges()
	var speaker_walker: CampRosterWalker = _get_social_participant_by_name(_spontaneous_social_participants, speaker_name)
	var center: Vector2 = _get_social_group_center(_spontaneous_social_participants)
	for p in _spontaneous_social_participants:
		if not (p is CampRosterWalker) or not is_instance_valid(p):
			continue
		var walker: CampRosterWalker = p as CampRosterWalker
		if speaker_walker != null and walker == speaker_walker:
			var focus_target: Vector2 = center
			for other in _spontaneous_social_participants:
				if other is CampRosterWalker and other != walker and is_instance_valid(other):
					focus_target = (other as CampRosterWalker).global_position
					break
			walker.face_toward(focus_target)
			walker.begin_speaking()
		else:
			if speaker_walker != null:
				walker.face_toward(speaker_walker.global_position)
			walker.begin_listening()
	_record_ambient_history("social", _spontaneous_social_entry, speaker_name, _spontaneous_social_index == 0)
	_bubble.show_ambient_bubble(text, speaker_walker, speaker_name)
	var now: float = Time.get_ticks_msec() / 1000.0
	_spontaneous_social_current_until = now + _get_dynamic_ambient_duration(text, _spontaneous_social_participants.size(), float(_spontaneous_social_entry.get("duration", SPONTANEOUS_SOCIAL_LINE_DURATION)))

func _advance_spontaneous_social() -> void:
	_spontaneous_social_index += 1
	if _spontaneous_social_index >= _spontaneous_social_lines.size():
		_end_spontaneous_social()
		return
	_show_spontaneous_social_line()

func _cancel_pending_spontaneous_social() -> void:
	_clear_spontaneous_social_speaking_state()
	for p in _spontaneous_social_participants:
		if p is CampRosterWalker and is_instance_valid(p):
			(p as CampRosterWalker).end_social_move()
	_spontaneous_social_active = false
	_spontaneous_social_entry = {}
	_spontaneous_social_participants.clear()
	_spontaneous_social_speaker = null
	_spontaneous_social_lines.clear()
	_spontaneous_social_index = 0
	_spontaneous_social_current_until = 0.0
	_spontaneous_social_meetup_started_at = 0.0
	_spontaneous_social_settle_until = 0.0
	_bubble.hide_ambient_bubble()
	var now: float = Time.get_ticks_msec() / 1000.0
	_spontaneous_social_next_attempt_time = now + randf_range(SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MIN, SPONTANEOUS_SOCIAL_ATTEMPT_INTERVAL_MAX)

func _collect_passing_observers(entry: Dictionary, existing_participants: Array, center: Vector2) -> Array:
	var max_observers: int = mini(clampi(int(entry.get("max_observers", 0)), 0, SPONTANEOUS_SOCIAL_MAX_OBSERVERS), SPONTANEOUS_SOCIAL_MAX_OBSERVERS)
	if max_observers <= 0:
		return []
	var observer_units_v: Variant = entry.get("observer_units", [])
	if not (observer_units_v is Array):
		return []
	var observer_radius: float = float(entry.get("observer_radius", SPONTANEOUS_SOCIAL_OBSERVER_RADIUS))
	var candidates: Array = []
	for unit_name_v in observer_units_v:
		var unit_name: String = str(unit_name_v).strip_edges()
		if unit_name == "":
			continue
		var observer: CampRosterWalker = _ctx.get_walker_by_name(unit_name)
		if observer == null or observer in existing_participants:
			continue
		if not observer.is_available_for_social():
			continue
		var dist_sq: float = observer.global_position.distance_squared_to(center)
		if dist_sq > observer_radius * observer_radius:
			continue
		candidates.append({ "walker": observer, "dist_sq": dist_sq })
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("dist_sq", 0.0)) < float(b.get("dist_sq", 0.0))
	)
	var out: Array = []
	for candidate in candidates:
		if out.size() >= max_observers:
			break
		out.append(candidate.get("walker"))
	return out

func _get_eligible_micro_bark() -> Dictionary:
	var player: Node2D = _player_node()
	if player == null:
		return {}
	var context: Dictionary = _ctx.build_camp_context_dict()
	var best: Dictionary = {}
	var best_score: float = -99999.0
	for entry in CAMP_MICRO_BARK_DB.get_all_micro_barks():
		if not (entry is Dictionary):
			continue
		var bark: Dictionary = entry
		if bark.get("once_per_visit", false):
			var mid: String = str(bark.get("id", "")).strip_edges()
			if mid != "" and _micro_bark_shown_this_visit.get(mid, false):
				continue
		if not CAMP_MICRO_BARK_DB.when_matches(bark, context):
			continue
		var speaker: String = str(bark.get("speaker", "")).strip_edges()
		var listener: String = str(bark.get("listener", "")).strip_edges()
		if speaker.is_empty() or listener.is_empty():
			continue
		if not _ctx.content_condition_matches(bark, speaker, listener):
			continue
		if not _ctx.pair_memory_matches(bark, speaker, listener):
			continue
		var speaker_walker: Node = _ctx.find_walker_by_name(speaker)
		var listener_walker: Node = _ctx.find_walker_by_name(listener)
		if speaker_walker == null or listener_walker == null:
			continue
		var pair_radius: float = float(bark.get("pair_radius", CAMP_MICRO_BARK_DB.MICRO_BARK_DEFAULT_PAIR_RADIUS)) * 1.1
		if not _ctx.are_walkers_near_each_other(speaker_walker, listener_walker, pair_radius):
			continue
		var radius: float = float(bark.get("radius", CAMP_MICRO_BARK_DB.MICRO_BARK_DEFAULT_RADIUS)) * 1.1
		if player.global_position.distance_squared_to(speaker_walker.global_position) > radius * radius:
			continue
		if bark.has("zone_type"):
			var zt: String = str(bark.get("zone_type", "")).strip_edges()
			if zt != "" and not _ctx.is_walker_near_zone(speaker_walker, zt):
				continue
		var score: float = _ctx.score_with_relationship_bias(float(bark.get("priority", 0)), bark, speaker, listener)
		score += _ctx.visit_theme_score_adjust(bark, "micro")
		score -= _get_recent_history_penalty("micro", bark, speaker)
		if score > best_score:
			best_score = score
			best = bark
	return best
