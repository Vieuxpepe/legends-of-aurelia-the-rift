extends RefCounted

static func process_phase_h_combat_cleanup(field, attacker: Node2D, defender: Node2D) -> void:
	for unit in [attacker, defender]:
		if unit == null or not is_instance_valid(unit):
			continue

		if unit.has_meta("inner_peace_avo_bonus_temp"): unit.remove_meta("inner_peace_avo_bonus_temp")
		if unit.has_meta("inner_peace_res_bonus_temp"): unit.remove_meta("inner_peace_res_bonus_temp")
		if unit.has_meta("inner_peace_def_bonus_temp"): unit.remove_meta("inner_peace_def_bonus_temp")
		if unit.has_meta("frenzy_def_penalty_temp"): unit.remove_meta("frenzy_def_penalty_temp")
		if unit.has_meta("frenzy_res_penalty_temp"): unit.remove_meta("frenzy_res_penalty_temp")
		if unit.has_meta("holy_ward_res_bonus_temp"): unit.remove_meta("holy_ward_res_bonus_temp")

