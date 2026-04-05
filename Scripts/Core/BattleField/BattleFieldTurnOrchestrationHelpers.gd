extends RefCounted

const ActiveCombatAbilityHelpers = preload("res://Scripts/Core/BattleField/ActiveCombatAbilityHelpers.gd")


static func process(field, delta: float) -> void:
	field.update_cursor_pos()
	field.update_cursor_color()
	field._refresh_overhead_unit_bars()
	field.update_unit_info_panel()
	field._refresh_hover_status_popup()
	field._refresh_unit_hotkey_hud()
	if field.current_state == field.pre_battle_state:
		field._update_mock_coop_start_battle_button_state()
	sanitize_player_phase_active_unit_for_mock_coop_ownership(field)
	if field.is_mock_coop_unit_ownership_active() and field.current_state == field.player_state:
		field.update_objective_ui(true)
	process_mock_partner_placeholder_frame(field)
	field._update_skip_button_visual_modulate()
	field._handle_camera_panning(delta)

	# === ADD THIS LINE ===
	field._process_fog(delta)
	# =====================

	if field._danger_zone_recalc_dirty:
		field._danger_zone_recalc_dirty = false
		if field.show_danger_zone:
			field.calculate_full_danger_zone()

	if field.current_state:
		field.current_state.update(delta)

	field.draw_preview_path()
	field.queue_redraw()


static func change_state(field, new_state) -> void:
	var previous_state = field.current_state
	if field.current_state:
		field.current_state.exit()

	field.current_state = null
	if previous_state == field.pre_battle_state and new_state != field.pre_battle_state:
		field._reset_mock_coop_prebattle_ready_state()
	if new_state == field.player_state:
		reset_mock_coop_player_phase_ready_state(field)

	if new_state == field.player_state:
		await field.show_phase_banner("PLAYER PHASE", Color(0.4, 0.6, 0.9))
		await process_spawners(field, 2) # <--- ADDED AWAIT

	elif new_state == field.ally_state:
		await field.show_phase_banner("ALLY PHASE", Color(0.4, 0.8, 0.5))
		await process_spawners(field, 1) # <--- ADDED AWAIT

		# --- ESCORT CONVOY LOGIC ---
		if field.map_objective == field.Objective.DEFEND_TARGET and is_instance_valid(field.vip_target):
			if field.vip_target.has_method("process_escort_turn"):
				var target_cam_pos = field.vip_target.global_position + Vector2(32, 32)
				if field.main_camera.anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT:
					var half_vp_world = (field.get_viewport_rect().size * 0.5) / field.main_camera.zoom
					target_cam_pos -= half_vp_world

				var c_tween = field.create_tween()
				c_tween.tween_property(field.main_camera, "global_position", target_cam_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				await c_tween.finished
				await field.get_tree().create_timer(0.3).timeout

				if field.coop_enet_is_host_authority_escort_turn_host():
					field.vip_target.process_escort_turn(field)
					await field.vip_target.turn_completed
					field.coop_enet_sync_after_host_authority_escort_turn(field.vip_target)
				elif field.coop_enet_should_wait_for_host_authority_escort_turn():
					await field.coop_enet_guest_wait_for_escort_turn_end()
				else:
					field.vip_target.process_escort_turn(field)
					await field.vip_target.turn_completed
				field._clamp_camera_position()
				await field.get_tree().create_timer(0.5).timeout
				if field._coop_pending_escort_destination_victory:
					field._coop_pending_escort_destination_victory = false
					await field._trigger_victory()
					return

	elif new_state == field.enemy_state:
		await field.show_phase_banner("ENEMY PHASE", Color(0.85, 0.3, 0.3))
		if field.coop_enet_is_host_authority_enemy_turn_host():
			await process_spawners(field, 0)
			field.coop_enet_sync_after_host_authority_enemy_phase_setup()
		elif not field.coop_enet_should_wait_for_host_authority_enemy_turn():
			await process_spawners(field, 0)

	field.update_objective_ui(true)
	field.queue_redraw()
	if new_state == field.player_state:
		field._maybe_log_enemy_reinforcement_warning_for_player_phase()

	field.current_state = new_state
	if field.current_state:
		field.current_state.enter(field)
	field._queue_tactical_ui_overhaul()


static func process_spawners(field, faction_id: int) -> void:
	if field.destructibles_container:
		for child in field.destructibles_container.get_children():
			if child.has_method("process_turn") and not child.is_queued_for_deletion():
				# <--- ADDED AWAIT SO IT WAITS FOR THE CINEMATIC TO FINISH!
				await child.process_turn(field, faction_id)


static func on_skip_button_pressed(field) -> void:
	if field.current_state == field.player_state:
		# --- QOL: AUTO-DEFEND UNUSED UNITS ---
		var auto_defended_anyone = false

		# Loop through all player units on the board
		if field.player_container != null:
			for u in field.player_container.get_children():
				# If they are alive and haven't finished their turn yet...
				if is_instance_valid(u) and not u.is_queued_for_deletion() and u.current_hp > 0:
					if field.is_local_player_command_blocked_for_mock_coop_unit(u):
						continue
					if u.get("is_exhausted") == false:
						if u.has_method("trigger_defend"):
							u.trigger_defend()
						else:
							u.set("is_defending", true)
							if u.has_method("finish_turn"):
								u.finish_turn()
						field.animate_shield_drop(u)
						field.coop_enet_sync_after_local_defend(u)
						auto_defended_anyone = true

		# Play the shield sound once if anyone braced for impact!
		if auto_defended_anyone and field.defend_sound != null and field.defend_sound.stream != null:
			field.defend_sound.play()
		# --------------------------------------

		if mock_coop_player_phase_ready_sync_active(field):
			mock_coop_set_local_player_phase_ready(field, true)
			if not field._mock_coop_remote_player_phase_ready:
				return

		# If we have green units, they go next. Otherwise, skip to enemies.
		if field.ally_container and field.ally_container.get_child_count() > 0:
			field.change_state(field.ally_state)
		else:
			field.change_state(field.enemy_state)


static func on_ally_turn_finished(field) -> void:
	# Reset player units for the new turn
	for u in field.player_container.get_children():
		if is_instance_valid(u):
			if u.has_method("reset_turn"):
				u.reset_turn()

			# --- TICK COOLDOWNS ---
			var cd = u.get_meta("ability_cooldown", 0)
			if cd > 0:
				u.set_meta("ability_cooldown", cd - 1)
	field.change_state(field.enemy_state)


static func on_enemy_turn_finished(field) -> void:
	await field._tick_burn_status_effects()
	await field._tick_bone_toxin_status_effects()

	# Tick the turn counter
	field.current_turn += 1
	field.tick_fire_tiles_for_new_turn()
	await field._tick_skeleton_bone_piles_async()

	field.update_objective_ui()

	# --- CHECK 'SURVIVE' / 'DEFEND' CONDITIONS ---
	if field.map_objective == field.Objective.SURVIVE_TURNS or field.map_objective == field.Objective.DEFEND_TARGET:
		if field.current_turn > field.turn_limit:
			field.add_combat_log("MISSION ACCOMPLISHED: Held the line.", "lime")
			field._trigger_victory() # <--- CHANGED!
			return # Stop processing, the game is over!

	# Reset player units for the new turn
	for u in field.player_container.get_children():
		if is_instance_valid(u):
			if u.has_method("reset_turn"):
				u.reset_turn()

			# --- TICK COOLDOWNS ---
			var cd = u.get_meta("ability_cooldown", 0)
			if cd > 0:
				u.set_meta("ability_cooldown", cd - 1)

	ActiveCombatAbilityHelpers.tick_all_units_phase(field)
	field.change_state(field.player_state)


## Drops selection if active_unit somehow points at a partner-owned unit (mock co-op only). Skips while forecasting to avoid tearing an in-flight forecast await.
static func sanitize_player_phase_active_unit_for_mock_coop_ownership(field) -> void:
	if field.current_state != field.player_state or field.player_state == null:
		return
	if field.player_state.is_forecasting:
		return
	var au: Node2D = field.player_state.active_unit
	if au == null or not is_instance_valid(au):
		return
	if not field.is_local_player_command_blocked_for_mock_coop_unit(au):
		return
	field.player_state.clear_active_unit()


static func mock_coop_player_phase_ready_sync_active(field) -> bool:
	return (
		field.is_mock_coop_unit_ownership_active()
		and CoopExpeditionSessionManager.uses_runtime_network_coop_transport()
		and CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.NONE
	)


static func reset_mock_coop_player_phase_ready_state(field) -> void:
	field._mock_coop_local_player_phase_ready = false
	field._mock_coop_remote_player_phase_ready = false
	field._mock_coop_player_phase_transition_pending = false


static func mock_coop_try_advance_player_phase_after_ready_sync(field) -> void:
	if field.current_state != field.player_state:
		return
	if not mock_coop_player_phase_ready_sync_active(field):
		return
	if not field._mock_coop_local_player_phase_ready or not field._mock_coop_remote_player_phase_ready:
		return
	if field._mock_coop_player_phase_transition_pending:
		return
	field._mock_coop_player_phase_transition_pending = true
	if field.ally_container and field.ally_container.get_child_count() > 0:
		field.change_state(field.ally_state)
	else:
		field.change_state(field.enemy_state)


static func mock_coop_set_local_player_phase_ready(field, send_sync: bool = true) -> void:
	if not mock_coop_player_phase_ready_sync_active(field):
		return
	if field._mock_coop_local_player_phase_ready:
		mock_coop_try_advance_player_phase_after_ready_sync(field)
		return
	field._mock_coop_local_player_phase_ready = true
	if send_sync:
		CoopExpeditionSessionManager.send_runtime_coop_action({"action": "player_phase_ready", "ready": true})
	if field.battle_log != null and field.battle_log.visible and not field._mock_coop_remote_player_phase_ready:
		field.add_combat_log("Co-op: your detachment is ready. Waiting for your partner to end phase.", "gold")
	field.update_objective_ui(true)
	mock_coop_try_advance_player_phase_after_ready_sync(field)


static func process_mock_partner_placeholder_frame(field) -> void:
	if not field.is_mock_partner_placeholder_active():
		field._mock_partner_placeholder_combat_log_done = false
		return
	if field.player_state != null and field.player_state.is_forecasting:
		field.player_state.is_forecasting = false
		field.player_state.targeted_enemy = null
		field._on_forecast_cancel()
	if field.player_state != null and field.player_state.active_unit != null:
		field.player_state.clear_active_unit()
	if field._mock_partner_placeholder_combat_log_done:
		return
	field._mock_partner_placeholder_combat_log_done = true
	if field.battle_log != null and field.battle_log.visible:
		if field._mock_coop_local_player_phase_ready and not field._mock_coop_remote_player_phase_ready:
			field.add_combat_log("Co-op: your detachment is ready. Waiting for your partner to end phase.", "gold")
		elif field._mock_coop_remote_player_phase_ready and not field._mock_coop_local_player_phase_ready:
			field.add_combat_log("Co-op: partner detachment is ready. End / Skip when you are ready.", "gold")
		else:
			field.add_combat_log("Mock co-op: all your units have acted. End / Skip phase when you are ready.", "gold")


## Player phase: true when at least one local-commandable player unit is fielded and alive, and every such unit has finished acting (is_exhausted).
static func local_player_fielded_commandable_units_all_exhausted(field) -> bool:
	if field.player_container == null:
		return false
	var any_eligible: bool = false
	for u in field.player_container.get_children():
		if not is_instance_valid(u) or u.is_queued_for_deletion():
			continue
		if u.get("current_hp") == null or int(u.current_hp) <= 0:
			continue
		if field.is_local_player_command_blocked_for_mock_coop_unit(u):
			continue
		any_eligible = true
		if u.get("is_exhausted") == false:
			return false
	return any_eligible


static func should_pulse_skip_button_end_turn_nudge(field) -> bool:
	if field.current_state != field.player_state:
		return false
	if mock_coop_player_phase_ready_sync_active(field) and field._mock_coop_local_player_phase_ready:
		return false
	return local_player_fielded_commandable_units_all_exhausted(field)
