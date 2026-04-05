extends RefCounted

const UnitCombatStatusHelpers = preload("res://Scripts/Core/UnitCombatStatusHelpers.gd")

# Phase 2 support / relationship combat helpers extracted from `BattleField.gd`.

static func normalize_support_rank(field, bond: Variant) -> int:
	if bond == null or not (bond is Dictionary):
		return 0
	var r: Variant = bond.get("rank", null)
	if r == null:
		return 0
	if r is int:
		return clampi(int(r), 0, 3)
	if r is String:
		var s := (r as String).strip_edges().to_upper()
		if s == "C": return 1
		if s == "B": return 2
		if s == "A": return 3
		return 0
	return 0


static func get_support_combat_bonus(field, unit: Node2D) -> Dictionary:
	var out := {"hit": 0, "avo": 0, "crit_avo": 0}
	if unit == null or unit.get_parent() == field.destructibles_container:
		return out

	# `field` is intentionally untyped here, so we must explicitly type `is_allied`
	# to keep GDScript static analysis happy.
	var is_allied: bool = (unit.get_parent() == field.player_container or (field.ally_container != null and unit.get_parent() == field.ally_container))
	if not is_allied:
		return out

	var my_pos: Vector2i = field.get_grid_pos(unit)
	var my_name: String = field.get_support_name(unit)
	var best_rank: int = 0
	var allies: Array[Node2D] = []

	var collect := func(container: Node) -> void:
		if container == null:
			return
		for c in container.get_children():
			if not (c is Node2D) or c == unit:
				continue
			if not is_instance_valid(c) or c.is_queued_for_deletion():
				continue
			if c.get("current_hp") != null and int(c.current_hp) <= 0:
				continue
			allies.append(c)

	collect.call(field.player_container)
	if field.ally_container:
		collect.call(field.ally_container)

	for ally in allies:
		var dist: int = abs(field.get_grid_pos(ally).x - my_pos.x) + abs(field.get_grid_pos(ally).y - my_pos.y)
		if dist > field.SUPPORT_COMBAT_RANGE_MANHATTAN:
			continue
		var bond: Dictionary = CampaignManager.get_support_bond(my_name, field.get_support_name(ally))
		var rank: int = normalize_support_rank(field, bond)
		if rank > best_rank:
			best_rank = rank

	if best_rank <= 0 or not field.SUPPORT_COMBAT_RANK_BONUSES.has(best_rank):
		return out

	out = field.SUPPORT_COMBAT_RANK_BONUSES[best_rank].duplicate()
	if field.DEBUG_SUPPORT_COMBAT and unit.get("unit_name") != null:
		print("[SupportCombat] ", unit.unit_name, " rank ", best_rank, " -> +", out["hit"], " hit +", out["avo"], " avo +", out["crit_avo"], " c.avo")
	return out


static func apply_hit_with_support_reactions(field, victim: Node2D, damage: int, source: Node2D, exp_tgt: Node2D, is_redirected: bool) -> void:
	if victim == null or not is_instance_valid(victim):
		return

	# Rivalry: record ally damager of this enemy (for contested-kill rivalry later).
	if victim.get_parent() == field.enemy_container and source != null and is_instance_valid(source):
		var src_parent: Node = source.get_parent()
		if src_parent == field.player_container or (field.ally_container != null and src_parent == field.ally_container):
			var eid: int = victim.get_instance_id()
			if not field._enemy_damagers.has(eid):
				field._enemy_damagers[eid] = []
			var rid: String = field.get_relationship_id(source)
			if rid != "" and rid not in field._enemy_damagers[eid]:
				field._enemy_damagers[eid].append(rid)

	if is_redirected:
		victim.take_damage(damage, source)
		return

	# Guard: one redirect per sequence; rank >= 2; redirect this hit to partner (partner cannot be victim).
	if not field._support_guard_used_this_sequence:
		var ctx: Dictionary = field.get_best_support_context(victim)
		var partner: Node2D = ctx.get("partner", null) as Node2D
		var rank: int = int(ctx.get("rank", 0))
		if partner != null and partner != victim and rank >= 2 and ctx.get("can_react", false):
			var guard_chance: int = field.SUPPORT_GUARD_CHANCE_RANK3 if rank >= 3 else field.SUPPORT_GUARD_CHANCE_RANK2
			guard_chance += field.get_relationship_combat_modifiers(victim).get("support_chance_bonus", 0)
			if randi() % 100 < guard_chance:
				field._support_guard_used_this_sequence = true
				if field.DEBUG_SUPPORT_COMBAT:
					print("[SupportReaction] Guard! ", victim.get("unit_name"), " -> partner takes hit")
				var guard_log: String = "Guard!"
				if field.get_relationship_combat_modifiers(victim).get("support_chance_bonus", 0) > 0 and victim.get("unit_name") != null and partner.get("unit_name") != null:
					guard_log = str(partner.unit_name) + " guarded " + str(victim.unit_name) + " out of trust."
				field.add_combat_log(guard_log, "lime")
				field.spawn_loot_text("Guard!", Color(0.2, 1.0, 0.4), partner.global_position + Vector2(32, -24))
				field._award_relationship_event(partner, victim, "guard", 1)
				if field._can_gain_mentorship(partner, victim):
					field._award_relationship_stat_event(partner, victim, "mentorship", "guard_mentorship", 1)
				# Fire-and-forget recursive application to match existing behavior.
				apply_hit_with_support_reactions(field, partner, damage, source, null, true)
				return

	# Defy Death: rank 3 only; lethal hit; once per unit per battle; Guard did not fire.
	var victim_instance_id: int = victim.get_instance_id()
	var would_be_lethal: bool = (victim.get("current_hp") != null and (int(victim.current_hp) - damage <= 0))
	if would_be_lethal:
		var ctx: Dictionary = field.get_best_support_context(victim)
		var partner: Node2D = ctx.get("partner", null) as Node2D
		var rank: int = int(ctx.get("rank", 0))
		if rank >= 3 and partner != null and not field._defy_death_used.get(victim_instance_id, false):
			field._defy_death_used[victim_instance_id] = true
			var capped: int = int(victim.current_hp) - 1
			if capped < 0:
				capped = 0
			if field.DEBUG_SUPPORT_COMBAT:
				print("[SupportReaction] Defy Death! ", victim.get("unit_name"), " saved at 1 HP")

			var victim_name: String = field.get_support_name(victim)
			var rescue_line: String = field._get_defy_death_rescue_line(partner, victim_name)
			var savior_name: String = partner.get("unit_name") if partner.get("unit_name") != null else "Ally"
			await field._show_defy_death_savior_portrait(partner, savior_name, rescue_line)
			field.add_combat_log(savior_name + ": " + rescue_line, "gold")
			field.spawn_loot_text("Defied Death!", Color(1.0, 0.84, 0.0), victim.global_position + Vector2(32, -32))
			if victim.get("is_custom_avatar") == true and victim.get("combat_statuses") != null:
				UnitCombatStatusHelpers.add_status(victim, UnitCombatStatusHelpers.ID_RESOLVE, {})
			victim.take_damage(capped, source)
			return

	victim.take_damage(damage, exp_tgt)
