extends RefCounted

const CombatVfxHelpersRef = preload("res://Scripts/Core/BattleField/BattleFieldCombatVfxHelpers.gd")

const DefensiveReactionFlowHelpers = preload("res://Scripts/Core/BattleField/BattleFieldDefensiveReactionFlowHelpers.gd")

const CoopRuntimeSyncHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopRuntimeSyncHelpers.gd")
const CombatPassiveAbilityHelpers = preload("res://Scripts/Core/BattleField/CombatPassiveAbilityHelpers.gd")
const UnitCombatStatusHelpers = preload("res://Scripts/Core/UnitCombatStatusHelpers.gd")

static func _resolve_weapon_impact_family(wpn) -> int:
	if wpn == null:
		return -1
	if WeaponData.is_staff_like(wpn):
		return CombatVfxHelpersRef.FAMILY_STAFF_UTILITY
	return WeaponData.get_weapon_family(int(wpn.weapon_type))


static func _spawn_melee_hit_impact_vfx(
	field,
	defender: Node2D,
	attacker: Node2D,
	is_crit: bool,
	weapon_impact_fam: int,
	phys_subtype: int,
	used_ranged_projectile: bool,
	wpn = null
) -> void:
	var dpos: Vector2 = defender.global_position
	var apos: Vector2 = attacker.global_position
	if (
		not used_ranged_projectile
		and wpn != null
		and wpn is WeaponData
		and WeaponData.is_dragon_weapon(wpn as WeaponData)
	):
		field.spawn_claw_strike_effect(dpos, apos, is_crit)
		return
	# Projectile already sells thrust/impact; a second pierce strip on contact feels like double motion.
	if used_ranged_projectile:
		if phys_subtype == int(WeaponData.PhysicalSubtype.PIERCING):
			return
		elif phys_subtype == int(WeaponData.PhysicalSubtype.BLUDGEONING):
			field.spawn_bludgeon_impact_effect(dpos, apos, is_crit, weapon_impact_fam)
		else:
			field.spawn_slash_effect(dpos, apos, is_crit, weapon_impact_fam)
		return
	if phys_subtype == int(WeaponData.PhysicalSubtype.PIERCING):
		field.spawn_piercing_strike_effect(dpos, apos, is_crit, weapon_impact_fam)
	elif phys_subtype == int(WeaponData.PhysicalSubtype.BLUDGEONING):
		field.spawn_bludgeon_impact_effect(dpos, apos, is_crit, weapon_impact_fam)
	else:
		field.spawn_slash_effect(dpos, apos, is_crit, weapon_impact_fam)


static func _play_weapon_hit_sound(field, wpn, phys_subtype: int) -> void:
	if wpn != null and wpn is WeaponData and WeaponData.is_dragon_weapon(wpn as WeaponData):
		var wd: WeaponData = wpn as WeaponData
		if wd.get("custom_hit_sound") != null:
			var custom_audio := AudioStreamPlayer.new()
			custom_audio.stream = wd.custom_hit_sound
			field.add_child(custom_audio)
			field.play_attack_hit_sound(custom_audio)
			custom_audio.finished.connect(custom_audio.queue_free)
			return
		var chs: AudioStreamPlayer = field.get("claw_hit_sound") as AudioStreamPlayer
		if chs != null and chs.stream != null:
			field.play_attack_hit_sound(chs)
			return
		if field.attack_sound != null and field.attack_sound.stream != null:
			field.play_attack_hit_sound(field.attack_sound)
			return
	if phys_subtype == int(WeaponData.PhysicalSubtype.PIERCING):
		var phs: AudioStreamPlayer = field.get("piercing_hit_sound") as AudioStreamPlayer
		if phs != null and phs.stream != null:
			field.play_attack_hit_sound(phs)
			return
	if phys_subtype == int(WeaponData.PhysicalSubtype.BLUDGEONING):
		var bhs: AudioStreamPlayer = field.get("bludgeon_hit_sound") as AudioStreamPlayer
		if bhs != null and bhs.stream != null:
			field.play_attack_hit_sound(bhs)
			return
	if wpn != null and wpn.get("custom_hit_sound") != null:
		var custom_audio := AudioStreamPlayer.new()
		custom_audio.stream = wpn.custom_hit_sound
		field.add_child(custom_audio)
		field.play_attack_hit_sound(custom_audio)
		custom_audio.finished.connect(custom_audio.queue_free)
	elif field.attack_sound != null and field.attack_sound.stream != null:
		field.play_attack_hit_sound(field.attack_sound)


# Phase E: normal attack resolution (post Phase D defensive abilities).
# Uses a context Dictionary to avoid an unmanageable parameter list.
static func resolve_phase_e_normal_attack(field, ctx: Dictionary) -> Dictionary:
	var attacker: Node2D = ctx["attacker"]
	var defender: Node2D = ctx["defender"]

	var incoming_damage_multiplier: float = ctx["incoming_damage_multiplier"]
	var damage: int = ctx["damage"]
	var defense_resolved_and_won: bool = ctx["defense_resolved_and_won"]
	var attack_hits: bool = ctx["attack_hits"]
	var is_crit: bool = ctx["is_crit"]
	var is_magic: bool = ctx["is_magic"]
	var already_staggered: bool = ctx["already_staggered"]
	var will_stagger: bool = ctx["will_stagger"]
	var did_melee_normal_animation: bool = ctx["did_melee_normal_animation"]
	var did_melee_crit_animation: bool = ctx["did_melee_crit_animation"]
	var used_ranged_projectile: bool = ctx.get("used_ranged_projectile", false)
	var def_current_poise: int = ctx["def_current_poise"]
	var poise_dmg: int = ctx["poise_dmg"]
	var def_max_poise: int = ctx["def_max_poise"]
	var combo_hits: int = ctx["combo_hits"]
	var hellfire_result: int = ctx["hellfire_result"]
	var lunge_dir: Vector2 = ctx["lunge_dir"]
	var atk_rel: Dictionary = ctx["atk_rel"]
	var ability_triggers_count: int = ctx["ability_triggers_count"]
	var loot_recipient = ctx.get("loot_recipient", null)

	var severing_strike_hits: int = ctx.get("severing_strike_hits", 0)
	var severing_strike_damage_multiplier: float = ctx.get("severing_strike_damage_multiplier", 1.0)
	var force_crit: bool = ctx.get("force_crit", false)
	var parting_shot_dodge: bool = ctx.get("parting_shot_dodge", false)
	var shadow_pin_speed_lock: bool = ctx.get("shadow_pin_speed_lock", false)
	var vanguards_rally_might_bonus: int = ctx.get("vanguards_rally_might_bonus", 0)
	var savage_toss_distance: int = ctx.get("savage_toss_distance", 0)
	var lifesteal_percent: float = ctx.get("lifesteal_percent", 0.0)

	var volley_extra_hits: int = ctx.get("volley_extra_hits", 0)
	var volley_spread_target = ctx.get("volley_spread_target", null)
	var volley_damage_multiplier: float = ctx.get("volley_damage_multiplier", 1.0)

	var rain_splash_targets: Array = ctx.get("rain_splash_targets", [])
	var rain_splash_damage: int = ctx.get("rain_splash_damage", 0)
	var rain_tail_unit = ctx.get("rain_tail_unit", null)
	var rain_rear_extra_damage: int = ctx.get("rain_rear_extra_damage", 0)

	var fireball_splash_targets: Array = ctx.get("fireball_splash_targets", [])
	var fireball_splash_damage: int = ctx.get("fireball_splash_damage", 0)
	var fireball_tail_unit = ctx.get("fireball_tail_unit", null)
	var fireball_tail_extra_damage: int = ctx.get("fireball_tail_extra_damage", 0)

	var meteor_storm_splash_targets: Array = ctx.get("meteor_storm_splash_targets", [])
	var meteor_storm_splash_damage: int = ctx.get("meteor_storm_splash_damage", 0)
	var meteor_tail_unit = ctx.get("meteor_tail_unit", null)
	var meteor_tail_extra_damage: int = ctx.get("meteor_tail_extra_damage", 0)

	var flurry_strike_hits: int = ctx.get("flurry_strike_hits", 0)
	var flurry_strike_damage_multiplier: float = ctx.get("flurry_strike_damage_multiplier", 1.0)

	var blade_tempest_splash_targets: Array = ctx.get("blade_tempest_splash_targets", [])
	var blade_tempest_splash_damage: int = ctx.get("blade_tempest_splash_damage", 0)

	var chi_burst_splash_targets: Array = ctx.get("chi_burst_splash_targets", [])
	var chi_burst_splash_damage: int = ctx.get("chi_burst_splash_damage", 0)

	var smite_splash_targets: Array = ctx.get("smite_splash_targets", [])
	var smite_splash_damage: int = ctx.get("smite_splash_damage", 0)

	var sacred_judgment_splash_targets: Array = ctx.get("sacred_judgment_splash_targets", [])
	var sacred_judgment_splash_damage: int = ctx.get("sacred_judgment_splash_damage", 0)

	var elemental_convergence_splash_targets: Array = ctx.get("elemental_convergence_splash_targets", [])
	var elemental_convergence_splash_damage: int = ctx.get("elemental_convergence_splash_damage", 0)

	var charge_collision_target = ctx.get("charge_collision_target", null)
	var charge_collision_damage: int = ctx.get("charge_collision_damage", 0)

	var ballista_shot_pierce_targets: Array = ctx.get("ballista_shot_pierce_targets", [])
	var ballista_shot_pierce_damage: int = ctx.get("ballista_shot_pierce_damage", 0)

	var earthshatter_splash_targets: Array = ctx.get("earthshatter_splash_targets", [])
	var earthshatter_splash_damage: int = ctx.get("earthshatter_splash_damage", 0)

	# Apply defensive damage reductions
	damage = int(round(float(damage) * incoming_damage_multiplier))

	# Presentation-only: weapon-family signature + damage-kind tinting
	var wpn_fx: Variant = ctx.get("wpn", null)
	var weapon_impact_fam: int = _resolve_weapon_impact_family(wpn_fx)
	var impact_damage_kind: int = 0
	if is_magic or (wpn_fx != null and int(wpn_fx.damage_type) == int(WeaponData.DamageType.MAGIC)):
		impact_damage_kind = 1
	# Hit VFX subtype (pierce/bludgeon/slash). Magic lances (e.g. Holy Lance) still use lance presentation.
	var phys_subtype: int = -1
	if wpn_fx != null and wpn_fx is WeaponData:
		var wd_fx: WeaponData = wpn_fx as WeaponData
		var fam_fx: int = WeaponData.get_weapon_family(int(wd_fx.weapon_type))
		if not is_magic or fam_fx == WeaponData.WeaponType.LANCE:
			phys_subtype = field.resolve_physical_subtype(wd_fx)

	if not defense_resolved_and_won:
		if attack_hits:
			field._rookie_register_apprentice_magic_hit(attacker, ctx.get("wpn", null), is_magic, true)
			var impact_focus: Vector2 = defender.global_position + Vector2(32, 32)

			var is_bludgeon: bool = phys_subtype == int(WeaponData.PhysicalSubtype.BLUDGEONING)
			if attack_hits and is_crit:
				await field._play_critical_impact(impact_focus, is_bludgeon)
			elif already_staggered or will_stagger:
				await field._play_guard_break_impact(impact_focus)
			elif used_ranged_projectile:
				if is_bludgeon:
					await field._play_heavy_bludgeon_hit_impact(impact_focus)
				else:
					await field._play_light_hit_impact(impact_focus)
			elif did_melee_normal_animation:
				if is_bludgeon:
					await field._play_heavy_bludgeon_hit_impact(impact_focus)
				else:
					await field._play_normal_hit_impact(impact_focus)

			var final_dmg: int = damage * 3 if is_crit else damage

			# 1) APPLY POISE REDUCTION ALWAYS (Even on 0 DMG!)
			if will_stagger:
				defender.set_meta("current_poise", 0)
				defender.set_meta("is_staggered_this_combat", true)
			elif not already_staggered:
				defender.set_meta("current_poise", clampi(def_current_poise - poise_dmg, 0, def_max_poise))

			if defender.has_method("update_poise_visuals"):
				defender.update_poise_visuals()

			# 2) NO DAMAGE CHECK
			if final_dmg <= 0:
				if field.no_damage_sound and field.no_damage_sound.stream:
					field.no_damage_sound.play()
				field.spawn_loot_text("NO DAMAGE", Color.LIGHT_GRAY, defender.global_position + Vector2(32, -16))
				field.add_combat_log(attacker.unit_name + " attacked " + defender.unit_name + " but dealt no damage!", "gray")
				field.screen_shake(3.0, 0.15)

				if combo_hits == 0:
					CombatPassiveAbilityHelpers.apply_status_on_weapon_hit_passives(field, attacker, defender, wpn_fx, is_magic)

				if will_stagger:
					field.spawn_loot_text("GUARD BREAK!", Color(1.0, 0.62, 0.18), defender.global_position + Vector2(28, -46), {
						"stack_anchor": defender,
						"font_size": 24,
						"text_scale": 2.48,
						"rise_px": 36.0,
						"scatter_amount": 12.0,
					})
					field.screen_shake(12.0, 0.2)
					if defender.has_method("set_staggered_visuals"):
						defender.set_staggered_visuals(true)
			else:
				var is_lethal: bool = final_dmg >= defender.current_hp
				var death_defied: bool = false

				# CLERIC: MIRACLE
				if is_lethal and defender.get("ability") == "Miracle" and (defender.get_parent() == field.player_container or defender.get_parent() == field.ally_container):
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_miracle_minigame(field, defender)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						death_defied = true
						ability_triggers_count += 1

						if result == 2:
							defender.current_hp = max(1, int(round(defender.max_hp * 0.25)))
							field.spawn_loot_text("PERFECT MIRACLE!", Color(1.0, 0.85, 0.2), defender.global_position + Vector2(32, -16))
							field.add_combat_log(defender.unit_name + " invoked a PERFECT MIRACLE and cheated death!", "gold")
						else:
							defender.current_hp = 1
							field.spawn_loot_text("MIRACLE!", Color(1.0, 1.0, 0.6), defender.global_position + Vector2(32, -16))
							field.add_combat_log(defender.unit_name + " survived the fatal blow with Miracle!", "khaki")

						if defender.get("health_bar") != null:
							defender.health_bar.value = defender.current_hp

				# THE LAST STAND
				var ls := await DefensiveReactionFlowHelpers.resolve_last_stand_if_lethal(
					field,
					defender,
					is_lethal,
					death_defied,
					final_dmg,
					is_crit,
					ability_triggers_count
				)
				death_defied = ls.get("death_defied", death_defied)
				final_dmg = ls.get("final_dmg", final_dmg)
				is_crit = ls.get("is_crit", is_crit)
				ability_triggers_count = ls.get("ability_triggers_count", ability_triggers_count)

				var actually_dies: bool = is_lethal and not death_defied

				# 3) GUARD BREAK VISUALS (Only if they survive!)
				if will_stagger and not actually_dies:
					field.spawn_loot_text("GUARD BREAK!", Color(1.0, 0.62, 0.18), defender.global_position + Vector2(28, -46), {
						"stack_anchor": defender,
						"font_size": 24,
						"text_scale": 2.48,
						"rise_px": 36.0,
						"scatter_amount": 12.0,
					})
					field.screen_shake(12.0, 0.2)
					if defender.has_method("set_staggered_visuals"):
						defender.set_staggered_visuals(true)

				if not death_defied:
					# HUNDRED POINT STRIKE FLURRY
					if combo_hits > 0:
						for hit_idx in range(combo_hits):
							if not is_instance_valid(defender) or defender.current_hp <= 0:
								break
							var current_hit_dmg: int = int(max(1.0, float(damage) * 0.5))
							if hit_idx >= 5:
								current_hit_dmg = int(float(current_hit_dmg) * pow(0.75, hit_idx - 4))
							current_hit_dmg = int(max(1, current_hit_dmg))

							_play_weapon_hit_sound(field, wpn_fx, phys_subtype)
							if is_bludgeon:
								field.screen_shake(8.0, 0.11)
							else:
								field.screen_shake(4.0, 0.05)
							attacker.position += lunge_dir * 4.0
							var snap = field.create_tween()
							snap.tween_property(attacker, "position", attacker.position - (lunge_dir * 4.0), 0.05)

							field.spawn_loot_text(str(current_hit_dmg), Color(0.9, 0.25, 0.98), defender.global_position + Vector2(32, -10) + Vector2(randf_range(-9.0, 9.0), randf_range(-7.0, 7.0)), {
								"stack_anchor": defender,
								"font_size": 18,
								"text_scale": 2.05,
								"scatter_amount": 11.0,
								"rise_px": 36.0,
							})

							_spawn_melee_hit_impact_vfx(field, defender, attacker, false, weapon_impact_fam, phys_subtype, used_ranged_projectile)
							field.spawn_blood_splatter(defender, attacker.global_position, false, impact_damage_kind)

							var exp_tgt = attacker if (defender.current_hp <= current_hit_dmg or hit_idx == combo_hits - 1) else null
							if phys_subtype >= 0:
								defender.set_meta("last_damage_subtype", phys_subtype)
							field._apply_hit_with_support_reactions(defender, current_hit_dmg, attacker, exp_tgt, false)

						if hellfire_result == 2 and is_instance_valid(defender) and defender.current_hp > 0:
							if defender.get("combat_statuses") != null:
								UnitCombatStatusHelpers.add_status(defender, UnitCombatStatusHelpers.ID_BURNING, {})
							field.add_combat_log(attacker.unit_name + " ignited " + defender.unit_name + "!", "orange")
							field.spawn_loot_text("IGNITED!", Color(1.0, 0.4, 0.1), defender.global_position + Vector2(32, -40))
							await field.get_tree().create_timer(0.1).timeout
					else:
						# STANDARD ATTACK
						if attack_hits and is_crit:
							if not did_melee_crit_animation:
								if field.crit_sound != null and field.crit_sound.stream != null:
									field.play_attack_hit_sound(field.crit_sound)
								field.play_crit_striker_voice_grunt(attacker)
							if is_bludgeon:
								field.screen_shake(19.0, 0.48)
							else:
								field.screen_shake(15.0, 0.4)
						else:
							var wpn = ctx.get("wpn", null)
							_play_weapon_hit_sound(field, wpn, phys_subtype)
							if is_bludgeon:
								field.screen_shake(11.5, 0.33)

						field.add_combat_log(attacker.unit_name + " hit " + defender.unit_name + " for " + str(final_dmg) + (" (CRIT)" if is_crit else ""), "gold" if is_crit else "white")
						if is_crit and atk_rel.get("crit_bonus", 0) > 0 and attacker.get("unit_name") != null:
							field.add_combat_log("Rivalry sharpens " + str(attacker.unit_name) + "'s strike!", "yellow")
						var chunk_r: float = -1.0
						if defender.max_hp > 0:
							chunk_r = clampf(float(final_dmg) / float(defender.max_hp), 0.0, 1.0)
						var floater_tier: int = FloatingCombatText.Tier.CRIT if is_crit else FloatingCombatText.Tier.NORMAL
						var dmg_label_pos: Vector2 = defender.global_position + (Vector2(32, -26) if is_crit else Vector2(32, -15))
						field.spawn_loot_text(str(final_dmg) + (" CRIT" if is_crit else ""), Color(1.0, 0.2, 0.2) if is_crit else Color.WHITE, dmg_label_pos, {
							"tier": floater_tier,
							"hp_chunk_ratio": chunk_r,
							"stack_anchor": defender,
							"font_size": 26 if is_crit else 22,
							"text_scale": 2.62 if is_crit else 2.38,
							"rise_px": 48.0 if is_crit else 42.0,
							"scatter_amount": 14.0 if is_crit else 16.0,
						})
						_spawn_melee_hit_impact_vfx(field, defender, attacker, is_crit, weapon_impact_fam, phys_subtype, used_ranged_projectile, wpn_fx)
						field.spawn_blood_splatter(defender, attacker.global_position, is_crit, impact_damage_kind)

						# Earn support points (copied as-is: uses field funcs/containers)
						if attacker.get_parent() == field.player_container or attacker.get_parent() == field.ally_container:
							var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
							var current_pos = field.get_grid_pos(attacker)
							for dir in directions:
								var n_pos = current_pos + dir
								var support_ally = field.get_unit_at(n_pos)
								if support_ally == null and field.ally_container != null:
									for a in field.ally_container.get_children():
										if field.get_grid_pos(a) == n_pos and not a.is_queued_for_deletion():
											support_ally = a
											break
								if support_ally != null and support_ally != attacker:
									field._add_support_points_and_check(attacker, support_ally, 1)

						if attacker.get_parent() == field.player_container:
							loot_recipient = attacker
						else:
							loot_recipient = null

						if phys_subtype >= 0:
							defender.set_meta("last_damage_subtype", phys_subtype)
						field._apply_hit_with_support_reactions(defender, final_dmg, attacker, attacker, false)

						if combo_hits == 0:
							CombatPassiveAbilityHelpers.apply_status_on_weapon_hit_passives(field, attacker, defender, wpn_fx, is_magic)
							CombatPassiveAbilityHelpers.try_ember_wake_passives(field, attacker, defender, wpn_fx, is_magic)

						if hellfire_result == 2 and is_instance_valid(defender) and defender.current_hp > 0:
							if defender.get("combat_statuses") != null:
								UnitCombatStatusHelpers.add_status(defender, UnitCombatStatusHelpers.ID_BURNING, {})
							field.add_combat_log(attacker.unit_name + " ignited " + defender.unit_name + "!", "orange")
							field.spawn_loot_text("IGNITED!", Color(1.0, 0.4, 0.1), defender.global_position + Vector2(32, -40))

						# Remaining post-hit chains are preserved as-is (many local vars are expected in ctx)
						if severing_strike_hits > 1 and is_instance_valid(defender) and defender.current_hp > 0:
							for hit_idx in range(severing_strike_hits - 1):
								await field.get_tree().create_timer(0.15).timeout
								if not is_instance_valid(defender) or defender.current_hp <= 0:
									break
								var slash_dmg: int = int(max(1.0, float(damage) * severing_strike_damage_multiplier))
								_play_weapon_hit_sound(field, wpn_fx, phys_subtype)
								if is_bludgeon:
									field.screen_shake(9.0, 0.19)
								field.spawn_loot_text(str(slash_dmg), Color(0.70, 0.90, 1.00), defender.global_position + Vector2(32, -12) + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0)), {
									"stack_anchor": defender,
									"font_size": 19,
									"text_scale": 2.12,
									"scatter_amount": 11.0,
									"rise_px": 38.0,
								})
								_spawn_melee_hit_impact_vfx(field, defender, attacker, force_crit, weapon_impact_fam, phys_subtype, used_ranged_projectile, wpn_fx)
								if phys_subtype >= 0:
									defender.set_meta("last_damage_subtype", phys_subtype)
								field._apply_hit_with_support_reactions(defender, slash_dmg, attacker, attacker, false)

						if parting_shot_dodge and is_instance_valid(attacker) and attacker.current_hp > 0:
							var b_pos: Vector2i = field.get_grid_pos(attacker)
							var back_dir: Vector2i = Vector2i(round(-lunge_dir.x), round(-lunge_dir.y))
							var safe_tile: Vector2i = b_pos + back_dir
							if safe_tile.x >= 0 and safe_tile.x < field.GRID_SIZE.x and safe_tile.y >= 0 and safe_tile.y < field.GRID_SIZE.y:
								if not field.astar.is_point_solid(safe_tile) and field.get_occupant_at(safe_tile) == null:
									var backflip: Tween = field.create_tween()
									backflip.tween_property(attacker, "global_position", Vector2(safe_tile.x * field.CELL_SIZE.x, safe_tile.y * field.CELL_SIZE.y), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
									field.astar.set_point_solid(b_pos, false)
									field.astar.set_point_solid(safe_tile, true)
									field.spawn_loot_text("RETREAT!", Color.CYAN, attacker.global_position + Vector2(32, -40))

						if shadow_pin_speed_lock and is_instance_valid(defender):
							defender.speed = 0
							field.spawn_loot_text("PINNED!", Color(0.6, 0.3, 0.9), defender.global_position + Vector2(32, -40))

						if vanguards_rally_might_bonus > 0:
							if field.player_container != null:
								for ally in field.player_container.get_children():
									if is_instance_valid(ally) and ally.current_hp > 0:
										ally.strength += vanguards_rally_might_bonus
										ally.magic += vanguards_rally_might_bonus
										field.spawn_loot_text("RALLIED!", Color(1.0, 0.9, 0.4), ally.global_position + Vector2(32, -24))

						if savage_toss_distance > 0 and is_instance_valid(defender) and defender.current_hp > 0:
							var t_pos: Vector2i = field.get_grid_pos(defender)
							for step in range(savage_toss_distance):
								var next_tile: Vector2i = t_pos + Vector2i(round(lunge_dir.x), round(lunge_dir.y))
								if next_tile.x >= 0 and next_tile.x < field.GRID_SIZE.x and next_tile.y >= 0 and next_tile.y < field.GRID_SIZE.y:
									if not field.astar.is_point_solid(next_tile) and field.get_occupant_at(next_tile) == null:
										t_pos = next_tile
									else:
										var crash_dmg: int = 15
										field._apply_hit_with_support_reactions(defender, crash_dmg, attacker, attacker, false)
										field.screen_shake(12.0, 0.2)
										field.spawn_loot_text("CRASH!", Color.RED, defender.global_position + Vector2(32, -40))
										break
								else:
									break
							if t_pos != field.get_grid_pos(defender):
								var toss_tween: Tween = field.create_tween()
								toss_tween.tween_property(defender, "global_position", Vector2(t_pos.x * field.CELL_SIZE.x, t_pos.y * field.CELL_SIZE.y), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
								field.astar.set_point_solid(field.get_grid_pos(defender), false)
								field.astar.set_point_solid(t_pos, true)
								await toss_tween.finished

						if lifesteal_percent > 0.0 and is_instance_valid(attacker) and attacker.current_hp > 0:
							var heal: int = int(final_dmg * lifesteal_percent)
							if heal > 0:
								attacker.current_hp = min(attacker.current_hp + heal, attacker.max_hp)
								if attacker.get("health_bar") != null: attacker.health_bar.value = attacker.current_hp
								await field.get_tree().create_timer(0.2).timeout
								if is_instance_valid(attacker):
									field.spawn_loot_text("+" + str(heal) + " HP", Color(0.2, 1.0, 0.2), attacker.global_position + Vector2(-32, -16))

						# Follow-up hit/splash chains (still in Phase E)
						if volley_extra_hits > 0 and is_instance_valid(defender) and defender.current_hp > 0:
							for volley_idx in range(volley_extra_hits):
								await field.get_tree().create_timer(0.10).timeout
								var vol_tgt: Node2D = defender
								if volley_idx == 1 and volley_spread_target != null and is_instance_valid(volley_spread_target) and not volley_spread_target.is_queued_for_deletion() and volley_spread_target.current_hp > 0 and volley_spread_target.get_parent() == field.enemy_container:
									vol_tgt = volley_spread_target
								elif not is_instance_valid(defender) or defender.current_hp <= 0:
									break

								var volley_dmg: int = int(round(max(1.0, float(damage)) * volley_damage_multiplier))
								if field.attack_sound and field.attack_sound.stream != null:
									field.play_attack_hit_sound(field.attack_sound)
								field.spawn_loot_text(str(volley_dmg), Color(0.70, 0.90, 1.00), vol_tgt.global_position + Vector2(32, -16) + Vector2(randf_range(-18, 18), randf_range(-12, 12)))
								field.add_combat_log(attacker.unit_name + "'s Volley arrow hits " + str(vol_tgt.unit_name) + " for " + str(volley_dmg) + ".", "cyan")
								field._apply_hit_with_support_reactions(vol_tgt, volley_dmg, attacker, attacker, false)

						if rain_splash_targets.size() > 0:
							await field.get_tree().create_timer(0.12).timeout
							for splash_target in rain_splash_targets:
								if splash_target == null or not is_instance_valid(splash_target) or splash_target.is_queued_for_deletion():
									continue
								if splash_target.current_hp <= 0:
									continue
								if field.attack_sound and field.attack_sound.stream != null:
									field.play_attack_hit_sound(field.attack_sound)
								var rain_d: int = rain_splash_damage
								if rain_tail_unit != null and splash_target == rain_tail_unit and rain_rear_extra_damage > 0:
									rain_d += rain_rear_extra_damage
								field.spawn_loot_text(str(rain_d) + " SPLASH", Color(1.0, 0.86, 0.45), splash_target.global_position + Vector2(32, -16))
								field.add_combat_log(splash_target.unit_name + " is struck by falling arrows for " + str(rain_d) + ".", "khaki")
								splash_target.take_damage(rain_d, attacker)

						if fireball_splash_targets.size() > 0:
							await field.get_tree().create_timer(0.12).timeout
							for splash_target in fireball_splash_targets:
								if splash_target == null or not is_instance_valid(splash_target) or splash_target.is_queued_for_deletion():
									continue
								if splash_target.current_hp <= 0:
									continue
								if field.attack_sound and field.attack_sound.stream != null:
									field.play_attack_hit_sound(field.attack_sound)
								var fb_splash: int = fireball_splash_damage
								if fireball_tail_unit != null and splash_target == fireball_tail_unit:
									fb_splash += fireball_tail_extra_damage
								field.spawn_loot_text(str(fb_splash) + " BURN", Color(1.0, 0.65, 0.25), splash_target.global_position + Vector2(32, -16))
								field.add_combat_log(splash_target.unit_name + " is caught in the Fireball blast for " + str(fb_splash) + ".", "orange")
								splash_target.take_damage(fb_splash, attacker)

						if meteor_storm_splash_targets.size() > 0:
							await field.get_tree().create_timer(0.12).timeout
							for splash_target in meteor_storm_splash_targets:
								if splash_target == null or not is_instance_valid(splash_target) or splash_target.is_queued_for_deletion():
									continue
								if splash_target.current_hp <= 0:
									continue
								if field.attack_sound and field.attack_sound.stream != null:
									field.play_attack_hit_sound(field.attack_sound)
								var met_splash: int = meteor_storm_splash_damage
								if meteor_tail_unit != null and splash_target == meteor_tail_unit:
									met_splash += meteor_tail_extra_damage
								field.spawn_loot_text(str(met_splash) + " METEOR", Color(1.0, 0.45, 0.25), splash_target.global_position + Vector2(32, -16))
								field.add_combat_log(splash_target.unit_name + " is smashed by falling meteors for " + str(met_splash) + ".", "tomato")
								splash_target.take_damage(met_splash, attacker)

						if flurry_strike_hits > 0 and is_instance_valid(defender) and defender.current_hp > 0:
							for flurry_idx in range(flurry_strike_hits):
								await field.get_tree().create_timer(0.08).timeout
								if not is_instance_valid(defender) or defender.current_hp <= 0:
									break
								var flurry_dmg: int = int(round(max(1.0, float(damage)) * flurry_strike_damage_multiplier))
								if field.attack_sound and field.attack_sound.stream != null:
									field.play_attack_hit_sound(field.attack_sound)
								field.spawn_loot_text(str(flurry_dmg), Color(0.90, 0.95, 1.00), defender.global_position + Vector2(32, -16) + Vector2(randf_range(-18, 18), randf_range(-12, 12)))
								field.add_combat_log(attacker.unit_name + "'s Flurry Strike follow-up hits for " + str(flurry_dmg) + ".", "white")
								field._apply_hit_with_support_reactions(defender, flurry_dmg, attacker, attacker, false)

						if blade_tempest_splash_targets.size() > 0:
							await field.get_tree().create_timer(0.10).timeout
							for splash_target in blade_tempest_splash_targets:
								if splash_target == null or not is_instance_valid(splash_target) or splash_target.is_queued_for_deletion():
									continue
								if splash_target.current_hp <= 0:
									continue
								if field.attack_sound and field.attack_sound.stream != null:
									field.play_attack_hit_sound(field.attack_sound)
								field.spawn_loot_text(str(blade_tempest_splash_damage) + " TEMPEST", Color(0.75, 0.90, 1.00), splash_target.global_position + Vector2(32, -16))
								field.add_combat_log(splash_target.unit_name + " is slashed by Blade Tempest for " + str(blade_tempest_splash_damage) + ".", "cyan")
								splash_target.take_damage(blade_tempest_splash_damage, attacker)

						if chi_burst_splash_targets.size() > 0:
							await field.get_tree().create_timer(0.12).timeout
							for splash_target in chi_burst_splash_targets:
								if splash_target == null or not is_instance_valid(splash_target) or splash_target.is_queued_for_deletion():
									continue
								if splash_target.current_hp <= 0:
									continue
								if field.attack_sound and field.attack_sound.stream != null:
									field.play_attack_hit_sound(field.attack_sound)
								field.spawn_loot_text(str(chi_burst_splash_damage) + " CHI", Color(0.75, 0.55, 1.0), splash_target.global_position + Vector2(32, -16))
								field.add_combat_log(splash_target.unit_name + " is struck by the Chi Burst for " + str(chi_burst_splash_damage) + ".", "violet")
								splash_target.take_damage(chi_burst_splash_damage, attacker)

						if smite_splash_targets.size() > 0 and smite_splash_damage > 0:
							await field.get_tree().create_timer(0.10).timeout
							for sm_sp in smite_splash_targets:
								if sm_sp == null or not is_instance_valid(sm_sp) or sm_sp.is_queued_for_deletion():
									continue
								if sm_sp.current_hp <= 0:
									continue
								if field.attack_sound and field.attack_sound.stream != null:
									field.play_attack_hit_sound(field.attack_sound)
								field.spawn_loot_text(str(smite_splash_damage) + " HOLY", Color(1.0, 0.95, 0.55), sm_sp.global_position + Vector2(32, -16))
								field.add_combat_log(sm_sp.unit_name + " is scorched by Smite's holy spill for " + str(smite_splash_damage) + ".", "yellow")
								sm_sp.take_damage(smite_splash_damage, attacker)

						if sacred_judgment_splash_targets.size() > 0:
							await field.get_tree().create_timer(0.12).timeout
							for splash_target in sacred_judgment_splash_targets:
								if splash_target == null or not is_instance_valid(splash_target) or splash_target.is_queued_for_deletion():
									continue
								if splash_target.current_hp <= 0:
									continue
								if field.attack_sound and field.attack_sound.stream != null:
									field.play_attack_hit_sound(field.attack_sound)
								field.spawn_loot_text(str(sacred_judgment_splash_damage) + " HOLY", Color(1.0, 0.9, 0.4), splash_target.global_position + Vector2(32, -16))
								field.add_combat_log(splash_target.unit_name + " is scorched by Sacred Judgment for " + str(sacred_judgment_splash_damage) + ".", "yellow")
								splash_target.take_damage(sacred_judgment_splash_damage, attacker)

						if elemental_convergence_splash_targets.size() > 0:
							await field.get_tree().create_timer(0.12).timeout
							for splash_target in elemental_convergence_splash_targets:
								if splash_target == null or not is_instance_valid(splash_target) or splash_target.is_queued_for_deletion():
									continue
								if splash_target.current_hp <= 0:
									continue
								if field.attack_sound and field.attack_sound.stream != null:
									field.play_attack_hit_sound(field.attack_sound)
								field.spawn_loot_text(str(elemental_convergence_splash_damage) + " MAGIC", Color(0.4, 0.8, 1.0), splash_target.global_position + Vector2(32, -16))
								field.add_combat_log(splash_target.unit_name + " is hit by the Elemental Convergence blast for " + str(elemental_convergence_splash_damage) + ".", "cyan")
								splash_target.take_damage(elemental_convergence_splash_damage, attacker)

						if charge_collision_target != null and charge_collision_damage > 0:
							await field.get_tree().create_timer(0.08).timeout
							var cc: Node2D = charge_collision_target
							if is_instance_valid(cc) and not cc.is_queued_for_deletion() and cc.current_hp > 0 and cc.get_parent() == field.enemy_container:
								if field.attack_sound and field.attack_sound.stream != null:
									field.play_attack_hit_sound(field.attack_sound)
								field.spawn_loot_text(str(charge_collision_damage) + " PIN", Color(1.0, 0.55, 0.35), cc.global_position + Vector2(32, -16))
								field.add_combat_log(cc.unit_name + " is slammed by the pinned charge for " + str(charge_collision_damage) + ".", "coral")
								cc.take_damage(charge_collision_damage, attacker)

						if ballista_shot_pierce_targets.size() > 0 and ballista_shot_pierce_damage > 0:
							await field.get_tree().create_timer(0.10).timeout
							for pierce_target in ballista_shot_pierce_targets:
								if pierce_target == null or not is_instance_valid(pierce_target) or pierce_target.is_queued_for_deletion():
									continue
								if pierce_target.current_hp <= 0:
									continue
								if field.attack_sound and field.attack_sound.stream != null:
									field.play_attack_hit_sound(field.attack_sound)
								field.spawn_loot_text(str(ballista_shot_pierce_damage) + " PIERCE", Color(0.55, 0.85, 1.0), pierce_target.global_position + Vector2(32, -16))
								field.add_combat_log(pierce_target.unit_name + " is struck by the overpenetrating bolt for " + str(ballista_shot_pierce_damage) + ".", "lightskyblue")
								pierce_target.take_damage(ballista_shot_pierce_damage, attacker)

						if earthshatter_splash_targets.size() > 0:
							await field.get_tree().create_timer(0.12).timeout
							for splash_target in earthshatter_splash_targets:
								if splash_target == null or not is_instance_valid(splash_target) or splash_target.is_queued_for_deletion():
									continue
								if splash_target.current_hp <= 0:
									continue
								if field.attack_sound and field.attack_sound.stream != null:
									field.play_attack_hit_sound(field.attack_sound)
								field.spawn_loot_text(str(earthshatter_splash_damage) + " SHOCK", Color(1.0, 0.6, 0.2), splash_target.global_position + Vector2(32, -16))
								field.add_combat_log(splash_target.unit_name + " is caught in the Earthshatter shockwave for " + str(earthshatter_splash_damage) + ".", "orange")
								splash_target.take_damage(earthshatter_splash_damage, attacker)
		else:
			# MISS LOGIC
			var miss_focus_miss: Vector2 = defender.global_position + Vector2(32, 32)
			await field._play_miss_impact(miss_focus_miss)
			if field.miss_sound.stream != null: field.miss_sound.play()
			field.add_combat_log(attacker.unit_name + " missed " + defender.unit_name, "gray")
			field.spawn_loot_text("MISS", Color(0.62, 0.68, 0.74), defender.global_position + Vector2(32, -24), {
				"tier": FloatingCombatText.Tier.MISS,
				"stack_anchor": defender,
				"font_size": 23,
				"text_scale": 2.35,
				"scatter_amount": 10.0,
				"fade_time": 0.26,
			})

	ctx["incoming_damage_multiplier"] = incoming_damage_multiplier
	ctx["damage"] = damage
	ctx["ability_triggers_count"] = ability_triggers_count
	ctx["loot_recipient"] = loot_recipient
	return ctx
