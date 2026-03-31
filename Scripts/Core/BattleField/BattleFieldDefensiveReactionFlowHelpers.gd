extends RefCounted

const CoopRuntimeSyncHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopRuntimeSyncHelpers.gd")

# Owns the "defensive reaction" orchestration glue (QTE mirror + outcome application),
# not just the minigame implementations.

static func resolve_parry_and_shield_clash(
	field,
	attacker: Node2D,
	defender: Node2D,
	def_trigger_chance: int,
	parry_chance: int,
	defense_resolved_and_won: bool,
	ability_triggers_count: int
) -> Dictionary:
	# --- OLD SHIELD CLASH ---
	if defender.get("ability") == "Shield Clash" and randi() % 100 < def_trigger_chance:
		var _cqe: String = field._coop_qte_alloc_event_id()
		var clash_result: int
		if field._coop_qte_mirror_active:
			clash_result = field._coop_qte_mirror_read_int(_cqe, 0)
		else:
			clash_result = await field._run_shield_clash_minigame(defender, attacker)
			field._coop_qte_capture_write(_cqe, clash_result)

		if clash_result > 0:
			ability_triggers_count += 1
			defense_resolved_and_won = true

			var heal_amt = int(defender.max_hp * 0.25)
			defender.current_hp = min(defender.current_hp + heal_amt, defender.max_hp)
			if defender.get("health_bar") != null: defender.health_bar.value = defender.current_hp
			var clash_hr: float = -1.0
			if defender.max_hp > 0:
				clash_hr = clampf(float(heal_amt) / float(defender.max_hp), 0.0, 1.0)
			field.spawn_loot_text("+" + str(heal_amt) + " HP", Color(0.2, 1.0, 0.2), defender.global_position + Vector2(32, -32), {
				"tier": FloatingCombatText.Tier.HEAL,
				"hp_chunk_ratio": clash_hr,
				"stack_anchor": defender,
			})

			if clash_result == 2:
				field.add_combat_log("PERFECT CLASH! Devastating Counter!", "gold")
				var def_wpn = defender.equipped_weapon
				var base_counter_dmg = max(1, (defender.strength + (def_wpn.might if def_wpn else 0)) - attacker.defense)
				var final_counter_dmg = base_counter_dmg * 3

				field.screen_shake(15.0, 0.4)
				if field.crit_sound.stream != null: field.crit_sound.play()
				attacker.take_damage(final_counter_dmg, defender)
				var sc_chunk: float = -1.0
				if attacker.max_hp > 0:
					sc_chunk = clampf(float(final_counter_dmg) / float(attacker.max_hp), 0.0, 1.0)
				field.spawn_loot_text(str(final_counter_dmg) + " CRIT!", Color(1.0, 0.2, 0.2), attacker.global_position + Vector2(32, -16), {
					"tier": FloatingCombatText.Tier.CRIT,
					"hp_chunk_ratio": sc_chunk,
					"stack_anchor": attacker,
				})
			else:
				field.add_combat_log("SHIELD CLASH WON! Attack deflected.", "lime")
		else:
			field.add_combat_log("Shield Clash Failed! Guard broken!", "red")

		return {
			"defense_resolved_and_won": defense_resolved_and_won,
			"ability_triggers_count": ability_triggers_count,
		}

	# --- UNIVERSAL PARRY ---
	if randi() % 100 < parry_chance:
		var _cqe: String = field._coop_qte_alloc_event_id()
		var won_parry: bool
		if field._coop_qte_mirror_active:
			won_parry = field._coop_qte_mirror_read_bool(_cqe, false)
		else:
			won_parry = await field._run_parry_minigame(defender)
			field._coop_qte_capture_write(_cqe, won_parry)
		if won_parry:
			ability_triggers_count += 1
			defense_resolved_and_won = true
			field.add_combat_log("PARRY SUCCESSFUL!", "lime")

			var def_wpn = defender.equipped_weapon
			var is_magic_counter = def_wpn != null and def_wpn.damage_type == WeaponData.DamageType.MAGIC
			var counter_offense = defender.magic if is_magic_counter else defender.strength
			var counter_defense = attacker.resistance if is_magic_counter else attacker.defense
			var base_counter_dmg = max(1, (counter_offense + (def_wpn.might if def_wpn else 0)) - counter_defense)

			if field.crit_sound.stream != null: field.crit_sound.play()
			attacker.take_damage(base_counter_dmg, defender)
			field.spawn_loot_text(str(base_counter_dmg) + " DMG", Color(1.0, 1.0, 1.0), attacker.global_position + Vector2(32, -16))
		else:
			field.add_combat_log("Parry Failed! Timing missed!", "red")

	return {
		"defense_resolved_and_won": defense_resolved_and_won,
		"ability_triggers_count": ability_triggers_count,
	}


static func resolve_last_stand_if_lethal(
	field,
	defender: Node2D,
	is_lethal: bool,
	death_defied: bool,
	final_dmg: int,
	is_crit: bool,
	ability_triggers_count: int
) -> Dictionary:
	# --- THE LAST STAND (Lethal Blow Protection) ---
	if not death_defied and is_lethal and defender.get("is_custom_avatar") == true:
		var _cqe_ls: String = field._coop_qte_alloc_event_id()
		if field._coop_qte_mirror_active:
			death_defied = field._coop_qte_mirror_read_bool(_cqe_ls, false)
		else:
			death_defied = await field._run_last_stand_minigame(defender)
			field._coop_qte_capture_write(_cqe_ls, death_defied)
		if death_defied:
			final_dmg = 0
			is_crit = false
			ability_triggers_count += 2
			field.add_combat_log(defender.unit_name + " defied death!", "gold")
			field.spawn_loot_text("DEATH DEFIED!", Color(1.0, 0.8, 0.2), defender.global_position + Vector2(32, -16))

	return {
		"death_defied": death_defied,
		"final_dmg": final_dmg,
		"is_crit": is_crit,
		"ability_triggers_count": ability_triggers_count,
	}
