extends RefCounted

const CoopRuntimeSyncHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopRuntimeSyncHelpers.gd")

# Extracted orchestration pipeline from `BattleField.gd:execute_combat()`.
# This helper intentionally delegates back into `field` for internal methods,
# constants, and state to preserve gameplay behavior and await sequencing.


static func execute_combat(
	field,
	attacker: Node2D,
	defender: Node2D,
	trigger_active_ability: bool = false
) -> void:
	# --- SAFETY CHECKS ---
	if not field._is_valid_combat_unit(attacker):
		push_warning("execute_combat aborted: attacker is not a valid combat unit.")
		return

	if not field._is_valid_combat_unit(defender):
		push_warning("execute_combat aborted: defender is not a valid combat unit.")
		return

	var wpn = attacker.equipped_weapon
	if wpn == null:
		push_warning("execute_combat aborted: attacker has no equipped weapon.")
		return

	field._coop_qte_tick_reset_for_execute_combat()

	var is_staff: bool = wpn != null and (
		wpn.get("is_healing_staff") == true
		or wpn.get("is_buff_staff") == true
		or wpn.get("is_debuff_staff") == true
	)

	# ==========================================
	# --- FIRST COMBAT / BOSS QUOTES ---
	# ==========================================
	if not is_staff:
		# 1. Did the Player attack a Boss/Recruitable Enemy?
		if defender.get_parent() == field.enemy_container and not defender.has_meta("has_spoken_quote"):
			if defender.get("data") != null and "pre_battle_quote" in defender.data and defender.data.pre_battle_quote.size() > 0:
				defender.set_meta("has_spoken_quote", true)
				var port = defender.data.portrait
				await field.play_cinematic_dialogue(defender.unit_name, port, defender.data.pre_battle_quote)

		# 2. Did the Boss/Recruitable Enemy attack the Player first?
		elif attacker.get_parent() == field.enemy_container and not attacker.has_meta("has_spoken_quote"):
			if attacker.get("data") != null and "pre_battle_quote" in attacker.data and attacker.data.pre_battle_quote.size() > 0:
				attacker.set_meta("has_spoken_quote", true)
				var port = attacker.data.portrait
				await field.play_cinematic_dialogue(attacker.unit_name, port, attacker.data.pre_battle_quote)

		# 3. Boss Personal Dialogue (V1): special pre-attack line when playable attacks supported boss pair (once per battle).
		if defender.get_parent() == field.enemy_container and (
			attacker.get_parent() == field.player_container
			or (field.ally_container != null and attacker.get_parent() == field.ally_container)
		):
			var boss_id: String = field._get_boss_dialogue_id(defender)
			var unit_id: String = field._get_playable_dialogue_id(attacker)
			var play_key: String = boss_id + "|" + unit_id
			if not boss_id.is_empty() and not unit_id.is_empty() and not field._boss_personal_dialogue_played.get(play_key, false):
				var line: String = field._get_boss_personal_line(boss_id, unit_id, "pre_attack")
				if not line.is_empty():
					field._boss_personal_dialogue_played[play_key] = true
					field.add_combat_log(defender.unit_name + ": " + line, "gold")
					var snippet: String = line.substr(0, 24) + ("…" if line.length() > 24 else "")
					field.spawn_loot_text(snippet, Color(1.0, 0.9, 0.5), defender.global_position + Vector2(32, -36))

	# --- SET THE COOLDOWN IF TRIGGERED ---
	if trigger_active_ability:
		attacker.set_meta("ability_cooldown", 3)

	field._support_dual_strike_done_this_attack = false

	# --- PHASE 1: THE INITIATOR ATTACKS ---
	await field._run_strike_sequence(attacker, defender, trigger_active_ability)

	# --- Phase 2: DUAL STRIKE (support partner bonus strike; one per attack exchange; no chain) ---
	if (
		not is_staff
		and not field._support_dual_strike_done_this_attack
		and is_instance_valid(defender)
		and field._is_valid_combat_unit(defender)
		and defender.current_hp > 0
		and is_instance_valid(attacker)
		and field._is_valid_combat_unit(attacker)
		and attacker.current_hp > 0
	):
		var ctx: Dictionary = field.get_best_support_context(attacker)
		var partner: Node2D = ctx.get("partner", null) as Node2D
		var rank: int = int(ctx.get("rank", 0))
		if partner != null and rank >= 2 and ctx.get("can_react", false):
			var dual_chance: int = field.SUPPORT_DUAL_STRIKE_CHANCE_RANK3 if rank >= 3 else field.SUPPORT_DUAL_STRIKE_CHANCE_RANK2
			dual_chance += field.get_relationship_combat_modifiers(attacker).get("support_chance_bonus", 0)
			if randi() % 100 < dual_chance:
				field._support_dual_strike_done_this_attack = true
				if field.DEBUG_SUPPORT_COMBAT:
					print("[SupportReaction] Dual Strike! ", partner.get("unit_name"), " -> bonus strike on ", defender.get("unit_name"))
				field.add_combat_log("Dual Strike!", "cyan")
				field.spawn_loot_text("Dual Strike!", Color(0.4, 0.9, 1.0), defender.global_position + Vector2(32, -28))
				field._award_relationship_event(attacker, partner, "dual_strike", 1)
				await field.get_tree().create_timer(0.2, true, false, true).timeout
				# Re-validate before executing: do not run if partner or defender became invalid (e.g. death cleanup).
				if is_instance_valid(partner) and partner.current_hp > 0 and is_instance_valid(defender) and field._is_valid_combat_unit(defender):
					await field._run_strike_sequence(partner, defender, false, true)

	# --- PHASE 2: THE DEFENDER RETALIATES ---
	if (
		not is_staff
		and is_instance_valid(defender)
		and field._is_valid_combat_unit(defender)
		and defender.current_hp > 0
		and is_instance_valid(attacker)
		and field._is_valid_combat_unit(attacker)
		and attacker.current_hp > 0
	):

		# --- STAGGER CHECK ---
		if defender.get_meta("is_staggered_this_combat", false) == true:
			await field.get_tree().create_timer(0.6).timeout
			field.add_combat_log(defender.unit_name + "'s guard was broken! Cannot counter-attack!", "orange")
			field.spawn_loot_text("STAGGERED!", Color(1.0, 0.4, 0.0), defender.global_position + Vector2(32, -32))
		else:
			var def_wpn = defender.equipped_weapon
			var defender_is_staff: bool = def_wpn != null and (
				def_wpn.get("is_healing_staff") == true
				or def_wpn.get("is_buff_staff") == true
				or def_wpn.get("is_debuff_staff") == true
			)

			# Only retaliate if the defender is holding a real weapon
			if def_wpn != null and not defender_is_staff and field.is_in_range(defender, attacker):
				await field.get_tree().create_timer(0.5).timeout
				field.add_combat_log(defender.unit_name + " retaliates", "orange")
				await field._run_strike_sequence(defender, attacker, false)

