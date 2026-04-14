extends RefCounted

const CoopRuntimeSyncHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopRuntimeSyncHelpers.gd")

const DefensiveAbilityFlowHelpers = preload("res://Scripts/Core/BattleField/BattleFieldDefensiveAbilityFlowHelpers.gd")
const AttackResolutionHelpers = preload("res://Scripts/Core/BattleField/BattleFieldAttackResolutionHelpers.gd")
const PostStrikeCleanupHelpers = preload("res://Scripts/Core/BattleField/BattleFieldPostStrikeCleanupHelpers.gd")
const ForcedMovementTacticalHelpers = preload("res://Scripts/Core/BattleField/BattleFieldForcedMovementTacticalHelpers.gd")
const CombatCleanupHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCombatCleanupHelpers.gd")
const CombatPassiveAbilityHelpers = preload("res://Scripts/Core/BattleField/CombatPassiveAbilityHelpers.gd")
const UnitCombatStatusHelpers = preload("res://Scripts/Core/UnitCombatStatusHelpers.gd")
const WeaponRuneAppliedEffectsResolver = preload("res://Scripts/Core/WeaponRuneAppliedEffectsResolver.gd")

static func _compute_projectile_target_point(defender: Node2D, lunge_dir: Vector2, attack_hits: bool) -> Vector2:
	var defender_center: Vector2 = defender.global_position + Vector2(32, 32)
	if attack_hits:
		return defender_center
	var side_dir: Vector2 = Vector2(-lunge_dir.y, lunge_dir.x).normalized()
	var miss_side: float = -1.0 if lunge_dir.x >= 0.0 else 1.0
	return defender_center + (side_dir * (22.0 * miss_side)) + (lunge_dir * 10.0)


static func run_strike_sequence(
	field,
	attacker: Node2D,
	defender: Node2D,
	force_active_ability: bool = false,
	force_single_attack: bool = false
) -> void:
		if not field._is_valid_combat_unit(attacker):
			push_warning("_run_strike_sequence aborted: attacker is not a valid combat unit.")
			return
	
		if not field._is_valid_combat_unit(defender):
			push_warning("_run_strike_sequence aborted: defender is not a valid combat unit.")
			return
	
		if attacker.get("equipped_weapon") == null:
			push_warning("_run_strike_sequence aborted: attacker has no equipped weapon.")
			return
	
		field._support_guard_used_this_sequence = false
		var will_double: bool = (attacker.speed - defender.speed) >= 4 and not force_single_attack
		var total_attacks: int = 2 if will_double else 1
		
		var atk_adj: Dictionary = field.get_adjacency_bonus(attacker)
		var def_adj: Dictionary = field.get_adjacency_bonus(defender)
		var atk_sup: Dictionary = field.get_support_combat_bonus(attacker)
		var def_sup: Dictionary = field.get_support_combat_bonus(defender)
		var atk_rel: Dictionary = field.get_relationship_combat_modifiers(attacker)
		var def_rel: Dictionary = field.get_relationship_combat_modifiers(defender)
	
		var _atk_terrain: Dictionary = field.get_terrain_data(field.get_grid_pos(attacker))
		var def_terrain: Dictionary = field.get_terrain_data(field.get_grid_pos(defender))
		
		# ==========================================
		# --- ALL QTE TEMP VARIABLES (GLOBAL SCOPE) ---
		# ==========================================
		var charge_bonus_damage: int = 0
		var charge_collision_target: Node2D = null
		var charge_collision_damage: int = 0
		var incoming_damage_multiplier: float = 1.0
		
		# Archer
		var deadeye_bonus_damage: int = 0
		var volley_extra_hits: int = 0
		var volley_damage_multiplier: float = 0.0
		var volley_spread_target: Node2D = null
		var rain_primary_bonus_damage: int = 0
		var rain_splash_targets: Array[Node2D] = []
		var rain_splash_damage: int = 0
		var rain_tail_unit: Node2D = null
		var rain_rear_extra_damage: int = 0
		
		# Mage + Mercenary
		var fireball_bonus_damage: int = 0
		var fireball_splash_targets: Array[Node2D] = []
		var fireball_splash_damage: int = 0
		var fireball_tail_unit: Node2D = null
		var fireball_tail_extra_damage: int = 0
		var meteor_storm_bonus_damage: int = 0
		var meteor_storm_splash_targets: Array[Node2D] = []
		var meteor_storm_splash_damage: int = 0
		var meteor_tail_unit: Node2D = null
		var meteor_tail_extra_damage: int = 0
		var flurry_strike_hits: int = 0
		var flurry_strike_damage_multiplier: float = 0.45
		var battle_cry_bonus_damage: int = 0
		var battle_cry_bonus_hit: int = 0
		var blade_tempest_bonus_damage: int = 0
		var blade_tempest_splash_targets: Array[Node2D] = []
		var blade_tempest_splash_damage: int = 0
		
		# Monk + Monster
		var chakra_bonus_damage: int = 0
		var chakra_bonus_hit: int = 0
		var chi_burst_bonus_damage: int = 0
		var chi_burst_splash_targets: Array[Node2D] = []
		var chi_burst_splash_damage: int = 0
		var frenzy_bonus_damage: int = 0
		var frenzy_bonus_hit: int = 0
		var _frenzy_hit_count: int = 0
		var frenzy_def_penalty: int = 0
	
		# Paladin + Spellblade
		var smite_bonus_damage: int = 0
		var smite_splash_targets: Array[Node2D] = []
		var smite_splash_damage: int = 0
		var sacred_judgment_bonus_damage: int = 0
		var sacred_judgment_splash_targets: Array[Node2D] = []
		var sacred_judgment_splash_damage: int = 0
		var flame_blade_bonus_damage: int = 0
		var elemental_convergence_bonus_damage: int = 0
		var elemental_convergence_splash_targets: Array[Node2D] = []
		var elemental_convergence_splash_damage: int = 0
		
		# Thief + Warrior
		var shadow_strike_bonus_damage: int = 0
		var shadow_strike_armor_pierce: float = 0.0
		var assassinate_crit_bonus: int = 0
		var shadow_step_bonus_damage: int = 0
		var power_strike_bonus_damage: int = 0
		var earthshatter_bonus_damage: int = 0
		var earthshatter_splash_targets: Array[Node2D] = []
		var earthshatter_splash_damage: int = 0
		
		# Promoted Mastery Temp Vars
		var shadow_pin_bonus_damage: int = 0
		var shadow_pin_speed_lock: bool = false
		var _weapon_shatter_triggered: bool = false
		var savage_toss_distance: int = 0
		var savage_toss_bonus_damage: int = 0
		var vanguards_rally_bonus_damage: int = 0
		var vanguards_rally_might_bonus: int = 0
		
		# Batch 2 Promoted Mastery Temp Vars
		var severing_strike_hits: int = 0
		var severing_strike_damage_multiplier: float = 0.5
		var aether_bind_sparks: int = 0
		var parting_shot_result: int = 0
		var _parting_shot_bonus_damage: int = 0
		var parting_shot_dodge: bool = false
		var soul_harvest_result: int = 0
		
		# Final Batch Promoted Mastery Temp Vars
		var celestial_choir_hits: int = 0
		var hellfire_result: int = 0
		var hellfire_bonus_damage: int = 0
		var ballista_shot_bonus_damage: int = 0
		var ballista_shot_pierce_targets: Array[Node2D] = []
		var ballista_shot_pierce_damage: int = 0
		var aegis_strike_bonus_damage: int = 0
		
		for i in range(total_attacks):
			# --- BUG FIX: Ensure both units survived the previous hits! ---
			if not is_instance_valid(defender) or defender.current_hp <= 0: break
			if not is_instance_valid(attacker) or attacker.current_hp <= 0: break
			
			# Clear splash targets for the new attack phase!
			rain_splash_targets.clear()
			rain_tail_unit = null
			rain_rear_extra_damage = 0
			volley_spread_target = null
			smite_splash_targets.clear()
			smite_splash_damage = 0
			fireball_splash_targets.clear()
			fireball_tail_unit = null
			fireball_tail_extra_damage = 0
			meteor_storm_splash_targets.clear()
			meteor_tail_unit = null
			meteor_tail_extra_damage = 0
			blade_tempest_splash_targets.clear()
			chi_burst_splash_targets.clear()
			sacred_judgment_splash_targets.clear()
			elemental_convergence_splash_targets.clear()
			earthshatter_splash_targets.clear()
			ballista_shot_pierce_targets.clear()
			charge_collision_target = null
			charge_collision_damage = 0
			
			var wpn = attacker.equipped_weapon
			var is_heal: bool = wpn != null and wpn.get("is_healing_staff") == true
			var is_buff: bool = wpn != null and wpn.get("is_buff_staff") == true
			var is_debuff: bool = wpn != null and wpn.get("is_debuff_staff") == true

			# Face the combat pair (player attacks often skipped AI-only look_at; vertical adjacency needs non-X logic in look_at_pos).
			if is_instance_valid(defender) and attacker.has_method("look_at_pos"):
				attacker.look_at_pos(field.get_grid_pos(defender))
			if is_instance_valid(attacker) and defender.has_method("look_at_pos"):
				defender.look_at_pos(field.get_grid_pos(attacker))
			
			# ==========================================
			# PHASE A: STAFF LOGIC (Heal, Buff, Debuff)
			# ==========================================
			if is_heal or is_buff or is_debuff:
				var staff_orig_pos: Vector2 = attacker.global_position
				var staff_lunge_dir: Vector2 = (defender.global_position - attacker.global_position).normalized()
				var lunge_tween: Tween = field.create_tween()
				lunge_tween.tween_property(attacker, "global_position", staff_orig_pos + (staff_lunge_dir * 16.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				await lunge_tween.finished
				
				var popup_text: String = ""
				var text_color: Color = Color.WHITE
				
				if is_heal:
					# --- CLERIC: HEALING LIGHT ---
					var heal_amount: int = int(attacker.magic + wpn.might)
					
					var heal_trigger_chance: int = field.get_ability_trigger_chance(attacker)
					if field._attacker_has_attack_skill(attacker, "Healing Light") and randi() % 100 < heal_trigger_chance:
						var _cqe: String = CoopRuntimeSyncHelpers.coop_qte_alloc_event_id(field)
						var result: int
						if field._coop_qte_mirror_active:
							result = field._coop_qte_mirror_read_int(_cqe, 0)
						else:
							result = await QTEManager.run_healing_light_minigame(field, attacker)
							field._coop_qte_capture_write(_cqe, result)
						if result == 1:
							field.ability_triggers_count += 1
							heal_amount = int(round(float(heal_amount) * 1.5))
							field.add_combat_log("HEALING LIGHT! Restorative power surges.", "lime")
						elif result == 2:
							field.ability_triggers_count += 1
							heal_amount = int(round(float(heal_amount) * 2.0))
							field.add_combat_log("PERFECT HEALING LIGHT! Divine restoration unleashed!", "gold")
						else:
							field.add_combat_log("Healing Light failed to amplify the spell.", "gray")
	
					defender.current_hp = min(defender.current_hp + heal_amount, defender.max_hp)
					if defender.get("health_bar") != null:
						var bar_tween: Tween = field.create_tween()
						bar_tween.tween_property(defender.health_bar, "value", defender.current_hp, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
						bar_tween.finished.connect(func ():
							if is_instance_valid(defender) and defender.has_method("snap_health_delay_to_main"):
								defender.snap_health_delay_to_main()
						, CONNECT_ONE_SHOT)
					popup_text = "+" + str(heal_amount)
					text_color = Color(0.2, 1.0, 0.2)
					field.add_combat_log(attacker.unit_name + " healed " + defender.unit_name + ".", "lime")
					field._add_support_points_and_check(attacker, defender, 1)
					field._award_relationship_event(attacker, defender, "heal", 1)
					if field._can_gain_mentorship(attacker, defender):
						field._award_relationship_stat_event(attacker, defender, "mentorship", "heal_mentorship", 1)
					
				elif is_buff:
					var stat: String = wpn.affected_stat
					var amt: int = wpn.effect_amount
					defender.set(stat, defender.get(stat) + amt)
					popup_text = stat.to_upper() + " +" + str(amt)
					text_color = Color(0.2, 0.8, 1.0)
					field.add_combat_log(attacker.unit_name + " buffed " + defender.unit_name + "'s " + stat + ".", "cyan")
					field._award_relationship_event(attacker, defender, "buff", 1)
					if field._can_gain_mentorship(attacker, defender):
						field._award_relationship_stat_event(attacker, defender, "mentorship", "buff_mentorship", 1)
					
				elif is_debuff:
					var stat: String = wpn.affected_stat
					var amt: int = wpn.effect_amount
					defender.set(stat, max(0, defender.get(stat) - amt))
					popup_text = stat.to_upper() + " -" + str(amt)
					text_color = Color(0.8, 0.2, 1.0)
					field.add_combat_log(attacker.unit_name + " debuffed " + defender.unit_name + "'s " + stat + ".", "purple")
				
				if field.level_up_sound.stream != null: field.level_up_sound.play() 
				
				field.spawn_loot_text(popup_text, text_color, defender.global_position + Vector2(32, -16), {"stack_anchor": defender})
				
				var return_tween: Tween = field.create_tween()
				return_tween.tween_property(attacker, "global_position", staff_orig_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				await return_tween.finished
				
				await field.get_tree().create_timer(0.25).timeout
				break
			
			# ==========================================
			# PHASE B: COMBAT MATH & OFFENSIVE ABILITIES
			# ==========================================
			var advantage: int = field.get_triangle_advantage(attacker, defender)
			var tri_dmg: int = advantage * 1
			var tri_hit: int = advantage * 15
			
			var is_magic: bool = wpn.damage_type == WeaponData.DamageType.MAGIC if wpn else false
			var offense_stat: int = int(attacker.magic) if is_magic else int(attacker.strength)
			var defense_stat: int = int(defender.resistance) if is_magic else int(defender.defense)

			var atk_wpn_rune_might: int = 0
			var atk_wpn_rune_hit: int = 0
			if WeaponRuneAppliedEffectsResolver.is_apply_enabled() and wpn:
				var _atk_rune_strike: Dictionary = WeaponRuneAppliedEffectsResolver.resolve_from_weapon(wpn)
				var _atk_rune_fm_strike: Dictionary = _atk_rune_strike.get("flat_modifiers", {}) as Dictionary
				atk_wpn_rune_might = int(_atk_rune_fm_strike.get("might", 0))
				atk_wpn_rune_hit = int(_atk_rune_fm_strike.get("hit", 0))
	
			if defender.get("is_defending") == true:
				defense_stat += int(defender.defense_bonus)
			
			defense_stat += int(def_adj["def"]) + int(def_terrain["def"])
			
			# --- DEFENSIVE PENALTIES & BUFFS ---
			if is_magic:
				defense_stat += int(defender.get_meta("inner_peace_res_bonus_temp", 0))
				defense_stat += int(defender.get_meta("holy_ward_res_bonus_temp", 0))
				defense_stat -= int(defender.get_meta("frenzy_res_penalty_temp", 0))
			else:
				defense_stat += int(defender.get_meta("inner_peace_def_bonus_temp", 0))
				defense_stat -= int(defender.get_meta("frenzy_def_penalty_temp", 0))

			if WeaponRuneAppliedEffectsResolver.is_apply_enabled():
				var def_eq = defender.equipped_weapon
				if def_eq:
					var _def_rune_strike: Dictionary = WeaponRuneAppliedEffectsResolver.resolve_from_weapon(def_eq)
					var _def_rune_fm_strike: Dictionary = _def_rune_strike.get("flat_modifiers", {}) as Dictionary
					if is_magic:
						defense_stat += int(_def_rune_fm_strike.get("resistance", 0))
					else:
						defense_stat += int(_def_rune_fm_strike.get("defense", 0))
	
			defense_stat = int(max(0, defense_stat))
			
			var focused_failed: bool = false
			var lifesteal_percent: float = 0.0
			var force_crit: bool = false
			var force_hit: bool = false 
			var combo_hits: int = 0 
			
			# --- GET DYNAMIC TRIGGER CHANCE ---
			var atk_trigger_chance: int = field.get_ability_trigger_chance(attacker)
			
			
			if attacker.get_parent() == field.player_container and defender.get_parent() == field.enemy_container:
				# FOCUSED STRIKE
				if field._attacker_has_attack_skill(attacker, "Focused Strike") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var focus_result: int
					if field._coop_qte_mirror_active:
						focus_result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						focus_result = await field._run_focused_strike_minigame(attacker)
						field._coop_qte_capture_write(_cqe, focus_result)
					if focus_result > 0:
						field.ability_triggers_count += 1
						defense_stat = 0 # Completely ignore enemy armor
						force_hit = true 
						if focus_result == 2:
							field.add_combat_log("PERFECT FOCUS! Armor shattered & Critical blow!", "gold")
							force_crit = true 
							offense_stat += 5 
						else:
							field.add_combat_log("FOCUSED STRIKE! Defenses shattered!", "lime")
					else:
						field.add_combat_log("Focus Lost! Attack overextended!", "red")
						focused_failed = true
						
				# BLOODTHIRSTER
				elif field._attacker_has_attack_skill(attacker, "Bloodthirster") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var hits_landed: int
					if field._coop_qte_mirror_active:
						hits_landed = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						hits_landed = await field._run_bloodthirster_minigame(attacker)
						field._coop_qte_capture_write(_cqe, hits_landed)
					if hits_landed > 0:
						field.ability_triggers_count += 1
						lifesteal_percent = float(hits_landed) * 0.25 
						force_hit = true 
						field.add_combat_log("BLOODTHIRSTER! " + str(hits_landed) + " hits!", "crimson")
						if hits_landed == 3: force_crit = true 
					else:
						field.add_combat_log("Bloodthirster Failed! Combo broken.", "gray")
						
				# HUNDRED POINT STRIKE
				elif field._attacker_has_attack_skill(attacker, "Hundred Point Strike") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					if field._coop_qte_mirror_active:
						combo_hits = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						combo_hits = await field._run_hundred_point_strike_minigame(attacker)
						field._coop_qte_capture_write(_cqe, combo_hits)
					if combo_hits > 0:
						field.ability_triggers_count += 1
						force_hit = true 
						field.add_combat_log("HUNDRED POINT STRIKE! " + str(combo_hits) + " Combo!", "purple")
					else:
						field.add_combat_log("Strike Failed! Slipped up.", "gray")
						focused_failed = true
						
				# --- ARCHER: DEADEYE SHOT ---
				elif field._attacker_has_attack_skill(attacker, "Deadeye Shot") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var deadeye_result: int
					if field._coop_qte_mirror_active:
						deadeye_result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						deadeye_result = await QTEManager.run_deadeye_shot_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, deadeye_result)
					if deadeye_result > 0:
						field.ability_triggers_count += 1
						force_hit = true
						deadeye_bonus_damage = 6 if deadeye_result == 1 else 10
						if field.get_distance(attacker, defender) >= 3:
							deadeye_bonus_damage += 4
							field.add_combat_log("Deadeye: long draw — full string tension!", "aquamarine")
						if deadeye_result == 2:
							force_crit = true
							field.add_combat_log("PERFECT DEADEYE! Critical shot lined up!", "gold")
						else:
							field.add_combat_log("DEADEYE SHOT! Precision damage boosted!", "lime")
					else:
						field.add_combat_log("Deadeye timing missed.", "gray")
				
				# --- ARCHER: VOLLEY (perfect: second follow-up veers to a foe adjacent to the target) ---
				elif field._attacker_has_attack_skill(attacker, "Volley") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var volley_result: int
					if field._coop_qte_mirror_active:
						volley_result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						volley_result = await QTEManager.run_volley_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, volley_result)
					volley_spread_target = null
					if volley_result > 0:
						field.ability_triggers_count += 1
						force_hit = true
						volley_extra_hits = 1 if volley_result == 1 else 2
						volley_damage_multiplier = 0.55 if volley_result == 1 else 0.72
						if volley_result == 2:
							field.add_combat_log("PERFECT VOLLEY! Three arrows loose at once!", "gold")
							var vd: Vector2i = field.get_grid_pos(defender)
							for vdir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
								var ve: Node2D = field.get_enemy_at(vd + vdir)
								if ve != null and ve != defender and is_instance_valid(ve) and not ve.is_queued_for_deletion() and ve.get_parent() == field.enemy_container and ve.current_hp > 0:
									volley_spread_target = ve
									field.add_combat_log("One shaft veers into " + str(ve.unit_name) + "!", "lightcyan")
									break
						else:
							field.add_combat_log("VOLLEY! Bonus arrows incoming!", "cyan")
					else:
						field.add_combat_log("Volley fizzled. Not enough arrows loosed.", "gray")
				
				# --- ARCHER: RAIN OF ARROWS ---
				elif field._attacker_has_attack_skill(attacker, "Rain of Arrows") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var rain_result: int
					if field._coop_qte_mirror_active:
						rain_result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						rain_result = await QTEManager.run_rain_of_arrows_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, rain_result)
					if rain_result > 0:
						field.ability_triggers_count += 1
						force_hit = true
						rain_primary_bonus_damage = 5 if rain_result == 1 else 9
						rain_splash_damage = 4 if rain_result == 1 else 7
				
						var center_tile: Vector2i = field.get_grid_pos(defender)
						var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
				
						for dir in dirs:
							var splash_target: Node2D = field.get_enemy_at(center_tile + dir)
							if splash_target != null and splash_target != defender and splash_target.get_parent() == field.enemy_container and is_instance_valid(splash_target) and not splash_target.is_queued_for_deletion() and splash_target.current_hp > 0 and not rain_splash_targets.has(splash_target):
								rain_splash_targets.append(splash_target)
	
						rain_tail_unit = null
						rain_rear_extra_damage = 0
						var r_a: Vector2i = field.get_grid_pos(attacker)
						var r_d: Vector2i = field.get_grid_pos(defender)
						var r_step: Vector2i = field._attack_line_step(r_a, r_d)
						if r_step != Vector2i.ZERO:
							var r_tail: Node2D = field.get_enemy_at(r_d + r_step)
							if r_tail != null and r_tail != defender and is_instance_valid(r_tail) and not r_tail.is_queued_for_deletion() and r_tail.get_parent() == field.enemy_container and r_tail.current_hp > 0:
								rain_tail_unit = r_tail
								rain_rear_extra_damage = 6 if rain_result == 2 else 3
								if not rain_splash_targets.has(r_tail):
									rain_splash_targets.append(r_tail)
								field.add_combat_log("The volley hammers the rear rank (" + str(r_tail.unit_name) + ")!", "wheat")
	
						if rain_result == 1 and rain_splash_targets.size() > 1:
							if rain_tail_unit != null and rain_splash_targets.has(rain_tail_unit):
								rain_splash_targets = [rain_tail_unit]
							else:
								rain_splash_targets = [rain_splash_targets[0]]
				
						if rain_result == 2:
							field.add_combat_log("PERFECT RAIN OF ARROWS! The whole zone is covered!", "gold")
						else:
							field.add_combat_log("RAIN OF ARROWS! Nearby foes are caught in the barrage!", "khaki")
					else:
						field.add_combat_log("Rain of Arrows sequence broken.", "gray")
	
				# --- KNIGHT: CHARGE (pin vs rear foe — extra crush when someone stands behind the target) ---
				elif field._attacker_has_attack_skill(attacker, "Charge") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_charge_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result == 2:
						field.ability_triggers_count += 1
						force_hit = true
						force_crit = true
						charge_bonus_damage = 12
						field.add_combat_log("PERFECT CHARGE! Crushing impact!", "gold")
					elif result == 1:
						field.ability_triggers_count += 1
						force_hit = true
						charge_bonus_damage = 7
						field.add_combat_log("CHARGE! The Knight slams through with full momentum!", "orange")
					else:
						field.add_combat_log("Charge timing failed. Momentum lost.", "gray")
					if result > 0:
						var ca: Vector2i = field.get_grid_pos(attacker)
						var cd: Vector2i = field.get_grid_pos(defender)
						var cstep: Vector2i = field._attack_line_step(ca, cd)
						if cstep != Vector2i.ZERO:
							var pin_cell: Vector2i = cd + cstep
							var rear: Node2D = field.get_enemy_at(pin_cell)
							if rear != null and rear != defender and is_instance_valid(rear) and not rear.is_queued_for_deletion() and rear.get_parent() == field.enemy_container and rear.current_hp > 0:
								charge_collision_target = rear
								charge_collision_damage = 12 if result == 2 else 6
								charge_bonus_damage += 5 if result == 2 else 3
								field.add_combat_log(str(defender.unit_name) + " is crushed against " + str(rear.unit_name) + "!", "coral")
	
				# --- MAGE: FIREBALL ---
				elif field._attacker_has_attack_skill(attacker, "Fireball") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_fireball_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
	
						var center_tile: Vector2i = field.get_grid_pos(defender)
						var splash_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
						fireball_bonus_damage = 7 if result == 1 else 11
						fireball_splash_damage = 4 if result == 1 else 7
	
						if result == 2:
							splash_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])
	
						for dir in splash_dirs:
							var splash_target: Node2D = field.get_enemy_at(center_tile + dir)
							if splash_target != null and splash_target != defender and splash_target.get_parent() == field.enemy_container and is_instance_valid(splash_target) and not splash_target.is_queued_for_deletion() and splash_target.current_hp > 0 and not fireball_splash_targets.has(splash_target):
								fireball_splash_targets.append(splash_target)
	
						fireball_tail_unit = null
						fireball_tail_extra_damage = 0
						var fa: Vector2i = field.get_grid_pos(attacker)
						var fd: Vector2i = field.get_grid_pos(defender)
						var fstep: Vector2i = field._attack_line_step(fa, fd)
						if fstep != Vector2i.ZERO:
							var f_tail: Node2D = field.get_enemy_at(fd + fstep)
							if f_tail != null and f_tail != defender and is_instance_valid(f_tail) and not f_tail.is_queued_for_deletion() and f_tail.get_parent() == field.enemy_container and f_tail.current_hp > 0:
								fireball_tail_unit = f_tail
								fireball_tail_extra_damage = 6 if result == 2 else 3
								if not fireball_splash_targets.has(f_tail):
									fireball_splash_targets.append(f_tail)
								field.add_combat_log("The fireball rolls through onto " + str(f_tail.unit_name) + "!", "orangered")
	
						if result == 2:
							field.add_combat_log("PERFECT FIREBALL! The blast fully engulfs the area!", "gold")
						else:
							field.add_combat_log("FIREBALL! The explosion scorches nearby foes!", "orange")
					else:
						field.add_combat_log("Fireball fizzled. The spell landed poorly.", "gray")
	
				# --- MAGE: METEOR STORM ---
				elif field._attacker_has_attack_skill(attacker, "Meteor Storm") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_meteor_storm_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
	
						var center_tile: Vector2i = field.get_grid_pos(defender)
						var splash_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
						meteor_storm_bonus_damage = 11 if result == 1 else 17
						meteor_storm_splash_damage = 6 if result == 1 else 10
	
						if result == 2:
							splash_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])
	
						for dir in splash_dirs:
							var splash_target: Node2D = field.get_enemy_at(center_tile + dir)
							if splash_target != null and splash_target != defender and splash_target.get_parent() == field.enemy_container and is_instance_valid(splash_target) and not splash_target.is_queued_for_deletion() and splash_target.current_hp > 0 and not meteor_storm_splash_targets.has(splash_target):
								meteor_storm_splash_targets.append(splash_target)
	
						meteor_tail_unit = null
						meteor_tail_extra_damage = 0
						var ma: Vector2i = field.get_grid_pos(attacker)
						var md: Vector2i = field.get_grid_pos(defender)
						var mstep: Vector2i = field._attack_line_step(ma, md)
						if mstep != Vector2i.ZERO:
							var m_tail: Node2D = field.get_enemy_at(md + mstep)
							if m_tail != null and m_tail != defender and is_instance_valid(m_tail) and not m_tail.is_queued_for_deletion() and m_tail.get_parent() == field.enemy_container and m_tail.current_hp > 0:
								meteor_tail_unit = m_tail
								meteor_tail_extra_damage = 8 if result == 2 else 4
								if not meteor_storm_splash_targets.has(m_tail):
									meteor_storm_splash_targets.append(m_tail)
								field.add_combat_log("A meteor fragment streaks into " + str(m_tail.unit_name) + "!", "tomato")
	
						if result == 2:
							force_crit = true
							field.add_combat_log("PERFECT METEOR STORM! Cataclysmic impact across the battlefield!", "gold")
						else:
							field.add_combat_log("METEOR STORM! Burning fragments rain across the target zone!", "tomato")
					else:
						field.add_combat_log("Meteor Storm sequence failed. The heavens do not answer.", "gray")
	
				# --- MERCENARY: FLURRY STRIKE ---
				elif field._attacker_has_attack_skill(attacker, "Flurry Strike") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_flurry_strike_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
						flurry_strike_hits = result
	
						if result >= 5:
							flurry_strike_damage_multiplier = 0.60
							field.add_combat_log("PERFECT FLURRY STRIKE! A storm of blades erupts!", "gold")
						elif result >= 3:
							flurry_strike_damage_multiplier = 0.50
							field.add_combat_log("FLURRY STRIKE! Multiple rapid hits break through!", "cyan")
						else:
							flurry_strike_damage_multiplier = 0.42
							field.add_combat_log("Flurry Strike lands a short combo.", "white")
					else:
						field.add_combat_log("Flurry Strike failed. The combo never began.", "gray")
	
				# --- MERCENARY: BATTLE CRY ---
				elif field._attacker_has_attack_skill(attacker, "Battle Cry") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_battle_cry_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						var ally_count: int = 0
						var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
						var attacker_pos: Vector2i = field.get_grid_pos(attacker)
						var attacker_is_friendly: bool = (attacker.get_parent() == field.player_container or attacker.get_parent() == field.ally_container)
	
						for dir in dirs:
							var check_pos: Vector2i = attacker_pos + dir
							var nearby_unit: Node2D = null
	
							if attacker_is_friendly:
								nearby_unit = field.get_unit_at(check_pos)
								if nearby_unit == null and field.ally_container != null:
									for a in field.ally_container.get_children():
										if is_instance_valid(a) and not a.is_queued_for_deletion() and field.get_grid_pos(a) == check_pos:
											nearby_unit = a
											break
							else:
								nearby_unit = field.get_enemy_at(check_pos)
	
							if nearby_unit != null and nearby_unit != attacker:
								ally_count += 1
								field.spawn_loot_text("RALLIED!", Color(1.0, 0.95, 0.4), nearby_unit.global_position + Vector2(32, -24))
	
						if result == 2:
							battle_cry_bonus_damage = 5 + (ally_count * 3)
							battle_cry_bonus_hit = 18 + (ally_count * 4)
							field.add_combat_log("PERFECT BATTLE CRY! The whole formation surges with morale!", "gold")
						else:
							battle_cry_bonus_damage = 3 + (ally_count * 2)
							battle_cry_bonus_hit = 10 + (ally_count * 3)
							field.add_combat_log("BATTLE CRY! Nearby allies fuel the Mercenary's assault!", "orange")
					else:
						field.add_combat_log("Battle Cry falls flat. No momentum gained.", "gray")
	
				# --- MERCENARY: BLADE TEMPEST ---
				elif field._attacker_has_attack_skill(attacker, "Blade Tempest") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_blade_tempest_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
	
						var center_tile: Vector2i = field.get_grid_pos(attacker)
						var splash_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
						blade_tempest_bonus_damage = 7 if result == 1 else 12
						blade_tempest_splash_damage = 5 if result == 1 else 9
	
						if result == 2:
							splash_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])
	
						for dir in splash_dirs:
							var splash_target: Node2D = field.get_enemy_at(center_tile + dir)
							if splash_target != null and splash_target != defender and splash_target.get_parent() == field.enemy_container and is_instance_valid(splash_target) and not splash_target.is_queued_for_deletion() and splash_target.current_hp > 0 and not blade_tempest_splash_targets.has(splash_target):
								blade_tempest_splash_targets.append(splash_target)
	
						if result == 2:
							field.add_combat_log("PERFECT BLADE TEMPEST! Steel tears through everything nearby!", "gold")
						else:
							field.add_combat_log("BLADE TEMPEST! The Mercenary's spinning assault clips nearby enemies!", "cyan")
					else:
						field.add_combat_log("Blade Tempest loses rhythm before the storm begins.", "gray")
	
				# --- MONK: CHAKRA ---
				elif field._attacker_has_attack_skill(attacker, "Chakra") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_chakra_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						var heal_amount: int = 0
				
						if result == 2:
							heal_amount = int(max(8, attacker.magic + 4))
							chakra_bonus_damage = 6
							chakra_bonus_hit = 18
							field.add_combat_log("PERFECT CHAKRA! Body and spirit are fully aligned!", "gold")
						else:
							heal_amount = int(max(5, attacker.magic + 1))
							chakra_bonus_damage = 3
							chakra_bonus_hit = 10
							field.add_combat_log("CHAKRA! The Monk restores inner strength and focus.", "lime")
				
						attacker.current_hp = min(attacker.current_hp + heal_amount, attacker.max_hp)
						if attacker.get("health_bar") != null:
							attacker.health_bar.value = attacker.current_hp
				
						var chakra_hr: float = -1.0
						if attacker.max_hp > 0:
							chakra_hr = clampf(float(heal_amount) / float(attacker.max_hp), 0.0, 1.0)
						field.spawn_loot_text("+" + str(heal_amount) + " HP", Color(0.35, 1.0, 0.35), attacker.global_position + Vector2(32, -30), {
							"tier": FloatingCombatText.Tier.HEAL,
							"hp_chunk_ratio": chakra_hr,
							"stack_anchor": attacker,
						})
					else:
						field.add_combat_log("Chakra faltered. The Monk failed to center their breathing.", "gray")
	
				# --- MONK: CHI BURST ---
				elif field._attacker_has_attack_skill(attacker, "Chi Burst") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_chi_burst_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
				
						var center_tile: Vector2i = field.get_grid_pos(defender)
						var splash_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
				
						if result == 2:
							chi_burst_bonus_damage = 10
							chi_burst_splash_damage = 7
							splash_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])
							field.add_combat_log("PERFECT CHI BURST! Spiritual force erupts in every direction!", "gold")
						else:
							chi_burst_bonus_damage = 6
							chi_burst_splash_damage = 4
							field.add_combat_log("CHI BURST! The Monk's energy detonates outward.", "violet")
				
						for dir in splash_dirs:
							var splash_target: Node2D = field.get_enemy_at(center_tile + dir)
							if splash_target != null and splash_target != defender and splash_target.get_parent() == field.enemy_container and is_instance_valid(splash_target) and not splash_target.is_queued_for_deletion() and splash_target.current_hp > 0 and not chi_burst_splash_targets.has(splash_target):
								chi_burst_splash_targets.append(splash_target)
					else:
						field.add_combat_log("Chi Burst collapsed before release.", "gray")
	
				# --- MONSTER: ROAR ---
				elif field._attacker_has_attack_skill(attacker, "Roar") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_roar_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						var attacker_is_friendly: bool = (attacker.get_parent() == field.player_container or attacker.get_parent() == field.ally_container)
						var roar_radius: int = 1 if result == 1 else 2
						var debuff_amount: int = 1 if result == 1 else 2
						var affected_targets: Array[Node2D] = []
						var affected_count: int = 0
				
						for x in range(-roar_radius, roar_radius + 1):
							for y in range(-roar_radius, roar_radius + 1):
								var offset: Vector2i = Vector2i(x, y)
								if abs(offset.x) + abs(offset.y) > roar_radius: continue
								if offset == Vector2i.ZERO: continue
				
								var target_tile: Vector2i = field.get_grid_pos(attacker) + offset
								var target: Node2D = field.get_occupant_at(target_tile)
				
								if target == null or not is_instance_valid(target) or target.is_queued_for_deletion(): continue
								if affected_targets.has(target): continue
				
								var is_hostile: bool = false
								if attacker_is_friendly:
									is_hostile = target.get_parent() == field.enemy_container
								else:
									is_hostile = (target.get_parent() == field.player_container or target.get_parent() == field.ally_container)
				
								if not is_hostile: continue
				
								target.strength = int(max(0, target.strength - debuff_amount))
								target.magic = int(max(0, target.magic - debuff_amount))
								target.speed = int(max(0, target.speed - debuff_amount))
								target.agility = int(max(0, target.agility - debuff_amount))
				
								affected_targets.append(target)
								affected_count += 1
								field.spawn_loot_text("INTIMIDATED!", Color(1.0, 0.70, 0.25), target.global_position + Vector2(32, -20))
				
						if result == 2:
							field.add_combat_log("PERFECT ROAR! " + str(affected_count) + " enemies are shaken to the bone!", "gold")
						else:
							field.add_combat_log("ROAR! " + str(affected_count) + " enemies are rattled by the beast's cry.", "orange")
					else:
						field.add_combat_log("The Roar came out weak and uneven.", "gray")
	
				# --- MONSTER: FRENZY ---
				elif field._attacker_has_attack_skill(attacker, "Frenzy") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_frenzy_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						_frenzy_hit_count = result
						frenzy_bonus_damage = result * 2
						frenzy_bonus_hit = result * 4
						frenzy_def_penalty = 2 + int(float(result) / 2.0)
				
						attacker.set_meta("frenzy_def_penalty_temp", frenzy_def_penalty)
						attacker.set_meta("frenzy_res_penalty_temp", frenzy_def_penalty)
				
						if result >= 6:
							force_hit = true
							field.add_combat_log("PERFECT FRENZY! The Monster goes completely berserk!", "gold")
						elif result >= 4:
							field.add_combat_log("FRENZY! The Monster's rage spikes violently!", "crimson")
						else:
							field.add_combat_log("Frenzy builds, but leaves the Monster exposed.", "tomato")
				
						field.spawn_loot_text("-" + str(frenzy_def_penalty) + " DEF", Color(1.0, 0.45, 0.45), attacker.global_position + Vector2(32, -30))
					else:
						field.add_combat_log("Frenzy never took hold.", "gray")
	
				# --- MONSTER: RENDING CLAW ---
				elif field._attacker_has_attack_skill(attacker, "Rending Claw") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_rending_claw_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
						if result == 2:
							defense_stat = 0
							force_crit = true
							field.add_combat_log("PERFECT RENDING CLAW! Armor is shredded completely!", "gold")
						else:
							defense_stat = int(max(0, defense_stat - 8))
							field.add_combat_log("RENDING CLAW! The Monster tears through armor plating!", "tomato")
					else:
						field.add_combat_log("Rending Claw missed the weak point.", "gray")
						
				# --- PALADIN: SMITE ---
				elif field._attacker_has_attack_skill(attacker, "Smite") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_smite_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					smite_splash_targets.clear()
					smite_splash_damage = 0
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
						
						if result == 2:
							force_crit = true
							smite_bonus_damage = 8 + int(attacker.magic / 2)
							smite_splash_damage = 7 + int(attacker.magic / 4)
							field.add_combat_log("PERFECT SMITE! A blinding ray of holy light obliterates the target!", "gold")
						else:
							smite_bonus_damage = 4 + int(attacker.magic / 3)
							smite_splash_damage = 4 + int(attacker.magic / 5)
							field.add_combat_log("SMITE! Holy energy sears the enemy!", "yellow")
						var smite_center: Vector2i = field.get_grid_pos(defender)
						for sm_dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
							if smite_splash_targets.size() >= 2:
								break
							var sm_e: Node2D = field.get_enemy_at(smite_center + sm_dir)
							if sm_e != null and sm_e != defender and is_instance_valid(sm_e) and not sm_e.is_queued_for_deletion() and sm_e.get_parent() == field.enemy_container and sm_e.current_hp > 0 and not smite_splash_targets.has(sm_e):
								smite_splash_targets.append(sm_e)
						if smite_splash_targets.size() > 0:
							field.add_combat_log("Holy light splashes onto nearby foes!", "khaki")
					else:
						field.add_combat_log("Smite failed to find its mark.", "gray")
						
				# --- PALADIN: SACRED JUDGMENT ---
				elif field._attacker_has_attack_skill(attacker, "Sacred Judgment") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_sacred_judgment_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
	
						var center_tile: Vector2i = field.get_grid_pos(defender)
						var splash_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
						sacred_judgment_bonus_damage = 10 if result == 1 else 15
						sacred_judgment_splash_damage = 5 if result == 1 else 8
	
						if result == 2:
							splash_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])
	
						for dir in splash_dirs:
							var splash_target: Node2D = field.get_enemy_at(center_tile + dir)
							if splash_target != null and splash_target != defender and splash_target.get_parent() == field.enemy_container and is_instance_valid(splash_target) and not splash_target.is_queued_for_deletion() and splash_target.current_hp > 0 and not sacred_judgment_splash_targets.has(splash_target):
								sacred_judgment_splash_targets.append(splash_target)
	
						if result == 2:
							field.add_combat_log("PERFECT SACRED JUDGMENT! A colossal cross of light engulfs the area!", "gold")
						else:
							field.add_combat_log("SACRED JUDGMENT! The heavens strike down nearby foes!", "yellow")
					else:
						field.add_combat_log("Sacred Judgment was released too early.", "gray")
	
				# --- SPELLBLADE: FLAME BLADE ---
				elif field._attacker_has_attack_skill(attacker, "Flame Blade") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_flame_blade_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
						
						var magic_scale: int = int(float(attacker.magic) * 0.8)
						if result == 2:
							flame_blade_bonus_damage = 5 + magic_scale
							force_crit = true
							field.add_combat_log("PERFECT FLAME BLADE! The sword erupts into a roaring inferno!", "gold")
						else:
							flame_blade_bonus_damage = 2 + int(float(magic_scale) * 0.5)
							field.add_combat_log("FLAME BLADE! Searing heat wraps around the strike!", "orange")
					else:
						field.add_combat_log("Flame Blade fizzled out.", "gray")
	
				# --- SPELLBLADE: ELEMENTAL CONVERGENCE ---
				elif field._attacker_has_attack_skill(attacker, "Elemental Convergence") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_elemental_convergence_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
	
						var center_tile: Vector2i = field.get_grid_pos(defender)
						var splash_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
						elemental_convergence_bonus_damage = 12 if result == 1 else 20
						elemental_convergence_splash_damage = 6 if result == 1 else 10
	
						if result == 2:
							splash_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])
	
						for dir in splash_dirs:
							var splash_target: Node2D = field.get_enemy_at(center_tile + dir)
							if splash_target != null and splash_target != defender and splash_target.get_parent() == field.enemy_container and is_instance_valid(splash_target) and not splash_target.is_queued_for_deletion() and splash_target.current_hp > 0 and not elemental_convergence_splash_targets.has(splash_target):
								elemental_convergence_splash_targets.append(splash_target)
	
						if result == 2:
							force_crit = true
							field.add_combat_log("PERFECT CONVERGENCE! Fire, Ice, and Lightning detonate simultaneously!", "gold")
						else:
							field.add_combat_log("ELEMENTAL CONVERGENCE! A chaotic magical storm blasts the area!", "violet")
					else:
						field.add_combat_log("The elemental energies destabilized and vanished.", "gray")
						
				# --- THIEF: SHADOW STRIKE ---
				elif field._attacker_has_attack_skill(attacker, "Shadow Strike") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_shadow_strike_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
						if result == 2:
							shadow_strike_bonus_damage = 10
							shadow_strike_armor_pierce = 1.0 # Ignore 100% armor
							field.add_combat_log("PERFECT SHADOW STRIKE! A flawless strike from the darkness!", "gold")
						else:
							shadow_strike_bonus_damage = 5
							shadow_strike_armor_pierce = 0.5 # Ignore 50% armor
							field.add_combat_log("SHADOW STRIKE! The Thief strikes from the blind spot!", "violet")
					else:
						field.add_combat_log("Shadow Strike revealed. The element of surprise is gone.", "gray")
						
				# --- THIEF: ASSASSINATE ---
				elif field._attacker_has_attack_skill(attacker, "Assassinate") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_assassinate_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
						assassinate_crit_bonus = result * 25 # Each successful lockpick adds 25% crit chance
						if result == 3:
							force_crit = true
							field.add_combat_log("PERFECT ASSASSINATION! All vital points struck!", "gold")
						else:
							field.add_combat_log("ASSASSINATE! " + str(result) + " vitals hit!", "crimson")
					else:
						field.add_combat_log("Assassinate failed to find an opening.", "gray")
						
				# --- THIEF: ULTIMATE SHADOW STEP ---
				elif field._attacker_has_attack_skill(attacker, "Ultimate Shadow Step") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_ultimate_shadow_step_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
						if result == 2:
							shadow_step_bonus_damage = 15
							force_crit = true
							field.add_combat_log("PERFECT SHADOW STEP! Absolute teleportation mastery!", "gold")
						else:
							shadow_step_bonus_damage = 8
							field.add_combat_log("SHADOW STEP! The Thief materializes behind the enemy!", "cyan")
					else:
						field.add_combat_log("Ultimate Shadow Step collapsed. Sequence broken.", "gray")
	
				# --- WARRIOR: POWER STRIKE ---
				elif field._attacker_has_attack_skill(attacker, "Power Strike") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_power_strike_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
						if result == 2:
							power_strike_bonus_damage = int(float(attacker.strength) * 1.5)
							force_crit = true
							field.add_combat_log("PERFECT POWER STRIKE! Maximum kinetic energy!", "gold")
						else:
							power_strike_bonus_damage = int(float(attacker.strength) * 0.75)
							field.add_combat_log("POWER STRIKE! A heavy, punishing blow!", "orange")
					else:
						field.add_combat_log("Power Strike whiffed entirely.", "gray")
	
				# --- WARRIOR: ADRENALINE RUSH ---
				elif field._attacker_has_attack_skill(attacker, "Adrenaline Rush") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_adrenaline_rush_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						var buff_amt: int = 0
						if result == 2:
							buff_amt = 8
							field.add_combat_log("PERFECT ADRENALINE RUSH! Blood boils with pure fury!", "gold")
						else:
							buff_amt = 4
							field.add_combat_log("ADRENALINE RUSH! The Warrior pushes past their limits!", "tomato")
						
						attacker.strength += buff_amt
						attacker.speed += buff_amt
						field.spawn_loot_text("+" + str(buff_amt) + " STR/SPD", Color(1.0, 0.2, 0.2), attacker.global_position + Vector2(32, -32))
					else:
						field.add_combat_log("Adrenaline Rush faded.", "gray")
	
				# --- WARRIOR: EARTHSHATTER ---
				elif field._attacker_has_attack_skill(attacker, "Earthshatter") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_earthshatter_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
	
						var center_tile: Vector2i = field.get_grid_pos(defender)
						var splash_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
						if result == 2:
							earthshatter_bonus_damage = 18
							earthshatter_splash_damage = 12
							splash_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])
							force_crit = true
							field.add_combat_log("PERFECT EARTHSHATTER! The ground itself explodes!", "gold")
						else:
							earthshatter_bonus_damage = 10
							earthshatter_splash_damage = 6
							field.add_combat_log("EARTHSHATTER! Shockwaves tear through the terrain!", "orange")
	
						for dir in splash_dirs:
							var splash_target: Node2D = field.get_enemy_at(center_tile + dir)
							if splash_target != null and splash_target != defender and splash_target.get_parent() == field.enemy_container and is_instance_valid(splash_target) and not splash_target.is_queued_for_deletion() and splash_target.current_hp > 0 and not earthshatter_splash_targets.has(splash_target):
								earthshatter_splash_targets.append(splash_target)
					else:
						field.add_combat_log("Earthshatter miscalculated. The strike hit dirt.", "gray")
				
				# --- PROMOTED ASSASSIN: SHADOW PIN ---
				elif field._attacker_has_attack_skill(attacker, "Shadow Pin") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_shadow_pin_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
						shadow_pin_speed_lock = true
						
						if result == 2:
							shadow_pin_bonus_damage = 12
							force_crit = true
							field.add_combat_log("PERFECT SHADOW PIN! The target is completely paralyzed!", "gold")
						else:
							shadow_pin_bonus_damage = 6
							field.add_combat_log("SHADOW PIN! The target is crippled!", "violet")
					else:
						field.add_combat_log("Shadow Pin missed the pressure point.", "gray")
	
				# --- PROMOTED BERSERKER: SAVAGE TOSS ---
				elif field._attacker_has_attack_skill(attacker, "Savage Toss") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					if field._coop_qte_mirror_active:
						savage_toss_distance = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						savage_toss_distance = await QTEManager.run_savage_toss_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, savage_toss_distance)
					if savage_toss_distance > 0:
						field.ability_triggers_count += 1
						force_hit = true
						savage_toss_bonus_damage = savage_toss_distance * 3
						
						if savage_toss_distance == 3:
							force_crit = true
							field.add_combat_log("PERFECT SAVAGE TOSS! Sent flying across the battlefield!", "gold")
						else:
							field.add_combat_log("SAVAGE TOSS! The enemy is hurled backward!", "orange")
					else:
						field.add_combat_log("Savage Toss failed to lift the target.", "gray")
	
				# --- PROMOTED HERO: VANGUARD'S RALLY ---
				elif field._attacker_has_attack_skill(attacker, "Vanguard's Rally") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var combos: int
					if field._coop_qte_mirror_active:
						combos = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						combos = await QTEManager.run_vanguards_rally_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, combos)
					if combos > 0:
						field.ability_triggers_count += 1
						force_hit = true
						vanguards_rally_bonus_damage = 4 + (combos * 2)
						vanguards_rally_might_bonus = mini(combos, 4)
						
						if combos >= 4:
							force_crit = true
							field.add_combat_log("PERFECT VANGUARD'S RALLY! The entire army surges with power!", "gold")
						else:
							field.add_combat_log("VANGUARD'S RALLY! Inspiring strike bolsters nearby allies!", "cyan")
					else:
						field.add_combat_log("Vanguard's Rally failed to build momentum.", "gray")
	
				# --- PROMOTED BLADE MASTER: SEVERING STRIKE ---
				elif field._attacker_has_attack_skill(attacker, "Severing Strike") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					if field._coop_qte_mirror_active:
						severing_strike_hits = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						severing_strike_hits = await QTEManager.run_severing_strike_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, severing_strike_hits)
					if severing_strike_hits > 0:
						field.ability_triggers_count += 1
						force_hit = true
						
						if severing_strike_hits == 3:
							force_crit = true
							severing_strike_damage_multiplier = 0.8
							field.add_combat_log("PERFECT SEVERING STRIKE! Three absolute precision cuts!", "gold")
						else:
							severing_strike_damage_multiplier = 0.5
							field.add_combat_log("SEVERING STRIKE! " + str(severing_strike_hits) + " critical points hit!", "cyan")
					else:
						field.add_combat_log("Severing Strike missed all vital points.", "gray")
	
				# --- PROMOTED BLADE WEAVER: AETHER BIND ---
				elif field._attacker_has_attack_skill(attacker, "Aether Bind") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					if field._coop_qte_mirror_active:
						aether_bind_sparks = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						aether_bind_sparks = await QTEManager.run_aether_bind_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, aether_bind_sparks)
					if aether_bind_sparks > 0:
						field.ability_triggers_count += 1
						force_hit = true
						
						var bonus: int = aether_bind_sparks * 2
						offense_stat += bonus # Permanently boosts their magic for the rest of the attack!
						
						if aether_bind_sparks >= 5:
							force_crit = true
							field.add_combat_log("PERFECT AETHER BIND! Maximum magical energy harvested!", "gold")
						else:
							field.add_combat_log("AETHER BIND! Gathered " + str(aether_bind_sparks) + " sparks of raw power!", "violet")
						
						field.spawn_loot_text("+" + str(bonus) + " MAG", Color(0.8, 0.4, 1.0), attacker.global_position + Vector2(32, -32))
					else:
						field.add_combat_log("Aether Bind failed to catch any magical energy.", "gray")
	
				# --- PROMOTED BOW KNIGHT: PARTING SHOT ---
				elif field._attacker_has_attack_skill(attacker, "Parting Shot") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					if field._coop_qte_mirror_active:
						parting_shot_result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						parting_shot_result = await QTEManager.run_parting_shot_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, parting_shot_result)
					if parting_shot_result > 0:
						field.ability_triggers_count += 1
						force_hit = true
						
						if parting_shot_result == 2:
							force_crit = true
							_parting_shot_bonus_damage = 8
							parting_shot_dodge = true
							field.add_combat_log("PERFECT PARTING SHOT! Flawless strike and retreat!", "gold")
						else:
							_parting_shot_bonus_damage = 4
							field.add_combat_log("PARTING SHOT! Arrow strikes true!", "lime")
					else:
						field.add_combat_log("Parting Shot execution failed.", "gray")
	
				# --- PROMOTED DEATH KNIGHT: SOUL HARVEST ---
				elif field._attacker_has_attack_skill(attacker, "Soul Harvest") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					if field._coop_qte_mirror_active:
						soul_harvest_result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						soul_harvest_result = await QTEManager.run_soul_harvest_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, soul_harvest_result)
					if soul_harvest_result > 0:
						field.ability_triggers_count += 1
						force_hit = true
						
						# Soul Harvest drains HP equal to a % of the enemy's MAX HP instead of relying on attack stat!
						var drain_percent: float = 0.25 if soul_harvest_result == 2 else 0.10
						var drain_amt: int = int(float(defender.max_hp) * drain_percent)
						
						attacker.current_hp = min(attacker.current_hp + drain_amt, attacker.max_hp)
						if attacker.get("health_bar") != null:
							attacker.health_bar.value = attacker.current_hp
						field.spawn_loot_text("+" + str(drain_amt) + " HP", Color(0.2, 1.0, 0.2), attacker.global_position + Vector2(-32, -16))
						
						if soul_harvest_result == 2:
							force_crit = true
							field.add_combat_log("PERFECT SOUL HARVEST! Massive life force drained!", "gold")
						else:
							field.add_combat_log("SOUL HARVEST! Life force siphoned!", "crimson")
					else:
						field.add_combat_log("Soul Harvest grip broken.", "gray")
	
				# --- PROMOTED FIRE SAGE: HELLFIRE ---
				elif field._attacker_has_attack_skill(attacker, "Hellfire") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					if field._coop_qte_mirror_active:
						hellfire_result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						hellfire_result = await QTEManager.run_hellfire_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, hellfire_result)
					if hellfire_result == 2:
						field.ability_triggers_count += 1
						force_hit = true
						force_crit = true
						hellfire_bonus_damage = 15
						field.add_combat_log("PERFECT HELLFIRE! The enemy is engulfed in unholy flames!", "gold")
					else:
						field.add_combat_log("Hellfire failed to reach critical mass.", "gray")
	
				# --- CANNONEER / SIEGE: BALLISTA SHOT (overpenetration — foe behind primary target in line) ---
				elif field._attacker_has_attack_skill(attacker, "Ballista Shot") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_ballista_shot_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
						if result == 2:
							force_crit = true
							ballista_shot_bonus_damage = 18
							field.add_combat_log("PERFECT BALLISTA SHOT! An absolute bullseye!", "gold")
						else:
							ballista_shot_bonus_damage = 8
							field.add_combat_log("BALLISTA SHOT! A heavy bolt strikes the target!", "cyan")
						# Identity: siege bolt punches through — next enemy on the same line behind the target eats spill damage.
						ballista_shot_pierce_damage = 0
						var a_cell: Vector2i = field.get_grid_pos(attacker)
						var d_cell: Vector2i = field.get_grid_pos(defender)
						var step: Vector2i = field._attack_line_step(a_cell, d_cell)
						if step != Vector2i.ZERO:
							var behind_cell: Vector2i = d_cell + step
							var pierce: Node2D = field.get_enemy_at(behind_cell)
							if pierce != null and pierce != defender and is_instance_valid(pierce) and not pierce.is_queued_for_deletion() and pierce.get_parent() == field.enemy_container and pierce.current_hp > 0:
								ballista_shot_pierce_targets.append(pierce)
								ballista_shot_pierce_damage = 14 if result == 2 else 7
								field.add_combat_log("The bolt overpenetrates toward " + str(pierce.unit_name) + "!", "lightskyblue")
					else:
						field.add_combat_log("Ballista Shot missed the mark.", "gray")
	
				# --- PROMOTED HIGH PALADIN: AEGIS STRIKE ---
				elif field._attacker_has_attack_skill(attacker, "Aegis Strike") and randi() % 100 < atk_trigger_chance:
					var _cqe: String = field._coop_qte_alloc_event_id()
					var result: int
					if field._coop_qte_mirror_active:
						result = field._coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_aegis_strike_minigame(field, attacker)
						field._coop_qte_capture_write(_cqe, result)
					if result > 0:
						field.ability_triggers_count += 1
						force_hit = true
						if result == 2:
							force_crit = true
							aegis_strike_bonus_damage = 16
							field.add_combat_log("PERFECT AEGIS STRIKE! The holy cross detonates!", "gold")
						else:
							aegis_strike_bonus_damage = 7
							field.add_combat_log("AEGIS STRIKE! A heavy blow aligned with the heavens!", "yellow")
					else:
						field.add_combat_log("Aegis Strike lost its alignment.", "gray")
	
			var rookie_mods: Dictionary = field._compute_rookie_class_passive_mods(attacker, defender, is_magic, wpn)
			var rookie_hit: int = int(rookie_mods.get("hit", 0))
			var rookie_dmg: int = int(rookie_mods.get("dmg", 0))
			var rookie_crit: int = int(rookie_mods.get("crit", 0))
			var rookie_log: String = str(rookie_mods.get("log", ""))
	
			# --- FINAL HIT CHANCE MATH (support-combat: atk_sup hit, def_sup avo; relationship: atk_rel hit, def_rel avo) ---
			var hit_chance: int = int(clamp(80 + (wpn.hit_bonus if wpn else 0) + atk_wpn_rune_hit + tri_hit + atk_adj["hit"] + atk_sup["hit"] - def_sup["avo"] + atk_rel["hit"] - def_rel["avo"] + (attacker.agility * 2) - (defender.speed * 2) - def_terrain["avo"], 0, 100))
			hit_chance = int(
				clamp(
					hit_chance
					+ battle_cry_bonus_hit
					+ chakra_bonus_hit
					+ frenzy_bonus_hit
					+ rookie_hit
					+ CombatPassiveAbilityHelpers.passive_combat_hit_bonus(field, attacker, defender, wpn)
					- int(defender.get_meta("inner_peace_avo_bonus_temp", 0))
					+ UnitCombatStatusHelpers.resolve_combat_hit_bonus(attacker)
					- UnitCombatStatusHelpers.resolve_combat_avo_bonus(defender),
					0,
					100
				)
			)
			if focused_failed: hit_chance = 0 
			
			# --- ARMOR PIERCING CALCULATION ---
			var actual_defense: int = defense_stat
			if shadow_strike_armor_pierce > 0.0:
				actual_defense = int(float(actual_defense) * (1.0 - shadow_strike_armor_pierce))
			
			# ==========================================
			# --- POISE & GUARD BREAK SYSTEM ---
			# ==========================================
			# Use unit's get_max_poise() when available so forecast, UI, and resolution stay in sync.
			var def_max_poise: int = defender.get_max_poise() if defender.has_method("get_max_poise") else (defender.max_hp + (actual_defense * 2) + (25 if defender.get("is_defending") else 0))
			var def_current_poise: int = defender.get_meta("current_poise", def_max_poise)
			def_current_poise = clampi(def_current_poise, 0, def_max_poise)
	
			# --- Are they already broken from a previous attack? ---
			var already_staggered: bool = (def_current_poise <= 0) 
			
			var raw_power: int = offense_stat + (wpn.might if wpn else 0) + atk_wpn_rune_might
			var poise_dmg: int = raw_power
			
			# Axes deal massive poise damage to crack shields
			if wpn and wpn.get("weapon_type") == WeaponData.WeaponType.AXE:
				poise_dmg = int(float(poise_dmg) * 1.5)
				
			if force_crit: 
				poise_dmg *= 2
				
			# Only trigger the "Break" event if they weren't broken already
			var will_stagger: bool = not already_staggered and (def_current_poise - poise_dmg) <= 0
			
			if will_stagger or already_staggered:
				actual_defense = int(float(actual_defense) * 0.5) # Armor is cracked!
				
			# Calculate Base Damage
			var damage: int = int(max(0, (offense_stat + (wpn.might if wpn else 0) + atk_wpn_rune_might + tri_dmg) - actual_defense))
			
			# If staggering/staggered, guarantee at least 20% chip damage bypassing remaining armor
			if will_stagger or already_staggered:
				var chip_damage = int(float(raw_power) * 0.2)
				if damage < chip_damage: 
					damage = chip_damage
			# ==========================================
			
				
			
			# --- ADD QTE DAMAGE BOOSTS ---
			damage += deadeye_bonus_damage + rain_primary_bonus_damage + charge_bonus_damage 
			damage += fireball_bonus_damage + meteor_storm_bonus_damage + battle_cry_bonus_damage + blade_tempest_bonus_damage
			damage += chakra_bonus_damage + chi_burst_bonus_damage + frenzy_bonus_damage
			damage += smite_bonus_damage + sacred_judgment_bonus_damage + flame_blade_bonus_damage + elemental_convergence_bonus_damage
			damage += shadow_strike_bonus_damage + shadow_step_bonus_damage + power_strike_bonus_damage + earthshatter_bonus_damage
			damage += shadow_pin_bonus_damage + savage_toss_bonus_damage + vanguards_rally_bonus_damage
			damage += atk_rel["dmg_bonus"]
			var crit_chance: int = int(clamp((attacker.agility / 2) + assassinate_crit_bonus + atk_rel["crit_bonus"] - def_sup["crit_avo"] + rookie_crit, 0, 100))
			damage += hellfire_bonus_damage + ballista_shot_bonus_damage + aegis_strike_bonus_damage
			damage += rookie_dmg
			damage += UnitCombatStatusHelpers.resolve_combat_might_bonus(attacker)

			# Physical subtype + magic damage kind multipliers (must match forecast).
			if wpn != null:
				damage = field.apply_outgoing_weapon_damage_multipliers(int(damage), defender, wpn)

			var is_crit: bool = force_crit or (randi() % 100 < crit_chance)
			var attack_hits: bool = force_hit or (randi() % 100 < hit_chance)
			if not rookie_log.is_empty():
				field.add_combat_log(attacker.unit_name + ": " + rookie_log, "lightblue")
			# ==========================================
			# PHASE C: ATTACK LUNGE OR SHOOT
			# ==========================================
			var orig_pos: Vector2 = attacker.global_position
			# Grid-dominant direction keeps melee read cardinals (avoids diagonal lunge_dir from mixed origins / float tiles).
			var raw_lunge: Vector2 = defender.global_position - attacker.global_position
			var cell_delta: Vector2i = field.get_grid_pos(defender) - field.get_grid_pos(attacker)
			var lunge_dir: Vector2
			if cell_delta == Vector2i.ZERO:
				lunge_dir = Vector2.RIGHT if raw_lunge.length_squared() < 0.0001 else raw_lunge.normalized()
			elif absi(cell_delta.x) >= absi(cell_delta.y):
				lunge_dir = Vector2(signf(float(cell_delta.x)), 0.0) if cell_delta.x != 0 else Vector2(0.0, signf(float(cell_delta.y)))
			else:
				lunge_dir = Vector2(0.0, signf(float(cell_delta.y))) if cell_delta.y != 0 else Vector2(signf(float(cell_delta.x)), 0.0)
			var did_melee_crit_animation: bool = false
			var did_melee_normal_animation: bool = false
			var used_ranged_projectile: bool = false
	
			if wpn != null and wpn.get("is_instant_cast") == true:
				# --- INSTANT CAST (BEAM / PILLAR) ---
				var recoil_tween: Tween = field.create_tween()
				recoil_tween.tween_property(attacker, "global_position", orig_pos - (lunge_dir * 4.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				await recoil_tween.finished
				
				if wpn.get("impact_scene") != null and wpn.impact_scene != null:
					var impact: Node2D = wpn.impact_scene.instantiate()
					field.add_child(impact)
					impact.z_index = 115
					impact.global_position = defender.global_position + Vector2(32, 32)
					var p_scale: float = float(wpn.get("projectile_scale")) if wpn.get("projectile_scale") != null else 2.0
					impact.scale = Vector2(p_scale, p_scale)
					
				await field.get_tree().create_timer(0.3).timeout
				
			elif wpn != null and wpn.get("projectile_scene") != null:
				# --- RANGED PROJECTILE ---
				used_ranged_projectile = true
				var recoil_tween: Tween = field.create_tween()
				recoil_tween.tween_property(attacker, "global_position", orig_pos - (lunge_dir * 9.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				await recoil_tween.finished
				await field.get_tree().create_timer(0.025).timeout
				
				var proj: Node2D = wpn.projectile_scene.instantiate()
				field.add_child(proj)
				proj.z_index = 110
				if field.attack_sound != null and field.attack_sound.stream != null:
					var old_launch_volume: float = field.attack_sound.volume_db
					field.attack_sound.volume_db = -5.0
					field.play_attack_hit_sound(field.attack_sound, 1.16)
					field.attack_sound.volume_db = old_launch_volume
				
				var p_scale: float = float(wpn.get("projectile_scale")) if wpn.get("projectile_scale") != null else 2.0
				proj.scale = Vector2(p_scale, p_scale)
				
				var proj_start: Vector2 = attacker.global_position + Vector2(32, 32)
				proj.global_position = proj_start
				proj.rotation = lunge_dir.angle()
				var projectile_target: Vector2 = _compute_projectile_target_point(defender, lunge_dir, attack_hits)
				
				var distance: float = proj_start.distance_to(projectile_target)
				var travel_time: float = clampf(distance / 920.0, 0.09, 0.32)
				var travel_mid: Vector2 = proj_start.lerp(projectile_target, 0.68)
				var arc_height: float = clampf(distance * 0.06, 8.0, 26.0)
				travel_mid.y -= arc_height
				if is_magic:
					travel_mid.y -= 8.0
				var spin_turns: float = 0.0
				if wpn.get("projectile_spin_turns") != null:
					spin_turns = float(wpn.get("projectile_spin_turns"))
				elif not is_magic:
					spin_turns = clampf(distance / 180.0, 0.35, 1.20)
				
				var fly_tween: Tween = field.create_tween()
				fly_tween.tween_property(proj, "global_position", travel_mid, travel_time * 0.60).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				fly_tween.tween_property(proj, "global_position", projectile_target, travel_time * 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				if absf(spin_turns) > 0.001:
					fly_tween.parallel().tween_property(proj, "rotation", proj.rotation + (TAU * spin_turns), travel_time)
				await fly_tween.finished
				
				if wpn.get("impact_scene") != null and wpn.impact_scene != null and attack_hits:
					var impact: Node2D = wpn.impact_scene.instantiate()
					field.add_child(impact)
					impact.z_index = 115
					impact.global_position = projectile_target
					impact.scale = Vector2(p_scale * 1.2, p_scale * 1.2)
				elif not attack_hits:
					field.screen_shake(2.2, 0.05)
				
				if is_instance_valid(proj) and not proj.is_queued_for_deletion():
					proj.queue_free()
				if is_instance_valid(attacker):
					var ranged_return_tween: Tween = field.create_tween()
					ranged_return_tween.tween_property(attacker, "global_position", orig_pos, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					await ranged_return_tween.finished
				
			else:
				# --- MELEE ATTACK ---
				var melee_phys: int = int(WeaponData.PhysicalSubtype.SLASHING)
				if wpn != null:
					if not is_magic:
						melee_phys = field.resolve_physical_subtype(wpn)
					elif WeaponData.get_weapon_family(int(wpn.weapon_type)) == WeaponData.WeaponType.LANCE:
						melee_phys = field.resolve_physical_subtype(wpn)
				if is_crit and attack_hits:
					did_melee_crit_animation = true
					match melee_phys:
						int(WeaponData.PhysicalSubtype.PIERCING):
							await field._run_melee_crit_lunge_piercing(attacker, defender, orig_pos, lunge_dir)
						int(WeaponData.PhysicalSubtype.BLUDGEONING):
							await field._run_melee_crit_lunge_bludgeoning(attacker, defender, orig_pos, lunge_dir)
						_:
							await field._run_melee_crit_lunge(attacker, defender, orig_pos, lunge_dir)
				else:
					did_melee_normal_animation = true
					match melee_phys:
						int(WeaponData.PhysicalSubtype.PIERCING):
							await field._run_melee_normal_lunge_piercing(attacker, defender, orig_pos, lunge_dir)
						int(WeaponData.PhysicalSubtype.BLUDGEONING):
							await field._run_melee_normal_lunge_bludgeoning(attacker, defender, orig_pos, lunge_dir)
						_:
							await field._run_melee_normal_lunge(attacker, defender, orig_pos, lunge_dir)
			
			# ==========================================
			# PHASE D: DEFENSIVE ABILITIES & PARRY
			# ==========================================
			var defense_resolved_and_won: bool = false
			var phase_d := await DefensiveAbilityFlowHelpers.resolve_phase_d_defensive_abilities(
				field,
				attacker,
				defender,
				attack_hits,
				wpn,
				incoming_damage_multiplier,
				defense_resolved_and_won,
				field.ability_triggers_count,
				_weapon_shatter_triggered,
				celestial_choir_hits
			)
			incoming_damage_multiplier = phase_d.get("incoming_damage_multiplier", incoming_damage_multiplier)
			defense_resolved_and_won = phase_d.get("defense_resolved_and_won", defense_resolved_and_won)
			field.ability_triggers_count = phase_d.get("ability_triggers_count", field.ability_triggers_count)
			_weapon_shatter_triggered = phase_d.get("weapon_shatter_triggered", _weapon_shatter_triggered)
			celestial_choir_hits = phase_d.get("celestial_choir_hits", celestial_choir_hits)
			
			# ==========================================
			# PHASE E: NORMAL ATTACK RESOLUTION
			# ==========================================
			var phase_e_ctx := {
				"attacker": attacker,
				"defender": defender,
				"wpn": wpn,
				"incoming_damage_multiplier": incoming_damage_multiplier,
				"damage": damage,
				"defense_resolved_and_won": defense_resolved_and_won,
				"attack_hits": attack_hits,
				"is_crit": is_crit,
				"is_magic": is_magic,
				"already_staggered": already_staggered,
				"will_stagger": will_stagger,
				"did_melee_normal_animation": did_melee_normal_animation,
				"did_melee_crit_animation": did_melee_crit_animation,
				"used_ranged_projectile": used_ranged_projectile,
				"def_current_poise": def_current_poise,
				"poise_dmg": poise_dmg,
				"def_max_poise": def_max_poise,
				"combo_hits": combo_hits,
				"hellfire_result": hellfire_result,
				"lunge_dir": lunge_dir,
				"atk_rel": atk_rel,
				"ability_triggers_count": field.ability_triggers_count,
				"loot_recipient": field.loot_recipient,
				"severing_strike_hits": severing_strike_hits,
				"severing_strike_damage_multiplier": severing_strike_damage_multiplier,
				"force_crit": force_crit,
				"parting_shot_dodge": parting_shot_dodge,
				"shadow_pin_speed_lock": shadow_pin_speed_lock,
				"vanguards_rally_might_bonus": vanguards_rally_might_bonus,
				"savage_toss_distance": savage_toss_distance,
				"lifesteal_percent": lifesteal_percent,
				"volley_extra_hits": volley_extra_hits,
				"volley_spread_target": volley_spread_target,
				"volley_damage_multiplier": volley_damage_multiplier,
				"rain_splash_targets": rain_splash_targets,
				"rain_splash_damage": rain_splash_damage,
				"rain_tail_unit": rain_tail_unit,
				"rain_rear_extra_damage": rain_rear_extra_damage,
				"fireball_splash_targets": fireball_splash_targets,
				"fireball_splash_damage": fireball_splash_damage,
				"fireball_tail_unit": fireball_tail_unit,
				"fireball_tail_extra_damage": fireball_tail_extra_damage,
				"meteor_storm_splash_targets": meteor_storm_splash_targets,
				"meteor_storm_splash_damage": meteor_storm_splash_damage,
				"meteor_tail_unit": meteor_tail_unit,
				"meteor_tail_extra_damage": meteor_tail_extra_damage,
				"flurry_strike_hits": flurry_strike_hits,
				"flurry_strike_damage_multiplier": flurry_strike_damage_multiplier,
				"blade_tempest_splash_targets": blade_tempest_splash_targets,
				"blade_tempest_splash_damage": blade_tempest_splash_damage,
				"chi_burst_splash_targets": chi_burst_splash_targets,
				"chi_burst_splash_damage": chi_burst_splash_damage,
				"smite_splash_targets": smite_splash_targets,
				"smite_splash_damage": smite_splash_damage,
				"sacred_judgment_splash_targets": sacred_judgment_splash_targets,
				"sacred_judgment_splash_damage": sacred_judgment_splash_damage,
				"elemental_convergence_splash_targets": elemental_convergence_splash_targets,
				"elemental_convergence_splash_damage": elemental_convergence_splash_damage,
				"charge_collision_target": charge_collision_target,
				"charge_collision_damage": charge_collision_damage,
				"ballista_shot_pierce_targets": ballista_shot_pierce_targets,
				"ballista_shot_pierce_damage": ballista_shot_pierce_damage,
				"earthshatter_splash_targets": earthshatter_splash_targets,
				"earthshatter_splash_damage": earthshatter_splash_damage,
			}
			phase_e_ctx = await AttackResolutionHelpers.resolve_phase_e_normal_attack(field, phase_e_ctx)
			incoming_damage_multiplier = phase_e_ctx.get("incoming_damage_multiplier", incoming_damage_multiplier)
			damage = phase_e_ctx.get("damage", damage)
			field.ability_triggers_count = phase_e_ctx.get("ability_triggers_count", field.ability_triggers_count)
			field.loot_recipient = phase_e_ctx.get("loot_recipient", field.loot_recipient)
			
			# ==========================================
			# PHASE F: DURABILITY & RETURN
			# ==========================================
			await PostStrikeCleanupHelpers.process_phase_f_durability_and_return(
				field,
				attacker,
				wpn,
				did_melee_normal_animation,
				orig_pos
			)
	
			# ==========================================
			# PHASE G: FORCED MOVEMENT (SHOVE & PULL) + FIRE TRAP
			# ==========================================
			await ForcedMovementTacticalHelpers.process_phase_g_forced_movement_and_fire_trap(
				field,
				attacker,
				defender,
				force_active_ability,
				attack_hits,
				field.attack_sound
			)
			
		# ==========================================
		# PHASE H: COMBAT CLEANUP
		# ==========================================
		CombatCleanupHelpers.process_phase_h_combat_cleanup(field, attacker, defender)
									
