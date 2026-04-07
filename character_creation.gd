extends Control

# Visual language (kept local; matches warm, gold-accent UI)
const CC_BG := Color(0.10, 0.08, 0.06, 0.98)
const CC_BG_ALT := Color(0.15, 0.11, 0.08, 0.98)
const CC_BORDER := Color(0.82, 0.67, 0.29, 0.96)
const CC_BORDER_MUTED := Color(0.52, 0.43, 0.22, 0.85)
const CC_TEXT := Color(0.96, 0.93, 0.86, 1.0)
const CC_TEXT_MUTED := Color(0.75, 0.71, 0.62, 1.0)
const CC_ACCENT := Color(0.96, 0.80, 0.32, 1.0)
const CC_ERROR := Color(0.97, 0.42, 0.38, 1.0)
const CC_METAL_TINT := Color(0.88, 0.88, 0.90, 1.0)
const CC_CLASS_DESC := Color(0.86, 0.78, 0.56, 1.0)

const UnitInfoRuntimeHelpers := preload("res://Scripts/Core/BattleField/BattleFieldDetailedUnitInfoRuntimeHelpers.gd")

# =========================
# UI REFERENCES (existing)
# =========================
@onready var name_input: LineEdit = $Panel/MainMargin/MainVBox/TopRow/MidCol/NameInput
@onready var class_dropdown: OptionButton = $Panel/MainMargin/MainVBox/TopRow/MidCol/ClassDropdown
@onready var class_desc_label: Label = $Panel/MainMargin/MainVBox/TopRow/MidCol/ClassDescLabel
@onready var ability_dropdown: OptionButton = $Panel/MainMargin/MainVBox/TopRow/MidCol/AbilityDropdown
@onready var points_label: Label = $Panel/MainMargin/MainVBox/TopRow/MidCol/PointsLabel
@onready var difficulty_dropdown: OptionButton = $Panel/MainMargin/MainVBox/TopRow/RightCol/DifficultyCard/DifficultyDropdown
@onready var difficulty_desc_label: RichTextLabel = $Panel/MainMargin/MainVBox/TopRow/RightCol/DifficultyCard/DifficultyDescLabel

# Stat value labels
@onready var hp_value: Label = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/HpValue
@onready var str_value: Label = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/StrValue
@onready var mag_value: Label = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/MagValue
@onready var def_value: Label = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/DefValue
@onready var res_value: Label = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/ResValue
@onready var spd_value: Label = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/SpdValue
@onready var agi_value: Label = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/AgiValue

# Stat bars (battlefield-style)
@onready var hp_bar: ProgressBar = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/HpBar
@onready var str_bar: ProgressBar = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/StrBar
@onready var mag_bar: ProgressBar = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/MagBar
@onready var def_bar: ProgressBar = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/DefBar
@onready var res_bar: ProgressBar = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/ResBar
@onready var spd_bar: ProgressBar = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/SpdBar
@onready var agi_bar: ProgressBar = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/AgiBar

# Stat buttons
@onready var hp_plus: Button = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/HpPlus
@onready var hp_minus: Button = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/HpMinus
@onready var str_plus: Button = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/StrPlus
@onready var str_minus: Button = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/StrMinus
@onready var mag_plus: Button = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/MagPlus
@onready var mag_minus: Button = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/MagMinus
@onready var def_plus: Button = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/DefPlus
@onready var def_minus: Button = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/DefMinus
@onready var res_plus: Button = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/ResPlus
@onready var res_minus: Button = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/ResMinus
@onready var spd_plus: Button = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/SpdPlus
@onready var spd_minus: Button = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/SpdMinus
@onready var agi_plus: Button = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/AgiPlus
@onready var agi_minus: Button = $Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/AgiMinus

# Weapon selector
@onready var weapon_display: TextureRect = $Panel/MainMargin/MainVBox/TopRow/RightCol/WeaponCard/WeaponDisplay
@onready var weapon_name_label: Label = $Panel/MainMargin/MainVBox/TopRow/RightCol/WeaponCard/WeaponNameLabel
@onready var prev_weapon_btn: Button = $Panel/MainMargin/MainVBox/TopRow/RightCol/WeaponCard/PrevWeaponButton
@onready var next_weapon_btn: Button = $Panel/MainMargin/MainVBox/TopRow/RightCol/WeaponCard/NextWeaponButton

# Sprite selector
@onready var sprite_display: TextureRect = $Panel/MainMargin/MainVBox/TopRow/LeftCol/PortraitFrame/SpriteDisplay
@onready var prev_sprite_btn: Button = $Panel/MainMargin/MainVBox/TopRow/LeftCol/SpriteNavRow/PrevSpriteButton
@onready var next_sprite_btn: Button = $Panel/MainMargin/MainVBox/TopRow/LeftCol/SpriteNavRow/NextSpriteButton
@onready var battle_sprite_display: TextureRect = $Panel/MainMargin/MainVBox/TopRow/LeftCol/BattleSpriteFrame/BattleSpriteDisplay
@onready var portrait_frame: PanelContainer = $Panel/MainMargin/MainVBox/TopRow/LeftCol/PortraitFrame

# Music & dialogs
@onready var bg_music: AudioStreamPlayer = $BackgroundMusic
@onready var click_sound: AudioStreamPlayer = $ClickSound
@onready var start_confirmation: ConfirmationDialog = $StartConfirmation

# Start button
@onready var start_button: Button = $Panel/MainMargin/MainVBox/BottomRow/BottomRight/StartCampaignButton

# Main panel (for entrance animation; no new node)
@onready var _panel: Control = $Panel

# =========================
# OPTIONAL UI (add these nodes if you want the features)
# =========================
@export var build_summary_label_path: NodePath = NodePath("Panel/MainMargin/MainVBox/BottomRow/BottomLeft/SummaryCard/SummaryMargin/SummaryVBox/SummaryScroll/BuildSummaryLabel")
@export var preset_dropdown_path: NodePath = NodePath("Panel/MainMargin/MainVBox/BottomRow/BottomLeft/SummaryCard/SummaryMargin/SummaryVBox/PresetRow/PresetDropdown")
@export var apply_preset_button_path: NodePath = NodePath("Panel/MainMargin/MainVBox/BottomRow/BottomLeft/SummaryCard/SummaryMargin/SummaryVBox/PresetRow/ApplyPresetButton")
@export var reset_button_path: NodePath = NodePath("Panel/MainMargin/MainVBox/TopRow/MidCol/ResetButton")
@export var undo_button_path: NodePath = NodePath("Panel/MainMargin/MainVBox/TopRow/MidCol/UndoButton")

@onready var build_summary_label: Label = get_node_or_null(build_summary_label_path) as Label
@onready var preset_dropdown: OptionButton = get_node_or_null(preset_dropdown_path) as OptionButton
@onready var apply_preset_button: Button = get_node_or_null(apply_preset_button_path) as Button
@onready var reset_button: Button = get_node_or_null(reset_button_path) as Button
@onready var undo_button: Button = get_node_or_null(undo_button_path) as Button

@onready var hero_brief_card: PanelContainer = $Panel/MainMargin/MainVBox/BottomRow/BottomRight/HeroBriefCard
@onready var summary_card_panel: Panel = $Panel/MainMargin/MainVBox/BottomRow/BottomLeft/SummaryCard
@onready var soft_hints_label: Label = $Panel/MainMargin/MainVBox/TopRow/MidCol/SoftHintsLabel

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
var _bars: Dictionary = {}
var _bar_sheens: Dictionary = {} # stat -> ColorRect
var _bar_tweens: Dictionary = {} # stat -> Tween

# animation control (prevents “color gets messed up” when spam clicking)
var _label_tweens: Dictionary = {} # stat -> Tween
var _lock_in_feedback_tween: Tween
var _cc_ready_done: bool = false
var _start_ready_breathe_tween: Tween
var _points_header_pulse_tween: Tween
var _portrait_ambient_tween: Tween
var _last_points_for_pulse: int = -99999 # first _update_ui skips pulse

@onready var ability_desc_label: Label = $Panel/MainMargin/MainVBox/TopRow/MidCol/AbilityDescLabel

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
	if not _cc_reduced_motion():
		_cc_hide_sections_for_stagger()

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
	
	_update_class_description()
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
	_apply_theme()
	_setup_focus_chain()
	if name_input != null:
		name_input.call_deferred("grab_focus")
	_cc_ready_done = true


func _cc_reduced_motion() -> bool:
	return CampaignManager != null and CampaignManager.interface_reduced_motion


func _setup_focus_chain() -> void:
	var chain: Array[Control] = []
	chain.append(name_input)
	chain.append(class_dropdown)
	chain.append(ability_dropdown)
	var stat_btns: Array[Button] = [
		str_minus, str_plus, mag_minus, mag_plus, hp_minus, hp_plus,
		def_minus, def_plus, res_minus, res_plus, spd_minus, spd_plus, agi_minus, agi_plus
	]
	for b in stat_btns:
		chain.append(b)
	chain.append(reset_button)
	chain.append(undo_button)
	chain.append(prev_sprite_btn)
	chain.append(next_sprite_btn)
	chain.append(prev_weapon_btn)
	chain.append(next_weapon_btn)
	chain.append(difficulty_dropdown)
	if preset_dropdown != null:
		chain.append(preset_dropdown)
	if apply_preset_button != null:
		chain.append(apply_preset_button)
	chain.append(start_button)

	var valid: Array[Control] = []
	for c in chain:
		if c != null:
			valid.append(c)
	var n: int = valid.size()
	if n < 2:
		return
	for i in range(n):
		var c: Control = valid[i]
		c.focus_mode = Control.FOCUS_ALL
		var next_c: Control = valid[(i + 1) % n]
		var prev_c: Control = valid[(i - 1 + n) % n]
		c.focus_next = c.get_path_to(next_c)
		c.focus_previous = c.get_path_to(prev_c)


func _cc_style_line_edit(input: LineEdit) -> void:
	if input == null:
		return
	input.focus_mode = Control.FOCUS_ALL
	input.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	var fs: int = input.get_theme_font_size("font_size")
	if fs <= 0:
		fs = 40
	input.add_theme_font_size_override("font_size", fs)
	input.add_theme_color_override("font_color", CC_TEXT)
	input.add_theme_color_override("font_placeholder_color", CC_TEXT_MUTED)
	input.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.92))
	input.add_theme_constant_override("outline_size", 1)
	input.add_theme_stylebox_override("normal", _make_panel_style(Color(0.09, 0.075, 0.055, 0.96), CC_BORDER_MUTED, 1, 12, 0.22, 7, 3))
	input.add_theme_stylebox_override("focus", _make_panel_style(Color(0.14, 0.11, 0.09, 0.98), CC_ACCENT, 2, 12, 0.28, 9, 3))


func _cc_style_option_button(dd: OptionButton) -> void:
	if dd == null:
		return
	dd.focus_mode = Control.FOCUS_ALL
	dd.add_theme_stylebox_override("normal", _make_panel_style(Color(0.09, 0.075, 0.055, 0.94), CC_BORDER_MUTED, 1, 12, 0.20, 6, 3))
	dd.add_theme_stylebox_override("hover", _make_panel_style(Color(0.12, 0.10, 0.075, 0.96), CC_BORDER, 1, 12, 0.26, 8, 3))
	dd.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.08, 0.065, 0.05, 0.96), CC_ACCENT, 2, 12, 0.18, 5, 2))
	dd.add_theme_stylebox_override("focus", _make_panel_style(Color(0.13, 0.11, 0.085, 0.98), CC_ACCENT, 2, 12, 0.30, 9, 3))


func _feedback_choice_locked_in() -> void:
	_play_click_sound()
	if _cc_reduced_motion():
		return
	if hero_brief_card == null and summary_card_panel == null:
		return
	if _lock_in_feedback_tween != null and _lock_in_feedback_tween.is_valid():
		_lock_in_feedback_tween.kill()
	var peak := Color(1.0, 0.97, 0.88, 1.0)
	var t := create_tween()
	_lock_in_feedback_tween = t
	t.set_parallel(true)
	if hero_brief_card != null:
		hero_brief_card.modulate = Color.WHITE
		t.tween_property(hero_brief_card, "modulate", peak, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if summary_card_panel != null:
		summary_card_panel.modulate = Color.WHITE
		t.tween_property(summary_card_panel, "modulate", peak, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.chain()
	t.set_parallel(true)
	if hero_brief_card != null:
		t.tween_property(hero_brief_card, "modulate", Color.WHITE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if summary_card_panel != null:
		t.tween_property(summary_card_panel, "modulate", Color.WHITE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _soft_validation_message() -> String:
	if available_points > 0:
		var plural := "s" if available_points != 1 else ""
		return "%d point%s unspent — allocate or begin anyway." % [available_points, plural]
	var total_spent := 0
	var max_spent := 0
	for k in STAT_KEYS:
		var s: int = int(stats.get(k, 0)) - int(base_stats.get(k, 0))
		s = maxi(0, s)
		total_spent += s
		max_spent = maxi(max_spent, s)
	if total_spent < 6:
		return ""
	if max_spent >= 9:
		return "Heavy skew: one stat dominates — viable, but fragile."
	if float(max_spent) / float(max(total_spent, 1)) >= 0.58:
		return "Heavy skew: most points in one stat — fragile."
	return ""


func _make_panel_style(fill: Color, border: Color, border_width: int = 2, radius: int = 18, shadow_alpha: float = 0.38, shadow_size: int = 14, shadow_y: int = 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0, 0, 0, shadow_alpha)
	box.shadow_size = shadow_size
	box.shadow_offset = Vector2(0, shadow_y)
	return box


func _style_small_icon_button(btn: Button, accent: Color, bg: Color = Color(0.10, 0.08, 0.06, 0.92)) -> void:
	if btn == null:
		return
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", CC_TEXT)
	btn.add_theme_color_override("font_hover_color", CC_TEXT)
	btn.add_theme_color_override("font_pressed_color", CC_TEXT)
	btn.add_theme_color_override("font_focus_color", CC_TEXT)
	btn.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.94))
	btn.add_theme_constant_override("outline_size", 2)
	btn.add_theme_stylebox_override("normal", _make_panel_style(bg, CC_BORDER_MUTED, 1, 12, 0.22, 7, 3))
	btn.add_theme_stylebox_override("hover", _make_panel_style(bg.lightened(0.06), accent, 2, 12, 0.26, 9, 3))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(bg.darkened(0.06), accent, 2, 12, 0.18, 5, 2))
	btn.add_theme_stylebox_override("focus", _make_panel_style(bg.lightened(0.05), CC_ACCENT, 2, 12, 0.26, 9, 3))


func _style_stat_step_button(btn: Button, is_plus: bool) -> void:
	if btn == null:
		return
	var accent := CC_ACCENT if is_plus else CC_TEXT_MUTED
	_style_small_icon_button(btn, accent, Color(0.09, 0.075, 0.055, 0.94))
	btn.custom_minimum_size = Vector2(34, 32)


func _style_dropdown_popup(dd: OptionButton) -> void:
	if dd == null:
		return
	var popup := dd.get_popup()
	if popup == null:
		return
	# PopupMenu theme
	popup.add_theme_stylebox_override("panel", _make_panel_style(CC_BG_ALT, CC_BORDER_MUTED, 1, 12, 0.22, 8, 3))
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.22, 0.17, 0.10, 0.95)
	hover.border_color = CC_BORDER
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(10)
	popup.add_theme_stylebox_override("hover", hover)
	popup.add_theme_color_override("font_color", CC_TEXT_MUTED)
	popup.add_theme_color_override("font_hover_color", CC_TEXT)
	popup.add_theme_color_override("font_disabled_color", CC_TEXT_MUTED.darkened(0.25))
	popup.add_theme_color_override("font_separator_color", CC_BORDER_MUTED)
	popup.add_theme_constant_override("v_separation", 8)
	popup.add_theme_constant_override("outline_size", 0)
	popup.add_theme_constant_override("icon_max_width", 0)
	# Slightly taller rows
	popup.add_theme_constant_override("item_start_padding", 14)
	popup.add_theme_constant_override("item_end_padding", 14)
	popup.add_theme_constant_override("item_top_padding", 8)
	popup.add_theme_constant_override("item_bottom_padding", 8)


func _apply_theme() -> void:
	# Main card
	var panel := _panel
	if panel != null:
		var style := _make_panel_style(CC_BG, CC_BORDER, 2, 22, 0.42, 16, 7)
		if panel is Panel:
			(panel as Panel).add_theme_stylebox_override("panel", style)

		for card_name in ["WeaponCard", "DifficultyCard"]:
			var card := panel.get_node_or_null("MainMargin/MainVBox/TopRow/RightCol/%s" % card_name) as Panel
			if card != null:
				var r_style := _make_panel_style(CC_BG_ALT, CC_BORDER_MUTED, 1, 18, 0.30, 10, 4)
				card.add_theme_stylebox_override("panel", r_style)

		for frame_name in ["PortraitFrame", "BattleSpriteFrame"]:
			var frame := panel.get_node_or_null("MainMargin/MainVBox/TopRow/LeftCol/%s" % frame_name) as PanelContainer
			if frame != null:
				var f_style := _make_panel_style(Color(0.08, 0.07, 0.05, 0.96), CC_BORDER_MUTED, 1, 16, 0.22, 8, 3)
				frame.add_theme_stylebox_override("panel", f_style)

		var right_info := panel.get_node_or_null("MainMargin/MainVBox/TopRow/RightCol/RightInfoCard") as Panel
		if right_info != null:
			var i_style := _make_panel_style(Color(0.08, 0.07, 0.05, 0.96), CC_BORDER_MUTED, 1, 18, 0.26, 9, 3)
			right_info.add_theme_stylebox_override("panel", i_style)

		var hero_brief := panel.get_node_or_null("MainMargin/MainVBox/BottomRow/BottomRight/HeroBriefCard") as PanelContainer
		if hero_brief != null:
			var hb_style := _make_panel_style(Color(0.08, 0.07, 0.05, 0.96), CC_BORDER_MUTED, 1, 18, 0.26, 9, 3)
			hero_brief.add_theme_stylebox_override("panel", hb_style)

		var summary_card := panel.get_node_or_null("MainMargin/MainVBox/BottomRow/BottomLeft/SummaryCard") as Panel
		if summary_card != null:
			var s_style := _make_panel_style(Color(0.08, 0.06, 0.04, 0.98), CC_BORDER_MUTED, 1, 16, 0.26, 9, 3)
			summary_card.add_theme_stylebox_override("panel", s_style)

	# Headline labels
	for path in [
		"Panel/Label",
		"Panel/Label2",
		"Panel/Label3"
	]:
		var lbl := get_node_or_null(path) as Label
		if lbl != null:
			lbl.add_theme_color_override("font_color", CC_TEXT)
			lbl.add_theme_font_size_override("font_size", 20)

	# Section labels (new container layout)
	for path in [
		"Panel/MainMargin/MainVBox/TopRow/LeftCol/Section_Appearance",
		"Panel/MainMargin/MainVBox/TopRow/MidCol/Section_Training",
		"Panel/MainMargin/MainVBox/TopRow/RightCol/Section_Loadout",
		"Panel/MainMargin/MainVBox/BottomRow/BottomLeft/SummaryCard/SummaryMargin/SummaryVBox/DossierTitle",
	]:
		var s := get_node_or_null(path) as Label
		if s != null:
			s.add_theme_color_override("font_color", CC_ACCENT)
			s.add_theme_font_size_override("font_size", 18)
			s.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.92))
			s.add_theme_constant_override("outline_size", 2)

	for path in [
		"Panel/MainMargin/MainVBox/TopRow/LeftCol/PortraitLabel",
		"Panel/MainMargin/MainVBox/TopRow/LeftCol/BattleSpriteLabel",
	]:
		var sub := get_node_or_null(path) as Label
		if sub != null:
			sub.add_theme_color_override("font_color", CC_TEXT_MUTED)
			sub.add_theme_font_size_override("font_size", 14)
			sub.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.92))
			sub.add_theme_constant_override("outline_size", 2)

	points_label.add_theme_color_override("font_color", CC_ACCENT)

	_cc_style_line_edit(name_input)

	if soft_hints_label != null:
		soft_hints_label.add_theme_color_override("font_color", CC_TEXT_MUTED)
		soft_hints_label.add_theme_font_size_override("font_size", 14)

	# Stat labels & values
	for lbl in [
		$Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/Label,
		$Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/Label2,
		$Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/Label3,
		$Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/Label4,
		$Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/Label5,
		$Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/Label6,
		$Panel/MainMargin/MainVBox/TopRow/MidCol/GridContainer/Label7
	]:
		if lbl != null:
			lbl.add_theme_color_override("font_color", CC_TEXT_MUTED)

	for v in [hp_value, str_value, mag_value, def_value, res_value, spd_value, agi_value]:
		if v != null:
			v.add_theme_color_override("font_color", CC_TEXT)

	# Dropdowns & difficulty
	for dd in [class_dropdown, ability_dropdown, difficulty_dropdown, preset_dropdown]:
		if dd != null:
			_cc_style_option_button(dd)
			dd.add_theme_color_override("font_color", CC_TEXT)
			dd.add_theme_color_override("font_hover_color", CC_ACCENT)
			dd.add_theme_color_override("font_focus_color", CC_TEXT)
			_style_dropdown_popup(dd)

	if class_desc_label != null:
		class_desc_label.add_theme_color_override("font_color", CC_CLASS_DESC)

	if difficulty_desc_label != null:
		difficulty_desc_label.add_theme_color_override("default_color", CC_TEXT_MUTED)

	if build_summary_label != null:
		build_summary_label.add_theme_color_override("font_color", CC_TEXT_MUTED)

	var brief_title := get_node_or_null("Panel/MainMargin/MainVBox/TopRow/RightCol/RightInfoCard/Margin/VBox/Title") as Label
	if brief_title != null:
		brief_title.add_theme_color_override("font_color", CC_ACCENT)
		brief_title.add_theme_font_size_override("font_size", 16)
	var brief_body := get_node_or_null("Panel/MainMargin/MainVBox/TopRow/RightCol/RightInfoCard/Margin/VBox/Body") as Label
	if brief_body != null:
		brief_body.add_theme_color_override("font_color", CC_TEXT_MUTED)

	var hero_title := get_node_or_null("Panel/MainMargin/MainVBox/BottomRow/BottomRight/HeroBriefCard/Margin/VBox/Title") as Label
	if hero_title != null:
		hero_title.add_theme_color_override("font_color", CC_ACCENT)
		hero_title.add_theme_font_size_override("font_size", 16)
	var hero_body := get_node_or_null("Panel/MainMargin/MainVBox/BottomRow/BottomRight/HeroBriefCard/Margin/VBox/Body") as Label
	if hero_body != null:
		hero_body.add_theme_color_override("font_color", CC_TEXT_MUTED)

	# Stat +/- controls
	for key in STAT_KEYS:
		_style_stat_step_button(_plus_buttons.get(key) as Button, true)
		_style_stat_step_button(_minus_buttons.get(key) as Button, false)

	# Sprite / weapon arrows + utility buttons
	_style_small_icon_button(prev_sprite_btn, CC_ACCENT)
	_style_small_icon_button(next_sprite_btn, CC_ACCENT)
	_style_small_icon_button(prev_weapon_btn, CC_ACCENT)
	_style_small_icon_button(next_weapon_btn, CC_ACCENT)
	_style_small_icon_button(reset_button, Color(0.62, 0.92, 1.0, 1.0))
	_style_small_icon_button(undo_button, Color(0.62, 0.92, 1.0, 1.0))
	_style_small_icon_button(apply_preset_button, Color(0.58, 1.0, 0.68, 1.0))


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
	_bars = {
		"hp": hp_bar, "str": str_bar, "mag": mag_bar,
		"def": def_bar, "res": res_bar, "spd": spd_bar, "agi": agi_bar
	}
	_bar_sheens.clear()
	for k in STAT_KEYS:
		var b := _bars.get(k) as ProgressBar
		if b == null:
			continue
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sheen: ColorRect = UnitInfoRuntimeHelpers.attach_unit_info_bar_sheen(self, b)
		if sheen != null:
			# Stronger, more "metallic" sweep for thicker bars.
			sheen.color = Color(1.0, 1.0, 1.0, 0.16)
			sheen.size = Vector2(56, 44)
			sheen.rotation_degrees = 12.0
		_bar_sheens[k] = sheen
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

	class_dropdown.item_selected.connect(_on_class_changed)
	
	difficulty_dropdown.item_selected.connect(func(_i): 
		_update_difficulty_description()
		if _cc_ready_done:
			_feedback_choice_locked_in()
	)
	
	# Sprite buttons
	prev_sprite_btn.pressed.connect(_on_prev_sprite_pressed)
	next_sprite_btn.pressed.connect(_on_next_sprite_pressed)

	# Weapon buttons
	prev_weapon_btn.pressed.connect(_on_prev_weapon_pressed)
	next_weapon_btn.pressed.connect(_on_next_weapon_pressed)

	ability_dropdown.item_selected.connect(func(_i): 
		_update_ability_description()
		_update_ui()
		if _cc_ready_done:
			_feedback_choice_locked_in()
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
	_apply_selected_class_base(_cc_ready_done)
	_update_class_description()
	if _cc_ready_done:
		_feedback_choice_locked_in()

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
func _cc_section_column_nodes() -> Array[Control]:
	return [
		get_node_or_null("Panel/MainMargin/MainVBox/TopRow/LeftCol") as Control,
		get_node_or_null("Panel/MainMargin/MainVBox/TopRow/MidCol") as Control,
		get_node_or_null("Panel/MainMargin/MainVBox/TopRow/RightCol") as Control,
		get_node_or_null("Panel/MainMargin/MainVBox/BottomRow") as Control,
	]


func _cc_hide_sections_for_stagger() -> void:
	for c in _cc_section_column_nodes():
		if c != null:
			c.modulate.a = 0.0


func _play_cc_section_stagger() -> void:
	if _cc_reduced_motion():
		return
	var cols := _cc_section_column_nodes()
	var any: bool = false
	for c in cols:
		if c != null:
			any = true
			break
	if not any:
		_cc_start_portrait_ambient()
		return
	var step: float = 0.085
	var dur: float = 0.36
	var t := create_tween()
	t.set_parallel(false)
	var first := true
	for c in cols:
		if c == null:
			continue
		if not first:
			t.tween_interval(step)
		first = false
		t.tween_property(c, "modulate:a", 1.0, dur).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.finished.connect(_cc_start_portrait_ambient, CONNECT_ONE_SHOT)


func _cc_start_portrait_ambient() -> void:
	if _cc_reduced_motion() or portrait_frame == null:
		return
	if _portrait_ambient_tween != null and _portrait_ambient_tween.is_valid():
		return
	call_deferred("_cc_apply_portrait_pivot")
	var tw := create_tween()
	_portrait_ambient_tween = tw
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(portrait_frame, "scale", Vector2(1.014, 1.014), 2.8)
	tw.tween_property(portrait_frame, "scale", Vector2.ONE, 2.8)


func _cc_apply_portrait_pivot() -> void:
	if portrait_frame == null:
		return
	portrait_frame.pivot_offset = portrait_frame.size * 0.5


func _animate_points_header_pulse() -> void:
	if points_label == null:
		return
	if _points_header_pulse_tween != null and _points_header_pulse_tween.is_valid():
		_points_header_pulse_tween.kill()
	points_label.scale = Vector2.ONE
	var t := create_tween()
	_points_header_pulse_tween = t
	t.tween_property(points_label, "scale", Vector2(1.06, 1.06), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(points_label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_start_ready_breathe() -> void:
	if start_button == null:
		return
	if _cc_reduced_motion():
		start_button.modulate = Color.WHITE if available_points == 0 else Color(0.92, 0.92, 0.92)
		return
	if available_points != 0:
		if _start_ready_breathe_tween != null and _start_ready_breathe_tween.is_valid():
			_start_ready_breathe_tween.kill()
		_start_ready_breathe_tween = null
		start_button.modulate = Color(0.92, 0.92, 0.92)
		return
	if _start_ready_breathe_tween != null and _start_ready_breathe_tween.is_valid():
		return
	start_button.modulate = Color.WHITE
	var t := create_tween()
	_start_ready_breathe_tween = t
	t.set_loops()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(start_button, "modulate", Color(1.08, 0.97, 0.82, 1.0), 1.4)
	t.tween_property(start_button, "modulate", Color.WHITE, 1.4)


func _play_panel_entrance() -> void:
	if _panel == null:
		return
	if _cc_reduced_motion():
		_panel.scale = Vector2.ONE
		_panel.modulate.a = 1.0
		return
	_panel.scale = Vector2(0.97, 0.97)
	_panel.modulate.a = 0.0
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BACK)
	t.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.25)
	t.parallel().tween_property(_panel, "modulate:a", 1.0, 0.2)
	t.finished.connect(_play_cc_section_stagger, CONNECT_ONE_SHOT)

func _button_press_feedback(btn: Button) -> void:
	if btn == null:
		return
	if _cc_reduced_motion():
		return
	var t := create_tween()
	t.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _style_start_button() -> void:
	if start_button == null:
		return
	start_button.text = "BEGIN CAMPAIGN"
	start_button.add_theme_font_size_override("font_size", 28)
	var normal := _make_panel_style(Color(0.75, 0.61, 0.22, 0.98), CC_BORDER, 2, 18, 0.30, 10, 4)
	var hover := _make_panel_style(Color(0.83, 0.68, 0.26, 0.98), CC_BORDER, 2, 18, 0.34, 12, 4)
	var pressed := _make_panel_style(Color(0.59, 0.47, 0.17, 0.98), CC_BORDER, 2, 18, 0.24, 7, 2)
	start_button.add_theme_stylebox_override("normal", normal)
	start_button.add_theme_stylebox_override("hover", hover)
	start_button.add_theme_stylebox_override("pressed", pressed)
	start_button.add_theme_stylebox_override("focus", _make_panel_style(Color(0.83, 0.68, 0.26, 0.98), CC_ACCENT, 2, 18, 0.34, 12, 4))

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
	if _cc_reduced_motion():
		control.scale = Vector2.ONE
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
	var bar := _bars.get(stat_name) as ProgressBar
	if bar != null:
		bar.min_value = 0
		bar.max_value = cap
		UnitInfoRuntimeHelpers.style_unit_info_stat_bar(self, bar, _stat_bar_fill(stat_name), val >= cap)
		_animate_stat_bar_to(stat_name, float(val), val >= cap)


func _animate_stat_bar_to(stat_name: String, target_value: float, _overcap: bool) -> void:
	var bar := _bars.get(stat_name) as ProgressBar
	if bar == null:
		return
	var existing := _bar_tweens.get(stat_name) as Tween
	if existing != null:
		existing.kill()
	var tw := create_tween()
	_bar_tweens[stat_name] = tw
	tw.tween_property(bar, "value", target_value, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var sheen := _bar_sheens.get(stat_name) as ColorRect
	if sheen != null:
		_animate_cc_bar_sheen(sheen, bar)


func _animate_cc_bar_sheen(sheen: ColorRect, bar: ProgressBar) -> void:
	if sheen == null or bar == null:
		return
	var bar_w: float = maxf(maxf(bar.size.x, bar.custom_minimum_size.x), 120.0)
	var bar_h: float = maxf(maxf(bar.size.y, bar.custom_minimum_size.y), 16.0)

	# Center the glint vertically for thicker bars.
	var start_x := -sheen.size.x - 22.0
	var y := -((sheen.size.y - bar_h) * 0.5)
	sheen.position = Vector2(start_x, y)
	sheen.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_property(sheen, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(sheen, "position:x", bar_w + 18.0, 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(sheen, "modulate:a", 0.0, 0.12)


func _stat_bar_fill(stat_name: String) -> Color:
	match stat_name:
		"hp":
			return Color(0.94, 0.32, 0.30, 1.0).lerp(CC_METAL_TINT, 0.22)
		"str":
			return Color(0.96, 0.58, 0.24, 1.0).lerp(CC_METAL_TINT, 0.22)
		"mag":
			return Color(0.62, 0.62, 1.0, 1.0).lerp(CC_METAL_TINT, 0.22)
		"def":
			return Color(0.42, 0.88, 0.54, 1.0).lerp(CC_METAL_TINT, 0.22)
		"res":
			return Color(0.38, 0.90, 0.82, 1.0).lerp(CC_METAL_TINT, 0.22)
		"spd":
			return Color(0.46, 0.76, 1.0, 1.0).lerp(CC_METAL_TINT, 0.22)
		"agi":
			return Color(0.96, 0.82, 0.44, 1.0).lerp(CC_METAL_TINT, 0.22)
		_:
			return CC_ACCENT.lerp(CC_METAL_TINT, 0.22)

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
	_feedback_choice_locked_in()

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

	var points_changed: bool = false
	if _last_points_for_pulse != -99999:
		points_changed = _last_points_for_pulse != available_points
	_last_points_for_pulse = available_points
	if points_changed and not _cc_reduced_motion():
		_animate_points_header_pulse()

	# Start button: copy + readiness cue + optional breathe when all points spent
	if start_button != null:
		start_button.text = "Begin Journey" + (" • Ready!" if available_points == 0 else "")
		_refresh_start_ready_breathe()

	if soft_hints_label != null:
		var hint_msg: String = _soft_validation_message()
		soft_hints_label.text = hint_msg
		soft_hints_label.visible = not hint_msg.is_empty()
		if not hint_msg.is_empty():
			if available_points > 0:
				soft_hints_label.add_theme_color_override("font_color", Color(0.55, 0.88, 0.62, 1.0))
			else:
				soft_hints_label.add_theme_color_override("font_color", Color(0.95, 0.72, 0.45, 1.0))

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
	_update_right_brief()


func _cc_weapon_short_name() -> String:
	if not available_starting_weapons.is_empty() and current_weapon_index >= 0 and current_weapon_index < available_starting_weapons.size():
		var w: WeaponData = available_starting_weapons[current_weapon_index]
		if w != null:
			var wn := str(w.weapon_name).strip_edges()
			if not wn.is_empty():
				return wn
	if weapon_name_label != null:
		var raw := weapon_name_label.text.strip_edges()
		var nl := raw.find("\n")
		if nl >= 0:
			raw = raw.substr(0, nl).strip_edges()
		if not raw.is_empty():
			return raw
	return "bare hope and borrowed steel"


func _brief_is_named() -> bool:
	return name_input != null and not name_input.text.strip_edges().is_empty()


func _brief_subject() -> String:
	if _brief_is_named():
		return name_input.text.strip_edges()
	return "This recruit"


func _hero_brief_variant() -> int:
	var a: int = class_dropdown.selected if class_dropdown else 0
	var b: int = ability_dropdown.selected if ability_dropdown else 0
	var mix: int = ((a * 131 + b) * 17 + current_weapon_index * 7) & 0x7FFFFFFF
	if name_input != null:
		mix = (mix * 31 + hash(name_input.text)) & 0x7FFFFFFF
	return int(mix) % 6


func _compose_hero_brief_text() -> String:
	var subject := _brief_subject()
	var cls := ""
	if class_dropdown != null and class_dropdown.selected >= 0:
		cls = class_dropdown.get_item_text(class_dropdown.selected).strip_edges()
	if cls.is_empty():
		cls = "soldier"
	var abil := ""
	if ability_dropdown != null and ability_dropdown.selected >= 0:
		abil = ability_dropdown.get_item_text(ability_dropdown.selected).strip_edges()
	if abil.is_empty():
		abil = "their knack"
	var wpn := _cc_weapon_short_name()
	var v: int = _hero_brief_variant()

	var l1: String
	var l2: String
	var l3: String
	match v:
		0:
			l1 = "%s steps toward the Rift—one more tale the embers will try to eat." % subject
			l2 = "As a %s, they keep %s like a vow: close, familiar, earned." % [cls, wpn]
			l3 = "%s is not something they buckle on. It rises with the breath before the blow." % abil
		1:
			l1 = "The war-log gains a line: %s." % subject
			l2 = "Steel names itself %s; the ledger names them %s." % [wpn, cls]
			l3 = "When the moment narrows, %s answers—instinct, not inventory." % abil
		2:
			l1 = "%s listens for the horn the way others listen for rain on a roof." % subject
			l2 = "Their kit is plain: %s. Their pedigree reads %s." % [wpn, cls]
			l3 = "The third truth is %s—a knack blood knows before the mind agrees." % abil
		3:
			l1 = "%s does not bargain with the Rift. They bargain with themselves." % subject
			l2 = "Discipline of a %s; comfort with %s that only veterans recognize on sight." % [cls, wpn]
			l3 = "%s waits behind the eyes—patient until patience is a lie." % abil
		4:
			if _brief_is_named():
				l1 = "Another soul chooses the breach. This one is %s." % subject
			else:
				l1 = "Another soul chooses the breach—nameless still, but not hollow."
			l2 = "On the field they read as %s; in the hand, %s." % [cls, wpn]
			l3 = "What no drill teaches is %s—only the line reveals it." % abil
		_:
			l1 = "%s carries a quiet kind of thunder—useful, and a little dangerous." % subject
			l2 = "As a %s, they trust %s the way others trust compass north." % [cls, wpn]
			l3 = "%s is the wild card: not carried, but called up when the world goes sharp." % abil

	return "%s\n%s\n%s" % [l1, l2, l3]


func _update_right_brief() -> void:
	var body := get_node_or_null("Panel/MainMargin/MainVBox/TopRow/RightCol/RightInfoCard/Margin/VBox/Body") as Label
	if body == null:
		return
	var weapon_one := _cc_weapon_short_name()
	var ability_name := ""
	if ability_dropdown != null and ability_dropdown.selected >= 0:
		ability_name = ability_dropdown.get_item_text(ability_dropdown.selected)
	var diff_name := ""
	if difficulty_dropdown != null and difficulty_dropdown.selected >= 0:
		diff_name = difficulty_dropdown.get_item_text(difficulty_dropdown.selected)
	body.text = "Knack: %s\nDifficulty: %s\nArms: %s" % [ability_name, diff_name, weapon_one]

	var hero_body := get_node_or_null("Panel/MainMargin/MainVBox/BottomRow/BottomRight/HeroBriefCard/Margin/VBox/Body") as Label
	if hero_body == null:
		return
	hero_body.text = _compose_hero_brief_text()

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
	_button_press_feedback(prev_weapon_btn)
	if available_starting_weapons.is_empty():
		return
	_push_undo()
	current_weapon_index = (current_weapon_index - 1 + available_starting_weapons.size()) % available_starting_weapons.size()
	_update_weapon_display()
	_tween_display_pop(weapon_display)
	_update_ui()
	_feedback_choice_locked_in()

func _on_next_weapon_pressed() -> void:
	_button_press_feedback(next_weapon_btn)
	if available_starting_weapons.is_empty():
		return
	_push_undo()
	current_weapon_index = (current_weapon_index + 1) % available_starting_weapons.size()
	_update_weapon_display()
	_tween_display_pop(weapon_display)
	_update_ui()
	_feedback_choice_locked_in()

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
		"unlocked_skills": [],
		"traits": [],
		"rookie_legacies": [],
		"base_class_legacies": [],
		"promoted_class_legacies": []
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


func _update_class_description() -> void:
	if class_desc_label == null or class_dropdown == null:
		return
	var c_data: ClassData = null
	if class_dropdown.selected >= 0 and class_dropdown.selected < available_classes.size():
		c_data = available_classes[class_dropdown.selected]
	if c_data == null:
		class_desc_label.text = ""
		return
	var txt := str(c_data.description).strip_edges()
	if txt.is_empty():
		txt = "Move: %d" % int(c_data.move_range)
	class_desc_label.text = txt
	_tween_description_in(class_desc_label)

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
	if _cc_reduced_motion():
		label_control.modulate.a = 1.0
		label_control.scale = Vector2.ONE
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
