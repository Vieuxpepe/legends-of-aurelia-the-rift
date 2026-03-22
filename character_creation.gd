extends Control

# =========================
# UI REFERENCES (existing)
# =========================
@onready var name_input: LineEdit = $Panel/NameInput
@onready var class_dropdown: OptionButton = $Panel/ClassDropdown
@onready var ability_dropdown: OptionButton = $Panel/AbilityDropdown
@onready var points_label: Label = $Panel/PointsLabel
@onready var difficulty_dropdown: OptionButton = $Panel/DifficultyDropdown
@onready var difficulty_desc_label: RichTextLabel = $Panel/DifficultyDescLabel

# Stat value labels
@onready var hp_value: Label = $Panel/GridContainer/HpValue
@onready var str_value: Label = $Panel/GridContainer/StrValue
@onready var mag_value: Label = $Panel/GridContainer/MagValue
@onready var def_value: Label = $Panel/GridContainer/DefValue
@onready var res_value: Label = $Panel/GridContainer/ResValue
@onready var spd_value: Label = $Panel/GridContainer/SpdValue
@onready var agi_value: Label = $Panel/GridContainer/AgiValue

# Stat buttons
@onready var hp_plus: Button = $Panel/GridContainer/HpPlus
@onready var hp_minus: Button = $Panel/GridContainer/HpMinus
@onready var str_plus: Button = $Panel/GridContainer/StrPlus
@onready var str_minus: Button = $Panel/GridContainer/StrMinus
@onready var mag_plus: Button = $Panel/GridContainer/MagPlus
@onready var mag_minus: Button = $Panel/GridContainer/MagMinus
@onready var def_plus: Button = $Panel/GridContainer/DefPlus
@onready var def_minus: Button = $Panel/GridContainer/DefMinus
@onready var res_plus: Button = $Panel/GridContainer/ResPlus
@onready var res_minus: Button = $Panel/GridContainer/ResMinus
@onready var spd_plus: Button = $Panel/GridContainer/SpdPlus
@onready var spd_minus: Button = $Panel/GridContainer/SpdMinus
@onready var agi_plus: Button = $Panel/GridContainer/AgiPlus
@onready var agi_minus: Button = $Panel/GridContainer/AgiMinus

# Weapon selector
@onready var weapon_display: TextureRect = $Panel/WeaponDisplay
@onready var weapon_name_label: Label = $Panel/WeaponNameLabel
@onready var prev_weapon_btn: Button = $Panel/PrevWeaponButton
@onready var next_weapon_btn: Button = $Panel/NextWeaponButton

# Sprite selector
@onready var sprite_display: TextureRect = $Panel/SpriteDisplay
@onready var prev_sprite_btn: Button = $Panel/PrevSpriteButton
@onready var next_sprite_btn: Button = $Panel/NextSpriteButton
@onready var battle_sprite_display: TextureRect = $Panel/BattleSpriteDisplay

# Music & dialogs
@onready var bg_music: AudioStreamPlayer = $BackgroundMusic
@onready var click_sound: AudioStreamPlayer = $ClickSound
@onready var start_confirmation: ConfirmationDialog = $StartConfirmation

# Start button
@onready var start_button: Button = $Panel/StartCampaignButton

# Main panel (for entrance animation; no new node)
@onready var _panel: Control = $Panel

# =========================
# OPTIONAL UI (add these nodes if you want the features)
# =========================
@export var build_summary_label_path: NodePath = NodePath("Panel/BuildSummaryLabel")
@export var preset_dropdown_path: NodePath = NodePath("Panel/PresetDropdown")
@export var apply_preset_button_path: NodePath = NodePath("Panel/ApplyPresetButton")
@export var reset_button_path: NodePath = NodePath("Panel/ResetButton")
@export var undo_button_path: NodePath = NodePath("Panel/UndoButton")

@onready var build_summary_label: Label = get_node_or_null(build_summary_label_path) as Label
@onready var preset_dropdown: OptionButton = get_node_or_null(preset_dropdown_path) as OptionButton
@onready var apply_preset_button: Button = get_node_or_null(apply_preset_button_path) as Button
@onready var reset_button: Button = get_node_or_null(reset_button_path) as Button
@onready var undo_button: Button = get_node_or_null(undo_button_path) as Button

# =========================
# DATA
# =========================
@export var menu_music_tracks: Array[AudioStream] = []

# Drag your ClassData resource files (.tres) here in the Inspector
@export var available_classes: Array[ClassData] = []

@export var available_starting_weapons: Array[WeaponData] = []
@export var available_sprites: Array[Texture2D] = []
@export var available_battle_sprites: Array[Texture2D] = []

@export var starting_points: int = 15

# Caps (edit in Inspector)
@export var cap_hp: int = 35
@export var cap_str: int = 20
@export var cap_mag: int = 20
@export var cap_def: int = 18
@export var cap_res: int = 18
@export var cap_spd: int = 20
@export var cap_agi: int = 20

var current_weapon_index: int = 0
var current_sprite_index: int = 0
var available_points: int = 0

# --- FIX 1: THE CONSTANT BASE ---
const CREATION_BASE_STATS: Dictionary = {
	"hp": 15,
	"str": 5,
	"mag": 5,
	"def": 3,
	"res": 3,
	"spd": 5,
	"agi": 4
}

var stats: Dictionary = {}
var base_stats: Dictionary = {}

const STAT_KEYS: Array[String] = ["hp", "str", "mag", "def", "res", "spd", "agi"]

# per-stat UI map
var _value_labels: Dictionary = {}
var _plus_buttons: Dictionary = {}
var _minus_buttons: Dictionary = {}

# animation control (prevents “color gets messed up” when spam clicking)
var _label_tweens: Dictionary = {} # stat -> Tween

@onready var ability_desc_label: Label = $Panel/AbilityDescLabel

const DIFFICULTY_DESCRIPTIONS = {
	"Normal": "The standard experience. A fair and balanced tactical challenge.",
	"Hard": "Enemies are significantly stronger (+25% Stats). Mistakes will be punished.",
	"Maddening": "Enemies are massively stronger (+50% Stats) and highly intelligent. They will actively hunt your weakest units. For veterans only."
}

# Dictionary mapping Ability Names to Descriptions based on BattleField.gd logic
const ABILITY_DESCRIPTIONS = {
	"Bloodthirster": "OFFENSIVE: Trigger a timing minigame on attack.\nSuccessful hits heal you for 25% of damage dealt.\nLanding a Perfect 3-Hit Combo guarantees a CRITICAL HIT.",
	"Shield Clash": "DEFENSIVE: Trigger a button-mashing duel when attacked.\nSuccess negates all damage, heals you for 25% HP,\nand deals a massive 3x damage counter-attack.",
	"Focused Strike": "OFFENSIVE: Charge a powerful blow with a timing minigame.\nSuccess makes the attack IGNORE 100% of Enemy Defense\nand guarantees a hit.",
	"Hundred Point Strike": "OFFENSIVE: Chain a flurry of blows by matching directional keys.\nEach correct input adds an extra strike to the attack sequence.\nHigh risk, high reward.",
	"Shove": "TACTICAL: Push an adjacent enemy 1 tile away after attacking.\nIf they collide with an obstacle or unit, they take bonus damage.\nCooldown: 3 Turns.",
	"Grapple Hook": "TACTICAL: Pull an enemy 1 tile closer to you after attacking.\nGreat for dragging vulnerable targets into range of your allies.\nCooldown: 3 Turns.",
	"Fire Trap": "TACTICAL (Fire Sage): After a hit, sear the defender's tile with lingering flames.\nPerfect timing improves damage and duration.\nCooldown: 3 Turns."
}

# undo stack
@export var undo_limit: int = 50
var _undo_stack: Array[Dictionary] = []

# Presets
const PRESETS: Array[Dictionary] = [
	{
		"name": "Balanced",
		"alloc": {"hp": 2, "str": 2, "mag": 2, "def": 2, "res": 2, "spd": 2, "agi": 3}
	},
	{
		"name": "Bruiser",
		"alloc": {"hp": 5, "str": 5, "mag": 0, "def": 3, "res": 1, "spd": 1, "agi": 0}
	},
	{
		"name": "Caster",
		"alloc": {"hp": 2, "str": 0, "mag": 6, "def": 1, "res": 3, "spd": 2, "agi": 1}
	},
	{
		"name": "Swift",
		"alloc": {"hp": 1, "str": 2, "mag": 1, "def": 1, "res": 1, "spd": 5, "agi": 4}
	}
]

func _ready() -> void:
	randomize()

	name_input.max_length = 12
	name_input.placeholder_text = "Your hero's name (optional)"
	name_input.focus_exited.connect(_on_name_input_focus_exited)

	# --- FIX 1B: INIT CONSTANTS ---
	available_points = starting_points
	base_stats = CREATION_BASE_STATS.duplicate(true)
	stats = base_stats.duplicate(true)

	_cache_stat_ui()
	_setup_dropdowns()
	_wire_buttons()
	
	# --- FIX 1C: FORCE APPLY INDEX 0 CLASS STATS ON LOAD ---
	if class_dropdown.item_count > 0:
		class_dropdown.selected = 0
		_apply_selected_class_base(false)
	
	_update_ability_description()
	_update_difficulty_description()
	_update_sprite_display()
	_update_weapon_display()

	# Start button + confirmation
	start_button.pressed.connect(_on_start_button_pressed)
	start_confirmation.confirmed.connect(_on_start_confirmed)
	_style_start_button()
	_wire_start_button_hover()

	# Music
	bg_music.finished.connect(_on_bg_music_finished)
	_play_random_music()

	# Optional features
	_setup_presets_ui()
	_wire_optional_buttons()

	_update_ui()
	_play_panel_entrance()

# --- FIX 1D: THE HELPER FUNCTION ---
func _apply_selected_class_base(push_undo: bool = false) -> void:
	if class_dropdown.selected < 0 or class_dropdown.selected >= available_classes.size():
		return

	var c_data: ClassData = available_classes[class_dropdown.selected]
	if c_data == null:
		return

	if push_undo:
		_push_undo()

	base_stats = {
		"hp": int(CREATION_BASE_STATS["hp"]) + c_data.hp_bonus,
		"str": int(CREATION_BASE_STATS["str"]) + c_data.str_bonus,
		"mag": int(CREATION_BASE_STATS["mag"]) + c_data.mag_bonus,
		"def": int(CREATION_BASE_STATS["def"]) + c_data.def_bonus,
		"res": int(CREATION_BASE_STATS["res"]) + c_data.res_bonus,
		"spd": int(CREATION_BASE_STATS["spd"]) + c_data.spd_bonus,
		"agi": int(CREATION_BASE_STATS["agi"]) + c_data.agi_bonus
	}

	stats = base_stats.duplicate(true)
	available_points = starting_points
	_update_ui()

func _cache_stat_ui() -> void:
	_value_labels = {
		"hp": hp_value, "str": str_value, "mag": mag_value,
		"def": def_value, "res": res_value, "spd": spd_value, "agi": agi_value
	}
	_plus_buttons = {
		"hp": hp_plus, "str": str_plus, "mag": mag_plus,
		"def": def_plus, "res": res_plus, "spd": spd_plus, "agi": agi_plus
	}
	_minus_buttons = {
		"hp": hp_minus, "str": str_minus, "mag": mag_minus,
		"def": def_minus, "res": res_minus, "spd": spd_minus, "agi": agi_minus
	}

func _wire_buttons() -> void:
	# Stat +/- buttons
	hp_plus.pressed.connect(func(): _adjust_stat("hp", 1))
	hp_minus.pressed.connect(func(): _adjust_stat("hp", -1))

	str_plus.pressed.connect(func(): _adjust_stat("str", 1))
	str_minus.pressed.connect(func(): _adjust_stat("str", -1))

	mag_plus.pressed.connect(func(): _adjust_stat("mag", 1))
	mag_minus.pressed.connect(func(): _adjust_stat("mag", -1))

	def_plus.pressed.connect(func(): _adjust_stat("def", 1))
	def_minus.pressed.connect(func(): _adjust_stat("def", -1))

	res_plus.pressed.connect(func(): _adjust_stat("res", 1))
	res_minus.pressed.connect(func(): _adjust_stat("res", -1))

	spd_plus.pressed.connect(func(): _adjust_stat("spd", 1))
	spd_minus.pressed.connect(func(): _adjust_stat("spd", -1))

	agi_plus.pressed.connect(func(): _adjust_stat("agi", 1))
	agi_minus.pressed.connect(func(): _adjust_stat("agi", -1))

	# Dropdown click sound
	class_dropdown.item_selected.connect(func(_i: int): _play_click_sound())
	ability_dropdown.item_selected.connect(func(_i: int): _play_click_sound())
	class_dropdown.item_selected.connect(_on_class_changed)
	
	difficulty_dropdown.item_selected.connect(func(_i): 
		_play_click_sound()
		_update_difficulty_description()
	)
	
	# Sprite buttons
	prev_sprite_btn.pressed.connect(_on_prev_sprite_pressed)
	next_sprite_btn.pressed.connect(_on_next_sprite_pressed)

	# Weapon buttons
	prev_weapon_btn.pressed.connect(_on_prev_weapon_pressed)
	next_weapon_btn.pressed.connect(_on_next_weapon_pressed)

	ability_dropdown.item_selected.connect(func(_i): 
		_play_click_sound()
		_update_ability_description()
	)

func _wire_optional_buttons() -> void:
	if apply_preset_button:
		apply_preset_button.pressed.connect(_on_apply_preset_pressed)
		apply_preset_button.pressed.connect(func(): _button_press_feedback(apply_preset_button))
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
		reset_button.pressed.connect(func(): _button_press_feedback(reset_button))
	if undo_button:
		undo_button.pressed.connect(_on_undo_pressed)
		undo_button.pressed.connect(func(): _button_press_feedback(undo_button))

func _setup_dropdowns() -> void:
	class_dropdown.clear()
	
	for c_data in available_classes:
		if c_data:
			class_dropdown.add_item(c_data.job_name)
		else:
			class_dropdown.add_item("Unknown Class")

	ability_dropdown.clear()
	ability_dropdown.add_item("Bloodthirster")
	ability_dropdown.add_item("Shield Clash")
	ability_dropdown.add_item("Focused Strike")
	ability_dropdown.add_item("Hundred Point Strike")
	ability_dropdown.add_item("Shove")          
	ability_dropdown.add_item("Grapple Hook")   

	difficulty_dropdown.clear()
	difficulty_dropdown.add_item("Normal")
	difficulty_dropdown.add_item("Hard")
	difficulty_dropdown.add_item("Maddening")

func _on_class_changed(_index: int) -> void:
	_play_click_sound()
	_apply_selected_class_base(true)

func _setup_presets_ui() -> void:
	if preset_dropdown == null:
		return
	preset_dropdown.clear()
	for p in PRESETS:
		preset_dropdown.add_item(String(p.get("name", "Preset")))
	preset_dropdown.selected = 0

func _play_click_sound() -> void:
	if click_sound.stream != null:
		click_sound.play()

# --- UX: Entrance and button feedback (no new nodes). ---
func _play_panel_entrance() -> void:
	if _panel == null:
		return
	_panel.scale = Vector2(0.97, 0.97)
	_panel.modulate.a = 0.0
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BACK)
	t.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.25)
	t.parallel().tween_property(_panel, "modulate:a", 1.0, 0.2)

func _button_press_feedback(btn: Button) -> void:
	if btn == null:
		return
	var t := create_tween()
	t.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _style_start_button() -> void:
	if start_button == null:
		return
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.bg_color = Color(0.15, 0.45, 0.2)
	style.border_color = Color(0.3, 0.85, 0.4)
	style.set_border_width_all(2)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	start_button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.2, 0.55, 0.28)
	start_button.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = Color(0.12, 0.38, 0.18)
	start_button.add_theme_stylebox_override("pressed", pressed)

func _wire_start_button_hover() -> void:
	if start_button == null:
		return
	start_button.mouse_entered.connect(_on_start_button_hover_entered)
	start_button.mouse_exited.connect(_on_start_button_hover_exited)

func _on_start_button_hover_entered() -> void:
	if start_button == null:
		return
	var t := create_tween()
	t.tween_property(start_button, "scale", Vector2(1.02, 1.02), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_start_button_hover_exited() -> void:
	if start_button == null:
		return
	var t := create_tween()
	t.tween_property(start_button, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _tween_display_pop(control: Control) -> void:
	if control == null:
		return
	control.scale = Vector2(1.08, 1.08)
	var t := create_tween()
	t.tween_property(control, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# =========================
# Caps + button enabling
# =========================
func _set_stat_value(label_control: Label, stat_name: String, cap: int) -> void:
	if label_control == null:
		return
	var val: int = int(stats.get(stat_name, 0))
	label_control.text = "%d / %d" % [val, cap]
	# At-cap visual: gold tint so "value/cap" clarity is obvious (avoids confusion like current > cap)
	label_control.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45) if val >= cap else Color.WHITE)

func _on_name_input_focus_exited() -> void:
	if name_input == null:
		return
	name_input.text = name_input.text.strip_edges().substr(0, name_input.max_length)

func _get_cap(stat_name: String) -> int:
	match stat_name:
		"hp": return cap_hp
		"str": return cap_str
		"mag": return cap_mag
		"def": return cap_def
		"res": return cap_res
		"spd": return cap_spd
		"agi": return cap_agi
		_: return 999

func _can_increase(stat_name: String) -> bool:
	if available_points <= 0:
		return false
	return int(stats[stat_name]) < _get_cap(stat_name)

func _can_decrease(stat_name: String) -> bool:
	return int(stats[stat_name]) > int(base_stats[stat_name])

func _refresh_button_states() -> void:
	for key in STAT_KEYS:
		var plus_btn: Button = _plus_buttons[key] as Button
		var minus_btn: Button = _minus_buttons[key] as Button
		plus_btn.disabled = not _can_increase(key)
		minus_btn.disabled = not _can_decrease(key)

# =========================
# Undo / Reset / Presets
# =========================

# --- FIX 2A: UNDO STACK NOW SAVES BASE STATS ---
func _push_undo() -> void:
	var snapshot: Dictionary = {
		"stats": stats.duplicate(true),
		"base_stats": base_stats.duplicate(true),
		"points": available_points,
		"sprite_idx": current_sprite_index,
		"weapon_idx": current_weapon_index,
		"class_sel": class_dropdown.selected,
		"ability_sel": ability_dropdown.selected
	}
	_undo_stack.append(snapshot)
	if _undo_stack.size() > undo_limit:
		_undo_stack.pop_front()

# --- FIX 2B: UNDO PRESS RESTORES BASE STATS ---
func _on_undo_pressed() -> void:
	_play_click_sound()
	if _undo_stack.is_empty():
		return

	var last: Dictionary = _undo_stack.pop_back()

	stats = (last.get("stats", CREATION_BASE_STATS.duplicate(true)) as Dictionary).duplicate(true)
	base_stats = (last.get("base_stats", CREATION_BASE_STATS.duplicate(true)) as Dictionary).duplicate(true)
	available_points = int(last.get("points", starting_points))
	current_sprite_index = int(last.get("sprite_idx", 0))
	current_weapon_index = int(last.get("weapon_idx", 0))
	class_dropdown.selected = int(last.get("class_sel", 0))
	ability_dropdown.selected = int(last.get("ability_sel", 0))

	_update_sprite_display()
	_update_weapon_display()
	_update_ability_description()
	_update_ui()

func _on_reset_pressed() -> void:
	_play_click_sound()
	_push_undo()
	stats = base_stats.duplicate(true)
	available_points = starting_points
	_update_ui()

func _on_apply_preset_pressed() -> void:
	_play_click_sound()
	if preset_dropdown == null:
		return
	var idx: int = preset_dropdown.selected
	if idx < 0 or idx >= PRESETS.size():
		return

	_push_undo()

	# Reset to base first
	stats = base_stats.duplicate(true)
	available_points = starting_points

	var alloc: Dictionary = PRESETS[idx].get("alloc", {})
	for key in STAT_KEYS:
		var add_amt: int = int(alloc.get(key, 0))
		for _i in range(add_amt):
			if not _can_increase(key):
				break
			stats[key] = int(stats[key]) + 1
			available_points -= 1

	_update_ui()

# =========================
# Stat changing + animation
# =========================
func _adjust_stat(stat_name: String, amount: int) -> void:
	_play_click_sound()

	if amount > 0 and not _can_increase(stat_name):
		return
	if amount < 0 and not _can_decrease(stat_name):
		return

	var btn: Button = _plus_buttons[stat_name] if amount > 0 else _minus_buttons[stat_name]
	_button_press_feedback(btn)

	_push_undo()

	stats[stat_name] = int(stats[stat_name]) + amount
	available_points -= amount

	_update_ui()
	_animate_stat_label(stat_name, amount)

func _animate_stat_label(stat_name: String, delta: int) -> void:
	var label: Label = _value_labels[stat_name] as Label
	if label == null:
		return

	# Kill previous tween for this label
	if _label_tweens.has(stat_name):
		var old_t: Tween = _label_tweens[stat_name] as Tween
		if old_t != null and old_t.is_valid():
			old_t.kill()
	_label_tweens.erase(stat_name)

	# Reset visuals
	label.modulate = Color.WHITE
	label.scale = Vector2.ONE

	var flash_color: Color = Color(0.2, 1.0, 0.2) if delta > 0 else Color(1.0, 0.35, 0.35)
	var t: Tween = create_tween()
	_label_tweens[stat_name] = t

	t.tween_property(label, "scale", Vector2(1.12, 1.12), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(label, "modulate", flash_color, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	t.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(label, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	t.finished.connect(func():
		label.modulate = Color.WHITE
		label.scale = Vector2.ONE
		_label_tweens.erase(stat_name)
	)

# =========================
# UI update
# =========================
func _update_ui() -> void:
	var points_hint: String = " — All spent!" if available_points == 0 else ""
	points_label.text = "Points: %d" % [available_points] + points_hint
	if available_points > 0:
		points_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	elif available_points == 0:
		points_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	else:
		points_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))

	# Start button: copy + readiness cue (slight dim when points left, full brightness when ready)
	if start_button != null:
		start_button.text = "Begin Journey" + (" • Ready!" if available_points == 0 else "")
		start_button.modulate = Color.WHITE if available_points == 0 else Color(0.92, 0.92, 0.92)

	# Stat value labels: value / cap; at-cap stats use gold tint for clarity
	_set_stat_value(hp_value, "hp", cap_hp)
	_set_stat_value(str_value, "str", cap_str)
	_set_stat_value(mag_value, "mag", cap_mag)
	_set_stat_value(def_value, "def", cap_def)
	_set_stat_value(res_value, "res", cap_res)
	_set_stat_value(spd_value, "spd", cap_spd)
	_set_stat_value(agi_value, "agi", cap_agi)

	_refresh_button_states()
	_update_build_summary()

func _format_growth(bonus: int) -> String:
	"""Returns e.g. '+12%' or '-10%' for class growth display (avoids ambiguous '+-10%')."""
	if bonus >= 0:
		return "+%d%%" % bonus
	return "%d%%" % bonus

func _get_matching_preset_name() -> String:
	"""If current allocation matches a preset's alloc exactly, returns that preset name; else empty."""
	var spent: Dictionary = {}
	for k in STAT_KEYS:
		spent[k] = int(stats.get(k, 0)) - int(base_stats.get(k, 0))
	for p in PRESETS:
		var alloc: Dictionary = p.get("alloc", {})
		var match_found := true
		for k in STAT_KEYS:
			if int(spent.get(k, 0)) != int(alloc.get(k, 0)):
				match_found = false
				break
		if match_found:
			return str(p.get("name", ""))
	return ""

func _update_build_summary() -> void:
	if build_summary_label == null:
		return

	var selected_class_name: String = class_dropdown.get_item_text(class_dropdown.selected)
	var selected_ability: String = ability_dropdown.get_item_text(ability_dropdown.selected)

	# --- 1. Get Weapon Name ---
	var wpn_name: String = "None"
	if not available_starting_weapons.is_empty() and current_weapon_index >= 0 and current_weapon_index < available_starting_weapons.size():
		var w: WeaponData = available_starting_weapons[current_weapon_index]
		if w != null:
			wpn_name = w.weapon_name

	# --- 2. Get Class Resource for Move/Growths ---
	var c_data: ClassData = null
	if class_dropdown.selected >= 0 and class_dropdown.selected < available_classes.size():
		c_data = available_classes[class_dropdown.selected]

	# --- 3. Build the Text ---
	var lines: Array[String] = []
	
	if c_data:
		lines.append("CLASS: %s (MOVE: %d)" % [selected_class_name.to_upper(), c_data.move_range])
	else:
		lines.append("CLASS: %s" % [selected_class_name.to_upper()])
		
	lines.append("ABILITY: %s" % [selected_ability.to_upper()])
	lines.append("WEAPON: %s" % [wpn_name.to_upper()])
	
	lines.append("") # Spacer
	
	lines.append("BASE STATS:")
	lines.append("HP %d | STR %d | MAG %d | DEF %d | RES %d | SPD %d | AGI %d" % [
		int(stats["hp"]), int(stats["str"]), int(stats["mag"]),
		int(stats["def"]), int(stats["res"]), int(stats["spd"]), int(stats["agi"])
	])

	if c_data:
		lines.append("") # Spacer
		lines.append("CLASS GROWTH BONUSES:")
		lines.append("HP %s | STR %s | MAG %s | DEF %s" % [
			_format_growth(c_data.hp_growth_bonus), _format_growth(c_data.str_growth_bonus),
			_format_growth(c_data.mag_growth_bonus), _format_growth(c_data.def_growth_bonus)
		])
		lines.append("RES %s | SPD %s | AGI %s" % [
			_format_growth(c_data.res_growth_bonus), _format_growth(c_data.spd_growth_bonus), _format_growth(c_data.agi_growth_bonus)
		])

	# Preset match: show which profile the current allocation matches (e.g. BALANCED ✓)
	var profile_name: String = _get_matching_preset_name()
	if profile_name.length() > 0:
		lines.append("")
		lines.append("PROFILE: %s ✓" % [profile_name.to_upper()])
	else:
		lines.append("")
		lines.append("PROFILE: Custom")

	lines.append("") # Spacer
	lines.append("UNSPENT POINTS: %d" % [available_points])

	build_summary_label.text = "\n".join(lines)

# =========================
# Sprite selector
# =========================
func _on_prev_sprite_pressed() -> void:
	_play_click_sound()
	_button_press_feedback(prev_sprite_btn)
	if available_sprites.is_empty():
		return
	_push_undo()
	current_sprite_index -= 1
	if current_sprite_index < 0:
		current_sprite_index = available_sprites.size() - 1
	_update_sprite_display()
	_tween_display_pop(sprite_display)
	_tween_display_pop(battle_sprite_display)
	_update_ui()

func _on_next_sprite_pressed() -> void:
	_play_click_sound()
	_button_press_feedback(next_sprite_btn)
	if available_sprites.is_empty():
		return
	_push_undo()
	current_sprite_index = (current_sprite_index + 1) % available_sprites.size()
	_update_sprite_display()
	_tween_display_pop(sprite_display)
	_tween_display_pop(battle_sprite_display)
	_update_ui()

func _update_sprite_display() -> void:
	if not available_sprites.is_empty() and current_sprite_index < available_sprites.size():
		sprite_display.texture = available_sprites[current_sprite_index]

	if not available_battle_sprites.is_empty() and current_sprite_index < available_battle_sprites.size():
		battle_sprite_display.texture = available_battle_sprites[current_sprite_index]

# =========================
# Weapon selector
# =========================
func _on_prev_weapon_pressed() -> void:
	_play_click_sound()
	_button_press_feedback(prev_weapon_btn)
	if available_starting_weapons.is_empty():
		return
	_push_undo()
	current_weapon_index = (current_weapon_index - 1 + available_starting_weapons.size()) % available_starting_weapons.size()
	_update_weapon_display()
	_tween_display_pop(weapon_display)
	_update_ui()

func _on_next_weapon_pressed() -> void:
	_play_click_sound()
	_button_press_feedback(next_weapon_btn)
	if available_starting_weapons.is_empty():
		return
	_push_undo()
	current_weapon_index = (current_weapon_index + 1) % available_starting_weapons.size()
	_update_weapon_display()
	_tween_display_pop(weapon_display)
	_update_ui()

func _update_weapon_display() -> void:
	if available_starting_weapons.is_empty():
		weapon_name_label.text = "No Weapons Found"
		weapon_display.texture = null
		return

	if current_weapon_index < 0 or current_weapon_index >= available_starting_weapons.size():
		current_weapon_index = 0

	var wpn: WeaponData = available_starting_weapons[current_weapon_index]
	if wpn == null:
		weapon_name_label.text = "Invalid Weapon"
		weapon_display.texture = null
		return

	weapon_display.texture = wpn.icon
	
	weapon_name_label.text = "%s\nMt: %d | Hit: + %d | Rng: %d-%d" % [
		wpn.weapon_name, 
		wpn.might, 
		wpn.hit_bonus, 
		wpn.min_range, 
		wpn.max_range
	]

# =========================
# Start flow
# =========================
func _on_start_button_pressed() -> void:
	_play_click_sound()
	_button_press_feedback(start_button)

	var unspent_warning: String = ""
	if available_points > 0:
		unspent_warning = "\n\nYou have %d unspent points — they'll be lost." % [available_points]
	else:
		unspent_warning = "\n\nYour build is ready."

	start_confirmation.dialog_text = "Begin your journey as " + (name_input.text.strip_edges() if name_input.text.strip_edges().length() > 0 else "Cathaldus") + "?" + unspent_warning
	start_confirmation.popup_centered()

func _on_start_confirmed() -> void:
	var player_name: String = name_input.text.strip_edges()
	if player_name == "":
		player_name = "Cathaldus"
		
	var chosen_ability: String = ability_dropdown.get_item_text(ability_dropdown.selected)
	var chosen_portrait: Texture2D = null
	var chosen_battle_sprite: Texture2D = null

	if not available_sprites.is_empty() and current_sprite_index < available_sprites.size():
		chosen_portrait = available_sprites[current_sprite_index]
	if not available_battle_sprites.is_empty() and current_sprite_index < available_battle_sprites.size():
		chosen_battle_sprite = available_battle_sprites[current_sprite_index]

	var chosen_weapon: WeaponData = null
	var starting_inventory: Array[Resource] = [] # --- FIX 5: TYPED ARRAY ---
	
	if not available_starting_weapons.is_empty() and current_weapon_index < available_starting_weapons.size():
		chosen_weapon = CampaignManager.duplicate_item(available_starting_weapons[current_weapon_index])
		starting_inventory.append(chosen_weapon)
	
	var selected_class_name: String = "Mercenary"
	var selected_class_res: ClassData = null
	var starting_move_range: int = 5
	var starting_move_type: int = 0 
	
	if class_dropdown.selected >= 0 and class_dropdown.selected < available_classes.size():
		selected_class_res = available_classes[class_dropdown.selected]
		if selected_class_res:
			selected_class_name = selected_class_res.job_name
			starting_move_range = selected_class_res.move_range
			starting_move_type = selected_class_res.move_type

	CampaignManager.reset_campaign_data()

	# --- FIX 4: BULLETPROOF CUSTOM AVATAR DICT ---
	CampaignManager.custom_avatar = {
		"name": player_name,
		"unit_name": player_name,
		"stats": stats.duplicate(true),
		"class_name": selected_class_name,
		"unit_class": selected_class_name,
		"class_data": selected_class_res,
		"move_range": starting_move_range,
		"move_type": starting_move_type, 
		"portrait": chosen_portrait,
		"battle_sprite": chosen_battle_sprite,
		"ability": chosen_ability,
		"unlocked_abilities": [chosen_ability], 
		"skill_points": 0, 
		"unlocked_skills": [] 
	}

	# --- FIX 3: BULLETPROOF HERO UNIT DICT ---
	var hero_unit: Dictionary = {
		"unit_name": player_name,
		"unit_class": selected_class_name,
		"class_name": selected_class_name,
		"is_promoted": false,
		"data": null,
		"level": 1,
		"experience": 0,
		"current_hp": int(stats["hp"]),
		"max_hp": int(stats["hp"]),
		"strength": int(stats["str"]),
		"magic": int(stats["mag"]),
		"defense": int(stats["def"]),
		"resistance": int(stats["res"]),
		"speed": int(stats["spd"]),
		"agility": int(stats["agi"]),
		"move_range": starting_move_range,
		"move_type": starting_move_type, 
		"equipped_weapon": chosen_weapon,
		"inventory": starting_inventory,
		"portrait": chosen_portrait,
		"battle_sprite": chosen_battle_sprite,
		"ability": chosen_ability,
		"class_data": selected_class_res,
		"unlocked_abilities": [chosen_ability],
		"skill_points": 0,
		"unlocked_skills": []
	}
	
	match difficulty_dropdown.selected:
		0: CampaignManager.current_difficulty = CampaignManager.Difficulty.NORMAL
		1: CampaignManager.current_difficulty = CampaignManager.Difficulty.HARD
		2: CampaignManager.current_difficulty = CampaignManager.Difficulty.MADDENING

	CampaignManager.player_roster.clear()
	CampaignManager.player_roster.append(hero_unit)
	
	SceneTransition.change_scene_to_file("res://Scenes/story_sequence.tscn")
		
func _update_ability_description() -> void:
	if ability_desc_label == null:
		return
	var selected_ability := ability_dropdown.get_item_text(ability_dropdown.selected)
	ability_desc_label.text = ABILITY_DESCRIPTIONS.get(selected_ability, "No description available.")
	_tween_description_in(ability_desc_label)

func _update_difficulty_description() -> void:
	if difficulty_desc_label == null:
		return
	var selected_diff := difficulty_dropdown.get_item_text(difficulty_dropdown.selected)
	difficulty_desc_label.text = DIFFICULTY_DESCRIPTIONS.get(selected_diff, "")
	if difficulty_desc_label.text.length() > 0:
		_tween_description_in(difficulty_desc_label)

func _tween_description_in(label_control: Control) -> void:
	if label_control == null:
		return
	label_control.modulate.a = 0.7
	label_control.scale = Vector2(0.98, 0.98)
	var t := create_tween()
	t.tween_property(label_control, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(label_control, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
# =========================
# Music
# =========================
func _play_random_music() -> void:
	if menu_music_tracks.is_empty():
		return

	var random_track: AudioStream = menu_music_tracks[randi() % menu_music_tracks.size()]
	if menu_music_tracks.size() > 1 and bg_music.stream == random_track:
		_play_random_music()
		return

	bg_music.stream = random_track
	bg_music.play()

func _on_bg_music_finished() -> void:
	_play_random_music()
