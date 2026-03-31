extends RefCounted

# Mock co-op: handoff / ownership queries, stable command ids, remote-AI camera tweens, prebattle ready + start button — extracted from `BattleField.gd`.


static func get_consumed_mock_coop_battle_handoff_snapshot(field) -> Dictionary:
	return field._consumed_mock_coop_battle_handoff.duplicate(true)


static func get_mock_coop_battle_context_snapshot(field) -> Dictionary:
	if field._mock_coop_battle_context == null:
		return {"active": false, "context_valid": false}
	return field._mock_coop_battle_context.get_snapshot()


static func get_mock_coop_unit_ownership_snapshot(field) -> Dictionary:
	if field._mock_coop_ownership_assignments.is_empty():
		return {"active": false}
	return {
		"active": true,
		"rule": "first_half_local_ceil",
		"assignments": field._mock_coop_ownership_assignments.duplicate(true),
	}


## Returns MOCK_COOP_OWNER_LOCAL / MOCK_COOP_OWNER_REMOTE, or "" if unset / not mock co-op.
static func get_mock_coop_unit_owner_for_unit(field, unit: Node) -> String:
	if unit == null or not is_instance_valid(unit) or not unit.has_meta(field.MOCK_COOP_BATTLE_OWNER_META):
		return ""
	return str(unit.get_meta(field.MOCK_COOP_BATTLE_OWNER_META))


static func is_mock_coop_unit_ownership_active(field) -> bool:
	return not field._mock_coop_ownership_assignments.is_empty()


## True when mock co-op ownership is on and this unit is assigned to the remote partner (not locally commandable).
static func is_local_player_command_blocked_for_mock_coop_unit(field, unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit) or field._mock_coop_ownership_assignments.is_empty():
		return false
	return get_mock_coop_unit_owner_for_unit(field, unit) == field.MOCK_COOP_OWNER_REMOTE


static func notify_mock_coop_remote_command_blocked(field, unit: Node2D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	field.play_ui_sfx(field.UISfx.INVALID)
	var uname: String = str(unit.get("unit_name")) if unit.get("unit_name") != null else str(unit.name)
	if field.battle_log != null and field.battle_log.visible:
		field.add_combat_log("Co-op: %s answers to your partner — you cannot command this unit here." % uname, "orange")
	if unit is CanvasItem and (unit as CanvasItem).visible:
		field.spawn_loot_text("Partner's unit", Color(1.0, 0.55, 0.2), unit.global_position + Vector2(32, -32))


static func try_allow_local_player_select_unit_for_command(field, unit: Node2D) -> bool:
	if is_local_player_command_blocked_for_mock_coop_unit(field, unit):
		notify_mock_coop_remote_command_blocked(field, unit)
		return false
	return true


static func _infer_mock_coop_command_prefix_for_node(field, unit: Node2D) -> String:
	if unit == null or not is_instance_valid(unit):
		return ""
	var parent: Node = unit.get_parent()
	if parent == field.player_container:
		return "player"
	if parent == field.ally_container:
		return "ally"
	if parent == field.enemy_container:
		return "enemy"
	if parent == field.destructibles_container:
		return "destructible"
	if parent == field.chests_container:
		return "chest"
	return ""


static func _ensure_mock_coop_command_id_for_node(field, unit: Node2D) -> String:
	if unit == null or not is_instance_valid(unit):
		return ""
	if unit.has_meta(field.MOCK_COOP_COMMAND_ID_META):
		var existing: String = str(unit.get_meta(field.MOCK_COOP_COMMAND_ID_META, "")).strip_edges()
		if existing != "":
			return existing
	var prefix: String = _infer_mock_coop_command_prefix_for_node(field, unit)
	if prefix == "":
		return field.get_relationship_id(unit).strip_edges()
	var parent: Node = unit.get_parent()
	var sibling_index: int = -1
	if parent != null:
		sibling_index = parent.get_children().find(unit)
	var base_name: String = ""
	if unit.get("unit_name") != null:
		base_name = str(unit.get("unit_name")).strip_edges()
	if base_name == "":
		base_name = str(unit.name).strip_edges()
	if base_name == "":
		base_name = prefix
	base_name = base_name.replace("::", "_")
	var stable_id: String = "%s::%03d::%s" % [prefix, maxi(sibling_index, 0), base_name]
	unit.set_meta(field.MOCK_COOP_COMMAND_ID_META, stable_id)
	return stable_id


static func _get_mock_coop_command_id(field, unit_or_name: Variant) -> String:
	if unit_or_name is Node2D:
		var unit: Node2D = unit_or_name as Node2D
		if unit.has_meta(field.MOCK_COOP_COMMAND_ID_META):
			var meta_id: String = str(unit.get_meta(field.MOCK_COOP_COMMAND_ID_META, "")).strip_edges()
			if meta_id != "":
				return meta_id
		return _ensure_mock_coop_command_id_for_node(field, unit)
	if unit_or_name is String:
		return str(unit_or_name).strip_edges()
	return ""


static func _seed_mock_coop_command_ids_for_live_battle_nodes(field) -> void:
	for cont in [field.player_container, field.ally_container, field.enemy_container, field.destructibles_container, field.chests_container]:
		if cont == null:
			continue
		for child in cont.get_children():
			if not child is Node2D:
				continue
			var node: Node2D = child as Node2D
			if not is_instance_valid(node) or node.is_queued_for_deletion():
				continue
			_ensure_mock_coop_command_id_for_node(field, node)


static func _coop_focus_camera_on_world_point(field, world_point: Vector2, duration: float) -> void:
	if field.main_camera == null or not field.camera_follows_enemies:
		return
	var cam: Camera2D = field.main_camera
	var vp: Vector2 = field.get_viewport_rect().size
	var target_cam_pos: Vector2 = world_point + Vector2(0, field.COOP_REMOTE_AI_CAMERA_OFFSET_Y)
	if cam.anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT:
		var half_vp_world: Vector2 = (vp * 0.5) / cam.zoom
		target_cam_pos -= half_vp_world
	var map_limit_x: float = float(field.GRID_SIZE.x * field.CELL_SIZE.x)
	var map_limit_y: float = float(field.GRID_SIZE.y * field.CELL_SIZE.y)
	target_cam_pos.x = clamp(
		target_cam_pos.x,
		field.COOP_REMOTE_AI_CAMERA_LEFT_MARGIN,
		map_limit_x + field.COOP_REMOTE_AI_CAMERA_RIGHT_MARGIN
	)
	target_cam_pos.y = clamp(
		target_cam_pos.y,
		field.COOP_REMOTE_AI_CAMERA_TOP_MARGIN,
		map_limit_y + field.COOP_REMOTE_AI_CAMERA_BOTTOM_MARGIN
	)
	var camera_tween: Tween = (field as Node2D).create_tween()
	camera_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	camera_tween.tween_property(cam, "global_position", target_cam_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await camera_tween.finished


static func _coop_focus_camera_on_unit(field, unit: Node2D, duration: float = 0.55) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	await _coop_focus_camera_on_world_point(field, unit.global_position + Vector2(32, 32), duration)


static func _coop_focus_camera_on_action(field, attacker: Node2D, target: Node2D, duration: float = 0.4) -> void:
	if attacker == null or target == null:
		return
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return
	var focus_point: Vector2 = ((attacker.global_position + Vector2(32, 32)) + (target.global_position + Vector2(32, 32))) * 0.5
	await _coop_focus_camera_on_world_point(field, focus_point, duration)


static func _mock_coop_battle_sync_active(field) -> bool:
	return (
			not field._mock_coop_ownership_assignments.is_empty()
			and CoopExpeditionSessionManager.uses_runtime_network_coop_transport()
			and CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.NONE
		)


static func _mock_coop_prebattle_ready_sync_active(field) -> bool:
	return _mock_coop_battle_sync_active(field)


static func _mock_coop_role_key_from_command_id(_field, command_id: String) -> String:
	var cid: String = str(command_id).strip_edges()
	if cid == "":
		return ""
	var parts: PackedStringArray = cid.split("::", false, 1)
	if parts.size() < 2:
		return ""
	return str(parts[0]).strip_edges().to_lower()


static func get_mock_coop_allowed_prebattle_slots_for_command_id(field, command_id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if field.pre_battle_state == null:
		return out
	var slots: Array[Vector2i] = field.pre_battle_state.valid_deployment_slots
	if slots.is_empty():
		return out
	if field._mock_coop_ownership_assignments.is_empty():
		return slots.duplicate()
	var role_key: String = _mock_coop_role_key_from_command_id(field, command_id)
	if role_key == "":
		return slots.duplicate()
	var party_slot_count: int = mini(field.MOCK_COOP_COMMANDER_DEPLOYMENT_SLOT_COUNT, slots.size())
	if party_slot_count <= 0:
		return out
	var start: int = 0
	if role_key == "guest":
		start = party_slot_count
	elif role_key != "host":
		return slots.duplicate()
	var end_exclusive: int = mini(start + party_slot_count, slots.size())
	for i in range(start, end_exclusive):
		out.append(slots[i])
	return out


static func get_mock_coop_allowed_prebattle_slots_for_unit(field, unit: Node2D) -> Array[Vector2i]:
	if unit == null or not is_instance_valid(unit):
		return []
	return get_mock_coop_allowed_prebattle_slots_for_command_id(field, _get_mock_coop_command_id(field, unit))


static func is_mock_coop_prebattle_slot_allowed_for_unit(field, unit: Node2D, slot: Vector2i) -> bool:
	var allowed: Array[Vector2i] = get_mock_coop_allowed_prebattle_slots_for_unit(field, unit)
	if allowed.is_empty():
		return false
	return slot in allowed


static func _reset_mock_coop_prebattle_ready_state(field) -> void:
	field._mock_coop_local_prebattle_ready = false
	field._mock_coop_remote_prebattle_ready = false
	field._mock_coop_prebattle_transition_pending = false
	_update_mock_coop_start_battle_button_state(field)


static func _update_mock_coop_start_battle_button_state(field) -> void:
	var btn: Button = field.get_node_or_null("UI/StartBattleButton") as Button
	if btn == null:
		return
	if field._mock_coop_start_battle_button_base_text == "":
		var live_text: String = str(btn.text).strip_edges()
		field._mock_coop_start_battle_button_base_text = live_text if live_text != "" else "Start Battle"
	var base_text: String = field._mock_coop_start_battle_button_base_text
	if field.current_state != field.pre_battle_state or not btn.visible:
		btn.text = base_text
		btn.disabled = false
		return
	if not _mock_coop_prebattle_ready_sync_active(field):
		btn.text = base_text
		btn.disabled = false
		return
	if field._mock_coop_local_prebattle_ready and field._mock_coop_remote_prebattle_ready:
		btn.text = "Starting..."
		btn.disabled = true
	elif field._mock_coop_local_prebattle_ready:
		btn.text = "Ready - Waiting"
		btn.disabled = true
	elif field._mock_coop_remote_prebattle_ready:
		btn.text = "Partner Ready - Start"
		btn.disabled = false
	else:
		btn.text = base_text
		btn.disabled = false


static func _mock_coop_try_advance_prebattle_after_ready_sync(field) -> void:
	if field.current_state != field.pre_battle_state:
		return
	if not _mock_coop_prebattle_ready_sync_active(field):
		return
	if not field._mock_coop_local_prebattle_ready or not field._mock_coop_remote_prebattle_ready:
		return
	if field._mock_coop_prebattle_transition_pending:
		return
	field._mock_coop_prebattle_transition_pending = true
	_update_mock_coop_start_battle_button_state(field)
	field._start_battle_from_deployment()


static func _mock_coop_set_local_prebattle_ready(field, send_sync: bool = true) -> void:
	if not _mock_coop_prebattle_ready_sync_active(field):
		return
	if field._mock_coop_local_prebattle_ready:
		_mock_coop_try_advance_prebattle_after_ready_sync(field)
		return
	field._mock_coop_local_prebattle_ready = true
	if send_sync:
		CoopExpeditionSessionManager.send_runtime_coop_action({"action": "prebattle_ready", "ready": true})
	if field.battle_log != null and field.battle_log.visible:
		if field._mock_coop_remote_prebattle_ready:
			field.add_combat_log("Co-op: your commander is ready. Starting the battle.", "gold")
		else:
			field.add_combat_log("Co-op: your commander is ready. Waiting for your partner to press Start.", "gold")
	_update_mock_coop_start_battle_button_state(field)
	_mock_coop_try_advance_prebattle_after_ready_sync(field)


static func _mock_coop_clear_local_prebattle_ready(field, send_sync: bool = true) -> void:
	if not _mock_coop_prebattle_ready_sync_active(field):
		return
	if not field._mock_coop_local_prebattle_ready:
		return
	field._mock_coop_local_prebattle_ready = false
	field._mock_coop_prebattle_transition_pending = false
	if send_sync:
		CoopExpeditionSessionManager.send_runtime_coop_action({"action": "prebattle_ready", "ready": false})
	if field.battle_log != null and field.battle_log.visible:
		field.add_combat_log("Co-op: deployment changed. Press Start again when you are ready.", "gold")
	_update_mock_coop_start_battle_button_state(field)
