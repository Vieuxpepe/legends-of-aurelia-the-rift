extends RefCounted

# Player-phase turn-flow glue: mock co-op detachment readiness, END TURN button nudge, deployed/all-units iteration.

static func mock_coop_unit_ownership_bbcode_line_for_panel(field, unit: Node2D) -> String:
	if unit == null or not is_instance_valid(unit):
		return ""
	if not field.is_mock_coop_unit_ownership_active():
		return ""
	if not field._is_friendly_unit_on_field(unit):
		return ""
	var o: String = field.get_mock_coop_unit_owner_for_unit(unit)
	if o == field.MOCK_COOP_OWNER_REMOTE:
		return "[color=orange][b]Partner Unit[/b][/color] (co-op)\n"
	if o == field.MOCK_COOP_OWNER_LOCAL:
		return "[color=cyan][b]Your Unit[/b][/color] (co-op)\n"
	return ""


static func get_mock_coop_player_phase_detachment_counts(field) -> Dictionary:
	var out: Dictionary = {"valid": false, "local_total": 0, "local_ready": 0, "partner_fielded": 0}
	if not field.is_mock_coop_unit_ownership_active() or field.current_state != field.player_state:
		return out
	out["valid"] = true
	var total: int = 0
	var ready: int = 0
	var partner_fielded: int = 0
	for cont in [field.player_container, field.ally_container]:
		if cont == null:
			continue
		for u in cont.get_children():
			if not is_instance_valid(u) or u.is_queued_for_deletion():
				continue
			if u.get("current_hp") == null or int(u.current_hp) <= 0:
				continue
			if not is_mock_coop_deployed_player_side_unit(field, u):
				continue
			var own: String = field.get_mock_coop_unit_owner_for_unit(u)
			if own == field.MOCK_COOP_OWNER_LOCAL:
				total += 1
				if u.get("is_exhausted") == false:
					ready += 1
			elif own == field.MOCK_COOP_OWNER_REMOTE:
				partner_fielded += 1
	out["local_total"] = total
	out["local_ready"] = ready
	out["partner_fielded"] = partner_fielded
	return out


static func is_mock_partner_placeholder_active(field) -> bool:
	if not field.is_mock_coop_unit_ownership_active() or field.current_state != field.player_state:
		return false
	var c: Dictionary = get_mock_coop_player_phase_detachment_counts(field)
	if not bool(c.get("valid", false)):
		return false
	var lt: int = int(c.get("local_total", 0))
	var lr: int = int(c.get("local_ready", 0))
	var pf: int = int(c.get("partner_fielded", 0))
	return lt > 0 and lr == 0 and pf > 0


static func build_mock_coop_player_phase_readiness_bbcode_suffix(field) -> String:
	var c: Dictionary = get_mock_coop_player_phase_detachment_counts(field)
	if not bool(c.get("valid", false)):
		return ""
	var total: int = int(c.get("local_total", 0))
	var ready: int = int(c.get("local_ready", 0))
	var partner_fielded: int = int(c.get("partner_fielded", 0))
	if total <= 0:
		return ""
	var s: String = "\n[color=cyan][b]Co-op â€” Your units ready: %d / %d[/b][/color]" % [ready, total]
	if partner_fielded > 0:
		var partner_state: String = "Ready" if field._mock_coop_remote_player_phase_ready else "Acting"
		s += "\n[color=gold][b]Partner commander: %s[/b][/color]" % partner_state
	if field._mock_coop_local_player_phase_ready:
		s += "\n[color=cyan][font_size=16]You have ended your phase for this turn.[/font_size][/color]"
		if partner_fielded > 0 and not field._mock_coop_remote_player_phase_ready:
			s += "\n[color=gold][b]Waiting for your partner to proceed to enemy phase.[/b][/color]"
	elif ready == 0:
		s += "\n[color=gray][font_size=16]All your fielded units have acted this phase.[/font_size][/color]"
		if partner_fielded > 0:
			s += "\n[color=orange][font_size=16]Partner detachment still on the field â€” not under your command. End or Skip phase when you are ready.[/font_size][/color]"
	elif partner_fielded > 0 and field._mock_coop_remote_player_phase_ready:
		s += "\n[color=gold][font_size=16]Partner is ready. Finish your commands when you are ready.[/font_size][/color]"
	return s + "\n"


static func update_skip_button_visual_modulate(field) -> void:
	var btn: Button = field.get_node_or_null("UI/SkipButton") as Button
	if btn == null or not btn.visible:
		return
	if not field._skip_button_base_modulate_captured:
		field._skip_button_base_modulate = btn.modulate
		field._skip_button_base_modulate_captured = true
	var m: Color = field._skip_button_base_modulate
	if is_mock_partner_placeholder_active(field):
		m *= Color(1.14, 1.12, 0.96, 1.0)
	var pulse_active: bool = field._should_pulse_skip_button_end_turn_nudge()
	if pulse_active:
		var t: float = float(Time.get_ticks_msec()) * field.END_TURN_PULSE_TIME_SCALE
		var wave: float = 0.5 + 0.5 * sin(t)
		var wave_scale: float = 0.5 + 0.5 * sin(t * 1.19 + 0.85)
		var boost: float = 1.0 + field.END_TURN_PULSE_MOD_DEPTH * wave
		m *= Color(boost * 1.12, boost * 1.04, boost * 0.78, 1.0)
		var s: float = field.END_TURN_PULSE_SCALE_CENTER + field.END_TURN_PULSE_SCALE_DEPTH * (wave_scale - 0.5) * 2.0
		btn.pivot_offset = btn.size * 0.5
		btn.scale = Vector2(s, s)
	else:
		btn.scale = Vector2.ONE
		btn.pivot_offset = Vector2.ZERO
	btn.modulate = m


static func is_mock_coop_deployed_player_side_unit(field, unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit) or unit.is_queued_for_deletion():
		return false
	if unit is CanvasItem and not (unit as CanvasItem).visible:
		return false
	if unit.process_mode == Node.PROCESS_MODE_DISABLED:
		return false
	return true


static func get_mock_coop_deployed_player_side_unit_nodes(field) -> Array:
	var out: Array = []
	if field.player_container != null:
		for u in field.player_container.get_children():
			if is_mock_coop_deployed_player_side_unit(field, u):
				out.append(u)
	if field.ally_container != null:
		for u in field.ally_container.get_children():
			if is_mock_coop_deployed_player_side_unit(field, u):
				out.append(u)
	return out


static func iter_all_player_side_unit_nodes_for_mock_coop(field) -> Array:
	var out: Array = []
	for cont in [field.player_container, field.ally_container]:
		if cont == null:
			continue
		for u in cont.get_children():
			if u == null or not is_instance_valid(u) or u.is_queued_for_deletion():
				continue
			out.append(u)
	return out
