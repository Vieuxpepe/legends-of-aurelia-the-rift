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
@onready var _online_section: VBoxContainer = %OnlineSectionVBox
@onready var _online_room_code_field: LineEdit = %OnlineRoomCodeField
@onready var _online_host_button: Button = %OnlineHostButton
@onready var _online_join_button: Button = %OnlineJoinButton
@onready var _online_refresh_button: Button = %OnlineRefreshButton
@onready var _online_room_list: ItemList = %OnlineRoomList
@onready var _online_status_label: Label = %OnlineStatusLabel
@onready var _local_companion_option: OptionButton = %LocalCompanionOption
@onready var _partner_companion_value: Label = %PartnerCompanionValue

var _map_id: String = ""
var _last_launch_error: String = ""
var _style_launch_status_warn: StyleBoxFlat
var _style_launch_status_ok: StyleBoxFlat
var _local_companion_option_ids: PackedStringArray = PackedStringArray()
var _online_browser_transport: SilentWolfOnlineCoopTransport = null
var _online_room_list_initialized: bool = false


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
	_online_host_button.pressed.connect(_on_online_host_pressed)
	_online_join_button.pressed.connect(_on_online_join_pressed)
	_online_refresh_button.pressed.connect(_on_online_refresh_pressed)
	_online_room_list.item_selected.connect(_on_online_room_selected)
	_online_room_list.item_activated.connect(_on_online_room_activated)
	_local_companion_option.item_selected.connect(_on_local_companion_selected)
	_ensure_online_browser_transport()
	if not CoopExpeditionSessionManager.session_state_changed.is_connected(_on_session_state_changed):
		CoopExpeditionSessionManager.session_state_changed.connect(_on_session_state_changed)
	if not CoopExpeditionSessionManager.enet_battle_launch_committed.is_connected(_on_enet_battle_launch_committed):
		CoopExpeditionSessionManager.enet_battle_launch_committed.connect(_on_enet_battle_launch_committed)
	if not CoopExpeditionSessionManager.enet_guest_finalize_finished.is_connected(_on_enet_guest_finalize_finished):
		CoopExpeditionSessionManager.enet_guest_finalize_finished.connect(_on_enet_guest_finalize_finished)
	hide()


func _process(_delta: float) -> void:
	if _online_browser_transport != null:
		_online_browser_transport.poll_transport()


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
	## Already connected as a network guest (e.g. LAN join / online room): only sync map + payload.
	if (mgr.uses_enet_coop_transport() or mgr.uses_online_coop_transport()) and phase == mgr.Phase.GUEST:
		mgr.set_selected_expedition_map(map_key)
		mgr.refresh_local_player_payload_from_campaign()
		return
	if phase == mgr.Phase.NONE:
		## Skip auto-host when the transport expects an explicit network bootstrap (LAN or online room).
		if not mgr.uses_enet_coop_transport() and not mgr.uses_online_coop_transport():
			mgr.begin_host_session()
	elif phase != mgr.Phase.HOST:
		if (mgr.uses_enet_coop_transport() or mgr.uses_online_coop_transport()) and phase == mgr.Phase.GUEST:
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
		elif CoopExpeditionSessionManager.uses_online_coop_transport():
			s += "[font_size=13][color=#a89888]Use the [b]Online room[/b] controls above and share the room code with your partner. This path relays staging and live battle sync through the online room service, so expect a little more latency than LAN/direct play.[/color][/font_size]"
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

@warning_ignore("unreachable_code")
func _format_detachment_command_preview_bbcode(ordered_names: PackedStringArray) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[font_size=16][color=#d8c8a8][b]Command preview[/b][/color][/font_size]")
	lines.append("[font_size=12][color=#918888][i]Each commander brings [b]exactly two units[/b]: their Avatar and one selected companion. Signing the charter locks a shared four-unit battle handoff so both LAN peers load the same commander roster.[/i][/color][/font_size]")
	lines.append("")
	lines.append("[color=#6ec8e8][b]Your detachment[/b][/color] [color=#8a9088](commander of record)[/color]")
	lines.append("   [color=#c8e8f8]-[/color]  %s" % _get_local_avatar_preview_name())
	lines.append("   [color=#c8e8f8]-[/color]  %s" % _get_local_companion_preview_name())
	lines.append("")
	lines.append("[color=#e8a868][b]Partner detachment[/b][/color] [color=#8a9088](co-commander)[/color]")
	lines.append("   [color=#f0c898]-[/color]  %s" % _get_remote_avatar_preview_name())
	lines.append("   [color=#f0c898]-[/color]  %s" % _get_remote_companion_preview_name())
	lines.append("")
	lines.append("[font_size=12][color=#7a7068][i]Pre-battle deployment only uses these four commander units. Partner-owned units stay partner-owned in battle, and deployment sync mirrors those same four units instead of rebuilding from each save's full roster.[/i][/font_size]")
	return "\n".join(lines)
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


func _get_local_avatar_preview_name() -> String:
	var payload: Dictionary = CoopExpeditionSessionManager.local_player_payload
	var name_str: String = str(payload.get("coop_party_avatar_display_name", "")).strip_edges()
	if name_str == "":
		name_str = str(payload.get("display_name", "")).strip_edges()
	if name_str == "":
		name_str = str(CampaignManager.custom_avatar.get("unit_name", CampaignManager.custom_avatar.get("name", "Commander"))).strip_edges()
	return name_str if name_str != "" else "Commander"


func _get_remote_avatar_preview_name() -> String:
	if not CoopExpeditionSessionManager.has_remote_peer_for_staging():
		return "Awaiting partner"
	var payload: Dictionary = CoopExpeditionSessionManager.remote_player_payload
	var name_str: String = str(payload.get("coop_party_avatar_display_name", "")).strip_edges()
	if name_str == "":
		name_str = str(payload.get("display_name", "")).strip_edges()
	return name_str if name_str != "" else "Partner Commander"


func _get_local_companion_preview_name() -> String:
	var payload: Dictionary = CoopExpeditionSessionManager.local_player_payload
	var name_str: String = str(payload.get("selected_companion_display_name", "")).strip_edges()
	if name_str != "":
		return name_str
	var unit_id: String = str(payload.get("selected_companion_unit_id", "")).strip_edges()
	return unit_id if unit_id != "" else "Select a companion"


func _get_remote_companion_preview_name() -> String:
	if not CoopExpeditionSessionManager.has_remote_peer_for_staging():
		return "Awaiting selection"
	var payload: Dictionary = CoopExpeditionSessionManager.remote_player_payload
	var name_str: String = str(payload.get("selected_companion_display_name", "")).strip_edges()
	if name_str != "":
		return name_str
	var unit_id: String = str(payload.get("selected_companion_unit_id", "")).strip_edges()
	return unit_id if unit_id != "" else "Awaiting selection"


func _refresh_local_companion_selector(coop_ok: bool) -> void:
	if _local_companion_option == null:
		return
	_local_companion_option.clear()
	_local_companion_option_ids = PackedStringArray()
	var entries: Array[Dictionary] = CampaignManager.get_mock_coop_companion_candidate_entries()
	var enabled: bool = coop_ok and not entries.is_empty()
	_local_companion_option.disabled = not enabled
	if not enabled:
		_local_companion_option.add_item("No eligible companion")
		_local_companion_option.select(0)
		return
	var selected_id: String = CoopExpeditionSessionManager.get_local_selected_companion_unit_id()
	if selected_id == "":
		var default_id: String = CampaignManager.get_default_mock_coop_companion_unit_id()
		if default_id != "":
			CoopExpeditionSessionManager.set_local_selected_companion_unit_id(default_id)
			selected_id = CoopExpeditionSessionManager.get_local_selected_companion_unit_id()
	var selected_index: int = -1
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var unit_id: String = str(entry.get("unit_id", "")).strip_edges()
		var display_name: String = str(entry.get("display_name", unit_id)).strip_edges()
		if display_name == "":
			display_name = unit_id if unit_id != "" else "Unknown"
		_local_companion_option.add_item(display_name)
		_local_companion_option_ids.append(unit_id)
		if unit_id == selected_id:
			selected_index = i
	if selected_index < 0 and _local_companion_option_ids.size() > 0:
		var fallback_id: String = str(_local_companion_option_ids[0]).strip_edges()
		if fallback_id != "":
			CoopExpeditionSessionManager.set_local_selected_companion_unit_id(fallback_id)
		selected_index = 0
	if selected_index >= 0:
		_local_companion_option.select(selected_index)


func _on_local_companion_selected(index: int) -> void:
	if index < 0 or index >= _local_companion_option_ids.size():
		return
	var unit_id: String = str(_local_companion_option_ids[index]).strip_edges()
	if unit_id == "":
		return
	if not CoopExpeditionSessionManager.set_local_selected_companion_unit_id(unit_id):
		_last_launch_error = "Unable to reserve that companion for co-op staging."
	else:
		_last_launch_error = ""
	_refresh_ui()


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
	_refresh_local_companion_selector(coop_ok)
	if _partner_companion_value != null:
		_partner_companion_value.text = _get_remote_companion_preview_name()

	var body_bb: PackedStringArray = PackedStringArray()
	if not coop_ok:
		body_bb.append("[color=#e8a070][b]Contract note[/b][/color]")
		body_bb.append("This chart cannot be staged for co-op from your current campaign state (ownership or expedition flags).")
		body_bb.append("")
		body_bb.append(_divider_bb())
		body_bb.append("")
		body_bb.append(_format_detachment_command_preview_bbcode(PackedStringArray()))
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
		body_bb.append(_format_detachment_command_preview_bbcode(PackedStringArray()))

	_body.text = "\n".join(body_bb)
	_body.scroll_to_line(0)

	if not coop_ok:
		if _online_section != null:
			_online_section.visible = false
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

	if _online_section != null:
		_online_section.visible = true
		if not _online_room_list_initialized:
			_refresh_online_room_listing()
			_online_room_list_initialized = true
	_refresh_online_status_line()
	if _lan_section != null:
		_lan_section.visible = true
	_refresh_lan_status_line()

	var guest_network_pending: bool = (
			CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.GUEST
			and CoopExpeditionSessionManager.uses_runtime_network_coop_transport()
			and CoopExpeditionSessionManager.is_runtime_finalize_request_pending()
	)

	var blockers: PackedStringArray = CoopExpeditionSessionManager.get_coop_launch_blockers()
	## Do not treat guest "waiting on host" as a marshal blocker — it wrongly shows orange requirements while staging is valid.
	if _last_launch_error.strip_edges() != "" and not guest_network_pending:
		var extra: PackedStringArray = blockers.duplicate()
		extra.append("last_launch: " + _last_launch_error)
		blockers = extra

	var all_clear: bool = blockers.is_empty()
	if guest_network_pending and all_clear:
		_blockers_label.text = (
				"[b][color=#a8e090]Marshal's desk — co-op finalize sent[/color][/b]\n"
				+ "[b]Request is with the host.[/b] Keep this window open; when the host finishes finalize, both games should load the battle.\n"
				+ ("[font_size=12][color=#a0a0b8][i]Tip: online room relay can take a moment to flush the handoff. LAN/direct is faster, online is friendlier to join.[/i][/color][/font_size]" if CoopExpeditionSessionManager.uses_online_coop_transport() else "[font_size=12][color=#a0a0b8][i]Tip: leave the [b]host[/b] instance running in the foreground — if the OS or Godot pauses unfocused games, direct sync may not process until you switch back.[/i][/color][/font_size]")
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
	_launch_button.disabled = not launchable or guest_network_pending

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
	if CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.GUEST and CoopExpeditionSessionManager.uses_runtime_network_coop_transport():
		_last_launch_error = ""
		CoopExpeditionSessionManager.request_runtime_finalize_launch()
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

	if CoopExpeditionSessionManager.uses_runtime_network_coop_transport() and CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.HOST:
		if not CoopExpeditionSessionManager.try_begin_runtime_launch_pipeline():
			_last_launch_error = "Launch already in progress (network)."
			_refresh_ui()
			return

	if CoopExpeditionSessionManager.runtime_host_can_mirror_launch_handoff():
		CoopExpeditionSessionManager.host_send_runtime_launch_handoff(hh as Dictionary)

	if CoopExpeditionSessionManager.uses_runtime_network_coop_transport() and CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.HOST:
		## Let launch_handoff flush through the active transport before this instance loads the battle too.
		await get_tree().create_timer(CoopExpeditionSessionManager.runtime_launch_flush_delay_seconds(), true, true, true).timeout
		var exec_res: Dictionary = CoopExpeditionSessionManager.execute_pending_runtime_handoff_launch(hh as Dictionary, false)
		if not bool(exec_res.get("ok", false)):
			CoopExpeditionSessionManager.release_runtime_launch_pipeline()
			_last_launch_error = str(exec_res.get("errors", []))
			_refresh_ui()
			return
		CoopExpeditionSessionManager.release_runtime_launch_pipeline()
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


func _refresh_online_status_line() -> void:
	if _online_status_label == null:
		return
	var mgr = CoopExpeditionSessionManager
	if not mgr.uses_online_coop_transport():
		var browse_suffix: String = ""
		if _online_browser_transport != null:
			var browser_err: String = _online_browser_transport.get_last_error()
			if browser_err != "":
				browse_suffix = "\nRoom list: %s" % browser_err
		_online_status_label.text = "Online room codes use the SilentWolf service as a lightweight relay for staging and live battle sync. LAN/direct play remains available below for the fastest local link." + browse_suffix
		return
	var transport_instance: CoopSessionTransport = mgr.get_transport()
	if transport_instance is SilentWolfOnlineCoopTransport:
		var online: SilentWolfOnlineCoopTransport = transport_instance as SilentWolfOnlineCoopTransport
		var msg: String = online.get_status_line()
		var err: String = online.get_last_error()
		if err != "":
			msg += "\nLast error: %s" % err
		_online_status_label.text = msg
		return
	_online_status_label.text = "Online transport selected."


func _ensure_online_browser_transport() -> void:
	if _online_browser_transport != null:
		return
	_online_browser_transport = SilentWolfOnlineCoopTransport.new()
	if not _online_browser_transport.room_directory_updated.is_connected(_on_online_room_directory_updated):
		_online_browser_transport.room_directory_updated.connect(_on_online_room_directory_updated)


func _refresh_online_room_listing() -> void:
	_ensure_online_browser_transport()
	if _online_room_list == null:
		return
	var ok: bool = _online_browser_transport.refresh_room_directory_listing()
	if not ok:
		_rebuild_online_room_list(_online_browser_transport.get_room_directory_listing())
		_refresh_online_status_line()


func _rebuild_online_room_list(entries: Array[Dictionary]) -> void:
	if _online_room_list == null:
		return
	_online_room_list.clear()
	if entries.is_empty():
		_online_room_list.add_item("No open online rooms found. Host one or refresh again.")
		_online_room_list.set_item_disabled(0, true)
		return
	for room in entries:
		var joinable: bool = bool(room.get("joinable", false))
		if not joinable:
			continue
		var code: String = str(room.get("code", "")).strip_edges().to_upper()
		if code == "":
			continue
		var host_name: String = str(room.get("host_display_name", "")).strip_edges()
		if host_name == "":
			host_name = "Host"
		var status: String = "OPEN"
		var label: String = "[%s] %s  -  %s" % [status, code, host_name]
		var idx: int = _online_room_list.get_item_count()
		_online_room_list.add_item(label)
		_online_room_list.set_item_metadata(idx, room.duplicate(true))
	if _online_room_list.get_item_count() == 0:
		_online_room_list.add_item("No open online rooms found. Host one or refresh again.")
		_online_room_list.set_item_disabled(0, true)


func _on_online_room_directory_updated() -> void:
	if _online_browser_transport == null:
		return
	_rebuild_online_room_list(_online_browser_transport.get_room_directory_listing())
	_refresh_online_status_line()


func _on_online_refresh_pressed() -> void:
	_refresh_online_room_listing()


func _on_online_room_selected(index: int) -> void:
	if _online_room_list == null or _online_room_code_field == null:
		return
	if index < 0 or index >= _online_room_list.get_item_count():
		return
	if _online_room_list.is_item_disabled(index):
		return
	var meta: Variant = _online_room_list.get_item_metadata(index)
	if not (meta is Dictionary):
		return
	var room: Dictionary = meta as Dictionary
	var code: String = str(room.get("code", "")).strip_edges().to_upper()
	if code == "":
		return
	_online_room_code_field.text = code
	_last_launch_error = ""
	_refresh_ui()


func _on_online_room_activated(index: int) -> void:
	_on_online_room_selected(index)
	if _online_room_code_field != null and str(_online_room_code_field.text).strip_edges() != "":
		_on_online_join_pressed()


func _refresh_lan_status_line() -> void:
	if _lan_status_label == null:
		return
	var mgr = CoopExpeditionSessionManager
	var bits: PackedStringArray = PackedStringArray()
	if mgr.uses_loopback_coop_transport():
		bits.append("Mode: same-PC rehearsal")
	elif mgr.uses_enet_coop_transport():
		bits.append("Mode: LAN")
		var transport_instance: CoopSessionTransport = mgr.get_transport()
		if transport_instance is ENetCoopTransport:
			var en: ENetCoopTransport = transport_instance as ENetCoopTransport
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


func _apply_session_after_transport_change() -> void:
	CoopExpeditionSessionManager.set_selected_expedition_map(_map_id)
	CoopExpeditionSessionManager.refresh_local_player_payload_from_campaign()
	_last_launch_error = ""
	_refresh_ui()


func _on_lan_host_pressed() -> void:
	var p: int = int(str(_lan_port_field.text).strip_edges())
	if p <= 0:
		p = ENetCoopTransport.DEFAULT_PORT
	CoopExpeditionSessionManager.leave_session()
	var enet_transport := ENetCoopTransport.new()
	enet_transport.configure_listen_port(p)
	CoopExpeditionSessionManager.set_transport(enet_transport)
	var r: Dictionary = CoopExpeditionSessionManager.begin_host_session()
	if not bool(r.get("ok", false)):
		_last_launch_error = "LAN host: " + str(r.get("error", str(r)))
		_refresh_ui()
		return
	_apply_session_after_transport_change()


func _on_lan_join_pressed() -> void:
	var jp: String = str(_lan_address_field.text).strip_edges()
	if jp == "":
		_last_launch_error = "Enter the host address (host:port)."
		_refresh_ui()
		return
	CoopExpeditionSessionManager.leave_session()
	var enet_transport := ENetCoopTransport.new()
	if jp.contains(":"):
		var parts: PackedStringArray = jp.split(":")
		if parts.size() >= 2:
			var pt: int = int(str(parts[parts.size() - 1]).strip_edges())
			if pt > 0:
				enet_transport.configure_listen_port(pt)
	CoopExpeditionSessionManager.set_transport(enet_transport)
	var r: Dictionary = CoopExpeditionSessionManager.join_session(jp)
	if not bool(r.get("ok", false)):
		_last_launch_error = "LAN join: " + str(r.get("error", str(r)))
		_refresh_ui()
		return
	_apply_session_after_transport_change()


func _on_lan_loopback_pressed() -> void:
	CoopExpeditionSessionManager.leave_session()
	var lb := LocalLoopbackCoopTransport.new()
	CoopExpeditionSessionManager.set_transport(lb)
	var r: Dictionary = CoopExpeditionSessionManager.begin_host_session()
	if not bool(r.get("ok", false)):
		_last_launch_error = "Offline rehearsal: " + str(r.get("error", str(r)))
		_refresh_ui()
		return
	_apply_session_after_transport_change()


func _on_online_host_pressed() -> void:
	CoopExpeditionSessionManager.leave_session()
	var online_transport := SilentWolfOnlineCoopTransport.new()
	CoopExpeditionSessionManager.set_transport(online_transport)
	var r: Dictionary = CoopExpeditionSessionManager.begin_host_session()
	if not bool(r.get("ok", false)):
		_last_launch_error = "Online host: " + str(r.get("error", str(r)))
		_refresh_ui()
		return
	_apply_session_after_transport_change()


func _on_online_join_pressed() -> void:
	var code: String = str(_online_room_code_field.text).strip_edges()
	if code == "":
		_last_launch_error = "Enter an online room code."
		_refresh_ui()
		return
	CoopExpeditionSessionManager.leave_session()
	var online_transport := SilentWolfOnlineCoopTransport.new()
	CoopExpeditionSessionManager.set_transport(online_transport)
	var r: Dictionary = CoopExpeditionSessionManager.join_session(code)
	if not bool(r.get("ok", false)):
		_last_launch_error = "Online join: " + str(r.get("error", str(r)))
		_refresh_ui()
		return
	_apply_session_after_transport_change()


func _on_back_pressed() -> void:
	_last_launch_error = ""
	if CoopExpeditionSessionManager.uses_runtime_network_coop_transport() and CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.GUEST:
		CoopExpeditionSessionManager.clear_runtime_finalize_pending()
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
