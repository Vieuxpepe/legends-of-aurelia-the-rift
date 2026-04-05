extends RefCounted

# Combat-turn orchestration helpers extracted from `PlayerTurnState.gd`.
# Scope: after forecast confirm -> co-op delegation/QTE capture -> execute_combat -> canto/finish-turn.

const ActiveCombatAbilityHelpers = preload("res://Scripts/Core/BattleField/ActiveCombatAbilityHelpers.gd")
const ActiveCombatAbilityExecutionHelpers = preload("res://Scripts/Core/BattleField/ActiveCombatAbilityExecutionHelpers.gd")


static func resolve_player_active_ability_after_forecast(
	field,
	state,
	active_unit: Node2D,
	target_node: Node2D,
	ability_id: String
) -> bool:
	var aid: String = ability_id.strip_edges()
	if aid == "":
		return true

	var def: ActiveCombatAbilityData = ActiveCombatAbilityHelpers.get_definition(active_unit, aid)
	if def == null:
		return true

	var coop_aid: String = field.get_relationship_id(active_unit).strip_edges()
	var coop_did: String = field.get_relationship_id(target_node).strip_edges()

	var delegate_host: bool = false
	if field.has_method("coop_enet_should_delegate_player_combat_to_host"):
		delegate_host = field.coop_enet_should_delegate_player_combat_to_host()
	if delegate_host:
		if field.battle_log and field.battle_log.visible:
			field.add_combat_log("Data-driven actives are not replicated in guest combat-delegation mode yet — use a normal attack.", "gray")
		return true

	var primary: Node2D = target_node
	if int(def.effect_kind) == int(ActiveCombatAbilityData.EffectKind.SELF_CENTERED):
		primary = active_unit

	var coop_packed: int = -1
	var coop_pre_alive: Dictionary = {}
	if field.has_method("coop_enet_begin_synchronized_combat_round"):
		coop_packed = field.coop_enet_begin_synchronized_combat_round()
	if coop_packed >= 0 and field.has_method("coop_net_snapshot_alive_unit_ids"):
		coop_pre_alive = field.coop_net_snapshot_alive_unit_ids()
	if coop_packed >= 0 and field.has_method("coop_net_begin_local_combat_qte_capture"):
		field.coop_net_begin_local_combat_qte_capture()
	if coop_packed >= 0 and field.has_method("coop_net_begin_local_combat_loot_capture"):
		field.coop_net_begin_local_combat_loot_capture()

	var ok: bool = await ActiveCombatAbilityExecutionHelpers.execute_async(field, active_unit, primary, def)

	var coop_qte_snap: Dictionary = {}
	if field.has_method("coop_net_end_local_combat_qte_capture"):
		coop_qte_snap = field.coop_net_end_local_combat_qte_capture()

	if is_instance_valid(field) and field.is_inside_tree() and field.get_tree().paused:
		while is_instance_valid(field) and field.get_tree().paused:
			await field.get_tree().process_frame

	var coop_loot_events: Array = []
	if field.has_method("coop_net_end_local_combat_loot_capture"):
		coop_loot_events = field.coop_net_end_local_combat_loot_capture()

	var coop_auth_snap: Dictionary = {}
	if coop_packed >= 0 and field.has_method("coop_net_build_authoritative_combat_snapshot"):
		coop_auth_snap = field.coop_net_build_authoritative_combat_snapshot(coop_pre_alive)

	if not ok:
		if field.has_method("coop_enet_sync_local_combat_done"):
			field.coop_enet_sync_local_combat_done(
				coop_aid,
				coop_did,
				false,
				active_unit,
				false,
				0.0,
				coop_packed,
				coop_qte_snap,
				coop_auth_snap,
				false,
				coop_loot_events
			)
		return true

	if not is_instance_valid(active_unit) or int(active_unit.current_hp) <= 0:
		if field.has_method("coop_enet_sync_local_combat_done"):
			field.coop_enet_sync_local_combat_done(
				coop_aid,
				coop_did,
				false,
				null,
				false,
				0.0,
				coop_packed,
				coop_qte_snap,
				coop_auth_snap,
				false,
				coop_loot_events
			)
		state.clear_active_unit()
		return true

	var used: float = float(active_unit.move_points_used_this_turn)
	var rem: float = float(active_unit.move_range) - used
	if field.unit_supports_canto(active_unit) and rem > 0.001:
		active_unit.has_moved = true
		active_unit.in_canto_phase = true
		active_unit.canto_move_budget = rem
		if field.battle_log and field.battle_log.visible:
			field.add_combat_log(active_unit.unit_name + " — Canto (" + str(snappedf(rem, 0.1)) + " move left).", "cyan")
		field.rebuild_grid()
		field.calculate_ranges(active_unit)
		if field.has_method("coop_enet_sync_local_combat_done"):
			field.coop_enet_sync_local_combat_done(
				coop_aid,
				coop_did,
				false,
				active_unit,
				true,
				rem,
				coop_packed,
				coop_qte_snap,
				coop_auth_snap,
				false,
				coop_loot_events
			)
		return true

	if field.has_method("coop_enet_sync_local_combat_done"):
		field.coop_enet_sync_local_combat_done(
			coop_aid,
			coop_did,
			false,
			active_unit,
			false,
			0.0,
			coop_packed,
			coop_qte_snap,
			coop_auth_snap,
			false,
			coop_loot_events
		)

	active_unit.finish_turn()
	state.clear_active_unit()
	return true


static func resolve_confirmed_player_combat_after_forecast(
	field,
	state,
	active_unit: Node2D,
	target_node: Node2D,
	used_ability: bool
) -> bool:
	# NOTE: `state` is the PlayerTurnState instance; we only touch what the old code touched:
	# - `state.active_unit` for the co-op host delegation canto return path
	# - `state.clear_active_unit()` for the standard completion paths

	var coop_aid: String = field.get_relationship_id(active_unit).strip_edges()
	var coop_did: String = field.get_relationship_id(target_node).strip_edges()

	var delegate_host: bool = false
	if field.has_method("coop_enet_should_delegate_player_combat_to_host"):
		delegate_host = field.coop_enet_should_delegate_player_combat_to_host()

	# Guest: host-authoritative player combat
	if delegate_host and field.has_method("coop_enet_guest_delegate_player_combat_to_host"):
		await field.coop_enet_guest_delegate_player_combat_to_host(coop_aid, coop_did, used_ability)

		if is_instance_valid(field) and field.is_inside_tree() and field.get_tree().paused:
			while is_instance_valid(field) and field.is_inside_tree() and field.get_tree().paused:
				await field.get_tree().process_frame

		var au: Node2D = null
		if field.has_method("coop_enet_get_player_side_unit_by_rel_id"):
			au = field.coop_enet_get_player_side_unit_by_rel_id(coop_aid)

		if au == null or not is_instance_valid(au) or int(au.current_hp) <= 0:
			state.clear_active_unit()
			return true

		if au.in_canto_phase:
			state.active_unit = au
			au.set_selected_glow(true)
			au.set_selected(true)
			field.rebuild_grid()
			field.calculate_ranges(au)
			return true

		state.clear_active_unit()
		return true

	# Local combat sim (host or non-delegated)
	var coop_packed: int = -1
	var coop_pre_alive: Dictionary = {}

	if field.has_method("coop_enet_begin_synchronized_combat_round"):
		coop_packed = field.coop_enet_begin_synchronized_combat_round()
	if coop_packed >= 0 and field.has_method("coop_net_snapshot_alive_unit_ids"):
		coop_pre_alive = field.coop_net_snapshot_alive_unit_ids()
	if coop_packed >= 0 and field.has_method("coop_net_begin_local_combat_qte_capture"):
		field.coop_net_begin_local_combat_qte_capture()
	if coop_packed >= 0 and field.has_method("coop_net_begin_local_combat_loot_capture"):
		field.coop_net_begin_local_combat_loot_capture()

	await field.execute_combat(active_unit, target_node, used_ability)

	var coop_qte_snap: Dictionary = {}
	if field.has_method("coop_net_end_local_combat_qte_capture"):
		coop_qte_snap = field.coop_net_end_local_combat_qte_capture()

	if is_instance_valid(field) and field.is_inside_tree() and field.get_tree().paused:
		while is_instance_valid(field) and field.get_tree().paused:
			await field.get_tree().process_frame

	var coop_loot_events: Array = []
	if field.has_method("coop_net_end_local_combat_loot_capture"):
		coop_loot_events = field.coop_net_end_local_combat_loot_capture()

	var coop_auth_snap: Dictionary = {}
	if coop_packed >= 0 and field.has_method("coop_net_build_authoritative_combat_snapshot"):
		coop_auth_snap = field.coop_net_build_authoritative_combat_snapshot(coop_pre_alive)

	# Attacker died during combat: still notify peer, then clear selection
	if not is_instance_valid(active_unit) or int(active_unit.current_hp) <= 0:
		if field.has_method("coop_enet_sync_local_combat_done"):
			field.coop_enet_sync_local_combat_done(
				coop_aid,
				coop_did,
				used_ability,
				null,
				false,
				0.0,
				coop_packed,
				coop_qte_snap,
				coop_auth_snap,
				false,
				coop_loot_events
			)
		state.clear_active_unit()
		return true

	# Canto follow-up
	var used: float = float(active_unit.move_points_used_this_turn)
	var rem: float = float(active_unit.move_range) - used
	if field.unit_supports_canto(active_unit) and rem > 0.001:
		active_unit.has_moved = true
		active_unit.in_canto_phase = true
		active_unit.canto_move_budget = rem
		if field.battle_log and field.battle_log.visible:
			field.add_combat_log(active_unit.unit_name + " — Canto (" + str(snappedf(rem, 0.1)) + " move left).", "cyan")
		field.rebuild_grid()
		field.calculate_ranges(active_unit)
		if field.has_method("coop_enet_sync_local_combat_done"):
			field.coop_enet_sync_local_combat_done(
				coop_aid,
				coop_did,
				used_ability,
				active_unit,
				true,
				rem,
				coop_packed,
				coop_qte_snap,
				coop_auth_snap,
				false,
				coop_loot_events
			)
		return true

	# Normal completion (no canto)
	if field.has_method("coop_enet_sync_local_combat_done"):
		field.coop_enet_sync_local_combat_done(
			coop_aid,
			coop_did,
			used_ability,
			active_unit,
			false,
			0.0,
			coop_packed,
			coop_qte_snap,
			coop_auth_snap,
			false,
			coop_loot_events
		)

	active_unit.finish_turn()
	state.clear_active_unit()
	return true
