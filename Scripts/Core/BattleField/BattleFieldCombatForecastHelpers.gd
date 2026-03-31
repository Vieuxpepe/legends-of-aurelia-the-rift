extends RefCounted

# Combat forecast panel + math + await `forecast_resolved` — extracted from `BattleField.gd`.

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

	field._ensure_forecast_support_labels()
	if field.forecast_atk_support_label:
		field.forecast_atk_support_label.text = field._get_forecast_support_text(attacker)
	if field.forecast_def_support_label:
		field.forecast_def_support_label.text = field._get_forecast_support_text(defender)

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

	if atk_wpn == null or atk_wpn.get("is_healing_staff") != true:
		var fr_rookie: Dictionary = field._forecast_rookie_class_passive_mods(attacker, defender, atk_is_magic, atk_wpn)
		atk_hit = clampi(atk_hit + int(fr_rookie.get("hit", 0)), 0, 100)
		atk_dmg = max(0, atk_dmg + int(fr_rookie.get("dmg", 0)))
		atk_crit = clampi(atk_crit + int(fr_rookie.get("crit", 0)), 0, 100)

	# UI Updates (columns: left = attacker / you, right = defender / target)
	field.forecast_atk_name.text = field._format_forecast_name_fitted("ATK", attacker.unit_name, 17)
	field.forecast_atk_weapon.text = field._format_forecast_weapon_name(atk_wpn, 14)
	field.forecast_atk_hp.text = "HP: %d / %d" % [attacker.current_hp, attacker.max_hp]

	field.forecast_def_name.text = field._format_forecast_name_fitted("TARGET", defender.unit_name, 18)
	field.forecast_def_weapon.text = field._format_forecast_weapon_name(def_wpn, 14)
	field.forecast_def_hp.text = "HP: %d / %d" % [defender.current_hp, defender.max_hp]
	var atk_weapon_badge := field.forecast_panel.get_node_or_null("AtkWeaponBadgePanel/Text") as Label
	if atk_weapon_badge != null:
		atk_weapon_badge.text = field._forecast_weapon_marker(atk_wpn)
	var def_weapon_badge := field.forecast_panel.get_node_or_null("DefWeaponBadgePanel/Text") as Label
	if def_weapon_badge != null:
		def_weapon_badge.text = field._forecast_weapon_marker(def_wpn)
	var atk_weapon_icon_panel := field.forecast_panel.get_node_or_null("AtkWeaponIconPanel") as Panel
	var atk_weapon_icon := field.forecast_panel.get_node_or_null("AtkWeaponIconPanel/Icon") as TextureRect
	var atk_weapon_glow := field.forecast_panel.get_node_or_null("AtkWeaponIconPanel/Glow") as Panel
	var atk_weapon_glow_color: Color = field._forecast_weapon_rarity_glow_color(atk_wpn)
	if atk_weapon_icon_panel != null:
		atk_weapon_icon_panel.visible = atk_wpn != null and atk_wpn.icon != null
	if atk_weapon_icon != null:
		atk_weapon_icon.texture = atk_wpn.icon if atk_wpn != null else null
	if atk_weapon_glow != null:
		atk_weapon_glow.visible = atk_wpn != null and atk_wpn.icon != null and atk_weapon_glow_color.a > 0.0
		field._style_forecast_weapon_glow(atk_weapon_glow, atk_weapon_glow_color)
	var def_weapon_icon_panel := field.forecast_panel.get_node_or_null("DefWeaponIconPanel") as Panel
	var def_weapon_icon := field.forecast_panel.get_node_or_null("DefWeaponIconPanel/Icon") as TextureRect
	var def_weapon_glow := field.forecast_panel.get_node_or_null("DefWeaponIconPanel/Glow") as Panel
	var def_weapon_glow_color: Color = field._forecast_weapon_rarity_glow_color(def_wpn)
	if def_weapon_icon_panel != null:
		def_weapon_icon_panel.visible = def_wpn != null and def_wpn.icon != null
	if def_weapon_icon != null:
		def_weapon_icon.texture = def_wpn.icon if def_wpn != null else null
	if def_weapon_glow != null:
		def_weapon_glow.visible = def_wpn != null and def_wpn.icon != null and def_weapon_glow_color.a > 0.0
		field._style_forecast_weapon_glow(def_weapon_glow, def_weapon_glow_color)
	field._ensure_forecast_hp_bars()
	if field.forecast_atk_hp_bar != null:
		field.forecast_atk_hp_bar.max_value = float(max(1, int(attacker.max_hp)))
		field.forecast_atk_hp_bar.value = float(clampi(int(attacker.current_hp), 0, int(attacker.max_hp)))
		field._style_forecast_hp_bar(field.forecast_atk_hp_bar, field._forecast_hp_fill_color(int(attacker.current_hp), int(attacker.max_hp)))
	if field.forecast_def_hp_bar != null:
		field.forecast_def_hp_bar.max_value = float(max(1, int(defender.max_hp)))
		field.forecast_def_hp_bar.value = float(clampi(int(defender.current_hp), 0, int(defender.max_hp)))
		field._style_forecast_hp_bar(field.forecast_def_hp_bar, field._forecast_hp_fill_color(int(defender.current_hp), int(defender.max_hp)))

	# --- RESET UI MODULATES ---
	field._reset_forecast_emphasis_visuals()

	# --- HEALING VS ATTACKING LOGIC ---
	if atk_wpn != null and atk_wpn.get("is_healing_staff") == true:
		field.forecast_def_name.text = field._format_forecast_name_fitted("TARGET", defender.unit_name, 18)
		var heal_amount = attacker.magic + atk_wpn.might
		field.forecast_atk_dmg.text = "HEAL: " + str(heal_amount)
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

		var def_is_healer = def_wpn != null and def_wpn.get("is_healing_staff") == true
		if defender.get_parent() == field.enemy_container:
			field.forecast_def_name.text = field._format_forecast_name_fitted("DEF", defender.unit_name, 17)
		else:
			field.forecast_def_name.text = field._format_forecast_name_fitted("TARGET", defender.unit_name, 18)

		if def_wpn == null or def_is_healer or not field.is_in_range(defender, attacker):
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
		field._start_forecast_emphasis_pulse(attacker_lethal, defender_lethal, atk_crit > 0, def_crit > 0)

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
		else:
			var ins := "Left: your strike · Right: enemy counter (if any). Click the defender's tile to commit."
			if talk_visible:
				ins += " Talk = recruit (ends turn)."
			field.forecast_instruction_label.text = ins

	if field.forecast_reaction_label:
		var rsum: String = field._build_forecast_reaction_summary(attacker, defender, atk_wpn)
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
	field._reset_forecast_emphasis_visuals()

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
