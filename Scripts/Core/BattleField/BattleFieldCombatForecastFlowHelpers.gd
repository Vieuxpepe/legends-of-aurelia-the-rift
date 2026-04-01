extends RefCounted

# Forecast flow: value assembly, panel population, target cursor, await `forecast_resolved`.
# Panel micro-widgets / bar styling live in `BattleFieldCombatForecastHelpers.gd`.

const ForecastUI = preload("res://Scripts/Core/BattleField/BattleFieldCombatForecastHelpers.gd")


## Matches `BattleFieldCombatOrchestrationHelpers.execute_combat` / strike staff gate (heal, buff, debuff).
static func is_utility_staff_weapon(wpn: Resource) -> bool:
	if wpn == null:
		return false
	return (
		wpn.get("is_healing_staff") == true
		or wpn.get("is_buff_staff") == true
		or wpn.get("is_debuff_staff") == true
	)


static func get_forecast_support_text(field, unit: Node2D) -> String:
	if unit == null:
		return ""
	var sup: Dictionary = field.get_support_combat_bonus(unit)
	var h: int = int(sup.get("hit", 0))
	var a: int = int(sup.get("avo", 0))
	var c: int = int(sup.get("crit_avo", 0))
	if h <= 0 and a <= 0 and c <= 0:
		return "SUPPORT: --"
	var parts: PackedStringArray = []
	if h > 0: parts.append("+%d HIT" % h)
	if a > 0: parts.append("+%d AVO" % a)
	if c > 0: parts.append("+%d C.AVO" % c)
	return "SUPPORT: " + "  |  ".join(parts)


static func is_forecast_allied_unit(field, unit: Node2D) -> bool:
	if unit == null:
		return false
	return unit.get_parent() == field.player_container or (field.ally_container != null and unit.get_parent() == field.ally_container)


## Lines for support reactions + burn hints; mirrors execute_combat / _apply_hit_with_support_reactions / Dual Strike gates (no balance changes).
static func build_forecast_reaction_summary(field, attacker: Node2D, defender: Node2D, atk_wpn: Resource) -> String:
	var lines: Array[String] = []
	if attacker == null or defender == null:
		return ""

	if is_utility_staff_weapon(atk_wpn):
		lines.append("Staff: Guard / Dual Strike / Defy Death do not apply to this exchange.")
		return "\n".join(lines)

	# Dual Strike: allied attacker only; same gates as execute_combat (non-staff).
	if is_forecast_allied_unit(field, attacker):
		var actx: Dictionary = field.get_best_support_context(attacker)
		var apart: Node2D = actx.get("partner", null) as Node2D
		var arank: int = int(actx.get("rank", 0))
		if apart != null and arank >= 2 and bool(actx.get("can_react", false)):
			var dual_pct: int = field.SUPPORT_DUAL_STRIKE_CHANCE_RANK3 if arank >= 3 else field.SUPPORT_DUAL_STRIKE_CHANCE_RANK2
			dual_pct += int(field.get_relationship_combat_modifiers(attacker).get("support_chance_bonus", 0))
			lines.append("Dual Strike chance (partner bonus hit after yours): ~%d%%" % clampi(dual_pct, 0, 100))

	# Guard & Defy Death: allied defender only; matches get_best_support_context + _apply_hit_with_support_reactions.
	if is_forecast_allied_unit(field, defender):
		var dctx: Dictionary = field.get_best_support_context(defender)
		var dpartner: Node2D = dctx.get("partner", null) as Node2D
		var drank: int = int(dctx.get("rank", 0))
		var dcan: bool = bool(dctx.get("can_react", false))
		if dpartner != null and drank >= 2 and dcan:
			var guard_pct: int = field.SUPPORT_GUARD_CHANCE_RANK3 if drank >= 3 else field.SUPPORT_GUARD_CHANCE_RANK2
			guard_pct += int(field.get_relationship_combat_modifiers(defender).get("support_chance_bonus", 0))
			lines.append("Guard chance (partner takes this hit): ~%d%%" % clampi(guard_pct, 0, 100))
		if dpartner != null and drank >= 3 and dcan:
			if bool(field._defy_death_used.get(defender.get_instance_id(), false)):
				lines.append("Defy Death: already used this battle for this unit.")
			else:
				lines.append("Defy Death: if a hit here would kill, survive at 1 HP once (A-rank bond).")

	if defender.has_meta("is_burning") and defender.get_meta("is_burning") == true:
		lines.append("Target is burning (fire damage after each enemy phase).")

	if field._attacker_has_attack_skill(attacker, "Hellfire"):
		lines.append("Hellfire: strong minigame can ignite (burn DoT after enemy phase).")

	if field._attacker_has_attack_skill(attacker, "Ballista Shot"):
		lines.append("Ballista Shot: on proc, bolt can overpenetrate â€” spill damage to a foe in the tile behind this target (same line).")

	if field._attacker_has_attack_skill(attacker, "Charge"):
		lines.append("Charge: on proc, if another enemy stands behind this target in your line, they take collision damage and your impact is stronger.")

	if field._attacker_has_attack_skill(attacker, "Fireball"):
		lines.append("Fireball: on proc, flames wash down the line â€” extra burn on a foe in the tile behind the target.")

	if field._attacker_has_attack_skill(attacker, "Meteor Storm"):
		lines.append("Meteor Storm: on proc, a fragment may streak into a foe behind the target (same line) for extra splash damage.")

	if field._attacker_has_attack_skill(attacker, "Deadeye Shot"):
		lines.append("Deadeye Shot: at range 3+, a successful proc gains extra precision damage.")

	if field._attacker_has_attack_skill(attacker, "Smite"):
		lines.append("Smite: on proc, holy energy can splash to up to two foes orthogonally adjacent to the target.")

	if field._attacker_has_attack_skill(attacker, "Volley"):
		lines.append("Volley: on a perfect proc, the second follow-up arrow can strike a different foe adjacent to the target.")

	if field._attacker_has_attack_skill(attacker, "Rain of Arrows"):
		lines.append("Rain of Arrows: rear-rank pressure â€” extra damage to a foe in the tile behind the target (same line); non-perfect splash favors that foe when you must pick one.")

	if lines.is_empty():
		return ""
	return "\n".join(lines)


static func ensure_forecast_support_labels(field) -> void:
	if field.forecast_panel == null:
		return

	if field.forecast_atk_support_label == null:
		field.forecast_atk_support_label = Label.new()
		field.forecast_atk_support_label.name = "AtkSupportBonus"
		field.forecast_atk_support_label.position = Vector2(24, 190)
		field.forecast_atk_support_label.size = Vector2(190, 22)
		field.forecast_atk_support_label.add_theme_font_size_override("font_size", 16)
		field.forecast_atk_support_label.add_theme_color_override("font_color", Color(0.60, 0.95, 1.0))
		field.forecast_panel.add_child(field.forecast_atk_support_label)

	if field.forecast_def_support_label == null:
		field.forecast_def_support_label = Label.new()
		field.forecast_def_support_label.name = "DefSupportBonus"
		field.forecast_def_support_label.position = Vector2(326, 190)
		field.forecast_def_support_label.size = Vector2(190, 22)
		field.forecast_def_support_label.add_theme_font_size_override("font_size", 16)
		field.forecast_def_support_label.add_theme_color_override("font_color", Color(0.60, 0.95, 1.0))
		field.forecast_panel.add_child(field.forecast_def_support_label)

	if field.forecast_instruction_label == null:
		field.forecast_instruction_label = Label.new()
		field.forecast_instruction_label.name = "ForecastInstruction"
		field.forecast_instruction_label.position = Vector2(24, 262)
		field.forecast_instruction_label.size = Vector2(492, 20)
		field.forecast_instruction_label.add_theme_font_size_override("font_size", 11)
		field.forecast_instruction_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9))
		field.forecast_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		field.forecast_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		field.forecast_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		field.forecast_panel.add_child(field.forecast_instruction_label)

	if field.forecast_reaction_label == null:
		field.forecast_reaction_label = Label.new()
		field.forecast_reaction_label.name = "ForecastReactionSummary"
		field.forecast_reaction_label.position = Vector2(24, 284)
		field.forecast_reaction_label.size = Vector2(492, 18)
		field.forecast_reaction_label.add_theme_font_size_override("font_size", 10)
		field.forecast_reaction_label.add_theme_color_override("font_color", Color(0.90, 0.84, 0.62))
		field.forecast_reaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		field.forecast_reaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		field.forecast_reaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		field.forecast_panel.add_child(field.forecast_reaction_label)

	# Keep bottom stack above Confirm/Cancel (~y 201+).
	if field.forecast_instruction_label != null:
		field.forecast_instruction_label.position = Vector2(24, 262)
		field.forecast_instruction_label.size = Vector2(492, 20)
	if field.forecast_reaction_label != null:
		field.forecast_reaction_label.position = Vector2(24, 284)
		field.forecast_reaction_label.size = Vector2(492, 18)


static func show_combat_forecast(field, attacker: Node2D, defender: Node2D) -> Array:
	if attacker == null or defender == null:
		return []

	if field.is_local_player_command_blocked_for_mock_coop_unit(attacker):
		return []

	if attacker.get("equipped_weapon") == null:
		return []

	# Defender can be forecasted even if unarmed, but must still be a combat unit
	if attacker.get("strength") == null or attacker.get("magic") == null:
		return []
	if defender.get("strength") == null or defender.get("magic") == null:
		return []

	var atk_wpn = attacker.equipped_weapon
	var def_wpn = defender.equipped_weapon

	# Adjacency check
	var atk_adj = field.get_adjacency_bonus(attacker)
	var def_adj = field.get_adjacency_bonus(defender)

	ensure_forecast_support_labels(field)
	if field.forecast_atk_support_label:
		field.forecast_atk_support_label.text = get_forecast_support_text(field, attacker)
	if field.forecast_def_support_label:
		field.forecast_def_support_label.text = get_forecast_support_text(field, defender)

	var atk_terrain = field.get_terrain_data(field.get_grid_pos(attacker))
	var def_terrain = field.get_terrain_data(field.get_grid_pos(defender))

	var atk_might = atk_wpn.might if atk_wpn else 0
	var atk_hit_bonus = atk_wpn.hit_bonus if atk_wpn else 0
	var def_might = def_wpn.might if def_wpn else 0
	var def_hit_bonus = def_wpn.hit_bonus if def_wpn else 0

	# --- THE BROKEN PENALTY ---
	if atk_wpn and atk_wpn.get("current_durability") != null and atk_wpn.current_durability <= 0:
		atk_might /= 2
		atk_hit_bonus /= 2

	if def_wpn and def_wpn.get("current_durability") != null and def_wpn.current_durability <= 0:
		def_might /= 2
		def_hit_bonus /= 2
	# -------------------------------

	var atk_is_magic = atk_wpn.damage_type == WeaponData.DamageType.MAGIC if atk_wpn else false
	var def_is_magic = def_wpn.damage_type == WeaponData.DamageType.MAGIC if def_wpn else false

	var atk_offense = attacker.magic if atk_is_magic else attacker.strength
	var def_offense = defender.magic if def_is_magic else defender.strength

	# Apply Defender's Adjacency to their Defense
	var atk_defense_target = defender.resistance if atk_is_magic else defender.defense
	if defender.get("is_defending") == true:
		atk_defense_target += defender.defense_bonus
	atk_defense_target += def_adj["def"]
	atk_defense_target += def_terrain["def"]

	# Apply Attacker's Adjacency to their Defense
	var def_defense_target = attacker.resistance if def_is_magic else attacker.defense
	def_defense_target += atk_adj["def"]
	def_defense_target += atk_terrain["def"]

	var advantage = field.get_triangle_advantage(attacker, defender)
	var atk_tri_dmg = advantage * 1
	var atk_tri_hit = advantage * 15
	var def_tri_dmg = (advantage * -1) * 1
	var def_tri_hit = (advantage * -1) * 15

	# Support-combat and relationship web (forecast must match resolution)
	var atk_sup: Dictionary = field.get_support_combat_bonus(attacker)
	var def_sup: Dictionary = field.get_support_combat_bonus(defender)
	var atk_rel: Dictionary = field.get_relationship_combat_modifiers(attacker)
	var def_rel: Dictionary = field.get_relationship_combat_modifiers(defender)
	var atk_dmg = max(0, (atk_offense + atk_might + atk_tri_dmg) - atk_defense_target) + atk_rel.get("dmg_bonus", 0)
	var def_dmg = max(0, (def_offense + def_might + def_tri_dmg) - def_defense_target) + def_rel.get("dmg_bonus", 0)
	var atk_hit: int = clamp(80 + atk_hit_bonus + atk_tri_hit + atk_adj["hit"] + atk_sup["hit"] - def_sup["avo"] + atk_rel["hit"] - def_rel["avo"] + (attacker.agility * 2) - (defender.speed * 2) - def_terrain["avo"], 0, 100)
	var atk_crit: int = clamp(attacker.agility / 2 + atk_rel["crit_bonus"] - def_sup["crit_avo"], 0, 100)
	var def_hit: int = clamp(80 + def_hit_bonus + def_tri_hit + def_adj["hit"] + def_sup["hit"] - atk_sup["avo"] + def_rel["hit"] - atk_rel["avo"] + (defender.agility * 2) - (attacker.speed * 2) - atk_terrain["avo"], 0, 100)
	var def_crit: int = clamp(defender.agility / 2 + def_rel["crit_bonus"] - atk_sup["crit_avo"], 0, 100)

	if atk_wpn == null or not is_utility_staff_weapon(atk_wpn):
		var fr_rookie: Dictionary = field._forecast_rookie_class_passive_mods(attacker, defender, atk_is_magic, atk_wpn)
		atk_hit = clampi(atk_hit + int(fr_rookie.get("hit", 0)), 0, 100)
		atk_dmg = max(0, atk_dmg + int(fr_rookie.get("dmg", 0)))
		atk_crit = clampi(atk_crit + int(fr_rookie.get("crit", 0)), 0, 100)

	# Physical subtype multipliers (forecast must match resolution)
	if not atk_is_magic and atk_wpn != null:
		var atk_subtype: int = field.resolve_physical_subtype(atk_wpn)
		atk_dmg = int(round(float(atk_dmg) * field.resolve_physical_subtype_multiplier(defender, atk_subtype)))
	if not def_is_magic and def_wpn != null:
		var def_subtype: int = field.resolve_physical_subtype(def_wpn)
		def_dmg = int(round(float(def_dmg) * field.resolve_physical_subtype_multiplier(attacker, def_subtype)))

	# UI Updates (columns: left = attacker / you, right = defender / target)
	field.forecast_atk_name.text = ForecastUI.format_forecast_name_fitted("ATK", attacker.unit_name, 17)
	field.forecast_atk_weapon.text = ForecastUI.format_forecast_weapon_name(atk_wpn, 14)
	field.forecast_atk_hp.text = "HP: %d / %d" % [attacker.current_hp, attacker.max_hp]

	field.forecast_def_name.text = ForecastUI.format_forecast_name_fitted("TARGET", defender.unit_name, 18)
	field.forecast_def_weapon.text = ForecastUI.format_forecast_weapon_name(def_wpn, 14)
	field.forecast_def_hp.text = "HP: %d / %d" % [defender.current_hp, defender.max_hp]
	var atk_weapon_badge := field.forecast_panel.get_node_or_null("AtkWeaponBadgePanel/Text") as Label
	if atk_weapon_badge != null:
		atk_weapon_badge.text = ForecastUI.forecast_weapon_marker(atk_wpn)
	var def_weapon_badge := field.forecast_panel.get_node_or_null("DefWeaponBadgePanel/Text") as Label
	if def_weapon_badge != null:
		def_weapon_badge.text = ForecastUI.forecast_weapon_marker(def_wpn)
	var atk_weapon_icon_panel := field.forecast_panel.get_node_or_null("AtkWeaponIconPanel") as Panel
	var atk_weapon_icon := field.forecast_panel.get_node_or_null("AtkWeaponIconPanel/Icon") as TextureRect
	var atk_weapon_glow := field.forecast_panel.get_node_or_null("AtkWeaponIconPanel/Glow") as Panel
	var atk_weapon_glow_color: Color = ForecastUI.forecast_weapon_rarity_glow_color(atk_wpn)
	if atk_weapon_icon_panel != null:
		atk_weapon_icon_panel.visible = atk_wpn != null and atk_wpn.icon != null
	if atk_weapon_icon != null:
		atk_weapon_icon.texture = atk_wpn.icon if atk_wpn != null else null
	if atk_weapon_glow != null:
		atk_weapon_glow.visible = atk_wpn != null and atk_wpn.icon != null and atk_weapon_glow_color.a > 0.0
		ForecastUI.style_forecast_weapon_glow(atk_weapon_glow, atk_weapon_glow_color)
	var def_weapon_icon_panel := field.forecast_panel.get_node_or_null("DefWeaponIconPanel") as Panel
	var def_weapon_icon := field.forecast_panel.get_node_or_null("DefWeaponIconPanel/Icon") as TextureRect
	var def_weapon_glow := field.forecast_panel.get_node_or_null("DefWeaponIconPanel/Glow") as Panel
	var def_weapon_glow_color: Color = ForecastUI.forecast_weapon_rarity_glow_color(def_wpn)
	if def_weapon_icon_panel != null:
		def_weapon_icon_panel.visible = def_wpn != null and def_wpn.icon != null
	if def_weapon_icon != null:
		def_weapon_icon.texture = def_wpn.icon if def_wpn != null else null
	if def_weapon_glow != null:
		def_weapon_glow.visible = def_wpn != null and def_wpn.icon != null and def_weapon_glow_color.a > 0.0
		ForecastUI.style_forecast_weapon_glow(def_weapon_glow, def_weapon_glow_color)
	ForecastUI.ensure_forecast_hp_bars(field)
	if field.forecast_atk_hp_bar != null:
		field.forecast_atk_hp_bar.max_value = float(max(1, int(attacker.max_hp)))
		field.forecast_atk_hp_bar.value = float(clampi(int(attacker.current_hp), 0, int(attacker.max_hp)))
		ForecastUI.style_forecast_hp_bar(field, field.forecast_atk_hp_bar, ForecastUI.forecast_hp_fill_color(int(attacker.current_hp), int(attacker.max_hp)))
	if field.forecast_def_hp_bar != null:
		field.forecast_def_hp_bar.max_value = float(max(1, int(defender.max_hp)))
		field.forecast_def_hp_bar.value = float(clampi(int(defender.current_hp), 0, int(defender.max_hp)))
		ForecastUI.style_forecast_hp_bar(field, field.forecast_def_hp_bar, ForecastUI.forecast_hp_fill_color(int(defender.current_hp), int(defender.max_hp)))

	# --- RESET UI MODULATES ---
	ForecastUI.reset_forecast_emphasis_visuals(field)

	# --- UTILITY STAFF (heal / buff / debuff) — same classification as execute_combat + strike PHASE A ---
	if is_utility_staff_weapon(atk_wpn):
		field.forecast_def_name.text = ForecastUI.format_forecast_name_fitted("TARGET", defender.unit_name, 18)
		if atk_wpn.get("is_healing_staff") == true:
			var heal_amount = attacker.magic + atk_wpn.might
			field.forecast_atk_dmg.text = "HEAL: " + str(heal_amount)
		elif atk_wpn.get("is_buff_staff") == true:
			var bstat: String = str(atk_wpn.get("affected_stat", "?"))
			var bamt: int = int(atk_wpn.get("effect_amount", 0))
			field.forecast_atk_dmg.text = "BUFF: " + bstat.to_upper() + " +" + str(bamt)
		elif atk_wpn.get("is_debuff_staff") == true:
			var dstat: String = str(atk_wpn.get("affected_stat", "?"))
			var damt: int = int(atk_wpn.get("effect_amount", 0))
			field.forecast_atk_dmg.text = "DEBUFF: " + dstat.to_upper() + " -" + str(damt)
		else:
			field.forecast_atk_dmg.text = "STAFF: --"

		field.forecast_atk_hit.text = "HIT: 100%"
		field.forecast_atk_crit.text = "CRIT: 0%"

		field.forecast_def_dmg.text = "DAMAGE: --"
		field.forecast_def_hit.text = ""
		field.forecast_def_crit.text = ""

		field.forecast_atk_adv.text = ""
		field.forecast_def_adv.text = ""
		field.forecast_atk_double.text = ""
		field.forecast_def_double.text = ""
	else:
		# Standard Attack UI
		field.forecast_atk_dmg.text = "DMG: " + str(atk_dmg)
		field.forecast_atk_hit.text = "HIT: " + str(atk_hit) + "%"
		field.forecast_atk_crit.text = "CRIT: " + str(atk_crit) + "%"

		var def_is_utility_staff: bool = is_utility_staff_weapon(def_wpn)
		if defender.get_parent() == field.enemy_container:
			field.forecast_def_name.text = ForecastUI.format_forecast_name_fitted("DEF", defender.unit_name, 17)
		else:
			field.forecast_def_name.text = ForecastUI.format_forecast_name_fitted("TARGET", defender.unit_name, 18)

		if def_wpn == null or def_is_utility_staff or not field.is_in_range(defender, attacker):
			field.forecast_def_dmg.text = "COUNTER: NONE"
			field.forecast_def_hit.text = ""
			field.forecast_def_crit.text = ""
			field.forecast_def_double.text = ""
		else:
			field.forecast_def_dmg.text = "COUNTER: " + str(def_dmg)
			field.forecast_def_hit.text = "HIT: " + str(def_hit) + "%"
			field.forecast_def_crit.text = "CRIT: " + str(def_crit) + "%"
			var def_doubles = (defender.speed - attacker.speed) >= 4
			field.forecast_def_double.text = "x2" if def_doubles else ""

		# Advantage Indicators
		if advantage == 1:
			field.forecast_atk_adv.text = "Adv."
			field.forecast_atk_adv.modulate = Color.CYAN
			field.forecast_def_adv.text = "Disadv."
			field.forecast_def_adv.modulate = Color.TOMATO
		elif advantage == -1:
			field.forecast_atk_adv.text = "Disadv."
			field.forecast_atk_adv.modulate = Color.TOMATO
			field.forecast_def_adv.text = "Adv."
			field.forecast_def_adv.modulate = Color.CYAN
		else:
			field.forecast_atk_adv.text = ""
			field.forecast_def_adv.text = ""

		# --- POISE BREAK WARNING ---
		var raw_power = atk_offense + atk_might
		var poise_dmg = raw_power
		if atk_wpn and atk_wpn.get("weapon_type") == WeaponData.WeaponType.AXE:
			poise_dmg = int(float(poise_dmg) * 1.5)

		var def_cur_poise = defender.get_current_poise() if defender.has_method("get_current_poise") else 999

		if def_cur_poise <= 0:
			field.forecast_def_adv.text = "GUARD BROKEN"
			field.forecast_def_adv.modulate = Color.RED
		elif (def_cur_poise - poise_dmg) <= 0:
			field.forecast_def_adv.text = "STAGGER RISK!"
			field.forecast_def_adv.modulate = Color.ORANGE

		var atk_doubles = (attacker.speed - defender.speed) >= 4
		field.forecast_atk_double.text = "x2" if atk_doubles else ""
		var attacker_lethal: bool = atk_hit > 0 and atk_dmg >= int(defender.current_hp)
		var defender_lethal: bool = field.forecast_def_dmg.text != "COUNTER: NONE" and def_hit > 0 and def_dmg >= int(attacker.current_hp)
		ForecastUI.start_forecast_emphasis_pulse(field, attacker_lethal, defender_lethal, atk_crit > 0, def_crit > 0)

	# --- FIGURE-8 ANIMATION TRIGGER ---
	if field.forecast_atk_double.text != "" or field.forecast_def_double.text != "":
		field._start_double_animation()
	else:
		if field.figure_8_tween:
			field.figure_8_tween.kill()

	var talk_visible: bool = false
	if field.forecast_talk_btn != null:
		if defender.get_parent() == field.enemy_container and defender.get("data") != null and defender.data.get("is_recruitable") == true:
			field.forecast_talk_btn.visible = true
			talk_visible = true
			field.forecast_talk_btn.tooltip_text = "Recruit this unit through dialogue (ends this unit's turn)."
		else:
			field.forecast_talk_btn.visible = false
			field.forecast_talk_btn.tooltip_text = ""

	# --- ABILITY BUTTON LOGIC ---
	if field.forecast_ability_btn:
		field.forecast_ability_btn.visible = false # Hide by default

		var abil: String = field._resolve_tactical_ability_name(attacker)
		if abil == "Shove" or abil == "Grapple Hook" or abil == "Fire Trap":
			var cooldown = attacker.get_meta("ability_cooldown", 0)

			field.forecast_ability_btn.visible = true
			if cooldown > 0:
				field.forecast_ability_btn.text = abil + " (CD: " + str(cooldown) + ")"
				field.forecast_ability_btn.disabled = true
			else:
				field.forecast_ability_btn.text = "USE " + abil.to_upper()
				field.forecast_ability_btn.disabled = false

	if field.forecast_atk_support_label:
		field.forecast_atk_support_label.visible = true
	if field.forecast_def_support_label:
		field.forecast_def_support_label.visible = true

	var fc_btn: Button = field.forecast_panel.get_node_or_null("ConfirmButton") as Button
	if fc_btn != null:
		if atk_wpn != null and atk_wpn.get("is_healing_staff") == true:
			fc_btn.text = "Heal"
		elif atk_wpn != null and atk_wpn.get("is_buff_staff") == true:
			fc_btn.text = "Buff"
		elif atk_wpn != null and atk_wpn.get("is_debuff_staff") == true:
			fc_btn.text = "Debuff"
		else:
			fc_btn.text = "Attack"

	if field.forecast_instruction_label:
		if atk_wpn != null and atk_wpn.get("is_healing_staff") == true:
			field.forecast_instruction_label.text = "Confirm to heal. Cancel or right-click to go back."
		elif atk_wpn != null and atk_wpn.get("is_buff_staff") == true:
			field.forecast_instruction_label.text = "Confirm to buff. Cancel or right-click to go back."
		elif atk_wpn != null and atk_wpn.get("is_debuff_staff") == true:
			field.forecast_instruction_label.text = "Confirm to debuff. Cancel or right-click to go back."
		else:
			var ins := "Left: your strike · Right: enemy counter (if any). Click the defender's tile to commit."
			if talk_visible:
				ins += " Talk = recruit (ends turn)."
			field.forecast_instruction_label.text = ins

	if field.forecast_reaction_label:
		var rsum: String = build_forecast_reaction_summary(field, attacker, defender, atk_wpn)
		if rsum.is_empty():
			field.forecast_reaction_label.visible = false
			field.forecast_reaction_label.text = ""
		else:
			field.forecast_reaction_label.text = rsum
			field.forecast_reaction_label.visible = true

	if is_instance_valid(field.target_cursor):
		field.target_cursor.z_index = 80
		field.target_cursor.modulate = Color.WHITE
		if is_instance_valid(field.target_cursor_sprite):
			field.target_cursor_sprite.modulate = Color.WHITE
		# Match main Cursor: parent sits on tile top-left; child Sprite2D (~half cell + texture offset) centers the art.
		field.target_cursor.global_position = defender.global_position
		field._set_cursor_state(field.target_cursor, "ATTACK")
		if field.target_cursor.has_method("set_occluded"):
			field.target_cursor.call("set_occluded", true)
		field.target_cursor.visible = true

	field.forecast_panel.visible = true
	# --- UPDATE THE AWAIT ---
	var result_array = await field.forecast_resolved
	var action = result_array[0]
	var used_ability = result_array[1]

	# --- CLEANUP AND RESET ---
	if field.figure_8_tween:
		field.figure_8_tween.kill()
	ForecastUI.reset_forecast_emphasis_visuals(field)

	if field.atk_double_origin != Vector2.ZERO:
		field.forecast_atk_double.position = field.atk_double_origin
		field.forecast_def_double.position = field.def_double_origin

	if field.forecast_atk_support_label:
		field.forecast_atk_support_label.visible = false
	if field.forecast_def_support_label:
		field.forecast_def_support_label.visible = false
	if field.forecast_reaction_label:
		field.forecast_reaction_label.visible = false
		field.forecast_reaction_label.text = ""

	field.forecast_panel.visible = false
	if is_instance_valid(field.target_cursor):
		if is_instance_valid(field.target_cursor_sprite):
			field.target_cursor_sprite.modulate = Color.WHITE
		field._set_cursor_state(field.target_cursor, "DEFAULT")
		if field.target_cursor.has_method("set_occluded"):
			field.target_cursor.call("set_occluded", false)
		field.target_cursor.visible = false
	return [action, used_ability]
