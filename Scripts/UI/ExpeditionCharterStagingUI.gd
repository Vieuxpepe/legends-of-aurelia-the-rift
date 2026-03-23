# Expedition Charter — player-facing co-op staging before battle. Binds to CoopExpeditionSessionManager;
# launch uses finalize → CoopExpeditionBattleHandoff → pending handoff → CampaignManager.launch_expedition_with_pending_mock_coop_handoff.
class_name ExpeditionCharterStagingUI
extends CanvasLayer

signal closed

@onready var _title_label: Label = %TitleLabel
@onready var _charter_tagline: Label = %CharterTaglineLabel
@onready var _expedition_title: Label = %ExpeditionTitleLabel
@onready var _local_participant_rt: RichTextLabel = %LocalParticipantRichText
@onready var _partner_participant_rt: RichTextLabel = %PartnerParticipantRichText
@onready var _body: RichTextLabel = %BodyRichText
@onready var _launch_status_panel: PanelContainer = %LaunchStatusPanel
@onready var _blockers_label: RichTextLabel = %BlockersRichText
@onready var _launch_button: Button = %LaunchButton
@onready var _stage_partner_button: Button = %StagePartnerButton
@onready var _local_ready_button: Button = %LocalReadyButton
@onready var _partner_ready_button: Button = %PartnerReadyButton
@onready var _back_button: Button = %BackButton
@onready var _lan_section: VBoxContainer = %LanSectionVBox
@onready var _lan_port_field: LineEdit = %LanPortField
@onready var _lan_address_field: LineEdit = %LanAddressField
@onready var _lan_host_button: Button = %LanHostButton
@onready var _lan_join_button: Button = %LanJoinButton
@onready var _lan_loopback_button: Button = %LanLoopbackButton
@onready var _lan_status_label: Label = %LanStatusLabel

var _map_id: String = ""
var _last_launch_error: String = ""
var _style_launch_status_warn: StyleBoxFlat
var _style_launch_status_ok: StyleBoxFlat


func _ready() -> void:
	layer = 55
	_cache_launch_status_styles()
	_stage_partner_button.pressed.connect(_on_stage_partner_pressed)
	_local_ready_button.pressed.connect(_on_toggle_local_ready_pressed)
	_partner_ready_button.pressed.connect(_on_toggle_partner_ready_pressed)
	_launch_button.pressed.connect(_on_launch_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_lan_host_button.pressed.connect(_on_lan_host_pressed)
	_lan_join_button.pressed.connect(_on_lan_join_pressed)
	_lan_loopback_button.pressed.connect(_on_lan_loopback_pressed)
	if not CoopExpeditionSessionManager.session_state_changed.is_connected(_on_session_state_changed):
		CoopExpeditionSessionManager.session_state_changed.connect(_on_session_state_changed)
	if not CoopExpeditionSessionManager.enet_battle_launch_committed.is_connected(_on_enet_battle_launch_committed):
		CoopExpeditionSessionManager.enet_battle_launch_committed.connect(_on_enet_battle_launch_committed)
	if not CoopExpeditionSessionManager.enet_guest_finalize_finished.is_connected(_on_enet_guest_finalize_finished):
		CoopExpeditionSessionManager.enet_guest_finalize_finished.connect(_on_enet_guest_finalize_finished)
	hide()


func _cache_launch_status_styles() -> void:
	var base: StyleBoxFlat = _launch_status_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if base == null:
		return
	_style_launch_status_warn = base.duplicate() as StyleBoxFlat
	_style_launch_status_ok = base.duplicate() as StyleBoxFlat
	_style_launch_status_ok.bg_color = Color(0.12, 0.16, 0.11, 0.95)
	_style_launch_status_ok.border_color = Color(0.38, 0.52, 0.3, 0.92)
	_launch_status_panel.add_theme_stylebox_override("panel", _style_launch_status_warn)


func _apply_launch_status_panel_style(for_clear_to_launch: bool) -> void:
	if _style_launch_status_ok != null and for_clear_to_launch:
		_launch_status_panel.add_theme_stylebox_override("panel", _style_launch_status_ok)
	elif _style_launch_status_warn != null:
		_launch_status_panel.add_theme_stylebox_override("panel", _style_launch_status_warn)


func open_for_expedition(map_id: String) -> void:
	_map_id = str(map_id).strip_edges()
	_last_launch_error = ""
	_ensure_host_session_for_map(_map_id)
	_refresh_ui()
	show()


func _exit_tree() -> void:
	if CoopExpeditionSessionManager.session_state_changed.is_connected(_on_session_state_changed):
		CoopExpeditionSessionManager.session_state_changed.disconnect(_on_session_state_changed)
	if CoopExpeditionSessionManager.enet_battle_launch_committed.is_connected(_on_enet_battle_launch_committed):
		CoopExpeditionSessionManager.enet_battle_launch_committed.disconnect(_on_enet_battle_launch_committed)
	if CoopExpeditionSessionManager.enet_guest_finalize_finished.is_connected(_on_enet_guest_finalize_finished):
		CoopExpeditionSessionManager.enet_guest_finalize_finished.disconnect(_on_enet_guest_finalize_finished)


func _on_session_state_changed() -> void:
	if visible:
		_refresh_ui()


func _ensure_host_session_for_map(map_key: String) -> void:
	if map_key == "":
		return
	var mgr = CoopExpeditionSessionManager
	var phase: int = mgr.phase
	## Already connected as ENet guest (e.g. world map "Join friend's LAN"): only sync map + payload.
	if mgr.uses_enet_coop_transport() and phase == mgr.Phase.GUEST:
		mgr.set_selected_expedition_map(map_key)
		mgr.refresh_local_player_payload_from_campaign()
		return
	if phase == mgr.Phase.NONE:
		## Skip auto-host when transport is ENet but disconnected (user must tap Host / Join LAN).
		if not mgr.uses_enet_coop_transport():
			mgr.begin_host_session()
	elif phase != mgr.Phase.HOST:
		if mgr.uses_enet_coop_transport() and phase == mgr.Phase.GUEST:
			pass
		else:
			mgr.leave_session()
			mgr.begin_host_session()
	mgr.set_selected_expedition_map(map_key)
	mgr.refresh_local_player_payload_from_campaign()


func _ready_badge(is_ready: bool) -> String:
	if is_ready:
		return "\n[color=#8fdf7a]● [b]Standing by[/b][/color] — ready to sign."
	return "\n[color=#9a9088]○ [b]Not ready[/b][/color] — confirm when prepared."


func _format_commander_card_header(role_title: String, accent_hex: String) -> String:
	return "[font_size=12][color=#%s]%s[/color][/font_size]\n" % [accent_hex, role_title]


func _format_local_participant_card() -> String:
	var s: String = _format_commander_card_header("YOUR COMMAND", "c9b87c")
	var dn: String = str(CoopExpeditionSessionManager.local_player_payload.get("display_name", "")).strip_edges()
	var pid: String = str(CoopExpeditionSessionManager.local_player_payload.get("player_id", "")).strip_edges()
	var who: String = dn if dn != "" else pid
	if who == "":
		who = "Commander"
	s += "[font_size=17][b]%s[/b][/font_size]" % who
	s += _ready_badge(CoopExpeditionSessionManager.local_ready)
	return s


func _format_partner_participant_card(coop_ok: bool) -> String:
	var s: String = _format_commander_card_header("CO-COMMANDER", "d4a574")
	if not coop_ok:
		s += "[color=#b0a090][i]Awaiting contract validation…[/i][/color]"
		return s
	if not CoopExpeditionSessionManager.has_remote_peer_for_staging():
		s += "[color=#e8c8a0][b]Seat open[/b][/color]\n"
		if CoopExpeditionSessionManager.uses_enet_coop_transport():
			s += "[font_size=13][color=#a89888]Use [b]Host LAN game[/b] / [b]Join LAN game[/b] above. On another PC, your partner must enter your [b]LAN IP[/b] and port (not 127.0.0.1). For one machine, use [b]Same-PC rehearsal[/b] or [b]127.0.0.1:port[/b].[/color][/font_size]"
		else:
			s += "[font_size=13][color=#a89888]No co-commander on this charter yet. Use [b]Host LAN game[/b] / [b]Join LAN game[/b] above, or [b]Same-PC rehearsal[/b] then [b]Seat test partner[/b].[/color][/font_size]"
		return s
	var dn: String = str(CoopExpeditionSessionManager.remote_player_payload.get("display_name", "")).strip_edges()
	var pid: String = str(CoopExpeditionSessionManager.remote_player_payload.get("player_id", "")).strip_edges()
	var who: String = dn if dn != "" else pid
	if who == "":
		who = "Partner"
	s += "[font_size=17][b]%s[/b][/font_size]" % who
	s += _ready_badge(CoopExpeditionSessionManager.remote_ready)
	return s


func _divider_bb() -> String:
	return "[color=#5c4d3a]————————————————————[/color]"


## Display labels for the same ordered command IDs locked at charter finalize (see MockCoopDetachmentAssignment).
func _charter_deployment_display_names_ordered() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var ids: PackedStringArray = MockCoopDetachmentAssignment.build_ordered_command_unit_ids_from_campaign()
	for i in range(ids.size()):
		out.append(MockCoopDetachmentAssignment.display_label_for_command_unit_id(ids[i]))
	return out


func _format_detachment_command_preview_bbcode(ordered_names: PackedStringArray) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[font_size=16][color=#d8c8a8][b]Command preview[/b][/color][/font_size]")
	lines.append("[font_size=12][color=#918888][i]Split is [b]locked when you sign the charter[/b] from this roster order ([b]ceil(n/2)[/b] to you, rest to partner). Pre-battle moves do [b]not[/b] reassign command. Scenario allies not on this roster use partner command unless listed in a future handoff revision.[/i][/color][/font_size]")
	lines.append("")
	var n: int = ordered_names.size()
	if n == 0:
		lines.append("[color=#a89888]No names in your current deployment roster preview — the split applies once units are fielded.[/color]")
		lines.append("")
		lines.append("[font_size=12][color=#7a7068][i]Uses [b]MockCoopDetachmentAssignment[/b] (roster + adult dragons), same IDs as [b]BattleField.get_relationship_id[/b]. Signing stores this split in the expedition handoff.[/i][/font_size]")
		return "\n".join(lines)

	var local_slots: int = MockCoopBattleContext.mock_coop_local_command_slot_count(n)
	lines.append("[color=#8a9088]Units listed ([b]roster spawn order[/b]): [b]%d[/b]  ·  If [b]all[/b] are fielded at battle start: your slots [b]%d[/b]  ·  partner [b]%d[/b][/color]" % [n, local_slots, n - local_slots])
	lines.append("")
	lines.append("[color=#6ec8e8][b]Your detachment[/b][/color] [color=#8a9088](commander of record)[/color]")
	if local_slots <= 0:
		lines.append("   [color=#888888]—[/color]")
	else:
		for i in range(local_slots):
			lines.append("   [color=#c8e8f8]•[/color]  %s" % ordered_names[i])
	lines.append("")
	lines.append("[color=#e8a868][b]Partner detachment[/b][/color] [color=#8a9088](co-commander)[/color]")
	if local_slots >= n:
		lines.append("   [color=#888888]—[/color]")
	else:
		for j in range(local_slots, n):
			lines.append("   [color=#f0c898]•[/color]  %s" % ordered_names[j])
	lines.append("")
	lines.append("[font_size=12][color=#7a7068][i]IDs match battle roster spawn ([b]Avatar[/b] for custom commander). Benched units keep the same commander as on the charter. Units not in this list (e.g. map allies) are treated as [b]partner[/b] command at battle load.[/i][/font_size]")
	return "\n".join(lines)


func _refresh_ui() -> void:
	var entry: Dictionary = ExpeditionMapDatabase.get_map_by_id(_map_id)
	_title_label.text = "Expedition Charter"
	_charter_tagline.text = "Joint expedition contract · war-table staging"
	if entry.is_empty():
		_expedition_title.text = _map_id if _map_id != "" else "Unknown chart"
	else:
		_expedition_title.text = ExpeditionMapDatabase.build_world_map_short_title(entry)

	var hazard: String = str(entry.get("world_map_hazard_pitch", "")).strip_edges()
	var mod_line: String = ExpeditionMapDatabase.build_expedition_modifier_ui_line(entry)
	var desc: String = str(entry.get("description", "")).strip_edges()

	var coop_ok: bool = false
	if not entry.is_empty():
		coop_ok = bool(entry.get("coop_enabled", false)) and CampaignManager.can_use_expedition_for_coop(_map_id)

	_local_participant_rt.text = _format_local_participant_card()
	_partner_participant_rt.text = _format_partner_participant_card(coop_ok)

	var body_bb: PackedStringArray = PackedStringArray()
	var roster_preview: PackedStringArray = _charter_deployment_display_names_ordered()
	if not coop_ok:
		body_bb.append("[color=#e8a070][b]Contract note[/b][/color]")
		body_bb.append("This chart cannot be staged for co-op from your current campaign state (ownership or expedition flags).")
		body_bb.append("")
		body_bb.append(_divider_bb())
		body_bb.append("")
		body_bb.append(_format_detachment_command_preview_bbcode(roster_preview))
	else:
		body_bb.append("[font_size=16][color=#d8c8a8][b]Route and contract[/b][/color][/font_size]")
		if hazard != "":
			body_bb.append("[b]Hazard briefing:[/b] " + hazard)
		if mod_line != "":
			body_bb.append(mod_line)
		if desc != "":
			body_bb.append("")
			body_bb.append("[color=#b8a898][i]%s[/i][/color]" % desc)
		body_bb.append("")
		body_bb.append(_divider_bb())
		body_bb.append("")
		body_bb.append(_format_detachment_command_preview_bbcode(roster_preview))

	_body.text = "\n".join(body_bb)
	_body.scroll_to_line(0)

	if not coop_ok:
		if _lan_section != null:
			_lan_section.visible = false
		_blockers_label.text = "[b][color=#f0c090]Marshal's desk — hold[/color][/b]\nCo-op staging is [b]not available[/b] for this chart from your current save."
		if _last_launch_error.strip_edges() != "":
			_blockers_label.text += "\n\n[color=#d08060][b]Last error[/b][/color]\n" + _last_launch_error
		_apply_launch_status_panel_style(false)
		_launch_button.disabled = true
		_stage_partner_button.disabled = true
		_local_ready_button.disabled = true
		_partner_ready_button.disabled = true
		_blockers_label.scroll_to_line(0)
		_local_ready_button.text = "Your readiness"
		_partner_ready_button.text = "Partner readiness"
		return

	if _lan_section != null:
		_lan_section.visible = true
	_refresh_lan_status_line()

	var guest_enet_pending: bool = (
			CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.GUEST
			and CoopExpeditionSessionManager.uses_enet_coop_transport()
			and CoopExpeditionSessionManager.is_enet_guest_finalize_request_pending()
	)

	var blockers: PackedStringArray = CoopExpeditionSessionManager.get_coop_launch_blockers()
	## Do not treat guest "waiting on host" as a marshal blocker — it wrongly shows orange requirements while staging is valid.
	if _last_launch_error.strip_edges() != "" and not guest_enet_pending:
		var extra: PackedStringArray = blockers.duplicate()
		extra.append("last_launch: " + _last_launch_error)
		blockers = extra

	var all_clear: bool = blockers.is_empty()
	if guest_enet_pending and all_clear:
		_blockers_label.text = (
				"[b][color=#a8e090]Marshal's desk — co-op finalize sent[/color][/b]\n"
				+ "[b]Request is with the host.[/b] Keep this window open; when the host finishes finalize, both games should load the battle.\n"
				+ "[font_size=12][color=#a0a0b8][i]Tip: leave the [b]host[/b] instance running in the foreground — if the OS or Godot pauses unfocused games, ENet may not process until you switch back.[/i][/color][/font_size]"
		)
		_apply_launch_status_panel_style(true)
	elif all_clear:
		_blockers_label.text = "[b][color=#a8e090]Marshal's desk — clear[/color][/b]\n[b]All staging checks passed.[/b] You may [b]sign the charter[/b] and deploy when satisfied."
		_apply_launch_status_panel_style(true)
	else:
		var lines: PackedStringArray = PackedStringArray()
		lines.append("[b][color=#f0b070]Marshal's desk — requirements[/color][/b]")
		lines.append("Resolve the following before deployment:")
		for b in blockers:
			lines.append("   [color=#e8c8a8]•[/color]  " + str(b))
		_blockers_label.text = "\n".join(lines)
		_apply_launch_status_panel_style(false)

	_blockers_label.scroll_to_line(0)

	var launchable: bool = CoopExpeditionSessionManager.is_session_launchable() and coop_ok
	_launch_button.disabled = not launchable or guest_enet_pending

	var is_host: bool = CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.HOST
	var loopback: bool = CoopExpeditionSessionManager.uses_loopback_coop_transport()
	_stage_partner_button.disabled = not is_host or not coop_ok or not loopback
	_local_ready_button.disabled = not coop_ok
	## ENet: each player toggles readiness on their own copy; loopback host can fake partner ready for rehearsal.
	_partner_ready_button.disabled = not coop_ok or not CoopExpeditionSessionManager.has_remote_peer_for_staging() or not loopback

	_local_ready_button.text = "Stand down (not ready)" if CoopExpeditionSessionManager.local_ready else "Signal ready (you)"
	_partner_ready_button.text = "Partner: stand down" if CoopExpeditionSessionManager.remote_ready else "Partner: signal ready"
	_stage_partner_button.text = "Seat test partner"


func _on_stage_partner_pressed() -> void:
	var res: Dictionary = CoopExpeditionSessionManager.apply_loopback_partner_staging_payload([_map_id], false)
	if not bool(res.get("ok", false)):
		_last_launch_error = "stage_partner: " + str(res.get("error", "failed"))
	else:
		_last_launch_error = ""
	_refresh_ui()


func _on_toggle_local_ready_pressed() -> void:
	CoopExpeditionSessionManager.set_local_ready(not CoopExpeditionSessionManager.local_ready)
	_last_launch_error = ""
	_refresh_ui()


func _on_toggle_partner_ready_pressed() -> void:
	CoopExpeditionSessionManager.set_remote_ready(not CoopExpeditionSessionManager.remote_ready)
	_last_launch_error = ""
	_refresh_ui()


func _on_launch_pressed() -> void:
	_last_launch_error = ""
	if CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.GUEST and CoopExpeditionSessionManager.uses_enet_coop_transport():
		_last_launch_error = ""
		CoopExpeditionSessionManager.enet_guest_request_finalize_launch()
		_refresh_ui()
		return
	var fin: Dictionary = CoopExpeditionSessionManager.finalize_coop_expedition_launch()
	if not bool(fin.get("ok", false)):
		_last_launch_error = str(fin.get("errors", []))
		_refresh_ui()
		return

	var hand_res: Dictionary = CoopExpeditionBattleHandoff.prepare_from_finalize_result(fin)
	if not bool(hand_res.get("ok", false)):
		_last_launch_error = str(hand_res.get("errors", []))
		_refresh_ui()
		return

	var hh: Variant = hand_res.get("handoff", {})
	if typeof(hh) != TYPE_DICTIONARY:
		_last_launch_error = "handoff_missing"
		_refresh_ui()
		return

	if CoopExpeditionSessionManager.uses_enet_coop_transport() and CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.HOST:
		if not CoopExpeditionSessionManager.try_begin_enet_host_launch_pipeline():
			_last_launch_error = "Launch already in progress (network)."
			_refresh_ui()
			return

	if CoopExpeditionSessionManager.should_enet_mirror_launch_handoff_to_guest():
		CoopExpeditionSessionManager.enet_host_send_launch_handoff(hh as Dictionary)

	if CoopExpeditionSessionManager.uses_enet_coop_transport() and CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.HOST:
		## Let launch_handoff / stack flush reach the guest before this instance loads the battle (same issue as finalize_result).
		await get_tree().create_timer(0.18, true, true, true).timeout
		var exec_res: Dictionary = CoopExpeditionSessionManager.enet_execute_pending_handoff_launch(hh as Dictionary, false)
		if not bool(exec_res.get("ok", false)):
			CoopExpeditionSessionManager.release_enet_host_launch_pipeline()
			_last_launch_error = str(exec_res.get("errors", []))
			_refresh_ui()
			return
		CoopExpeditionSessionManager.release_enet_host_launch_pipeline()
		hide()
		closed.emit()
		queue_free()
		return

	var store_res: Dictionary = CampaignManager.store_pending_mock_coop_battle_handoff(hh as Dictionary)
	if not bool(store_res.get("ok", false)):
		_last_launch_error = str(store_res.get("errors", []))
		_refresh_ui()
		return

	var launch_res: Dictionary = CampaignManager.launch_expedition_with_pending_mock_coop_handoff()
	if not bool(launch_res.get("ok", false)):
		_last_launch_error = str(launch_res.get("errors", []))
		_refresh_ui()
		return

	hide()
	closed.emit()
	queue_free()


func _refresh_lan_status_line() -> void:
	if _lan_status_label == null:
		return
	var mgr = CoopExpeditionSessionManager
	var bits: PackedStringArray = PackedStringArray()
	if mgr.uses_loopback_coop_transport():
		bits.append("Mode: same-PC rehearsal")
	elif mgr.uses_enet_coop_transport():
		bits.append("Mode: LAN")
		var tr: CoopSessionTransport = mgr.get_transport()
		if tr is ENetCoopTransport:
			var en: ENetCoopTransport = tr as ENetCoopTransport
			bits.append("port %d" % en.get_listen_port())
			bits.append("link: %s" % ("ok" if en.is_session_wired() else "connecting…"))
	else:
		bits.append("Mode: —")
	if str(mgr.session_id).strip_edges() != "":
		bits.append("id %s" % mgr.session_id)
	match mgr.phase:
		mgr.Phase.HOST:
			bits.append("you: host")
		mgr.Phase.GUEST:
			bits.append("you: guest")
		_:
			bits.append("you: set up host/join above")
	_lan_status_label.text = " · ".join(bits)


func _lan_apply_session_after_transport_change() -> void:
	CoopExpeditionSessionManager.set_selected_expedition_map(_map_id)
	CoopExpeditionSessionManager.refresh_local_player_payload_from_campaign()
	_last_launch_error = ""
	_refresh_ui()


func _on_lan_host_pressed() -> void:
	var p: int = int(str(_lan_port_field.text).strip_edges())
	if p <= 0:
		p = ENetCoopTransport.DEFAULT_PORT
	CoopExpeditionSessionManager.leave_session()
	var tr := ENetCoopTransport.new()
	tr.configure_listen_port(p)
	CoopExpeditionSessionManager.set_transport(tr)
	var r: Dictionary = CoopExpeditionSessionManager.begin_host_session()
	if not bool(r.get("ok", false)):
		_last_launch_error = "LAN host: " + str(r.get("error", str(r)))
		_refresh_ui()
		return
	_lan_apply_session_after_transport_change()


func _on_lan_join_pressed() -> void:
	var jp: String = str(_lan_address_field.text).strip_edges()
	if jp == "":
		_last_launch_error = "Enter the host address (host:port)."
		_refresh_ui()
		return
	CoopExpeditionSessionManager.leave_session()
	var tr := ENetCoopTransport.new()
	if jp.contains(":"):
		var parts: PackedStringArray = jp.split(":")
		if parts.size() >= 2:
			var pt: int = int(str(parts[parts.size() - 1]).strip_edges())
			if pt > 0:
				tr.configure_listen_port(pt)
	CoopExpeditionSessionManager.set_transport(tr)
	var r: Dictionary = CoopExpeditionSessionManager.join_session(jp)
	if not bool(r.get("ok", false)):
		_last_launch_error = "LAN join: " + str(r.get("error", str(r)))
		_refresh_ui()
		return
	_lan_apply_session_after_transport_change()


func _on_lan_loopback_pressed() -> void:
	CoopExpeditionSessionManager.leave_session()
	var lb := LocalLoopbackCoopTransport.new()
	CoopExpeditionSessionManager.set_transport(lb)
	var r: Dictionary = CoopExpeditionSessionManager.begin_host_session()
	if not bool(r.get("ok", false)):
		_last_launch_error = "Offline rehearsal: " + str(r.get("error", str(r)))
		_refresh_ui()
		return
	_lan_apply_session_after_transport_change()


func _on_back_pressed() -> void:
	_last_launch_error = ""
	if CoopExpeditionSessionManager.uses_enet_coop_transport() and CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.GUEST:
		CoopExpeditionSessionManager.clear_enet_guest_finalize_pending()
	hide()
	closed.emit()
	queue_free()


func _on_enet_battle_launch_committed() -> void:
	if not visible:
		return
	_last_launch_error = ""
	hide()
	closed.emit()
	queue_free()


func _on_enet_guest_finalize_finished(fin: Dictionary) -> void:
	if not visible:
		return
	if bool(fin.get("ok", false)):
		return
	_last_launch_error = str(fin.get("errors", []))
	_refresh_ui()
