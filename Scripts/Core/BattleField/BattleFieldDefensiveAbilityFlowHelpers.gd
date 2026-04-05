extends RefCounted

# Extracts the full Phase D defensive-ability ladder (including co-op QTE mirror capture),
# preserving the original if/elif structure and side-effects.

const DefensiveReactionFlowHelpers = preload("res://Scripts/Core/BattleField/BattleFieldDefensiveReactionFlowHelpers.gd")

const CoopRuntimeSyncHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopRuntimeSyncHelpers.gd")

static func resolve_phase_d_defensive_abilities(
	field,
	attacker: Node2D,
	defender: Node2D,
	attack_hits: bool,
	wpn,
	incoming_damage_multiplier: float,
	defense_resolved_and_won: bool,
	ability_triggers_count: int,
	weapon_shatter_triggered: bool,
	celestial_choir_hits: int
) -> Dictionary:
	var def_trigger_chance: int = field.get_ability_trigger_chance(defender)
	var parry_chance: int = field.get_ability_trigger_chance(defender, true)

	if attack_hits and (defender.get_parent() == field.player_container or defender.get_parent() == field.ally_container):
		# --- PROMOTED GENERAL: WEAPON SHATTER ---
		if defender.get("ability") == "Weapon Shatter" and randi() % 100 < def_trigger_chance:
			var _cqe: String = field._coop_qte_alloc_event_id()
			var result: int
			if field._coop_qte_mirror_active:
				result = field._coop_qte_mirror_read_int(_cqe, 0)
			else:
				result = await QTEManager.run_weapon_shatter_minigame(field, defender)
				field._coop_qte_capture_write(_cqe, result)
			if result == 2:
				ability_triggers_count += 1
				weapon_shatter_triggered = true
				incoming_damage_multiplier = min(incoming_damage_multiplier, 0.5)

				field.spawn_loot_text("SHATTERED!", Color(1.0, 0.8, 0.2), attacker.global_position + Vector2(32, -32))
				field.add_combat_log("PERFECT WEAPON SHATTER! The General completely destroyed the enemy's weapon!", "gold")

				if attacker.equipped_weapon != null and attacker.equipped_weapon.get("current_durability") != null:
					attacker.equipped_weapon.current_durability = 0
			else:
				field.add_combat_log("Weapon Shatter failed to catch the blade.", "gray")

		# --- PROMOTED DIVINE SAGE: CELESTIAL CHOIR (Map-Wide Heal) ---
		elif defender.get("ability") == "Celestial Choir" and randi() % 100 < def_trigger_chance:
			var _cqe: String = field._coop_qte_alloc_event_id()
			if field._coop_qte_mirror_active:
				celestial_choir_hits = field._coop_qte_mirror_read_int(_cqe, 0)
			else:
				celestial_choir_hits = await QTEManager.run_celestial_choir_minigame(field, defender)
				field._coop_qte_capture_write(_cqe, celestial_choir_hits)
			if celestial_choir_hits > 0:
				ability_triggers_count += 1

				# Heal is based on hits AND the Sage's Magic!
				var aoe_heal_amount: int = celestial_choir_hits * (2 + int(float(defender.magic) * 0.2))

				var allies_healed: int = 0
				if field.player_container != null:
					for ally in field.player_container.get_children():
						if is_instance_valid(ally) and ally.current_hp > 0:
							ally.current_hp = min(ally.current_hp + aoe_heal_amount, ally.max_hp)
							if ally.get("health_bar") != null: ally.health_bar.value = ally.current_hp
							field.spawn_loot_text("+" + str(aoe_heal_amount), Color(0.4, 1.0, 0.4), ally.global_position + Vector2(32, -24))
							allies_healed += 1

				field.add_combat_log("CELESTIAL CHOIR! " + str(allies_healed) + " allies restored by heavenly music!", "lime")
			else:
				field.add_combat_log("Celestial Choir faltered. The notes were lost.", "gray")

		# --- PROMOTED GREAT KNIGHT: PHALANX (Map-Wide Defense) ---
		elif defender.get("ability") == "Phalanx" and randi() % 100 < def_trigger_chance:
			var _cqe: String = field._coop_qte_alloc_event_id()
			var result: int
			if field._coop_qte_mirror_active:
				result = field._coop_qte_mirror_read_int(_cqe, 0)
			else:
				result = await QTEManager.run_phalanx_minigame(field, defender)
				field._coop_qte_capture_write(_cqe, result)
			if result == 2:
				ability_triggers_count += 1
				defense_resolved_and_won = true
				incoming_damage_multiplier = min(incoming_damage_multiplier, 0.1) # Take almost 0 damage!

				var allies_buffed: int = 0
				if field.player_container != null:
					for ally in field.player_container.get_children():
						if is_instance_valid(ally) and ally.current_hp > 0:
							# Give them a temporary +10 Defense!
							ally.set_meta("inner_peace_def_bonus_temp", 10)
							field.spawn_loot_text("PHALANX!", Color(0.8, 0.9, 1.0), ally.global_position + Vector2(32, -24))
							allies_buffed += 1

				field.add_combat_log("PERFECT PHALANX! " + str(allies_buffed) + " allies raise their shields as one!", "gold")
			else:
				field.add_combat_log("Phalanx formation was broken before it could set.", "gray")

		# --- CLERIC: DIVINE PROTECTION ---
		if defender.get("ability") == "Divine Protection" and randi() % 100 < def_trigger_chance:
			var _cqe: String = field._coop_qte_alloc_event_id()
			var result: int
			if field._coop_qte_mirror_active:
				result = field._coop_qte_mirror_read_int(_cqe, 0)
			else:
				result = await QTEManager.run_divine_protection_minigame(field, defender)
				field._coop_qte_capture_write(_cqe, result)
			if result == 2:
				ability_triggers_count += 1
				defense_resolved_and_won = true

				var heal_amt: int = int(max(1, round(float(defender.max_hp) * 0.10)))
				defender.current_hp = min(defender.current_hp + heal_amt, defender.max_hp)
				if defender.get("health_bar") != null:
					defender.health_bar.value = defender.current_hp
				if is_instance_valid(defender) and defender.has_method("snap_health_delay_to_main"):
					defender.snap_health_delay_to_main()

				field.spawn_loot_text("BARRIER!", Color(1.0, 0.9, 0.4), defender.global_position + Vector2(32, -32))
				var barrier_hr: float = -1.0
				if defender.max_hp > 0:
					barrier_hr = clampf(float(heal_amt) / float(defender.max_hp), 0.0, 1.0)
				field.spawn_loot_text("+" + str(heal_amt) + " HP", Color(0.2, 1.0, 0.2), defender.global_position + Vector2(32, -56), {
					"tier": FloatingCombatText.Tier.HEAL,
					"hp_chunk_ratio": barrier_hr,
					"stack_anchor": defender,
				})
				field.add_combat_log("PERFECT DIVINE PROTECTION! The attack is completely warded off!", "gold")
			elif result == 1:
				ability_triggers_count += 1
				incoming_damage_multiplier = min(incoming_damage_multiplier, 0.35)
				field.spawn_loot_text("BARRIER!", Color(0.8, 0.9, 1.0), defender.global_position + Vector2(32, -32))
				field.add_combat_log("DIVINE PROTECTION! Most of the blow is absorbed.", "cyan")
			else:
				field.add_combat_log("Divine Protection failed to form in time.", "gray")

		# --- MAGE: ARCANE SHIFT ---
		elif defender.get("ability") == "Arcane Shift" and randi() % 100 < def_trigger_chance:
			var _cqe: String = field._coop_qte_alloc_event_id()
			var result: int
			if field._coop_qte_mirror_active:
				result = field._coop_qte_mirror_read_int(_cqe, 0)
			else:
				result = await QTEManager.run_arcane_shift_minigame(field, defender)
				field._coop_qte_capture_write(_cqe, result)
			if result > 0:
				ability_triggers_count += 1
				defense_resolved_and_won = true

				field.spawn_loot_text("SHIFT!", Color(0.7, 0.95, 1.0), defender.global_position + Vector2(32, -32))

				if result == 2:
					var counter_dmg: int = int(max(1, round(float(defender.magic) * 0.85)))
					if field.crit_sound and field.crit_sound.stream != null:
						field.play_attack_hit_sound(field.crit_sound)
					attacker.take_damage(counter_dmg, defender)
					field.spawn_loot_text(str(counter_dmg) + " ARCANE", Color(0.8, 0.6, 1.0), attacker.global_position + Vector2(32, -16))
					field.add_combat_log("PERFECT ARCANE SHIFT! The Mage vanishes and lashes back with arcane force!", "gold")
				else:
					field.add_combat_log("ARCANE SHIFT! The attack passes harmlessly through the Mage.", "cyan")
			else:
				field.add_combat_log("Arcane Shift failed. The dodge was mistimed.", "gray")

		# --- KNIGHT: SHIELD BASH ---
		elif defender.get("ability") == "Shield Bash" and randi() % 100 < def_trigger_chance:
			var _cqe: String = field._coop_qte_alloc_event_id()
			var result: int
			if field._coop_qte_mirror_active:
				result = field._coop_qte_mirror_read_int(_cqe, 0)
			else:
				result = await QTEManager.run_shield_bash_minigame(field, defender)
				field._coop_qte_capture_write(_cqe, result)
			if result > 0:
				ability_triggers_count += 1
				defense_resolved_and_won = true

				var def_wpn = defender.equipped_weapon
				var is_magic_counter: bool = false
				if def_wpn != null and def_wpn.get("damage_type") != null:
					is_magic_counter = (def_wpn.damage_type == WeaponData.DamageType.MAGIC)

				var counter_offense: int = int(defender.magic) if is_magic_counter else int(defender.strength)
				var counter_defense: int = int(attacker.resistance) if is_magic_counter else int(attacker.defense)
				var def_might: int = int(def_wpn.might) if def_wpn != null else 0

				var base_counter_dmg: int = int(max(1, (counter_offense + def_might) - counter_defense))
				var final_counter_dmg: int = base_counter_dmg if result == 1 else int(round(float(base_counter_dmg) * 1.75))

				if field.crit_sound and field.crit_sound.stream != null and result == 2:
					field.play_attack_hit_sound(field.crit_sound)
				elif field.attack_sound and field.attack_sound.stream != null:
					field.play_attack_hit_sound(field.attack_sound)

				attacker.take_damage(final_counter_dmg, defender)
				field.spawn_loot_text(str(final_counter_dmg) + " COUNTER", Color(0.8, 0.9, 1.0), attacker.global_position + Vector2(32, -16))

				if result == 2:
					field.add_combat_log("PERFECT SHIELD BASH! The enemy is smashed backward by the counter!", "gold")
				else:
					field.add_combat_log("SHIELD BASH! The attack is blocked and countered!", "cyan")
			else:
				field.add_combat_log("Shield Bash failed. Guard opened up.", "gray")

		# --- KNIGHT: UNBREAKABLE BASTION ---
		elif defender.get("ability") == "Unbreakable Bastion" and randi() % 100 < def_trigger_chance:
			var _cqe: String = field._coop_qte_alloc_event_id()
			var result: int
			if field._coop_qte_mirror_active:
				result = field._coop_qte_mirror_read_int(_cqe, 0)
			else:
				result = await QTEManager.run_unbreakable_bastion_minigame(field, defender)
				field._coop_qte_capture_write(_cqe, result)
			if result == 2:
				ability_triggers_count += 1
				defense_resolved_and_won = true
				field.spawn_loot_text("BASTION!", Color(1.0, 0.85, 0.2), defender.global_position + Vector2(32, -32))
				field.add_combat_log("PERFECT UNBREAKABLE BASTION! The blow does nothing!", "gold")
			elif result == 1:
				ability_triggers_count += 1
				incoming_damage_multiplier = min(incoming_damage_multiplier, 0.15)
				field.spawn_loot_text("BRACED!", Color(0.8, 0.9, 1.0), defender.global_position + Vector2(32, -32))
				field.add_combat_log("UNBREAKABLE BASTION! The shield absorbs nearly everything.", "cyan")
			else:
				field.add_combat_log("Unbreakable Bastion failed to set in time.", "gray")

		# --- MONK: INNER PEACE ---
		elif defender.get("ability") == "Inner Peace" and randi() % 100 < def_trigger_chance:
			var _cqe: String = field._coop_qte_alloc_event_id()
			var result: int
			if field._coop_qte_mirror_active:
				result = field._coop_qte_mirror_read_int(_cqe, 0)
			else:
				result = await QTEManager.run_inner_peace_minigame(field, defender)
				field._coop_qte_capture_write(_cqe, result)
			if result > 0:
				ability_triggers_count += 1
				defense_resolved_and_won = true

				var avo_bonus: int = 0
				var res_bonus: int = 0
				var def_bonus: int = 0
				var calm_heal: int = 0

				if result == 2:
					avo_bonus = 35
					res_bonus = 7
					def_bonus = 4
					calm_heal = int(max(2, int(round(float(defender.magic) * 0.35))))
					field.add_combat_log("PERFECT INNER PEACE! The Monk slips beyond harm itself.", "gold")
				else:
					avo_bonus = 20
					res_bonus = 4
					def_bonus = 2
					calm_heal = int(max(1, int(round(float(defender.magic) * 0.20))))
					field.add_combat_log("INNER PEACE! The Monk calmly avoids the blow.", "cyan")

				defender.set_meta("inner_peace_avo_bonus_temp", avo_bonus)
				defender.set_meta("inner_peace_res_bonus_temp", res_bonus)
				defender.set_meta("inner_peace_def_bonus_temp", def_bonus)

				if calm_heal > 0:
					defender.current_hp = min(defender.current_hp + calm_heal, defender.max_hp)
					if defender.get("health_bar") != null:
						defender.health_bar.value = defender.current_hp
					field.spawn_loot_text("+" + str(calm_heal), Color(0.65, 1.0, 0.85), defender.global_position + Vector2(32, -30))
			else:
				field.add_combat_log("Inner Peace broke. The Monk lost their meditative rhythm.", "gray")

		# --- PALADIN: HOLY WARD ---
		elif defender.get("ability") == "Holy Ward" and randi() % 100 < def_trigger_chance:
			var _cqe: String = field._coop_qte_alloc_event_id()
			var result: int
			if field._coop_qte_mirror_active:
				result = field._coop_qte_mirror_read_int(_cqe, 0)
			else:
				result = await QTEManager.run_holy_ward_minigame(field, defender)
				field._coop_qte_capture_write(_cqe, result)
			if result > 0:
				ability_triggers_count += 1
				var is_magic_atk: bool = (wpn != null and wpn.get("damage_type") != null and wpn.damage_type == WeaponData.DamageType.MAGIC)

				if result == 2:
					defender.set_meta("holy_ward_res_bonus_temp", 25)
					if is_magic_atk: incoming_damage_multiplier = min(incoming_damage_multiplier, 0.1)
					field.spawn_loot_text("HOLY WARD!", Color(1.0, 0.85, 0.2), defender.global_position + Vector2(32, -32))
					field.add_combat_log("PERFECT HOLY WARD! Absolute divine shielding!", "gold")
				else:
					defender.set_meta("holy_ward_res_bonus_temp", 10)
					if is_magic_atk: incoming_damage_multiplier = min(incoming_damage_multiplier, 0.5)
					field.spawn_loot_text("WARDED!", Color(0.8, 0.9, 1.0), defender.global_position + Vector2(32, -32))
					field.add_combat_log("HOLY WARD! Magical defenses raised.", "cyan")
			else:
				field.add_combat_log("Holy Ward failed to materialize.", "gray")

		# --- SPELLBLADE: BLINK STEP ---
		elif defender.get("ability") == "Blink Step" and randi() % 100 < def_trigger_chance:
			var _cqe: String = field._coop_qte_alloc_event_id()
			var result: int
			if field._coop_qte_mirror_active:
				result = field._coop_qte_mirror_read_int(_cqe, 0)
			else:
				result = await QTEManager.run_blink_step_minigame(field, defender)
				field._coop_qte_capture_write(_cqe, result)
			if result > 0:
				ability_triggers_count += 1

				if result == 2:
					defense_resolved_and_won = true # Dodge completely!
					field.spawn_loot_text("BLINK!", Color(0.9, 0.5, 1.0), defender.global_position + Vector2(32, -32))
					field.add_combat_log("PERFECT BLINK STEP! A flawless evasion!", "gold")
				else:
					incoming_damage_multiplier = min(incoming_damage_multiplier, 0.5) # Half damage
					field.spawn_loot_text("GLANCING!", Color(0.7, 0.5, 0.9), defender.global_position + Vector2(32, -32))
					field.add_combat_log("BLINK STEP! Only partially evaded the attack.", "violet")
			else:
				field.add_combat_log("Blink Step was too slow. Struck fully.", "gray")

		# --- OLD SHIELD CLASH + UNIVERSAL PARRY ---
		elif defender.get("ability") == "Shield Clash" or parry_chance > 0:
			var defreact := await DefensiveReactionFlowHelpers.resolve_parry_and_shield_clash(
				field,
				attacker,
				defender,
				def_trigger_chance,
				parry_chance,
				defense_resolved_and_won,
				ability_triggers_count
			)
			defense_resolved_and_won = defreact.get("defense_resolved_and_won", defense_resolved_and_won)
			ability_triggers_count = defreact.get("ability_triggers_count", ability_triggers_count)

	return {
		"incoming_damage_multiplier": incoming_damage_multiplier,
		"defense_resolved_and_won": defense_resolved_and_won,
		"ability_triggers_count": ability_triggers_count,
		"weapon_shatter_triggered": weapon_shatter_triggered,
		"celestial_choir_hits": celestial_choir_hits,
		"def_trigger_chance": def_trigger_chance,
		"parry_chance": parry_chance,
	}
