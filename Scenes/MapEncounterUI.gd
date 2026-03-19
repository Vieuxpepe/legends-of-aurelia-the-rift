# ==============================================================================
# Script Name: MapEncounterUI.gd
# Purpose: Displays a narrative event on the world map and resolves player choices.
# Overall Goal: Provide roster-dependent roleplaying events and rewards.
# Project Fit: Instantiated as a modal popup over the WorldMap scene.
# Dependencies: 
#   - CampaignManager.gd (Autoload): Expected to provide roster data and rewards.
# AI/Code Reviewer Guidance:
#   - Entry Point: load_encounter() populates the UI based on passed dictionary.
#   - Core Logic Sections: Roster checking to enable/disable specific choices, 
#     feedback generation for rewards, and UI tweening.
# ==============================================================================

extends CanvasLayer

@onready var main_panel = $Panel
@onready var title_label = $Panel/TitleLabel
@onready var desc_label = $Panel/DescriptionLabel
@onready var choice_container = $Panel/ChoiceContainer

@onready var result_panel = $ResultPanel
@onready var result_label = $ResultPanel/ResultLabel
@onready var close_btn = $ResultPanel/CloseButton

var hover_sound: AudioStreamPlayer
var select_sound: AudioStreamPlayer
var _encounter_data: Dictionary = {}
var _category_badge: Label = null
var _encounter_fame_state: String = ""

# Set to true to log flags set/cleared on choice resolution (easy to disable).
const DEBUG_ENCOUNTER_FLAGS: bool = false

signal encounter_finished

func _ready() -> void:
	result_panel.hide()
	close_btn.pressed.connect(_on_close_pressed)
	
	# Audio Setup
	hover_sound = AudioStreamPlayer.new()
	select_sound = AudioStreamPlayer.new()
	add_child(hover_sound)
	add_child(select_sound)

	# --- 1. THE JUICY ENTRANCE ---
	# Set pivot to the center for a bouncy scale-in
	main_panel.pivot_offset = main_panel.size / 2.0
	
	# Add a dramatic dark background dimmer
	var dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.8)
	dimmer.modulate.a = 0.0
	add_child(dimmer)
	move_child(dimmer, 0) # Push behind everything else
	
	# Add a sudden ambush screen flash
	var flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color.WHITE
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	
	# Start the panel tiny and invisible
	main_panel.scale = Vector2(0.5, 0.5)
	main_panel.modulate.a = 0.0
	
	var tw = create_tween().set_parallel(true)
	# Fade in the dark background
	tw.tween_property(dimmer, "modulate:a", 1.0, 0.3)
	# Snap the flash away quickly
	tw.tween_property(flash, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Bounce the panel in
	tw.tween_property(main_panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(main_panel, "modulate:a", 1.0, 0.2)
	
	# Clean up the flash node after it finishes fading
	tw.chain().tween_callback(flash.queue_free)
	
# Purpose: Populates the UI with the selected encounter data. Applies category/severity styling, fame variants, and risk/reward chips.
func load_encounter(encounter_data: Dictionary) -> void:
	_encounter_data = encounter_data
	var fame_state: String = EncounterDatabase.get_fame_state()
	var title: String = encounter_data.get("title", "Unknown Event")
	var desc: String = encounter_data.get("description", "")
	var fame_variants: Dictionary = EncounterDatabase.get_encounter_fame_variants(encounter_data)
	if fame_variants.has(fame_state):
		var v: Dictionary = fame_variants[fame_state]
		if v.get("title") != null and str(v.get("title")).strip_edges() != "":
			title = str(v.get("title")).strip_edges()
		if v.get("description") != null and str(v.get("description")).strip_edges() != "":
			desc = str(v.get("description")).strip_edges()
	title_label.text = title
	desc_label.text = desc
	_encounter_fame_state = fame_state
	_apply_category_severity_style(encounter_data)

	for child in choice_container.get_children():
		child.queue_free()

	var available_choices: int = 0

	var show_fame_chip: bool = EncounterDatabase.get_encounter_fame_variants(encounter_data).size() > 0 or EncounterDatabase.get_encounter_preferred_fame_states(encounter_data).size() > 0
	var fame_chip_text: String = _get_fame_reaction_chip_text(fame_state)
	var option_index: int = 0

	for option in encounter_data.get("options", []):
		var req_class = str(option.get("req_class", ""))
		var req_item = str(option.get("req_item", ""))
		var req_unit: String = EncounterDatabase.get_option_req_unit(option)
		var bonus_unit: String = EncounterDatabase.get_option_bonus_unit(option)
		var preferred_unit: String = EncounterDatabase.get_option_preferred_unit(option)
		var req_fame: Array = EncounterDatabase.get_option_req_fame_state(option)
		var has_req_fame: bool = req_fame.is_empty()
		if req_fame.size() > 0:
			var state_l: String = fame_state.to_lower()
			for s in req_fame:
				if str(s).to_lower() == state_l:
					has_req_fame = true
					break
		var req_flags: Array = EncounterDatabase.get_option_required_flags(option)
		var blocked_flags: Array = EncounterDatabase.get_option_blocked_flags(option)
		var has_req_flags: bool = EncounterDatabase.has_all_flags(req_flags)
		var not_blocked_flags: bool = not EncounterDatabase.has_any_flag(blocked_flags)

		var has_class = req_class == "" or _is_class_in_roster(req_class)
		var has_item = req_item == "" or _is_item_in_inventory(req_item)
		var has_req_unit = req_unit == "" or _is_unit_in_roster(req_unit)
		var has_bonus_unit = bonus_unit != "" and _roster_has_bonus_unit(bonus_unit)
		var has_preferred = preferred_unit != "" and _is_unit_in_roster(preferred_unit)
		var bonus_display_name: String = ""
		if has_bonus_unit and bonus_unit == EncounterDatabase.AVATAR_SENTINEL:
			var avatar_display: String = str(CampaignManager.custom_avatar.get("name", CampaignManager.custom_avatar.get("unit_name", ""))).strip_edges()
			bonus_display_name = avatar_display if not avatar_display.is_empty() else "You"
		elif has_bonus_unit:
			bonus_display_name = bonus_unit
		elif has_preferred:
			bonus_display_name = preferred_unit

		var row = VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var btn = Button.new()
		btn.mouse_entered.connect(_on_btn_hover)
		btn.custom_minimum_size.y = 36

		if has_class and has_item and has_req_unit and has_req_fame and has_req_flags and not_blocked_flags:
			if req_class != "":
				btn.text = "[" + req_class + "] " + option.get("text", "")
			elif req_item != "":
				btn.text = "[Use " + req_item + "] " + option.get("text", "")
			else:
				btn.text = option.get("text", "Continue")
			if req_unit != "":
				btn.text = "[" + req_unit + "] " + btn.text
			btn.disabled = false
			available_choices += 1
		else:
			var missing_text: String = ""
			if not has_class: missing_text = req_class
			elif not has_item: missing_text = req_item
			elif not has_req_unit: missing_text = req_unit
			elif not has_req_fame: missing_text = "Reputation"
			elif not has_req_flags: missing_text = "Past choice"
			elif not not_blocked_flags: missing_text = "Past choice"
			btn.text = "[Requires " + missing_text + "] " + option.get("text", "")
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5, 0.8)

		btn.pressed.connect(_on_choice_made.bind(option))
		row.add_child(btn)

		var chips: Array[String] = _build_option_chips(option, bonus_display_name, EncounterDatabase.has_branches(option))
		if option.get("flag_variants") is Dictionary and EncounterDatabase.get_option_flag_variant_result(option).size() > 0:
			chips.append("Remembered")
		if show_fame_chip and fame_chip_text != "" and option_index == 0:
			chips.append(fame_chip_text)
		option_index += 1
		if chips.size() > 0:
			var chip_line = HBoxContainer.new()
			chip_line.add_theme_constant_override("separation", 6)
			for c in chips:
				var chip = Label.new()
				chip.text = c
				chip.add_theme_font_size_override("font_size", 14)
				chip.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
				chip_line.add_child(chip)
			row.add_child(chip_line)

		choice_container.add_child(row)

	# --- ANTI-SOFT-LOCK SAFETY NET ---
	if available_choices == 0:
		var escape_btn = Button.new()
		escape_btn.text = "Retreat (No viable options)"
		escape_btn.modulate = Color(0.8, 0.3, 0.3) # Tint it red
		escape_btn.mouse_entered.connect(_on_btn_hover)
		
		var escape_dict = {
			"result_text": "Lacking the required skills or equipment, you are forced to bypass the event.",
			"reward_fame": -10
		}
		
		escape_btn.pressed.connect(_on_choice_made.bind(escape_dict))
		choice_container.add_child(escape_btn)

## Applies category badge and severity/category color to title and panel. Backward-compatible defaults.
func _apply_category_severity_style(enc: Dictionary) -> void:
	var category: String = EncounterDatabase.get_encounter_category(enc)
	var severity: String = EncounterDatabase.get_encounter_severity(enc)
	if _category_badge != null and is_instance_valid(_category_badge):
		_category_badge.queue_free()
	_category_badge = Label.new()
	_category_badge.text = "[" + category.capitalize() + "]"
	_category_badge.add_theme_font_size_override("font_size", 14)
	_category_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var accent: Color = _get_category_severity_color(category, severity)
	_category_badge.add_theme_color_override("font_color", accent)
	main_panel.add_child(_category_badge)
	_category_badge.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_category_badge.offset_top = 76
	_category_badge.offset_bottom = 96
	title_label.add_theme_color_override("font_color", accent)
	var panel_style = main_panel.get_theme_stylebox("panel")
	if panel_style is StyleBoxFlat:
		var flat: StyleBoxFlat = panel_style.duplicate() as StyleBoxFlat
		flat.border_color = accent
		main_panel.add_theme_stylebox_override("panel", flat)

## Returns accent color for category/severity (crisis=red, mystery=violets, profit=gold, mercy=calm blue).
func _get_category_severity_color(category: String, severity: String) -> Color:
	var c = category.to_lower()
	var s = severity.to_lower()
	if c == "crisis" or s == "dangerous": return Color(0.9, 0.35, 0.3)
	if c == "mystery" or c == "omen" or s == "occult": return Color(0.7, 0.5, 0.95)
	if c == "profit": return Color(0.85, 0.75, 0.35)
	if c == "mercy": return Color(0.45, 0.6, 0.9)
	if c == "ambush": return Color(0.8, 0.5, 0.2)
	return Color(0.83, 0.78, 0.7)

## Returns display label for branch key (Success / Partial Success / Failure).
func _get_branch_label(branch_key: String) -> String:
	if branch_key == "success": return "Success"
	if branch_key == "partial": return "Partial Success"
	if branch_key == "fail": return "Failure"
	return "Outcome"

## Returns accent color for branch header (success=green, partial=amber, fail=red).
func _get_branch_accent(branch_key: String) -> Color:
	if branch_key == "success": return Color(0.35, 0.75, 0.45)
	if branch_key == "partial": return Color(0.9, 0.7, 0.25)
	if branch_key == "fail": return Color(0.9, 0.35, 0.3)
	return Color(0.83, 0.78, 0.7)

## Returns chip label for current fame state when encounter is fame-reactive.
func _get_fame_reaction_chip_text(fame_state: String) -> String:
	var s: String = fame_state.to_lower()
	if s == "heretic": return "Heretic Reaction"
	if s == "savior": return "Savior Reaction"
	if s == "mercenary": return "Mercenary Reaction"
	return ""

## Builds risk/reward chip strings from option data and optional tags. bonus_unit_display_name: unit name for "Nyx Bonus" chip; has_branching: add "Risky" when branch has partial/fail.
func _build_option_chips(opt: Dictionary, bonus_unit_display_name: String, has_branching: bool = false) -> Array[String]:
	var chips: Array[String] = []
	var risk_tags: Array = EncounterDatabase.get_option_risk_tags(opt)
	var reward_tags: Array = EncounterDatabase.get_option_reward_tags(opt)
	for t in risk_tags:
		var tag = str(t).to_lower()
		if tag == "party_damage" or tag == "damage": chips.append("Party Damage Risk")
		elif tag == "consumes_item": chips.append("Consumes Item")
		elif tag == "high_risk": chips.append("High Risk")
		else: chips.append(tag.capitalize())
	for t in reward_tags:
		var tag = str(t).to_lower()
		if tag == "gold": chips.append("Possible Gold")
		elif tag == "fame": chips.append("Possible Fame")
		elif tag == "item": chips.append("Possible Item")
		else: chips.append(tag.capitalize())
	if risk_tags.is_empty():
		if int(opt.get("penalty_hp", 0)) > 0: chips.append("Party Damage Risk")
		if opt.get("consume_item", false) == true: chips.append("Consumes Item")
	if reward_tags.is_empty():
		if int(opt.get("reward_gold", 0)) != 0: chips.append("Possible Gold" if int(opt.get("reward_gold", 0)) > 0 else "Gold Loss")
		if int(opt.get("reward_fame", 0)) != 0: chips.append("Possible Fame" if int(opt.get("reward_fame", 0)) > 0 else "Fame Loss")
		if str(opt.get("reward_item_path", "")).strip_edges() != "": chips.append("Possible Item")
	if has_branching and EncounterDatabase.is_branch_risky(opt, bonus_unit_display_name != ""):
		chips.append("Risky")
	if bonus_unit_display_name != "":
		if bonus_unit_display_name == "You":
			chips.append("Your presence")
		else:
			chips.append(bonus_unit_display_name + " Bonus")
	return chips

## True if a unit with the given name (unit_name) is in CampaignManager.player_roster.
func _is_unit_in_roster(unit_name: String) -> bool:
	var target = unit_name.strip_edges()
	if target.is_empty(): return true
	for unit in CampaignManager.player_roster:
		var name_val = str(unit.get("unit_name", "")).strip_edges()
		if name_val == target: return true
	return false

## True if the Avatar is in the roster (unit whose unit_name matches CampaignManager.custom_avatar).
func _is_avatar_in_roster() -> bool:
	var avatar_name: String = str(CampaignManager.custom_avatar.get("unit_name", CampaignManager.custom_avatar.get("name", ""))).strip_edges()
	if avatar_name.is_empty(): return false
	return _is_unit_in_roster(avatar_name)

## True if roster contains the canonical bonus unit name or any of its aliases; treats EncounterDatabase.AVATAR_SENTINEL as Avatar match (neutral internal identity).
func _roster_has_bonus_unit(canonical_name: String) -> bool:
	if canonical_name.is_empty(): return false
	if canonical_name == EncounterDatabase.AVATAR_SENTINEL: return _is_avatar_in_roster()
	if _is_unit_in_roster(canonical_name): return true
	for alias in EncounterDatabase.get_bonus_unit_aliases(canonical_name):
		if _is_unit_in_roster(str(alias)): return true
	return false

# ==============================================================================
# Function Name: _is_class_in_roster
# Purpose: Checks the current roster to see if ANY unit possesses the required class.
# Inputs: req_class (String) - The name of the class required (e.g., "Thief").
# Outputs: bool - True if a matching class is found, False otherwise.
# Side Effects: None.
# AI/Code Reviewer Guidance:
#   - Checks the "unit_class" key created during CampaignManager.save_party().
#   - Uses .to_lower() to make the check case-insensitive just in case.
# ==============================================================================
func _is_class_in_roster(req_class: String) -> bool:
	var target_class = req_class.to_lower().strip_edges()
	
	for unit in CampaignManager.player_roster:
		# Grabs the unit_class saved by your save_party() function
		var u_class = str(unit.get("unit_class", "")).to_lower().strip_edges()
		
		if u_class == target_class:
			return true
			
	return false
	
func _on_btn_hover() -> void:
	if hover_sound.stream != null:
		hover_sound.pitch_scale = randf_range(0.9, 1.1)
		hover_sound.play()

# Purpose: Resolves the player's choice, applies items/HP penalties, and formats feedback. Supports branching (success/partial/fail) and exact-unit bonus.
func _on_choice_made(option: Dictionary) -> void:
	if select_sound.stream != null:
		select_sound.play()

	main_panel.hide()

	var bonus_unit_name: String = ""
	var canonical_bonus: String = EncounterDatabase.get_option_bonus_unit(option)
	if canonical_bonus != "" and _roster_has_bonus_unit(canonical_bonus):
		bonus_unit_name = canonical_bonus
		if canonical_bonus == EncounterDatabase.AVATAR_SENTINEL:
			var avatar_display: String = str(CampaignManager.custom_avatar.get("name", CampaignManager.custom_avatar.get("unit_name", ""))).strip_edges()
			bonus_unit_name = avatar_display if not avatar_display.is_empty() else "You"
	elif EncounterDatabase.get_option_preferred_unit(option) != "" and _is_unit_in_roster(EncounterDatabase.get_option_preferred_unit(option)):
		bonus_unit_name = EncounterDatabase.get_option_preferred_unit(option)
	var bonus_applied: bool = bonus_unit_name != "" and EncounterDatabase.has_bonus_outcome(option)

	var gold: int
	var fame: int
	var penalty_hp: int
	var reward_item_path: String
	var result_text: String
	var branch_key: String = ""

	if EncounterDatabase.has_branches(option):
		branch_key = EncounterDatabase.resolve_branch(option, bonus_applied)
		var branches: Dictionary = option.get("branches", {})
		var branch_data = branches.get(branch_key)
		var outcome: Dictionary = EncounterDatabase.get_branch_outcome(branch_data)
		result_text = outcome.get("result_text", "The event concludes.")
		gold = int(outcome.get("reward_gold", 0))
		fame = int(outcome.get("reward_fame", 0))
		penalty_hp = int(outcome.get("penalty_hp", 0))
		reward_item_path = str(outcome.get("reward_item_path", "")).strip_edges()
	else:
		gold = EncounterDatabase.get_effective_reward_gold(option, bonus_applied)
		fame = EncounterDatabase.get_effective_reward_fame(option, bonus_applied)
		penalty_hp = EncounterDatabase.get_effective_penalty_hp(option, bonus_applied)
		reward_item_path = EncounterDatabase.get_effective_reward_item_path(option, bonus_applied)
		result_text = EncounterDatabase.get_effective_result_text(option, bonus_applied)

	var fame_override: Dictionary = EncounterDatabase.get_option_fame_variant_result(option, _encounter_fame_state)
	if fame_override.size() > 0:
		if fame_override.get("result_text") != null and str(fame_override.get("result_text")).strip_edges() != "":
			result_text = str(fame_override.get("result_text")).strip_edges()
		if fame_override.get("reward_gold") != null:
			gold = int(fame_override.get("reward_gold", 0))
		if fame_override.get("reward_fame") != null:
			fame = int(fame_override.get("reward_fame", 0))
		if fame_override.get("penalty_hp") != null:
			penalty_hp = int(fame_override.get("penalty_hp", 0))
		if fame_override.get("reward_item_path") != null and str(fame_override.get("reward_item_path")).strip_edges() != "":
			reward_item_path = str(fame_override.get("reward_item_path")).strip_edges()

	# --- Flag variant result override (remembered consequences; applied after fame). ---
	var flag_override: Dictionary = EncounterDatabase.get_option_flag_variant_result(option)
	if flag_override.size() > 0:
		if flag_override.get("result_text") != null and str(flag_override.get("result_text")).strip_edges() != "":
			result_text = str(flag_override.get("result_text")).strip_edges()
		if flag_override.get("reward_gold") != null:
			gold = int(flag_override.get("reward_gold", 0))
		if flag_override.get("reward_fame") != null:
			fame = int(flag_override.get("reward_fame", 0))
		if flag_override.get("penalty_hp") != null:
			penalty_hp = int(flag_override.get("penalty_hp", 0))
		if flag_override.get("reward_item_path") != null and str(flag_override.get("reward_item_path")).strip_edges() != "":
			reward_item_path = str(flag_override.get("reward_item_path")).strip_edges()

	# --- Apply encounter flags (set/clear) so future encounters can react. ---
	var flags_set_this_resolve: bool = false
	for f in EncounterDatabase.get_option_set_flags(option):
		var key: String = str(f).strip_edges()
		if key.is_empty(): continue
		CampaignManager.encounter_flags[key] = true
		flags_set_this_resolve = true
		if DEBUG_ENCOUNTER_FLAGS:
			print("[MapEncounterUI] set flag (option): ", key)
	for f in EncounterDatabase.get_option_clear_flags(option):
		var key: String = str(f).strip_edges()
		if key.is_empty(): continue
		CampaignManager.encounter_flags.erase(key)
		if DEBUG_ENCOUNTER_FLAGS:
			print("[MapEncounterUI] clear flag (option): ", key)
	for f in EncounterDatabase.get_encounter_set_flags_on_resolve(_encounter_data):
		var key: String = str(f).strip_edges()
		if key.is_empty(): continue
		CampaignManager.encounter_flags[key] = true
		flags_set_this_resolve = true
		if DEBUG_ENCOUNTER_FLAGS:
			print("[MapEncounterUI] set flag (encounter): ", key)
	for f in EncounterDatabase.get_encounter_clear_flags_on_resolve(_encounter_data):
		var key: String = str(f).strip_edges()
		if key.is_empty(): continue
		CampaignManager.encounter_flags.erase(key)
		if DEBUG_ENCOUNTER_FLAGS:
			print("[MapEncounterUI] clear flag (encounter): ", key)

	if bonus_applied and canonical_bonus == EncounterDatabase.AVATAR_SENTINEL and result_text.contains("[AVATAR_ROLE]"):
		result_text = result_text.replace("[AVATAR_ROLE]", EncounterDatabase.get_avatar_public_role_phrase())

	# --- ITEM CONSUMPTION LOGIC (always from option) ---
	var req_item = str(option.get("req_item", ""))
	var item_consumed_text = ""
	if req_item != "" and option.get("consume_item", false) == true:
		var target = req_item.to_lower().strip_edges()
		for i in range(CampaignManager.global_inventory.size()):
			var item = CampaignManager.global_inventory[i]
			if item == null: continue
			var i_name = ""
			if "item_name" in item:
				i_name = str(item.get("item_name"))
			elif "weapon_name" in item:
				i_name = str(item.get("weapon_name"))
			else:
				i_name = item.resource_path.get_file().get_basename()
			if i_name.to_lower().strip_edges() == target:
				CampaignManager.global_inventory.remove_at(i)
				item_consumed_text = "[color=orange]- Used " + req_item + "[/color]\n"
				break

	# --- APPLY STATS TO CAMPAIGN ---
	CampaignManager.global_gold += gold
	CampaignManager.global_fame += fame

	# --- BRANCH HEADER: use branch accent when branched, else encounter category accent ---
	var accent: Color
	var header_title: String
	if branch_key != "":
		header_title = _get_branch_label(branch_key)
		accent = _get_branch_accent(branch_key)
	else:
		header_title = "Outcome"
		accent = _get_category_severity_color(
			EncounterDatabase.get_encounter_category(_encounter_data),
			EncounterDatabase.get_encounter_severity(_encounter_data)
		)
	var header_hex: String = accent.to_html(false)
	var feedback_text := "\n\n"
	if item_consumed_text != "":
		feedback_text += item_consumed_text
	if reward_item_path != "":
		var item_res = load(reward_item_path)
		if item_res:
			var new_item = item_res.duplicate()
			CampaignManager.global_inventory.append(new_item)
			var i_name = ""
			if "item_name" in new_item:
				i_name = str(new_item.get("item_name"))
			elif "weapon_name" in new_item:
				i_name = str(new_item.get("weapon_name"))
			else:
				i_name = new_item.resource_path.get_file().get_basename()
			feedback_text += "[color=cyan]+ Found " + i_name + "[/color]\n"
	if penalty_hp > 0:
		for unit in CampaignManager.player_roster:
			if unit.has("current_hp"):
				unit["current_hp"] = max(1, int(unit["current_hp"]) - penalty_hp)
		feedback_text += "[color=red]- Party took " + str(penalty_hp) + " damage[/color]\n"
	if gold > 0:
		feedback_text += "[color=gold]+ " + str(gold) + " Gold[/color]\n"
	elif gold < 0:
		feedback_text += "[color=red]- " + str(abs(gold)) + " Gold[/color]\n"
	if fame > 0:
		feedback_text += "[color=lightblue]+ " + str(fame) + " Fame[/color]\n"
	elif fame < 0:
		feedback_text += "[color=red]- " + str(abs(fame)) + " Fame[/color]\n"
	feedback_text += "\n[color=gray]———[/color]\n"
	feedback_text += "[color=gray]Gold: " + str(CampaignManager.global_gold) + "  ·  Fame: " + str(CampaignManager.global_fame) + "[/color]"
	if bonus_applied and branch_key == "":
		if bonus_unit_name == "You":
			feedback_text += "\n\n[color=cyan](Your presence improved the outcome.)[/color]"
		else:
			feedback_text += "\n\n[color=cyan](" + bonus_unit_name + "'s presence improved the outcome.)[/color]"
	elif bonus_applied and branch_key == "success":
		if bonus_unit_name == "You":
			feedback_text += "\n\n[color=cyan](Your presence improved your odds.)[/color]"
		else:
			feedback_text += "\n\n[color=cyan](" + bonus_unit_name + "'s presence improved your odds.)[/color]"
	if flags_set_this_resolve:
		feedback_text += "\n\n[color=gray](The road will remember this.)[/color]"

	var header_bbcode: String = "[color=#" + header_hex + "]——— " + header_title + " ———[/color]\n\n"
	result_label.text = header_bbcode + result_text + feedback_text

	result_panel.show()
	result_panel.scale = Vector2(0.9, 0.9)
	result_panel.modulate.a = 0.0
	var result_tw = create_tween().set_parallel(true)
	result_tw.tween_property(result_panel, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	result_tw.tween_property(result_panel, "modulate:a", 1.0, 0.15)
	
# ==============================================================================
# Function Name: _is_item_in_inventory
# Purpose: Scans the global inventory for an item matching the target name.
# ==============================================================================
func _is_item_in_inventory(target_item_name: String) -> bool:
	var target = target_item_name.to_lower().strip_edges()
	
	for item in CampaignManager.global_inventory:
		if item == null: continue
		
		var i_name = ""
		if "item_name" in item:
			i_name = str(item.item_name)
		elif "weapon_name" in item:
			i_name = str(item.weapon_name)
		else:
			i_name = item.resource_path.get_file().get_basename()
			
		if i_name.to_lower().strip_edges() == target:
			return true
			
	return false
	
func _on_close_pressed() -> void:
	if select_sound.stream != null:
		select_sound.play()
		
	main_panel.hide()
	result_panel.hide()
	emit_signal("encounter_finished")
	queue_free()
