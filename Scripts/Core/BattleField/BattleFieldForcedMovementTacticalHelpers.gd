extends RefCounted

const CoopRuntimeSyncHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopRuntimeSyncHelpers.gd")

static func process_phase_g_forced_movement_and_fire_trap(
	field,
	attacker: Node2D,
	defender: Node2D,
	force_active_ability: bool,
	attack_hits: bool,
	attack_sound
) -> void:
	if force_active_ability and attack_hits and is_instance_valid(defender) and defender.current_hp > 0:
		var abil: String = field._resolve_tactical_ability_name(attacker)

		if abil == "Fire Trap":
			var _cqe_ft: String = field._coop_qte_alloc_event_id()
			var is_perfect_ft: bool
			if field._coop_qte_mirror_active:
				is_perfect_ft = field._coop_qte_mirror_read_bool(_cqe_ft, false)
			else:
				is_perfect_ft = await field._run_tactical_action_minigame(attacker, abil)
				field._coop_qte_capture_write(_cqe_ft, is_perfect_ft)
			var trap_cell: Vector2i = field.get_grid_pos(defender)
			var mag: int = int(attacker.get("magic")) if attacker.get("magic") != null else 0
			var ft_dmg: int = field.default_fire_tile_damage + mag / 3
			ft_dmg = maxi(1, ft_dmg)
			if is_perfect_ft:
				ft_dmg += 2
			var ft_dur: int = 5 if is_perfect_ft else 3
			field.spawn_fire_tile(trap_cell, ft_dmg, ft_dur)
			field.add_combat_log(attacker.unit_name + " sears the ground under " + defender.unit_name + "!", "orange")
			field.spawn_loot_text("FIRE TRAP!", Color(1.0, 0.35, 0.12), defender.global_position + Vector2(32, -32))
		elif abil == "Shove" or abil == "Grapple Hook":
			var _cqe_tac: String = field._coop_qte_alloc_event_id()
			var is_perfect: bool
			if field._coop_qte_mirror_active:
				is_perfect = field._coop_qte_mirror_read_bool(_cqe_tac, false)
			else:
				is_perfect = await field._run_tactical_action_minigame(attacker, abil)
				field._coop_qte_capture_write(_cqe_tac, is_perfect)
			var max_distance: int = 2 if is_perfect else 1

			var a_pos: Vector2i = field.get_grid_pos(attacker)
			var d_pos: Vector2i = field.get_grid_pos(defender)
			var push_dir: Vector2i = Vector2i.ZERO

			if d_pos.x > a_pos.x: push_dir = Vector2i(1, 0)
			elif d_pos.x < a_pos.x: push_dir = Vector2i(-1, 0)
			elif d_pos.y > a_pos.y: push_dir = Vector2i(0, 1)
			elif d_pos.y < a_pos.y: push_dir = Vector2i(0, -1)

			var target_tile: Vector2i = d_pos
			var tiles_moved: int = 0
			var crashed: bool = false

			if abil == "Shove":
				field.add_combat_log(attacker.unit_name + " shoved " + defender.unit_name + "!", "yellow")
				field.spawn_loot_text("SHOVE!", Color.ORANGE, defender.global_position + Vector2(32, -32))

				for step in range(max_distance):
					var next_tile: Vector2i = target_tile + push_dir
					if next_tile.x >= 0 and next_tile.x < field.GRID_SIZE.x and next_tile.y >= 0 and next_tile.y < field.GRID_SIZE.y:
						if not field.astar.is_point_solid(next_tile) and field.get_occupant_at(next_tile) == null:
							target_tile = next_tile
							tiles_moved += 1
						else:
							crashed = true
							break
					else:
						crashed = true
						break

			elif abil == "Grapple Hook":
				field.add_combat_log(attacker.unit_name + " hooked " + defender.unit_name + "!", "purple")
				field.spawn_loot_text("PULLED!", Color.VIOLET, defender.global_position + Vector2(32, -32))

				for step in range(max_distance):
					var next_tile: Vector2i = target_tile - push_dir
					if next_tile == a_pos:
						break
					if next_tile.x >= 0 and next_tile.x < field.GRID_SIZE.x and next_tile.y >= 0 and next_tile.y < field.GRID_SIZE.y:
						if not field.astar.is_point_solid(next_tile) and field.get_occupant_at(next_tile) == null:
							target_tile = next_tile
							tiles_moved += 1
						else:
							crashed = true
							break
					else:
						crashed = true
						break

			if tiles_moved > 0:
				var slide_tween: Tween = field.create_tween()
				slide_tween.tween_property(defender, "global_position", Vector2(target_tile.x * field.CELL_SIZE.x, target_tile.y * field.CELL_SIZE.y), 0.15 * tiles_moved).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				field.astar.set_point_solid(d_pos, false)
				field.astar.set_point_solid(target_tile, true)
				await slide_tween.finished

			if crashed:
				field.spawn_loot_text("CRASH!", Color.RED, defender.global_position + Vector2(32, -16))
				field.screen_shake(18.0 if is_perfect else 12.0, 0.25)
				if attack_sound.stream != null: attack_sound.play()
				var crash_dmg: int = 10 if is_perfect else 5
				field._apply_hit_with_support_reactions(defender, crash_dmg, attacker, attacker, false)
				field.add_combat_log(defender.unit_name + " crashed into an obstacle for " + str(crash_dmg) + " damage!", "tomato")

	await field.get_tree().create_timer(0.25).timeout

