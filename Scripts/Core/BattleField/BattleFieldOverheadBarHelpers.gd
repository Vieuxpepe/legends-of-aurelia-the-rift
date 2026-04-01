extends RefCounted

const NON_FOCUS_ALPHA: float = 0.32


static func refresh_overhead_unit_bars(field) -> void:
	if field == null:
		return

	var show_bars: bool = CampaignManager.interface_show_health_bars
	var use_focus_mode: bool = CampaignManager.interface_focus_unit_bars
	var focused_ids: Dictionary = {}

	if show_bars and use_focus_mode:
		_mark_focus_candidate(focused_ids, field._get_locked_inspect_unit())
		_mark_focus_candidate(focused_ids, field.get_occupant_at(field.cursor_grid_pos))
		if field.player_state != null:
			_mark_focus_candidate(focused_ids, field.player_state.active_unit)
		if field.enemy_state != null:
			_mark_focus_candidate(focused_ids, field.enemy_state.active_unit)
		if field.ally_state != null:
			_mark_focus_candidate(focused_ids, field.ally_state.active_unit)

	for container in [field.player_container, field.enemy_container, field.ally_container]:
		if container == null:
			continue
		for child in container.get_children():
			var unit: Node2D = child as Node2D
			if unit == null or not is_instance_valid(unit) or unit.is_queued_for_deletion():
				continue
			if not unit.has_method("set_overhead_bar_focus_state"):
				continue
			var is_focused: bool = (not use_focus_mode) or focused_ids.has(unit.get_instance_id())
			unit.call("set_overhead_bar_focus_state", show_bars, use_focus_mode, is_focused, NON_FOCUS_ALPHA)


static func _mark_focus_candidate(focused_ids: Dictionary, candidate: Variant) -> void:
	var unit: Node = candidate as Node
	if unit == null or not is_instance_valid(unit) or unit.is_queued_for_deletion():
		return
	focused_ids[unit.get_instance_id()] = true
