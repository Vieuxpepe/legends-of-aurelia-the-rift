extends Control
const ROADMAP_MILESTONE_DATA_SCRIPT: GDScript = preload("res://Scripts/UI/Roadmap/RoadmapMilestoneData.gd")

const MENU_BG := Color(0.12, 0.10, 0.07, 0.96)
const MENU_BG_ALT := Color(0.17, 0.13, 0.09, 0.96)
const MENU_BORDER := Color(0.82, 0.67, 0.29, 0.96)
const MENU_BORDER_MUTED := Color(0.52, 0.43, 0.22, 0.80)
const MENU_TEXT := Color(0.96, 0.93, 0.86, 1.0)
const MENU_TEXT_MUTED := Color(0.73, 0.69, 0.60, 0.96)
const MENU_ACCENT := Color(0.95, 0.79, 0.28, 1.0)
const MENU_ACCENT_SOFT := Color(0.58, 0.87, 1.0, 1.0)
const MENU_SUCCESS := Color(0.52, 0.92, 0.60, 1.0)
const MENU_WARNING := Color(0.96, 0.67, 0.34, 1.0)
const MENU_ERROR := Color(0.97, 0.42, 0.38, 1.0)
const DISPATCH_LEADERBOARD := "main_menu_dispatch"
const DISPATCH_CATEGORIES := ["NEWS", "MODIFICATIONS", "OTHER"]
const DISPATCH_APPROVED_STEAM_IDS: Array[String] = []
const DISPATCH_ALLOW_DEBUG_EDITOR := true
const STUDIO_HANDOFF_META_FLAG := "studio_intro_black_handoff"
const STUDIO_HANDOFF_META_FADE := "studio_intro_black_handoff_fade"

@onready var backdrop_art: TextureRect = $BackdropArt
@onready var backdrop_shade: ColorRect = $BackdropShade
@onready var backdrop_warmth: ColorRect = $BackdropWarmth
@onready var intel_panel: Control = $IntelPanel
@onready var intel_card: PanelContainer = $IntelPanel/IntelCard
@onready var dispatch_panel: Control = $DispatchPanel
@onready var dispatch_card: PanelContainer = $DispatchPanel/DispatchCard
@onready var main_vbox: Control = $CenterStage/MainPanel
@onready var campaign_vbox: Control = $CenterStage/CampaignMenu

@onready var start_button: Button = $CenterStage/MainPanel/Margin/VBox/StartButton
@onready var settings_button: Button = $CenterStage/MainPanel/Margin/VBox/SettingsButton
@onready var profile_button: Button = $CenterStage/MainPanel/Margin/VBox/ProfileButton
@onready var credits_button: Button = $CenterStage/MainPanel/Margin/VBox/CreditsButton
@onready var roadmap_button: Button = $CenterStage/MainPanel/Margin/VBox/RoadmapButton
@onready var achievements_button: Button = $CenterStage/MainPanel/Margin/VBox/AchievementsButton
@onready var quit_button: Button = $CenterStage/MainPanel/Margin/VBox/QuitButton

@onready var continue_button: Button = $CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/ContinueButton
@onready var new_game_button: Button = $CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/NewGameButton
@onready var load_game_button: Button = $CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/LoadGameButton
@onready var back_button: Button = $CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/BackButton
@onready var slots_container: VBoxContainer = $CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/SlotsContainer

@onready var auto_slot_1_btn: Button = $CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/SlotsContainer/SlotRow1/AutoSlot1Button
@onready var auto_slot_2_btn: Button = $CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/SlotsContainer/SlotRow2/AutoSlot2Button
@onready var auto_slot_3_btn: Button = $CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/SlotsContainer/SlotRow3/AutoSlot3Button

@onready var slot_1_btn: Button = $CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/SlotsContainer/SlotRow1/Slot1Button
@onready var slot_2_btn: Button = $CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/SlotsContainer/SlotRow2/Slot2Button
@onready var slot_3_btn: Button = $CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/SlotsContainer/SlotRow3/Slot3Button

@onready var del_slot_1_btn: Button = $CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/SlotsContainer/SlotRow1/DeleteSlot1
@onready var del_slot_2_btn: Button = $CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/SlotsContainer/SlotRow2/DeleteSlot2
@onready var del_slot_3_btn: Button = $CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/SlotsContainer/SlotRow3/DeleteSlot3
@onready var delete_dialog: ConfirmationDialog = $DeleteConfirmation
@onready var overwrite_dialog: ConfirmationDialog = $OverwriteConfirmation
@onready var dispatch_editor_dialog: ConfirmationDialog = $DispatchEditorDialog

@onready var intel_rule: ColorRect = $IntelPanel/IntelCard/Margin/VBox/IntelRule
@onready var dispatch_rule: ColorRect = $DispatchPanel/DispatchCard/Margin/VBox/DispatchRule
@onready var dispatch_meta_label: Label = $DispatchPanel/DispatchCard/Margin/VBox/DispatchMeta
@onready var dispatch_scroll: ScrollContainer = $DispatchPanel/DispatchCard/Margin/VBox/DispatchScroll
@onready var dispatch_body_label: RichTextLabel = $DispatchPanel/DispatchCard/Margin/VBox/DispatchScroll/DispatchBody
@onready var dispatch_category_label: Label = $DispatchPanel/DispatchCard/Margin/VBox/Footer/DispatchInfoRow/DispatchCategory
@onready var dispatch_status_label: Label = $DispatchPanel/DispatchCard/Margin/VBox/Footer/DispatchInfoRow/DispatchStatus
@onready var edit_dispatch_button: Button = $DispatchPanel/DispatchCard/Margin/VBox/Footer/DispatchActionsRow/EditDispatchButton
@onready var dispatch_category_option: OptionButton = $DispatchEditorDialog/Margin/VBox/DispatchCategoryOption
@onready var dispatch_headline_edit: LineEdit = $DispatchEditorDialog/Margin/VBox/DispatchHeadlineEdit
@onready var dispatch_body_edit: TextEdit = $DispatchEditorDialog/Margin/VBox/DispatchBodyEdit
@onready var roadmap_dialog: AcceptDialog = $RoadmapDialog
@onready var roadmap_overline_label: Label = $RoadmapDialog/Margin/VBox/RoadmapOverline
@onready var roadmap_title_label: Label = $RoadmapDialog/Margin/VBox/RoadmapTitle
@onready var roadmap_hint_label: Label = $RoadmapDialog/Margin/VBox/RoadmapHint
@onready var roadmap_rule: ColorRect = $RoadmapDialog/Margin/VBox/RoadmapRule
@onready var roadmap_progress_row: HBoxContainer = $RoadmapDialog/Margin/VBox/RoadmapProgressRow
@onready var roadmap_progress_label: Label = $RoadmapDialog/Margin/VBox/RoadmapProgressRow/RoadmapProgressLabel
@onready var roadmap_progress_bar: ProgressBar = $RoadmapDialog/Margin/VBox/RoadmapProgressRow/RoadmapProgressBar
@onready var roadmap_progress_value: Label = $RoadmapDialog/Margin/VBox/RoadmapProgressRow/RoadmapProgressValue
@onready var roadmap_scroll: ScrollContainer = $RoadmapDialog/Margin/VBox/RoadmapScroll
@onready var roadmap_canvas: Control = $RoadmapDialog/Margin/VBox/RoadmapScroll/RoadmapCanvas
@onready var achievements_dialog: AcceptDialog = $AchievementsDialog
@onready var achievements_overline_label: Label = $AchievementsDialog/Margin/VBox/AchievementsOverline
@onready var achievements_title_label: Label = $AchievementsDialog/Margin/VBox/AchievementsTitle
@onready var achievements_hint_label: Label = $AchievementsDialog/Margin/VBox/AchievementsHint
@onready var achievements_rule: ColorRect = $AchievementsDialog/Margin/VBox/AchievementsRule
@onready var achievements_placeholder_label: Label = $AchievementsDialog/Margin/VBox/AchievementsPlaceholder
@onready var profile_dialog: Window = $ProfileDialog
@onready var profile_scroll: ScrollContainer = $ProfileDialog/Margin/Scroll
@onready var profile_overline_label: Label = $ProfileDialog/Margin/Scroll/VBox/ProfileOverline
@onready var profile_resolved_headline: Label = $ProfileDialog/Margin/Scroll/VBox/ProfileResolvedHeadline
@onready var profile_steam_name_line: Label = $ProfileDialog/Margin/Scroll/VBox/ProfileSteamNameLine
@onready var profile_override_line: Label = $ProfileDialog/Margin/Scroll/VBox/ProfileOverrideLine
@onready var profile_fallback_line: Label = $ProfileDialog/Margin/Scroll/VBox/ProfileFallbackLine
@onready var profile_coop_line: Label = $ProfileDialog/Margin/Scroll/VBox/ProfileCoopLine
@onready var profile_steam_status_label: Label = $ProfileDialog/Margin/Scroll/VBox/ProfileSteamActionsRow/ProfileSteamStatusLabel
@onready var profile_view_steam_button: Button = $ProfileDialog/Margin/Scroll/VBox/ProfileSteamActionsRow/ProfileViewSteamButton
@onready var profile_campaign_overline: Label = $ProfileDialog/Margin/Scroll/VBox/ProfileCampaignOverline
@onready var profile_campaign_body: Label = $ProfileDialog/Margin/Scroll/VBox/ProfileCampaignBody
@onready var profile_edit_overline: Label = $ProfileDialog/Margin/Scroll/VBox/ProfileEditOverline
@onready var profile_hint_label: Label = $ProfileDialog/Margin/Scroll/VBox/ProfileHint
@onready var profile_rule: ColorRect = $ProfileDialog/Margin/Scroll/VBox/ProfileRule
@onready var profile_name_edit: LineEdit = $ProfileDialog/Margin/Scroll/VBox/ProfileNameEdit
@onready var profile_use_steam_button: Button = $ProfileDialog/Margin/Scroll/VBox/ProfileUseSteamRow/ProfileUseSteamButton
@onready var profile_save_button: Button = $ProfileDialog/Margin/Scroll/VBox/ProfileUseSteamRow/ProfileSaveButton
@onready var steam_profile_corner: Control = $SteamProfileCorner
@onready var steam_avatar_frame: PanelContainer = $SteamProfileCorner/SteamCornerVBox/SteamAvatarFrame
@onready var steam_avatar_button: TextureButton = $SteamProfileCorner/SteamCornerVBox/SteamAvatarFrame/Margin/SteamAvatarButton
@onready var steam_playing_as_label: Label = $SteamProfileCorner/SteamCornerVBox/SteamPlayingAsLabel
@onready var main_menu_version_footer: Label = $MainMenuVersionFooter

var pending_delete_slot: int = 0
var _dispatch_payload: Dictionary = {}

var SFX_HOVER: AudioStream = preload("res://audio/menu_hover.wav")
var SFX_CLICK: AudioStream = preload("res://audio/menu_click.wav")
var MENU_MUSIC: AudioStream = preload("res://audio/Menu Music (Remastered).wav")

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _startup_black_overlay: ColorRect = null
var _startup_black_tween: Tween = null

const CREDITS_SCENE_PATH := "res://Scenes/credits_scene.tscn"
@export_group("Roadmap Data")
@export var roadmap_use_default_if_empty: bool = true
@export var roadmap_milestones: Array[Resource] = []
const DEFAULT_ROADMAP_MILESTONES: Array[Dictionary] = [
	{
		"phase": "MILESTONE 01",
		"title": "TACTICAL FOUNDATION",
		"eta": "COMPLETED",
		"status": "COMPLETED",
		"summary": "Core turn flow, unit identity, convoy pressure loops, and first polished battlefield UI pass.",
		"progress_to_next": 1.0
	},
	{
		"phase": "MILESTONE 02",
		"title": "WAR TABLE EXPERIENCE",
		"eta": "COMPLETED",
		"status": "COMPLETED",
		"summary": "Main menu overhaul, dispatch board pipeline, premium settings UI, and campaign archive readability.",
		"progress_to_next": 1.0
	},
	{
		"phase": "MILESTONE 03",
		"title": "CAMP COMMAND EXPANSION",
		"eta": "IN PROGRESS",
		"status": "IN_PROGRESS",
		"summary": "Camp UI modernization, inventory flow upgrades, unit dossier parity, and jukebox presentation polish.",
		"progress_to_next": 0.58
	},
	{
		"phase": "MILESTONE 04",
		"title": "RIVALRY + BOND ESCALATION",
		"eta": "NEXT",
		"status": "PLANNED",
		"summary": "Deeper unit relationships, rivalry payoffs, and consequence-rich interactions in and out of battle.",
		"progress_to_next": 0.0
	},
	{
		"phase": "MILESTONE 05",
		"title": "RAIDING OPERATIONS",
		"eta": "UPCOMING",
		"status": "PLANNED",
		"summary": "4-player hero raids against map-scale bosses with elite rewards and cooperative tactical objectives.",
		"progress_to_next": 0.0
	},
	{
		"phase": "MILESTONE 06",
		"title": "RANKED WARFARE 1V1",
		"eta": "UPCOMING",
		"status": "PLANNED",
		"summary": "Competitive ladder ecosystem with match integrity rules, balance cadence, and season progression.",
		"progress_to_next": 0.0
	}
]


func _make_panel_style(fill: Color, border: Color, border_width: int = 2, radius: int = 16, shadow_alpha: float = 0.40, shadow_size: int = 10, shadow_y: int = 4) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0.0, 0.0, 0.0, shadow_alpha)
	box.shadow_size = shadow_size
	box.shadow_offset = Vector2(0, shadow_y)
	return box


func _style_panel(panel: Control, fill: Color, border: Color, border_width: int = 2, radius: int = 16, shadow_alpha: float = 0.36) -> void:
	if panel == null:
		return
	var style := _make_panel_style(fill, border, border_width, radius, shadow_alpha, 10, 4)
	if panel is PanelContainer:
		(panel as PanelContainer).add_theme_stylebox_override("panel", style)
	elif panel is Panel:
		(panel as Panel).add_theme_stylebox_override("panel", style)


func _style_main_command_panel(panel: Control) -> void:
	if panel == null or not (panel is PanelContainer):
		return
	var fill := Color(0.23, 0.19, 0.13, 0.99).lerp(MENU_BG_ALT, 0.45)
	var border := Color(0.98, 0.86, 0.42, 1.0).lerp(MENU_BORDER, 0.42)
	var box := _make_panel_style(fill, border, 3, 26, 0.52, 17, 7)
	(panel as PanelContainer).add_theme_stylebox_override("panel", box)


func _style_label(label: Label, color: Color, font_size: int, outline_size: int = 2, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if label == null:
		return
	var regular_font: Font = label.get_theme_font("font", "Label")
	if regular_font != null:
		label.add_theme_font_override("font", regular_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.94))
	label.add_theme_constant_override("outline_size", outline_size)
	label.horizontal_alignment = alignment as HorizontalAlignment


func _style_rule(rule: ColorRect, color: Color, height: int = 2) -> void:
	if rule == null:
		return
	rule.color = color
	rule.custom_minimum_size = Vector2(0, height)


func _style_line_edit(input: LineEdit) -> void:
	if input == null:
		return
	var regular_font: Font = input.get_theme_font("font", "LineEdit")
	if regular_font != null:
		input.add_theme_font_override("font", regular_font)
	input.add_theme_font_size_override("font_size", 18)
	input.add_theme_color_override("font_color", MENU_TEXT)
	input.add_theme_color_override("font_placeholder_color", MENU_TEXT_MUTED)
	input.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.92))
	input.add_theme_constant_override("outline_size", 1)
	input.add_theme_stylebox_override("normal", _make_panel_style(Color(0.12, 0.10, 0.08, 0.98), MENU_BORDER_MUTED, 1, 10, 0.18, 5, 1))
	input.add_theme_stylebox_override("focus", _make_panel_style(Color(0.16, 0.13, 0.10, 0.98), MENU_ACCENT_SOFT, 2, 10, 0.24, 6, 2))


func _style_option_button(btn: OptionButton) -> void:
	if btn == null:
		return
	_style_button(btn, btn.text, false, 18, 46)
	btn.text = ""


func _style_text_edit(input: TextEdit) -> void:
	if input == null:
		return
	var regular_font: Font = input.get_theme_font("font", "TextEdit")
	if regular_font != null:
		input.add_theme_font_override("font", regular_font)
	input.add_theme_font_size_override("font_size", 18)
	input.add_theme_color_override("font_color", MENU_TEXT)
	input.add_theme_color_override("font_selected_color", MENU_TEXT)
	input.add_theme_color_override("selection_color", Color(0.43, 0.31, 0.11, 0.90))
	input.add_theme_color_override("background_color", Color(0.12, 0.10, 0.08, 0.98))
	input.add_theme_stylebox_override("normal", _make_panel_style(Color(0.12, 0.10, 0.08, 0.98), MENU_BORDER_MUTED, 1, 10, 0.18, 5, 1))
	input.add_theme_stylebox_override("focus", _make_panel_style(Color(0.16, 0.13, 0.10, 0.98), MENU_ACCENT_SOFT, 2, 10, 0.24, 6, 2))


func _style_button(btn: Button, label_text: String, primary: bool, font_size: int = 22, min_height: int = 62) -> void:
	if btn == null:
		return
	var regular_font: Font = btn.get_theme_font("font", "Label")
	if regular_font != null:
		btn.add_theme_font_override("font", regular_font)
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, min_height)
	btn.add_theme_font_size_override("font_size", font_size)
	var font_color := Color(0.13, 0.09, 0.04, 1.0) if primary else MENU_TEXT
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_color_override("font_focus_color", font_color)
	btn.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.94))
	btn.add_theme_constant_override("outline_size", 2)
	var normal_fill := Color(0.66, 0.50, 0.17, 0.98) if primary else Color(0.20, 0.16, 0.11, 0.98)
	var hover_fill := Color(0.76, 0.58, 0.20, 0.98) if primary else Color(0.28, 0.22, 0.14, 0.98)
	var press_fill := Color(0.54, 0.40, 0.14, 0.98) if primary else Color(0.16, 0.13, 0.09, 0.98)
	var border := MENU_BORDER if primary else MENU_BORDER_MUTED.lerp(MENU_BORDER, 0.35)
	btn.add_theme_stylebox_override("normal", _make_panel_style(normal_fill, border, 2, 12, 0.34, 9, 3))
	btn.add_theme_stylebox_override("hover", _make_panel_style(hover_fill, MENU_BORDER, 2, 12, 0.40, 11, 3))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(press_fill, MENU_BORDER, 2, 12, 0.30, 7, 1))
	btn.add_theme_stylebox_override("focus", _make_panel_style(hover_fill, MENU_ACCENT_SOFT, 2, 12, 0.40, 11, 3))


func _style_hero_primary_button(btn: Button, label_text: String, font_size: int = 24, min_height: int = 64) -> void:
	if btn == null:
		return
	var regular_font: Font = btn.get_theme_font("font", "Label")
	if regular_font != null:
		btn.add_theme_font_override("font", regular_font)
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, min_height)
	btn.add_theme_font_size_override("font_size", font_size)
	var font_color := Color(0.11, 0.07, 0.03, 1.0)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_color_override("font_focus_color", font_color)
	btn.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.94))
	btn.add_theme_constant_override("outline_size", 2)
	var gold_neutral := Color(0.64, 0.49, 0.17, 0.98)
	var normal_fill := Color(0.72, 0.55, 0.18, 0.99).lerp(gold_neutral, 0.38)
	var hover_fill := Color(0.84, 0.64, 0.22, 0.99).lerp(gold_neutral.lightened(0.07), 0.38)
	var press_fill := Color(0.52, 0.38, 0.12, 0.99).lerp(gold_neutral.darkened(0.12), 0.35)
	var border_gold := Color(0.55, 0.42, 0.14, 1.0).lerp(MENU_BORDER_MUTED.lerp(MENU_BORDER, 0.62), 0.45)
	btn.add_theme_stylebox_override("normal", _make_panel_style(normal_fill, border_gold, 3, 14, 0.36, 11, 4))
	btn.add_theme_stylebox_override("hover", _make_panel_style(hover_fill, MENU_BORDER, 3, 14, 0.40, 13, 4))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(press_fill, MENU_BORDER, 3, 14, 0.30, 8, 2))
	btn.add_theme_stylebox_override("focus", _make_panel_style(hover_fill, MENU_ACCENT_SOFT, 3, 14, 0.40, 12, 4))


## Secondary main-menu actions: each slot uses a different hue while staying in the same leather / gold / parchment family.
func _style_secondary_main_menu_button(btn: Button, label_text: String, slot: String, font_size: int = 22, min_height: int = 58) -> void:
	if btn == null:
		return
	var regular_font: Font = btn.get_theme_font("font", "Label")
	if regular_font != null:
		btn.add_theme_font_override("font", regular_font)
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, min_height)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", MENU_TEXT)
	btn.add_theme_color_override("font_hover_color", MENU_TEXT)
	btn.add_theme_color_override("font_pressed_color", MENU_TEXT)
	btn.add_theme_color_override("font_focus_color", MENU_TEXT)
	btn.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.94))
	btn.add_theme_constant_override("outline_size", 2)
	var n: Color
	var h: Color
	var p: Color
	var b: Color
	match slot:
		"settings":
			n = Color(0.17, 0.19, 0.22, 0.98)
			h = Color(0.22, 0.26, 0.30, 0.98)
			p = Color(0.13, 0.15, 0.17, 0.98)
			b = Color(0.42, 0.58, 0.68, 0.95)
		"profile":
			n = Color(0.24, 0.19, 0.15, 0.98)
			h = Color(0.32, 0.24, 0.18, 0.98)
			p = Color(0.16, 0.13, 0.10, 0.98)
			b = Color(0.78, 0.52, 0.32, 0.92)
		"credits":
			n = Color(0.20, 0.17, 0.23, 0.98)
			h = Color(0.28, 0.22, 0.32, 0.98)
			p = Color(0.14, 0.12, 0.16, 0.98)
			b = Color(0.62, 0.48, 0.78, 0.88)
		"roadmap":
			n = Color(0.16, 0.21, 0.18, 0.98)
			h = Color(0.20, 0.28, 0.23, 0.98)
			p = Color(0.12, 0.16, 0.14, 0.98)
			b = Color(0.40, 0.62, 0.50, 0.90)
		"achievements":
			n = Color(0.26, 0.21, 0.12, 0.98)
			h = Color(0.34, 0.28, 0.14, 0.98)
			p = Color(0.18, 0.15, 0.09, 0.98)
			b = Color(0.92, 0.74, 0.28, 0.98)
		"quit":
			n = Color(0.20, 0.15, 0.15, 0.98)
			h = Color(0.30, 0.20, 0.19, 0.98)
			p = Color(0.14, 0.11, 0.11, 0.98)
			b = Color(0.65, 0.38, 0.36, 0.92)
		_:
			n = Color(0.20, 0.16, 0.11, 0.98)
			h = Color(0.28, 0.22, 0.14, 0.98)
			p = Color(0.16, 0.13, 0.09, 0.98)
			b = MENU_BORDER_MUTED.lerp(MENU_BORDER, 0.45)
	var mute_fill: Color = Color(0.192, 0.156, 0.11, 0.98)
	var mute_border: Color = MENU_BORDER_MUTED.lerp(MENU_BORDER, 0.44)
	n = n.lerp(mute_fill, 0.55)
	h = h.lerp(mute_fill.lightened(0.05), 0.55)
	p = p.lerp(mute_fill.darkened(0.05), 0.55)
	b = b.lerp(mute_border, 0.52)
	var bh: Color = b.lerp(MENU_BORDER, 0.5)
	btn.add_theme_stylebox_override("normal", _make_panel_style(n, b, 2, 13, 0.22, 7, 2))
	btn.add_theme_stylebox_override("hover", _make_panel_style(h, bh, 2, 13, 0.28, 9, 3))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(p, b, 2, 13, 0.18, 5, 2))
	btn.add_theme_stylebox_override("focus", _make_panel_style(h, MENU_ACCENT_SOFT, 2, 13, 0.28, 8, 3))


func _style_steam_avatar_button(btn: TextureButton) -> void:
	if btn == null:
		return
	var empty := StyleBoxEmpty.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	btn.add_theme_stylebox_override("focus", empty)


func _set_control_rect(control: Control, pos: Vector2, rect_size: Vector2) -> void:
	if control == null:
		return
	control.position = pos
	control.size = rect_size
	control.offset_left = pos.x
	control.offset_top = pos.y
	control.offset_right = pos.x + rect_size.x
	control.offset_bottom = pos.y + rect_size.y


func _style_slot_button(btn: Button) -> void:
	if btn == null:
		return
	var regular_font: Font = btn.get_theme_font("font", "Label")
	if regular_font != null:
		btn.add_theme_font_override("font", regular_font)
	btn.text = ""
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_stylebox_override("normal", _make_panel_style(Color(0.17, 0.13, 0.09, 0.98), MENU_BORDER_MUTED, 1, 14, 0.28, 8, 3))
	btn.add_theme_stylebox_override("hover", _make_panel_style(Color(0.23, 0.18, 0.12, 0.98), MENU_BORDER, 2, 14, 0.34, 10, 3))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.13, 0.10, 0.07, 0.98), MENU_BORDER, 2, 14, 0.24, 6, 1))
	btn.add_theme_stylebox_override("focus", _make_panel_style(Color(0.23, 0.18, 0.12, 0.98), MENU_ACCENT_SOFT, 2, 14, 0.34, 10, 3))


func _style_auto_slot_button(btn: Button, slot_num: int) -> void:
	if btn == null:
		return
	var regular_font: Font = btn.get_theme_font("font", "Label")
	if regular_font != null:
		btn.add_theme_font_override("font", regular_font)
	btn.text = "AUTO\n%d" % slot_num
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color(0.10, 0.08, 0.04, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.10, 0.08, 0.04, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.10, 0.08, 0.04, 1.0))
	btn.add_theme_color_override("font_focus_color", Color(0.10, 0.08, 0.04, 1.0))
	btn.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.85))
	btn.add_theme_constant_override("outline_size", 2)
	btn.add_theme_stylebox_override("normal", _make_panel_style(Color(0.75, 0.61, 0.22, 0.98), MENU_BORDER, 2, 12, 0.26, 7, 2))
	btn.add_theme_stylebox_override("hover", _make_panel_style(Color(0.83, 0.68, 0.26, 0.98), MENU_BORDER, 2, 12, 0.30, 8, 2))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.59, 0.47, 0.17, 0.98), MENU_BORDER, 2, 12, 0.24, 5, 1))
	btn.add_theme_stylebox_override("focus", _make_panel_style(Color(0.83, 0.68, 0.26, 0.98), MENU_ACCENT_SOFT, 2, 12, 0.30, 8, 2))


func _style_delete_button(btn: Button) -> void:
	if btn == null:
		return
	var regular_font: Font = btn.get_theme_font("font", "Label")
	if regular_font != null:
		btn.add_theme_font_override("font", regular_font)
	btn.text = "X"
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", MENU_TEXT)
	btn.add_theme_color_override("font_hover_color", MENU_TEXT)
	btn.add_theme_color_override("font_pressed_color", MENU_TEXT)
	btn.add_theme_color_override("font_focus_color", MENU_TEXT)
	btn.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.94))
	btn.add_theme_constant_override("outline_size", 2)
	btn.add_theme_stylebox_override("normal", _make_panel_style(Color(0.21, 0.09, 0.08, 0.98), MENU_ERROR.lerp(MENU_BORDER_MUTED, 0.45), 1, 12, 0.22, 6, 2))
	btn.add_theme_stylebox_override("hover", _make_panel_style(Color(0.31, 0.11, 0.10, 0.98), MENU_ERROR, 2, 12, 0.28, 8, 2))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.17, 0.07, 0.06, 0.98), MENU_ERROR, 2, 12, 0.20, 4, 1))
	btn.add_theme_stylebox_override("focus", _make_panel_style(Color(0.31, 0.11, 0.10, 0.98), MENU_ACCENT_SOFT, 2, 12, 0.28, 8, 2))


func _style_dialog(dialog: AcceptDialog) -> void:
	if dialog == null:
		return
	var regular_font: Font = dialog.get_theme_font("font", "Label")
	if regular_font != null:
		dialog.add_theme_font_override("font", regular_font)
	dialog.add_theme_font_size_override("title_font_size", 20)
	dialog.add_theme_font_size_override("font_size", 18)
	dialog.add_theme_color_override("title_color", MENU_ACCENT)
	dialog.add_theme_color_override("font_color", MENU_TEXT)
	dialog.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.94))
	dialog.add_theme_constant_override("outline_size", 2)
	dialog.add_theme_stylebox_override("panel", _make_panel_style(MENU_BG, MENU_BORDER, 2, 18, 0.44, 14, 6))


func _get_roadmap_status_color(status_text: String) -> Color:
	var normalized: String = status_text.to_upper()
	if normalized == "COMPLETED":
		return MENU_SUCCESS
	if normalized == "IN_PROGRESS":
		return MENU_WARNING
	return MENU_ACCENT_SOFT


func _default_segment_progress_from_status(status_text: String) -> float:
	var normalized: String = status_text.to_upper()
	if normalized == "COMPLETED":
		return 1.0
	if normalized == "IN_PROGRESS":
		return 0.50
	return 0.0


func _ensure_roadmap_data() -> void:
	if not roadmap_milestones.is_empty():
		return
	if not roadmap_use_default_if_empty:
		return
	roadmap_milestones = _build_default_roadmap_resources()


func _build_default_roadmap_resources() -> Array[Resource]:
	var resources: Array[Resource] = []
	for entry_variant in DEFAULT_ROADMAP_MILESTONES:
		var entry: Dictionary = entry_variant
		var res: Resource = ROADMAP_MILESTONE_DATA_SCRIPT.new()
		res.set("phase", str(entry.get("phase", "MILESTONE")))
		res.set("title", str(entry.get("title", "Roadmap Item")))
		res.set("eta", str(entry.get("eta", "UPCOMING")))
		res.set("status", str(entry.get("status", "PLANNED")))
		res.set("summary", str(entry.get("summary", "")))
		res.set("progress_to_next", clampf(float(entry.get("progress_to_next", _default_segment_progress_from_status(str(entry.get("status", "PLANNED"))))), 0.0, 1.0))
		resources.append(res)
	return resources


func _get_active_roadmap_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for res_variant in roadmap_milestones:
		var res: Resource = res_variant
		if res == null:
			continue
		var title_text: String = str(res.get("title")).strip_edges()
		if title_text == "":
			continue
		var phase_text: String = str(res.get("phase")).strip_edges()
		if phase_text == "":
			phase_text = "MILESTONE"
		var eta_text: String = str(res.get("eta")).strip_edges()
		if eta_text == "":
			eta_text = "UPCOMING"
		var status_text: String = str(res.get("status")).strip_edges()
		if status_text == "":
			status_text = "PLANNED"
		var summary_text: String = str(res.get("summary")).strip_edges()
		var progress_to_next: float = _default_segment_progress_from_status(status_text)
		var progress_variant: Variant = res.get("progress_to_next")
		if progress_variant is float or progress_variant is int:
			progress_to_next = clampf(float(progress_variant), 0.0, 1.0)
		result.append({
			"phase": phase_text,
			"title": title_text,
			"eta": eta_text,
			"status": status_text,
			"summary": summary_text,
			"progress_to_next": progress_to_next
		})
	return result


func _update_roadmap_progress_ui(_milestones: Array[Dictionary]) -> void:
	# Progress now lives directly on each roadmap segment fill.
	if roadmap_progress_row != null:
		roadmap_progress_row.visible = false
	if roadmap_progress_label != null:
		roadmap_progress_label.text = ""
	if roadmap_progress_bar != null:
		roadmap_progress_bar.value = 0.0
	if roadmap_progress_value != null:
		roadmap_progress_value.text = ""


func _clear_roadmap_canvas() -> void:
	if roadmap_canvas == null:
		return
	var children: Array = roadmap_canvas.get_children()
	for child_variant in children:
		var child_node: Node = child_variant as Node
		if child_node != null:
			roadmap_canvas.remove_child(child_node)
			child_node.queue_free()


func _set_mouse_ignore(control: Control) -> void:
	if control == null:
		return
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_roadmap_visual() -> void:
	if roadmap_canvas == null:
		return
	_set_mouse_ignore(roadmap_canvas)
	_clear_roadmap_canvas()
	_ensure_roadmap_data()
	var milestones: Array[Dictionary] = _get_active_roadmap_entries()
	_update_roadmap_progress_ui(milestones)
	if milestones.is_empty():
		return
	var canvas_width: float = maxf(760.0, roadmap_scroll.size.x - 18.0) if roadmap_scroll != null else 900.0
	roadmap_canvas.custom_minimum_size.x = canvas_width
	var center_x: float = canvas_width * 0.5
	var lane_amplitude: float = clampf(canvas_width * 0.08, 46.0, 88.0)
	var left_x: float = center_x - lane_amplitude
	var right_x: float = center_x + lane_amplitude
	var top_y: float = 120.0
	var row_gap: float = 205.0
	var points: PackedVector2Array = PackedVector2Array()
	for idx in range(milestones.size()):
		var use_left: bool = idx % 2 == 0
		var px: float = left_x if use_left else right_x
		var py: float = top_y + (float(idx) * row_gap)
		points.append(Vector2(px, py))

	var road_shadow: Line2D = Line2D.new()
	road_shadow.default_color = Color(0.08, 0.06, 0.05, 0.95)
	road_shadow.width = 28.0
	road_shadow.joint_mode = Line2D.LINE_JOINT_ROUND
	road_shadow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	road_shadow.end_cap_mode = Line2D.LINE_CAP_ROUND
	road_shadow.points = points
	roadmap_canvas.add_child(road_shadow)

	var road_lane: Line2D = Line2D.new()
	road_lane.default_color = MENU_BORDER_MUTED.lerp(Color(0.18, 0.15, 0.10, 1.0), 0.45)
	road_lane.width = 16.0
	road_lane.joint_mode = Line2D.LINE_JOINT_ROUND
	road_lane.begin_cap_mode = Line2D.LINE_CAP_ROUND
	road_lane.end_cap_mode = Line2D.LINE_CAP_ROUND
	road_lane.points = points
	roadmap_canvas.add_child(road_lane)

	for segment_idx in range(points.size() - 1):
		var start_point: Vector2 = points[segment_idx]
		var end_point: Vector2 = points[segment_idx + 1]
		var segment_data: Dictionary = milestones[segment_idx]
		var segment_progress: float = clampf(float(segment_data.get("progress_to_next", 0.0)), 0.0, 1.0)
		if segment_progress <= 0.001:
			continue
		var status_text: String = str(segment_data.get("status", "PLANNED")).to_upper()
		var fill_color: Color = _get_roadmap_status_color(status_text).lerp(MENU_ACCENT, 0.24)
		var fill_shadow: Line2D = Line2D.new()
		fill_shadow.default_color = Color(0.04, 0.03, 0.02, 0.85)
		fill_shadow.width = 18.0
		fill_shadow.joint_mode = Line2D.LINE_JOINT_ROUND
		fill_shadow.begin_cap_mode = Line2D.LINE_CAP_ROUND
		fill_shadow.end_cap_mode = Line2D.LINE_CAP_ROUND
		fill_shadow.points = PackedVector2Array([start_point, start_point.lerp(end_point, segment_progress)])
		roadmap_canvas.add_child(fill_shadow)
		var fill_lane: Line2D = Line2D.new()
		fill_lane.default_color = fill_color
		fill_lane.width = 11.0
		fill_lane.joint_mode = Line2D.LINE_JOINT_ROUND
		fill_lane.begin_cap_mode = Line2D.LINE_CAP_ROUND
		fill_lane.end_cap_mode = Line2D.LINE_CAP_ROUND
		fill_lane.points = PackedVector2Array([start_point, start_point.lerp(end_point, segment_progress)])
		roadmap_canvas.add_child(fill_lane)

	for idx in range(milestones.size()):
		var milestone: Dictionary = milestones[idx]
		var point: Vector2 = points[idx]
		var status: String = str(milestone.get("status", "PLANNED")).to_upper()
		var status_color: Color = _get_roadmap_status_color(status)

		var stop_shadow: ColorRect = ColorRect.new()
		_set_mouse_ignore(stop_shadow)
		stop_shadow.color = Color(0.0, 0.0, 0.0, 0.35)
		stop_shadow.custom_minimum_size = Vector2(34, 34)
		stop_shadow.position = point - Vector2(17, 17) + Vector2(0, 3)
		roadmap_canvas.add_child(stop_shadow)

		var stop_dot: ColorRect = ColorRect.new()
		_set_mouse_ignore(stop_dot)
		stop_dot.color = status_color
		stop_dot.custom_minimum_size = Vector2(28, 28)
		stop_dot.position = point - Vector2(14, 14)
		roadmap_canvas.add_child(stop_dot)

		var card_margin: float = 28.0
		var card_w: float = clampf(canvas_width * 0.40, 320.0, 420.0)
		var card_h: float = 136.0
		var show_left_card: bool = idx % 2 == 0
		var card_x: float = card_margin if show_left_card else (canvas_width - card_w - card_margin)
		var card_y: float = point.y - (card_h * 0.5)
		card_x = clampf(card_x, 16.0, canvas_width - card_w - 16.0)

		var connector: ColorRect = ColorRect.new()
		_set_mouse_ignore(connector)
		connector.color = status_color.lerp(MENU_BORDER, 0.35)
		var connector_len: float = absf((card_x + card_w) - point.x) if show_left_card else absf(point.x - card_x)
		connector.custom_minimum_size = Vector2(maxf(connector_len - 14.0, 16.0), 3)
		if show_left_card:
			connector.position = Vector2(card_x + card_w + 8.0, point.y - 1.5)
		else:
			connector.position = Vector2(card_x - connector.custom_minimum_size.x - 8.0, point.y - 1.5)
		roadmap_canvas.add_child(connector)

		var card: PanelContainer = PanelContainer.new()
		_set_mouse_ignore(card)
		card.custom_minimum_size = Vector2(card_w, card_h)
		card.position = Vector2(card_x, card_y)
		card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.15, 0.12, 0.09, 0.94), status_color.lerp(MENU_BORDER, 0.45), 2, 14, 0.30, 8, 3))
		roadmap_canvas.add_child(card)

		var margin: MarginContainer = MarginContainer.new()
		_set_mouse_ignore(margin)
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(margin)

		var vbox: VBoxContainer = VBoxContainer.new()
		_set_mouse_ignore(vbox)
		vbox.add_theme_constant_override("separation", 5)
		margin.add_child(vbox)

		var phase_label: Label = Label.new()
		_set_mouse_ignore(phase_label)
		phase_label.text = str(milestone.get("phase", "MILESTONE"))
		_style_label(phase_label, status_color, 15, 1)
		vbox.add_child(phase_label)

		var title_label: Label = Label.new()
		_set_mouse_ignore(title_label)
		title_label.text = str(milestone.get("title", "Roadmap Item"))
		_style_label(title_label, MENU_ACCENT, 22, 2)
		vbox.add_child(title_label)

		var eta_label: Label = Label.new()
		_set_mouse_ignore(eta_label)
		eta_label.text = "STATUS // %s" % str(milestone.get("eta", "UPCOMING"))
		_style_label(eta_label, MENU_TEXT_MUTED, 14, 1)
		vbox.add_child(eta_label)

		var summary_label: Label = Label.new()
		_set_mouse_ignore(summary_label)
		summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary_label.text = str(milestone.get("summary", ""))
		_style_label(summary_label, MENU_TEXT, 14, 1)
		vbox.add_child(summary_label)

	var total_height: float = top_y + (float(maxi(milestones.size() - 1, 0)) * row_gap) + 300.0
	roadmap_canvas.custom_minimum_size = Vector2(canvas_width, total_height)
	roadmap_canvas.size = roadmap_canvas.custom_minimum_size
	roadmap_canvas.position = Vector2.ZERO


func _open_achievements_dialog() -> void:
	if achievements_dialog == null:
		return
	var vp_size: Vector2i = Vector2i(get_viewport_rect().size)
	var max_w: int = maxi(480, vp_size.x - 80)
	var max_h: int = maxi(300, vp_size.y - 100)
	achievements_dialog.min_size = Vector2i(480, 300)
	achievements_dialog.max_size = Vector2i(max_w, max_h)
	var popup_size := Vector2i(
		clampi(560, 480, max_w),
		clampi(380, 300, max_h)
	)
	achievements_dialog.popup_centered_clamped(popup_size, 0.88)


func _open_roadmap_dialog() -> void:
	if roadmap_dialog == null:
		return
	var vp_size: Vector2i = Vector2i(get_viewport_rect().size)
	var safe_margin_x: int = 90
	var safe_margin_y: int = 150
	var max_w: int = maxi(640, vp_size.x - (safe_margin_x * 2))
	var max_h: int = maxi(420, vp_size.y - (safe_margin_y * 2))
	roadmap_dialog.min_size = Vector2i(520, 360)
	roadmap_dialog.max_size = Vector2i(max_w, max_h)
	var popup_size: Vector2i = Vector2i(
		mini(max_w, 1180),
		mini(max_h, 680)
	)
	if roadmap_scroll != null:
		var dynamic_scroll_h: float = clampf(float(popup_size.y) - 260.0, 180.0, 520.0)
		roadmap_scroll.custom_minimum_size = Vector2(0.0, dynamic_scroll_h)
	roadmap_dialog.popup_centered_clamped(popup_size, 0.90)
	call_deferred("_finalize_roadmap_open", float(safe_margin_y))

func _finalize_roadmap_open(safe_margin: float = 36.0) -> void:
	if roadmap_dialog != null:
		var vp_size: Vector2i = Vector2i(get_viewport_rect().size)
		var max_w: int = maxi(640, vp_size.x - int(safe_margin * 2.0))
		var max_h: int = maxi(420, vp_size.y - int(safe_margin * 2.0))
		roadmap_dialog.max_size = Vector2i(max_w, max_h)
		var clamped_size := Vector2i(
			clampi(roadmap_dialog.size.x, 520, max_w),
			clampi(roadmap_dialog.size.y, 360, max_h)
		)
		roadmap_dialog.size = clamped_size
		roadmap_dialog.position = Vector2i(
			maxi(int(safe_margin), (vp_size.x - clamped_size.x) / 2),
			maxi(int(safe_margin), (vp_size.y - clamped_size.y) / 2)
		)
	if roadmap_scroll != null:
		var dynamic_scroll_h: float = clampf(float(roadmap_dialog.size.y) - 245.0, 240.0, 560.0)
		roadmap_scroll.custom_minimum_size = Vector2(0.0, dynamic_scroll_h)
		roadmap_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
		roadmap_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		roadmap_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
		roadmap_scroll.scroll_horizontal = 0
		roadmap_scroll.scroll_vertical = 0
	_build_roadmap_visual()
	if roadmap_scroll != null:
		roadmap_scroll.scroll_horizontal = 0
		roadmap_scroll.scroll_vertical = 0


func _on_roadmap_scroll_gui_input(event: InputEvent) -> void:
	if roadmap_scroll == null:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if not mouse_event.pressed:
		return
	var step: int = 92
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		roadmap_scroll.scroll_vertical += step
		roadmap_scroll.accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		roadmap_scroll.scroll_vertical = maxi(roadmap_scroll.scroll_vertical - step, 0)
		roadmap_scroll.accept_event()


func _style_slot_contents(slot_button: Button) -> void:
	var accent_bar = slot_button.get_node_or_null("MarginContainer/HBox/AccentBar") as ColorRect
	var portrait_rect = slot_button.get_node_or_null("MarginContainer/HBox/Portrait") as TextureRect
	var name_label = slot_button.get_node_or_null("MarginContainer/HBox/TextVBox/NameLabel") as Label
	var loc_label = slot_button.get_node_or_null("MarginContainer/HBox/TextVBox/LocationLabel") as Label
	var meta_label = slot_button.get_node_or_null("MarginContainer/HBox/TextVBox/MetaLabel") as Label
	var gold_label = slot_button.get_node_or_null("MarginContainer/HBox/GoldLabel") as Label
	if accent_bar != null:
		accent_bar.color = MENU_ACCENT_SOFT.lerp(MENU_ACCENT, 0.55)
		accent_bar.custom_minimum_size = Vector2(6, 0)
	if portrait_rect != null:
		portrait_rect.custom_minimum_size = Vector2(92, 92)
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if name_label != null:
		_style_label(name_label, MENU_ACCENT, 22, 2)
	if loc_label != null:
		_style_label(loc_label, MENU_TEXT, 16, 1)
	if meta_label != null:
		_style_label(meta_label, MENU_ACCENT_SOFT.lerp(MENU_TEXT, 0.42), 15, 1)
	if gold_label != null:
		_style_label(gold_label, MENU_ACCENT_SOFT, 20, 2, HORIZONTAL_ALIGNMENT_RIGHT)


func _get_dispatch_category_color(category: String) -> Color:
	match category.to_upper():
		"MODIFICATIONS":
			return MENU_WARNING
		"OTHER":
			return MENU_ACCENT_SOFT
		_:
			return MENU_ACCENT


func _default_dispatch_payload() -> Dictionary:
	return {
		"title": "WAR TABLE UPDATES",
		"category": "NEWS",
		"body": "The dispatch channel is live. Use this space for news, modifications, event notes, maintenance warnings, or community-facing updates once the bulletin is approved and published.",
		"author": "WAR TABLE",
		"updated_at": int(Time.get_unix_time_from_system())
	}


func _get_steam_singleton() -> Object:
	if Engine.has_singleton("Steam"):
		return Engine.get_singleton("Steam")
	return null


func _can_edit_dispatch() -> bool:
	var steam_singleton := _get_steam_singleton()
	if steam_singleton != null and steam_singleton.has_method("getSteamID"):
		var steam_id := str(steam_singleton.call("getSteamID"))
		return DISPATCH_APPROVED_STEAM_IDS.has(steam_id)
	return OS.is_debug_build() and DISPATCH_ALLOW_DEBUG_EDITOR


func _get_dispatch_editor_name() -> String:
	var steam_singleton := _get_steam_singleton()
	if steam_singleton != null and steam_singleton.has_method("getPersonaName"):
		return str(steam_singleton.call("getPersonaName"))
	return "LOCAL DEBUG"


func _format_dispatch_stamp(unix_time: int, author: String) -> String:
	var author_name := author.strip_edges()
	if unix_time <= 0:
		return "LIVE BULLETIN // %s" % (author_name if author_name != "" else "WAR TABLE")
	var date_info: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return "LIVE BULLETIN // %02d/%02d/%04d %02d:%02d // %s" % [
		int(date_info.get("day", 1)),
		int(date_info.get("month", 1)),
		int(date_info.get("year", 2000)),
		int(date_info.get("hour", 0)),
		int(date_info.get("minute", 0)),
		author_name if author_name != "" else "WAR TABLE"
	]


func _apply_dispatch_payload(payload: Dictionary, status_text: String = "Awaiting dispatch confirmation.") -> void:
	_dispatch_payload = payload.duplicate(true)
	var category := str(payload.get("category", "NEWS")).to_upper()
	var category_color := _get_dispatch_category_color(category)
	var headline := str(payload.get("title", "WAR TABLE UPDATES")).strip_edges()
	var body := str(payload.get("body", "")).strip_edges()
	var author := str(payload.get("author", "WAR TABLE"))
	var updated_at := int(payload.get("updated_at", 0))
	if headline == "":
		headline = "WAR TABLE UPDATES"
	if body == "":
		body = "No live dispatch is posted yet."
	dispatch_category_label.text = category
	dispatch_category_label.add_theme_color_override("font_color", category_color)
	dispatch_meta_label.text = _format_dispatch_stamp(updated_at, author)
	dispatch_meta_label.add_theme_color_override("font_color", MENU_TEXT_MUTED)
	dispatch_status_label.text = status_text
	dispatch_status_label.add_theme_color_override("font_color", MENU_TEXT_MUTED)
	dispatch_body_label.text = "[color=#f1d07a]%s[/color]\n\n[color=#efe7d5]%s[/color]" % [headline, body]
	call_deferred("_refresh_dispatch_body_layout")


func _refresh_dispatch_body_layout() -> void:
	if dispatch_body_label == null or dispatch_scroll == null:
		return
	var body_width: float = maxf(dispatch_scroll.size.x - 18.0, 280.0)
	dispatch_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dispatch_body_label.custom_minimum_size = Vector2(body_width, 0.0)
	dispatch_body_label.size = Vector2(body_width, dispatch_body_label.size.y)
	call_deferred("_finish_dispatch_body_layout", body_width)


func _finish_dispatch_body_layout(body_width: float) -> void:
	if dispatch_body_label == null or dispatch_scroll == null:
		return
	var content_height: float = maxf(dispatch_body_label.get_content_height() + 12.0, dispatch_scroll.size.y)
	dispatch_body_label.custom_minimum_size = Vector2(body_width, content_height)
	dispatch_body_label.size = Vector2(body_width, content_height)


func _fetch_dispatch_feed() -> void:
	_apply_dispatch_payload(_default_dispatch_payload(), "SYNCING DISPATCH FEED...")
	if not has_node("/root/SilentWolf"):
		_apply_dispatch_payload(_default_dispatch_payload(), "LOCAL FALLBACK // SILENTWOLF OFFLINE")
		return
	_fetch_dispatch_feed_async()


func _fetch_dispatch_feed_async() -> void:
	var sw_result = await SilentWolf.Scores.get_scores(1, DISPATCH_LEADERBOARD).sw_get_scores_complete
	var scores: Array = []
	if sw_result is Dictionary:
		scores = sw_result.get("scores", [])
	if scores.is_empty():
		scores = SilentWolf.Scores.scores
	if scores.is_empty():
		_apply_dispatch_payload(_default_dispatch_payload(), "LOCAL FALLBACK // NO LIVE DISPATCH")
		return
	var top_entry: Dictionary = scores[0]
	var metadata: Dictionary = top_entry.get("metadata", {})
	var payload := {
		"title": str(metadata.get("title", "WAR TABLE UPDATES")),
		"category": str(metadata.get("category", "NEWS")),
		"body": str(metadata.get("body", metadata.get("message", ""))),
		"author": str(metadata.get("author", top_entry.get("player_name", "WAR TABLE"))),
		"updated_at": int(metadata.get("updated_at", int(top_entry.get("score", 0))))
	}
	_apply_dispatch_payload(payload, "LIVE DISPATCH // VERIFIED")


func _open_dispatch_editor() -> void:
	if not _can_edit_dispatch():
		return
	if dispatch_editor_dialog == null:
		return
	dispatch_editor_dialog.get_ok_button().text = "PUBLISH DISPATCH"
	dispatch_category_option.select(max(DISPATCH_CATEGORIES.find(str(_dispatch_payload.get("category", "NEWS")).to_upper()), 0))
	dispatch_headline_edit.text = str(_dispatch_payload.get("title", "WAR TABLE UPDATES"))
	dispatch_body_edit.text = str(_dispatch_payload.get("body", ""))
	dispatch_editor_dialog.exclusive = true
	dispatch_editor_dialog.min_size = Vector2i(860, 560)
	dispatch_editor_dialog.popup_centered(Vector2i(860, 560))
	dispatch_editor_dialog.move_to_foreground()
	dispatch_headline_edit.call_deferred("grab_focus")


func _on_dispatch_editor_confirmed() -> void:
	var category: String = DISPATCH_CATEGORIES[dispatch_category_option.selected]
	var title := dispatch_headline_edit.text.strip_edges()
	var body := dispatch_body_edit.text.strip_edges()
	if title == "" or body == "":
		_apply_dispatch_payload(_dispatch_payload if not _dispatch_payload.is_empty() else _default_dispatch_payload(), "DISPATCH REJECTED // HEADLINE OR MESSAGE MISSING")
		return
	var payload := {
		"title": title,
		"category": category,
		"body": body,
		"author": _get_dispatch_editor_name(),
		"updated_at": int(Time.get_unix_time_from_system())
	}
	_apply_dispatch_payload(payload, "PUBLISHING DISPATCH...")
	_publish_dispatch_async(payload)


func _publish_dispatch_async(payload: Dictionary) -> void:
	if not has_node("/root/SilentWolf"):
		_apply_dispatch_payload(payload, "LOCAL DEBUG // NO CLOUD SYNC")
		return
	var fresh_score := int(Time.get_unix_time_from_system())
	var sw_result = await SilentWolf.Scores.save_score("SYSTEM", fresh_score, DISPATCH_LEADERBOARD, payload).sw_save_score_complete
	var success := false
	if sw_result is Dictionary:
		success = bool(sw_result.get("success", false))
	if success:
		_apply_dispatch_payload(payload, "LIVE DISPATCH // PUBLISHED")
		return
	_apply_dispatch_payload(payload, "LOCAL DISPLAY // CLOUD PUBLISH NOT CONFIRMED")


func _apply_theme() -> void:
	_style_panel(intel_panel, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 0, 0.0)
	_style_panel(dispatch_panel, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 0, 0.0)
	_style_panel(intel_card, Color(0.132, 0.108, 0.082, 0.93), MENU_BORDER_MUTED, 1, 19, 0.26)
	_style_panel(dispatch_card, Color(0.132, 0.108, 0.082, 0.93), MENU_BORDER_MUTED, 1, 19, 0.26)
	_style_main_command_panel(main_vbox)
	_style_panel(campaign_vbox, MENU_BG, MENU_BORDER, 2, 22, 0.50)

	_style_label($IntelPanel/IntelCard/Margin/VBox/IntelTitle, MENU_ACCENT, 28, 3)
	_style_rule(intel_rule, MENU_BORDER_MUTED.lerp(MENU_ACCENT_SOFT, 0.35), 2)
	_style_label($IntelPanel/IntelCard/Margin/VBox/IntelCopy, MENU_TEXT_MUTED, 15, 1)
	for path in [
		"IntelPanel/IntelCard/Margin/VBox/IntelItem1",
		"IntelPanel/IntelCard/Margin/VBox/IntelItem2",
		"IntelPanel/IntelCard/Margin/VBox/IntelItem3",
		"IntelPanel/IntelCard/Margin/VBox/IntelItem4",
		"IntelPanel/IntelCard/Margin/VBox/IntelItem5"
	]:
		_style_label(get_node(path) as Label, MENU_TEXT, 15, 1)
	_style_label($DispatchPanel/DispatchCard/Margin/VBox/DispatchTitle, MENU_ACCENT, 26, 3)
	_style_rule(dispatch_rule, MENU_BORDER_MUTED.lerp(MENU_ACCENT_SOFT, 0.35), 2)
	_style_label(dispatch_meta_label, MENU_TEXT_MUTED, 14, 1)
	_style_label(dispatch_category_label, MENU_ACCENT, 15, 2)
	_style_label(dispatch_status_label, MENU_TEXT_MUTED, 14, 1)
	dispatch_status_label.clip_text = true
	dispatch_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	dispatch_body_label.add_theme_font_size_override("normal_font_size", 16)
	dispatch_body_label.add_theme_font_override("normal_font", dispatch_body_label.get_theme_font("normal_font", "RichTextLabel"))
	dispatch_body_label.add_theme_color_override("default_color", MENU_TEXT)
	dispatch_body_label.scroll_active = false
	dispatch_body_label.fit_content = false

	_style_label($CenterStage/MainPanel/Margin/VBox/MainKicker, MENU_TEXT_MUTED, 16, 1)
	_style_label($CenterStage/MainPanel/Margin/VBox/MainTitle, MENU_ACCENT, 30, 3)
	_style_label($CenterStage/MainPanel/Margin/VBox/MainBody, MENU_TEXT_MUTED, 17, 1)
	_style_label($CenterStage/MainPanel/Margin/VBox/MainHint, MENU_ACCENT_SOFT.lerp(MENU_TEXT, 0.35), 15, 1)
	_style_label(roadmap_overline_label, MENU_TEXT_MUTED, 15, 1)
	_style_label(roadmap_title_label, MENU_ACCENT, 28, 3)
	_style_label(roadmap_hint_label, MENU_TEXT_MUTED, 15, 1)
	_style_rule(roadmap_rule, MENU_BORDER_MUTED.lerp(MENU_ACCENT_SOFT, 0.35), 2)
	if roadmap_progress_row != null:
		roadmap_progress_row.visible = false
	_style_label(achievements_overline_label, MENU_TEXT_MUTED, 15, 1)
	_style_label(achievements_title_label, MENU_ACCENT, 28, 3)
	_style_label(achievements_hint_label, MENU_TEXT_MUTED, 15, 1)
	_style_rule(achievements_rule, MENU_BORDER_MUTED.lerp(MENU_ACCENT_SOFT, 0.35), 2)
	_style_label(achievements_placeholder_label, MENU_TEXT, 15, 1)

	if main_menu_version_footer != null:
		main_menu_version_footer.text = "GAME VERSION %s\n%s\n%s · %s" % [
			GameVersion.get_display_string(),
			GameVersion.get_game_copyright_line(),
			GameVersion.get_godot_version_label(),
			GameVersion.get_godot_attribution_short(),
		]
		_style_label(main_menu_version_footer, MENU_TEXT_MUTED, 12, 1)

	_style_label($CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/CampaignKicker, MENU_TEXT_MUTED, 16, 1)
	_style_label($CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/CampaignTitle, MENU_ACCENT, 30, 3)
	_style_label($CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/CampaignBody, MENU_TEXT_MUTED, 17, 1)
	_style_label($CenterStage/CampaignMenu/Margin/CampaignScroll/VBox/SlotsHeader, MENU_WARNING, 18, 2)

	_style_hero_primary_button(start_button, "CAMPAIGN COMMAND", 24, 64)
	_style_secondary_main_menu_button(settings_button, "FIELD SETTINGS", "settings")
	_style_secondary_main_menu_button(profile_button, "COMMANDER PROFILE", "profile")
	_style_secondary_main_menu_button(credits_button, "CREDITS", "credits")
	_style_secondary_main_menu_button(roadmap_button, "ROADMAP", "roadmap")
	_style_secondary_main_menu_button(achievements_button, "ACHIEVEMENTS", "achievements")
	_style_secondary_main_menu_button(quit_button, "QUIT TO DESKTOP", "quit")
	_style_button(continue_button, "CONTINUE CAMPAIGN", true, 22, 66)
	_style_button(new_game_button, "NEW CAMPAIGN", false, 22, 62)
	_style_button(load_game_button, "ARCHIVE SLOTS", false, 22, 62)
	_style_button(back_button, "RETURN TO ENTRY", false, 20, 54)
	_style_button(edit_dispatch_button, "EDIT", false, 18, 46)

	for auto_btn in [auto_slot_1_btn, auto_slot_2_btn, auto_slot_3_btn]:
		var slot_num := 1 if auto_btn == auto_slot_1_btn else 2 if auto_btn == auto_slot_2_btn else 3
		_style_auto_slot_button(auto_btn, slot_num)

	for delete_btn in [del_slot_1_btn, del_slot_2_btn, del_slot_3_btn]:
		_style_delete_button(delete_btn)

	for slot_btn in [slot_1_btn, slot_2_btn, slot_3_btn]:
		_style_slot_button(slot_btn)
		_style_slot_contents(slot_btn)

	_style_dialog(delete_dialog)
	_style_dialog(overwrite_dialog)
	_style_dialog(dispatch_editor_dialog)
	_style_dialog(roadmap_dialog)
	if roadmap_dialog != null:
		roadmap_dialog.min_size = Vector2i(520, 360)
		var roadmap_ok := roadmap_dialog.get_ok_button()
		if roadmap_ok != null:
			_style_button(roadmap_ok, "CLOSE ROADMAP", false, 20, 54)
	_style_dialog(achievements_dialog)
	if achievements_dialog != null:
		achievements_dialog.min_size = Vector2i(480, 300)
		var ach_ok := achievements_dialog.get_ok_button()
		if ach_ok != null:
			_style_button(ach_ok, "CLOSE", false, 20, 54)
	if profile_dialog != null:
		profile_dialog.add_theme_font_size_override("title_font_size", 20)
		profile_dialog.add_theme_color_override("title_color", MENU_ACCENT)
		var bg_panel_node: Panel = profile_dialog.get_node_or_null("BgPanel")
		if bg_panel_node != null:
			bg_panel_node.add_theme_stylebox_override("panel", _make_panel_style(MENU_BG, MENU_BORDER, 2, 0, 0.44, 14, 6))
	_style_label(profile_overline_label, MENU_TEXT_MUTED, 15, 1)
	_style_label(profile_resolved_headline, MENU_ACCENT, 26, 3)
	_style_label(profile_steam_name_line, MENU_TEXT_MUTED, 14, 1)
	_style_label(profile_override_line, MENU_TEXT_MUTED, 14, 1)
	_style_label(profile_fallback_line, MENU_TEXT_MUTED, 14, 1)
	_style_label(profile_coop_line, MENU_TEXT, 15, 1)
	_style_label(profile_steam_status_label, MENU_TEXT_MUTED, 14, 1)
	_style_button(profile_view_steam_button, "VIEW STEAM PROFILE", false, 16, 44)
	_style_label(profile_campaign_overline, MENU_ACCENT_SOFT, 15, 2)
	_style_label(profile_campaign_body, MENU_TEXT, 14, 1)
	_style_label(profile_edit_overline, MENU_ACCENT, 18, 2)
	_style_label(profile_hint_label, MENU_TEXT_MUTED, 14, 1)
	if steam_playing_as_label != null:
		_style_label(steam_playing_as_label, MENU_TEXT_MUTED, 11, 1, HORIZONTAL_ALIGNMENT_CENTER)
		steam_playing_as_label.custom_minimum_size = Vector2(88, 0)
	_style_rule(profile_rule, MENU_BORDER_MUTED.lerp(MENU_ACCENT_SOFT, 0.35), 2)
	_style_line_edit(profile_name_edit)
	_style_button(profile_use_steam_button, "USE STEAM / DEFAULT", false, 18, 48)
	_style_button(profile_save_button, "SAVE", true, 20, 52)
	if steam_avatar_frame != null:
		_style_panel(steam_avatar_frame, Color(0.14, 0.11, 0.08, 0.94), MENU_BORDER_MUTED, 2, 14, 0.30)
	_style_steam_avatar_button(steam_avatar_button)
	_style_label($DispatchEditorDialog/Margin/VBox/DispatchCategoryLabel, MENU_ACCENT, 18, 2)
	_style_label($DispatchEditorDialog/Margin/VBox/DispatchHeadlineLabel, MENU_ACCENT, 18, 2)
	_style_label($DispatchEditorDialog/Margin/VBox/DispatchBodyLabel, MENU_ACCENT, 18, 2)
	_style_label($DispatchEditorDialog/Margin/VBox/DispatchEditorHint, MENU_TEXT_MUTED, 15, 1)
	_style_option_button(dispatch_category_option)
	_style_line_edit(dispatch_headline_edit)
	_style_text_edit(dispatch_body_edit)


func _init_audio() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = MENU_MUSIC
	_music_player.bus = "Music"
	_music_player.autoplay = true
	_music_player.volume_db = -6.0
	add_child(_music_player)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)


func _play_hover_sfx() -> void:
	if _sfx_player == null:
		return
	_sfx_player.stream = SFX_HOVER
	_sfx_player.pitch_scale = randf_range(0.95, 1.05)
	_sfx_player.play()


func _play_click_sfx() -> void:
	if _sfx_player == null:
		return
	_sfx_player.stream = SFX_CLICK
	_sfx_player.pitch_scale = randf_range(0.92, 1.08)
	_sfx_player.play()


func _button_press_feedback(control: Control) -> void:
	if control == null:
		return
	var t := create_tween()
	t.tween_property(control, "scale", Vector2(0.97, 0.97), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(control, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _button_hover_entered(control: Control) -> void:
	if control == null:
		return
	var t := create_tween()
	t.tween_property(control, "scale", Vector2(1.02, 1.02), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _button_hover_exited(control: Control) -> void:
	if control == null:
		return
	var t := create_tween()
	t.tween_property(control, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _wire_button_feedback(buttons: Array) -> void:
	for raw_button in buttons:
		var btn := raw_button as BaseButton
		if btn == null:
			continue
		var ctrl := btn as Control
		btn.mouse_entered.connect(func():
			_play_hover_sfx()
			_button_hover_entered(ctrl)
		)
		btn.mouse_exited.connect(func(): _button_hover_exited(ctrl))
		btn.pressed.connect(func():
			_play_click_sfx()
			_button_press_feedback(ctrl)
		)


func _connect_signals() -> void:
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_layout_menu):
		vp.size_changed.connect(_layout_menu)

	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	profile_button.pressed.connect(_on_profile_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	roadmap_button.pressed.connect(_on_roadmap_pressed)
	achievements_button.pressed.connect(_on_achievements_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	back_button.pressed.connect(_on_back_pressed)

	slot_1_btn.pressed.connect(func(): _on_slot_pressed(1))
	slot_2_btn.pressed.connect(func(): _on_slot_pressed(2))
	slot_3_btn.pressed.connect(func(): _on_slot_pressed(3))

	auto_slot_1_btn.pressed.connect(func(): _on_slot_pressed(1, true))
	auto_slot_2_btn.pressed.connect(func(): _on_slot_pressed(2, true))
	auto_slot_3_btn.pressed.connect(func(): _on_slot_pressed(3, true))

	del_slot_1_btn.pressed.connect(func(): _on_delete_pressed(1))
	del_slot_2_btn.pressed.connect(func(): _on_delete_pressed(2))
	del_slot_3_btn.pressed.connect(func(): _on_delete_pressed(3))

	if delete_dialog != null:
		delete_dialog.confirmed.connect(_on_delete_confirmed)
	if dispatch_editor_dialog != null:
		dispatch_editor_dialog.confirmed.connect(_on_dispatch_editor_confirmed)
	if edit_dispatch_button != null:
		edit_dispatch_button.pressed.connect(_open_dispatch_editor)
	if roadmap_scroll != null and not roadmap_scroll.gui_input.is_connected(_on_roadmap_scroll_gui_input):
		roadmap_scroll.gui_input.connect(_on_roadmap_scroll_gui_input)
	if profile_dialog != null:
		profile_dialog.close_requested.connect(func(): profile_dialog.hide())
	if profile_name_edit != null and not profile_name_edit.text_submitted.is_connected(_on_profile_name_submitted):
		profile_name_edit.text_submitted.connect(_on_profile_name_submitted)
	if profile_name_edit != null and not profile_name_edit.text_changed.is_connected(_on_profile_name_text_changed):
		profile_name_edit.text_changed.connect(_on_profile_name_text_changed)
	if profile_use_steam_button != null:
		profile_use_steam_button.pressed.connect(_on_profile_use_steam_pressed)
	if profile_save_button != null:
		profile_save_button.pressed.connect(_on_profile_save_pressed)

	_wire_button_feedback([
		start_button,
		settings_button,
		profile_button,
		credits_button,
		roadmap_button,
		achievements_button,
		quit_button,
		continue_button,
		new_game_button,
		load_game_button,
		back_button,
		slot_1_btn,
		slot_2_btn,
		slot_3_btn,
		auto_slot_1_btn,
		auto_slot_2_btn,
		auto_slot_3_btn,
		del_slot_1_btn,
		del_slot_2_btn,
		del_slot_3_btn,
		edit_dispatch_button
	])
	if roadmap_dialog != null and roadmap_dialog.get_ok_button() != null:
		_wire_button_feedback([roadmap_dialog.get_ok_button()])
	if achievements_dialog != null and achievements_dialog.get_ok_button() != null:
		_wire_button_feedback([achievements_dialog.get_ok_button()])
	if profile_use_steam_button != null and profile_save_button != null:
		_wire_button_feedback([profile_use_steam_button, profile_save_button])
	if profile_view_steam_button != null:
		_wire_button_feedback([profile_view_steam_button])
	if steam_avatar_button != null:
		_wire_button_feedback([steam_avatar_button])

	if SteamService != null and SteamService.has_signal("player_avatar_loaded"):
		var cb := Callable(self, "_on_steam_player_avatar_loaded")
		if not SteamService.player_avatar_loaded.is_connected(cb):
			SteamService.player_avatar_loaded.connect(cb)
	if steam_avatar_button != null:
		steam_avatar_button.pressed.connect(_on_steam_avatar_pressed)
	if profile_view_steam_button != null:
		profile_view_steam_button.pressed.connect(_on_profile_view_steam_pressed)


func _on_steam_player_avatar_loaded(tex: Variant) -> void:
	if steam_profile_corner == null:
		return
	var texture := tex as Texture2D
	if texture == null:
		steam_profile_corner.visible = false
		if steam_avatar_button != null:
			steam_avatar_button.disabled = true
			steam_avatar_button.texture_normal = null
		return
	if steam_avatar_button != null:
		steam_avatar_button.texture_normal = texture
		steam_avatar_button.disabled = false
	steam_profile_corner.visible = true
	_update_steam_corner_playing_as_label()


func _on_steam_avatar_pressed() -> void:
	_open_profile_dialog()


func _on_profile_view_steam_pressed() -> void:
	if SteamService != null and SteamService.has_method("open_local_player_steam_profile"):
		SteamService.open_local_player_steam_profile()


func _prepare_intro_state() -> void:
	_layout_menu()
	main_vbox.visible = true
	campaign_vbox.visible = false
	slots_container.visible = false
	main_vbox.modulate.a = 0.0
	main_vbox.scale = Vector2(0.97, 0.97)
	campaign_vbox.modulate.a = 0.0
	campaign_vbox.scale = Vector2(0.97, 0.97)
	if intel_panel != null:
		intel_panel.modulate.a = 0.0
		intel_panel.position.y += 18.0
	if dispatch_panel != null:
		dispatch_panel.modulate.a = 0.0
		dispatch_panel.position.y += 18.0
	var intro := create_tween()
	intro.set_parallel(true)
	intro.tween_property(main_vbox, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro.tween_property(main_vbox, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if intel_panel != null:
		intro.tween_property(intel_panel, "modulate:a", 1.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		intro.tween_property(intel_panel, "position:y", intel_panel.position.y - 18.0, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if dispatch_panel != null:
		intro.tween_property(dispatch_panel, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		intro.tween_property(dispatch_panel, "position:y", dispatch_panel.position.y - 18.0, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _enter_tree() -> void:
	_ensure_startup_black_overlay()
	if _startup_black_overlay == null:
		return
	var from_studio: bool = Engine.has_meta(STUDIO_HANDOFF_META_FLAG) and bool(Engine.get_meta(STUDIO_HANDOFF_META_FLAG))
	_startup_black_overlay.visible = from_studio
	_startup_black_overlay.modulate.a = 1.0 if from_studio else 0.0


func _ready() -> void:
	if SettingsMenu != null and SettingsMenu.has_method("hide_menu"):
		SettingsMenu.hide_menu()
	_ensure_roadmap_data()
	_apply_theme()
	_connect_signals()
	_layout_menu()
	_refresh_save_ui()
	dispatch_category_option.clear()
	for category in DISPATCH_CATEGORIES:
		dispatch_category_option.add_item(category)
	edit_dispatch_button.visible = _can_edit_dispatch()
	_init_audio()
	_prepare_intro_state()
	_start_atmosphere_pass()
	_fetch_dispatch_feed()
	start_button.grab_focus()
	_handle_startup_black_handoff()
	_request_steam_profile_avatar()
	_update_steam_corner_playing_as_label()


func _request_steam_profile_avatar() -> void:
	if SteamService == null or not SteamService.has_method("request_local_player_avatar"):
		if steam_profile_corner != null:
			steam_profile_corner.visible = false
		return
	SteamService.request_local_player_avatar(true)


func _layout_menu() -> void:
	var vp_size := get_viewport_rect().size
	if backdrop_art != null:
		backdrop_art.pivot_offset = vp_size * 0.5
	if intel_panel != null:
		var right_width := clampf(vp_size.x * 0.23, 360.0, 430.0)
		var right_x := vp_size.x - right_width - 32.0
		var right_top := 34.0
		var right_gap := 24.0
		var intel_size := Vector2(right_width, clampf(vp_size.y * 0.305, 300.0, 360.0))
		_set_control_rect(intel_panel, Vector2(right_x, right_top), intel_size)
		if intel_card != null:
			_set_control_rect(intel_card, Vector2.ZERO, intel_size)
		if dispatch_panel != null:
			var available_dispatch_height: float = maxf(vp_size.y - (right_top + intel_size.y + right_gap) - 44.0, 230.0)
			var dispatch_size := Vector2(right_width, clampf(minf(available_dispatch_height, vp_size.y * 0.29), 250.0, 330.0))
			var dispatch_pos := Vector2(right_x, right_top + intel_size.y + right_gap)
			_set_control_rect(dispatch_panel, dispatch_pos, dispatch_size)
			if dispatch_card != null:
				_set_control_rect(dispatch_card, Vector2.ZERO, dispatch_size)
	if main_vbox != null:
		var main_size := Vector2(clampf(vp_size.x * 0.41, 740.0, 900.0), clampf(vp_size.y * 0.30, 340.0, 430.0))
		_set_control_rect(main_vbox, Vector2((vp_size.x - main_size.x) * 0.5, clampf(vp_size.y * 0.21, 175.0, 255.0)), main_size)
	if campaign_vbox != null:
		var campaign_size := Vector2(clampf(vp_size.x * 0.66, 1120.0, 1320.0), clampf(vp_size.y * 0.56, 520.0, 640.0))
		_set_control_rect(campaign_vbox, Vector2((vp_size.x - campaign_size.x) * 0.5, clampf(vp_size.y * 0.22, 196.0, 252.0)), campaign_size)
	if main_menu_version_footer != null:
		var pad_l := 24.0
		var pad_b := 14.0
		var max_w := clampf(vp_size.x * 0.58, 280.0, 640.0)
		main_menu_version_footer.offset_left = pad_l
		main_menu_version_footer.offset_right = pad_l + max_w
		main_menu_version_footer.offset_top = -92.0
		main_menu_version_footer.offset_bottom = -pad_b
	_refresh_dispatch_body_layout()

func _ensure_startup_black_overlay() -> void:
	if _startup_black_overlay != null and is_instance_valid(_startup_black_overlay):
		return
	_startup_black_overlay = ColorRect.new()
	_startup_black_overlay.name = "StartupBlackOverlay"
	_startup_black_overlay.layout_mode = 1
	_startup_black_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_startup_black_overlay.anchor_right = 1.0
	_startup_black_overlay.anchor_bottom = 1.0
	_startup_black_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_startup_black_overlay.z_index = 4000
	_startup_black_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	_startup_black_overlay.modulate.a = 0.0
	add_child(_startup_black_overlay)

func _handle_startup_black_handoff() -> void:
	if _startup_black_overlay == null:
		return
	var use_handoff: bool = Engine.has_meta(STUDIO_HANDOFF_META_FLAG) and bool(Engine.get_meta(STUDIO_HANDOFF_META_FLAG))
	var fade_seconds: float = 0.95
	if Engine.has_meta(STUDIO_HANDOFF_META_FADE):
		fade_seconds = float(Engine.get_meta(STUDIO_HANDOFF_META_FADE))
	if Engine.has_meta(STUDIO_HANDOFF_META_FLAG):
		Engine.remove_meta(STUDIO_HANDOFF_META_FLAG)
	if Engine.has_meta(STUDIO_HANDOFF_META_FADE):
		Engine.remove_meta(STUDIO_HANDOFF_META_FADE)
	if not use_handoff:
		_startup_black_overlay.visible = false
		_startup_black_overlay.modulate.a = 0.0
		return

	# Preferred path: fade in from persistent SceneTransition black overlay.
	if Engine.has_singleton("SceneTransition"):
		var transition_rect := SceneTransition.get_node_or_null("ColorRect") as ColorRect
		if transition_rect != null and transition_rect.modulate.a > 0.01 and SceneTransition.has_method("fade_in_from_black"):
			_startup_black_overlay.visible = false
			_startup_black_overlay.modulate.a = 0.0
			var old_fade_in: float = SceneTransition.fade_in_time
			SceneTransition.fade_in_time = maxf(0.05, fade_seconds)
			SceneTransition.fade_in_from_black()
			SceneTransition.fade_in_time = old_fade_in
			return

	# Fallback path: local startup overlay.
	_startup_black_overlay.visible = true
	_startup_black_overlay.modulate.a = 1.0
	if _startup_black_tween != null:
		_startup_black_tween.kill()
	_startup_black_tween = create_tween()
	_startup_black_tween.tween_property(_startup_black_overlay, "modulate:a", 0.0, maxf(0.05, fade_seconds)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_startup_black_tween.tween_callback(func() -> void:
		if _startup_black_overlay != null:
			_startup_black_overlay.visible = false
	)


func _format_record_timestamp(unix_time: int) -> String:
	if unix_time <= 0:
		return "UPDATED: ARCHIVE DATE UNKNOWN"
	var date_info: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	var day := int(date_info.get("day", 1))
	var month := int(date_info.get("month", 1))
	var year := int(date_info.get("year", 2000))
	var hour := int(date_info.get("hour", 0))
	var minute := int(date_info.get("minute", 0))
	return "UPDATED: %02d/%02d/%04d  %02d:%02d" % [day, month, year, hour, minute]


func _format_playtime_seconds(sec: int) -> String:
	var s: int = maxi(sec, 0)
	var h: int = s / 3600
	var m: int = (s % 3600) / 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	if m > 0:
		return "%dm" % m
	if s > 0:
		return "%ds" % (s % 60)
	return "0m"


func _build_campaign_snapshot_profile_text() -> String:
	if CampaignManager == null or not CampaignManager.has_method("get_newest_save_snapshot"):
		return "No field record found."
	var snap: Dictionary = CampaignManager.get_newest_save_snapshot()
	if snap.is_empty():
		return "No field record on file — start or load a campaign to create a save."
	var slot: int = int(snap.get("save_slot", 0))
	var is_auto: bool = bool(snap.get("save_is_auto", false))
	var slot_label: String = "AUTO %d" % slot if is_auto else "SLOT %d" % slot
	var gold: int = int(snap.get("global_gold", 0))
	var map_n: int = int(snap.get("map_display_index", 1))
	var leader: String = str(snap.get("leader_name", "")).strip_edges()
	if leader == "":
		leader = "Unknown"
	var unix: int = int(snap.get("modified_unix", 0))
	var pt: int = int(snap.get("playtime_seconds", 0))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s  ·  MAP %d  ·  GOLD %d" % [slot_label, map_n, gold])
	lines.append("Commander: %s" % leader)
	if unix > 0:
		lines.append("Last written: %s" % _format_record_timestamp(unix))
	if pt > 0:
		lines.append("Playtime (in save): %s" % _format_playtime_seconds(pt))
	else:
		lines.append("Playtime: not stored in this save file.")
	var out: String = ""
	for i in range(lines.size()):
		if i > 0:
			out += "\n"
		out += lines[i]
	return out


func _profile_identity_breakdown_from_edit() -> Dictionary:
	var override_raw: String = profile_name_edit.text if profile_name_edit != null else ""
	var resolved: String = ""
	if CampaignManager != null and CampaignManager.has_method("resolve_player_display_name"):
		resolved = str(CampaignManager.resolve_player_display_name(override_raw)).strip_edges()
	var steam_name: String = ""
	if SteamService != null and SteamService.is_steam_ready() and SteamService.has_method("get_steam_persona_name"):
		steam_name = str(SteamService.get_steam_persona_name()).strip_edges()
	var override_sanitized: String = ""
	if CampaignManager != null and CampaignManager.has_method("sanitize_player_display_name"):
		override_sanitized = str(CampaignManager.sanitize_player_display_name(override_raw)).strip_edges()
	var has_override: bool = override_sanitized != ""
	var fallback_cmd: String = ""
	if CampaignManager != null:
		fallback_cmd = str(CampaignManager.custom_avatar.get("name", CampaignManager.custom_avatar.get("unit_name", ""))).strip_edges()
	if fallback_cmd == "":
		fallback_cmd = "— (create a commander in campaign)"
	return {
		"resolved": resolved if resolved != "" else "Commander",
		"steam_name": steam_name,
		"override_sanitized": override_sanitized,
		"has_override": has_override,
		"fallback_commander": fallback_cmd
	}


func _update_steam_corner_playing_as_label() -> void:
	if steam_playing_as_label == null:
		return
	var name_str: String = "Commander"
	if CampaignManager != null and CampaignManager.has_method("get_player_display_name"):
		name_str = str(CampaignManager.get_player_display_name()).strip_edges()
	if name_str == "":
		name_str = "Commander"
	var max_chars: int = 22
	var shown: String = name_str
	if shown.length() > max_chars:
		shown = shown.substr(0, max_chars - 1) + "…"
	steam_playing_as_label.text = "Playing as:\n%s" % shown


func _start_atmosphere_pass() -> void:
	if backdrop_art != null:
		backdrop_art.scale = Vector2(1.02, 1.02)
		backdrop_art.position = Vector2(-18.0, -10.0)
		var drift := create_tween()
		drift.set_loops()
		drift.set_parallel(true)
		drift.tween_property(backdrop_art, "scale", Vector2(1.05, 1.05), 10.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(backdrop_art, "position", Vector2(-34.0, -18.0), 10.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.chain().set_parallel(true)
		drift.tween_property(backdrop_art, "scale", Vector2(1.03, 1.03), 12.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(backdrop_art, "position", Vector2(12.0, -6.0), 12.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if backdrop_warmth != null:
		backdrop_warmth.modulate.a = 0.72
		var warmth := create_tween()
		warmth.set_loops()
		warmth.tween_property(backdrop_warmth, "modulate:a", 0.92, 6.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		warmth.tween_property(backdrop_warmth, "modulate:a", 0.68, 8.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if backdrop_shade != null:
		backdrop_shade.modulate.a = 1.0
		var shade := create_tween()
		shade.set_loops()
		shade.tween_property(backdrop_shade, "modulate:a", 0.96, 7.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		shade.tween_property(backdrop_shade, "modulate:a", 1.0, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _animate_archive_rows() -> void:
	if slots_container == null or not slots_container.visible:
		return
	var delay := 0.0
	for raw_row in slots_container.get_children():
		var row := raw_row as Control
		if row == null:
			continue
		row.modulate.a = 0.0
		row.scale = Vector2(0.985, 0.985)
		var row_tween := create_tween()
		row_tween.tween_property(row, "modulate:a", 1.0, 0.18).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		row_tween.parallel().tween_property(row, "scale", Vector2.ONE, 0.24).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		delay += 0.045


func _get_slot_button(slot_num: int, is_auto: bool) -> Button:
	match slot_num:
		1:
			return auto_slot_1_btn if is_auto else slot_1_btn
		2:
			return auto_slot_2_btn if is_auto else slot_2_btn
		3:
			return auto_slot_3_btn if is_auto else slot_3_btn
	return null


func _refresh_save_ui() -> void:
	var has_slot1 := FileAccess.file_exists(CampaignManager.get_save_path(1, false))
	var has_slot2 := FileAccess.file_exists(CampaignManager.get_save_path(2, false))
	var has_slot3 := FileAccess.file_exists(CampaignManager.get_save_path(3, false))
	var has_auto1 := FileAccess.file_exists(CampaignManager.get_save_path(1, true))
	var has_auto2 := FileAccess.file_exists(CampaignManager.get_save_path(2, true))
	var has_auto3 := FileAccess.file_exists(CampaignManager.get_save_path(3, true))

	var slot1_active := has_slot1 or has_auto1
	var slot2_active := has_slot2 or has_auto2
	var slot3_active := has_slot3 or has_auto3

	slot_1_btn.visible = slot1_active
	slot_2_btn.visible = slot2_active
	slot_3_btn.visible = slot3_active

	if slot1_active:
		_update_save_slot_ui(slot_1_btn, 1, false)
	if slot2_active:
		_update_save_slot_ui(slot_2_btn, 2, false)
	if slot3_active:
		_update_save_slot_ui(slot_3_btn, 3, false)

	auto_slot_1_btn.visible = has_auto1
	auto_slot_2_btn.visible = has_auto2
	auto_slot_3_btn.visible = has_auto3
	if auto_slot_1_btn.visible:
		auto_slot_1_btn.text = "AUTO\n1"
	if auto_slot_2_btn.visible:
		auto_slot_2_btn.text = "AUTO\n2"
	if auto_slot_3_btn.visible:
		auto_slot_3_btn.text = "AUTO\n3"

	del_slot_1_btn.visible = slot1_active
	del_slot_2_btn.visible = slot2_active
	del_slot_3_btn.visible = slot3_active

	var has_any_saves := slot1_active or slot2_active or slot3_active
	continue_button.visible = has_any_saves
	load_game_button.visible = has_any_saves
	if not has_any_saves:
		slots_container.visible = false


func _update_save_slot_ui(slot_button: Button, slot_num: int, is_auto: bool) -> void:
	var path: String = str(CampaignManager.get_save_path(slot_num, is_auto))
	var portrait_rect := slot_button.get_node_or_null("MarginContainer/HBox/Portrait") as TextureRect
	var name_label := slot_button.get_node_or_null("MarginContainer/HBox/TextVBox/NameLabel") as Label
	var loc_label := slot_button.get_node_or_null("MarginContainer/HBox/TextVBox/LocationLabel") as Label
	var meta_label := slot_button.get_node_or_null("MarginContainer/HBox/TextVBox/MetaLabel") as Label
	var gold_label := slot_button.get_node_or_null("MarginContainer/HBox/GoldLabel") as Label
	if name_label == null:
		return

	var prefix := "AUTO %d" % slot_num if is_auto else "SLOT %d" % slot_num
	if not FileAccess.file_exists(path):
		name_label.text = "%s - EMPTY" % prefix
		name_label.add_theme_color_override("font_color", MENU_TEXT_MUTED)
		if loc_label != null:
			loc_label.text = "No active field record."
		if meta_label != null:
			meta_label.text = "Awaiting a new war-table entry."
		if gold_label != null:
			gold_label.text = ""
		if portrait_rect != null:
			portrait_rect.texture = null
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var save_data = file.get_var()
	file.close()

	if typeof(save_data) != TYPE_DICTIONARY:
		name_label.text = "%s - CORRUPTED" % prefix
		name_label.add_theme_color_override("font_color", MENU_ERROR)
		if loc_label != null:
			loc_label.text = "Archive could not be decoded."
		if meta_label != null:
			meta_label.text = "Field record integrity check failed."
		if gold_label != null:
			gold_label.text = ""
		return

	var roster: Array = save_data.get("player_roster", [])
	var leader_name := "Unknown"
	var leader_lvl := 1
	var portrait_value: Variant = ""
	if roster.size() > 0:
		leader_name = roster[0].get("unit_name", "Hero")
		leader_lvl = roster[0].get("level", 1)
		portrait_value = roster[0].get("portrait", "")

	var gold: int = int(save_data.get("global_gold", 0))
	var map_idx := int(save_data.get("current_level_index", 0)) + 1
	var modified_time := int(FileAccess.get_modified_time(path))
	name_label.text = "%s // %s  LV %d" % [prefix, leader_name.to_upper(), leader_lvl]
	name_label.add_theme_color_override("font_color", MENU_ACCENT)
	if loc_label != null:
		loc_label.text = "FIELD RECORD: MAP %d  |  ACTIVE COMMANDER FILE" % map_idx
		loc_label.add_theme_color_override("font_color", MENU_TEXT_MUTED)
	if meta_label != null:
		meta_label.text = _format_record_timestamp(modified_time)
		meta_label.add_theme_color_override("font_color", MENU_ACCENT_SOFT.lerp(MENU_TEXT, 0.35))
	if gold_label != null:
		gold_label.text = "GOLD %d" % gold
		gold_label.add_theme_color_override("font_color", MENU_ACCENT_SOFT)
	if portrait_rect != null:
		if portrait_value is String and ResourceLoader.exists(str(portrait_value)):
			portrait_rect.texture = load(str(portrait_value))
		elif portrait_value is Texture2D:
			portrait_rect.texture = portrait_value as Texture2D


func _on_start_pressed() -> void:
	var t := create_tween()
	t.tween_property(main_vbox, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(main_vbox, "scale", Vector2(0.97, 0.97), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		main_vbox.visible = false
		campaign_vbox.visible = true
		campaign_vbox.modulate.a = 0.0
		campaign_vbox.scale = Vector2(0.97, 0.97)
		slots_container.visible = false
	)
	t.tween_property(campaign_vbox, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(campaign_vbox, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		if continue_button.visible:
			continue_button.grab_focus()
		else:
			new_game_button.grab_focus()
	)


func _on_back_pressed() -> void:
	var t := create_tween()
	t.tween_property(campaign_vbox, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(campaign_vbox, "scale", Vector2(0.97, 0.97), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		campaign_vbox.visible = false
		slots_container.visible = false
		main_vbox.visible = true
		main_vbox.modulate.a = 0.0
		main_vbox.scale = Vector2(0.97, 0.97)
	)
	t.tween_property(main_vbox, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(main_vbox, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): start_button.grab_focus())


func _on_settings_pressed() -> void:
	if SettingsMenu != null and SettingsMenu.has_method("show_settings_only"):
		SettingsMenu.show_settings_only()


func _on_profile_pressed() -> void:
	_open_profile_dialog()


func _open_profile_dialog() -> void:
	if profile_dialog == null or profile_name_edit == null:
		return
	profile_name_edit.text = CampaignManager.player_profile_display_override
	_refresh_profile_dialog_fields()
	var vp := get_viewport_rect().size
	var dlg_w := clampi(640, 420, int(vp.x * 0.56))
	var dlg_h := clampi(560, 380, int(vp.y * 0.78))
	if profile_scroll != null:
		profile_scroll.custom_minimum_size = Vector2(maxf(float(dlg_w) - 40.0, 360.0), 0.0)
	var dlg_pos := Vector2i(int((vp.x - float(dlg_w)) * 0.5), int((vp.y - float(dlg_h)) * 0.5))
	profile_dialog.popup(Rect2i(dlg_pos, Vector2i(dlg_w, dlg_h)))
	profile_name_edit.call_deferred("grab_focus")


func _refresh_profile_dialog_fields() -> void:
	var idn := _profile_identity_breakdown_from_edit()
	if profile_resolved_headline != null:
		profile_resolved_headline.text = idn["resolved"]
	if profile_steam_name_line != null:
		if str(idn["steam_name"]).strip_edges() != "":
			profile_steam_name_line.text = "Steam name: %s" % idn["steam_name"]
		else:
			profile_steam_name_line.text = "Steam name: — (Steam not active in this session)"
	if profile_override_line != null:
		if bool(idn["has_override"]):
			profile_override_line.text = "Custom tag: %s" % idn["override_sanitized"]
		else:
			profile_override_line.text = "Custom tag: (none — using Steam or commander fallback order)"
	if profile_fallback_line != null:
		profile_fallback_line.text = "Commander fallback: %s" % idn["fallback_commander"]
	if profile_coop_line != null:
		profile_coop_line.text = "Co-op / online: %s" % idn["resolved"]
	if profile_steam_status_label != null:
		if SteamService != null and SteamService.is_steam_ready():
			var pn2: String = str(idn["steam_name"]).strip_edges()
			if pn2 != "":
				profile_steam_status_label.text = "Steam connected as %s." % pn2
			else:
				profile_steam_status_label.text = "Steam running — persona name unavailable in this build."
		else:
			profile_steam_status_label.text = "Steam not active (editor, DRM-free build, or GodotSteam missing)."
	if profile_view_steam_button != null:
		profile_view_steam_button.visible = true
		profile_view_steam_button.disabled = SteamService == null or not SteamService.is_steam_ready()
	if profile_campaign_body != null:
		profile_campaign_body.text = _build_campaign_snapshot_profile_text()


func _on_profile_name_text_changed(_new_text: String) -> void:
	_refresh_profile_dialog_fields()


func _on_profile_name_submitted(_text: String) -> void:
	_on_profile_save_pressed()


func _on_profile_use_steam_pressed() -> void:
	if profile_name_edit != null:
		profile_name_edit.text = ""
	_refresh_profile_dialog_fields()


func _on_profile_save_pressed() -> void:
	_on_profile_dialog_confirmed()
	if profile_dialog != null:
		profile_dialog.hide()


func _on_profile_dialog_confirmed() -> void:
	if not CampaignManager.has_method("sanitize_player_display_name"):
		return
	var raw: String = profile_name_edit.text if profile_name_edit != null else ""
	CampaignManager.player_profile_display_override = CampaignManager.sanitize_player_display_name(raw)
	if CampaignManager.has_method("save_global_settings"):
		CampaignManager.save_global_settings()
	_refresh_profile_dialog_fields()
	_update_steam_corner_playing_as_label()


func _on_credits_pressed() -> void:
	SceneTransition.change_scene_to_file(CREDITS_SCENE_PATH)

func _on_roadmap_pressed() -> void:
	_open_roadmap_dialog()


func _on_achievements_pressed() -> void:
	_open_achievements_dialog()


func _on_new_game_pressed() -> void:
	if CampaignManager.has_method("reset_campaign_data"):
		CampaignManager.reset_campaign_data()
	CampaignManager.current_level_index = 0
	CampaignManager.active_save_slot = 1
	for i in range(1, 4):
		if not FileAccess.file_exists(CampaignManager.get_save_path(i, false)) and not FileAccess.file_exists(CampaignManager.get_save_path(i, true)):
			CampaignManager.active_save_slot = i
			break
	SceneTransition.change_scene_to_file("res://Scenes/character_creation.tscn")


func _on_continue_pressed() -> void:
	var newest_slot := -1
	var newest_is_auto := false
	var newest_time := 0
	for i in range(1, 4):
		var man_path: String = str(CampaignManager.get_save_path(i, false))
		if FileAccess.file_exists(man_path):
			var mod_time := FileAccess.get_modified_time(man_path)
			if mod_time > newest_time:
				newest_time = mod_time
				newest_slot = i
				newest_is_auto = false
		var auto_path: String = str(CampaignManager.get_save_path(i, true))
		if FileAccess.file_exists(auto_path):
			var auto_time := FileAccess.get_modified_time(auto_path)
			if auto_time > newest_time:
				newest_time = auto_time
				newest_slot = i
				newest_is_auto = true
	if newest_slot != -1:
		_on_slot_pressed(newest_slot, newest_is_auto)


func _on_load_game_pressed() -> void:
	var showing := not slots_container.visible
	if showing:
		slots_container.visible = true
		slots_container.modulate.a = 0.0
		slots_container.scale = Vector2(0.985, 0.985)
		var t := create_tween()
		t.tween_property(slots_container, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(slots_container, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_callback(_animate_archive_rows)
		if slot_1_btn.visible:
			slot_1_btn.grab_focus()
		elif slot_2_btn.visible:
			slot_2_btn.grab_focus()
		elif slot_3_btn.visible:
			slot_3_btn.grab_focus()
	else:
		var t := create_tween()
		t.tween_property(slots_container, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_callback(func(): slots_container.visible = false)
		load_game_button.grab_focus()


func _on_slot_pressed(slot_num: int, is_auto: bool = false) -> void:
	if CampaignManager.load_game(slot_num, is_auto):
		SceneTransition.change_scene_to_file("res://Scenes/camp_menu.tscn")
	else:
		var btn := _get_slot_button(slot_num, is_auto)
		if btn != null:
			_flash_slot_error(btn)
		print("Error: Failed to load save slot ", slot_num)


func _flash_slot_error(control: Control) -> void:
	if control == null:
		return
	var t := create_tween()
	t.tween_property(control, "modulate", Color(1.0, 0.35, 0.35), 0.08).set_trans(Tween.TRANS_SINE)
	t.tween_property(control, "modulate", Color.WHITE, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_delete_pressed(slot_num: int) -> void:
	pending_delete_slot = slot_num
	if delete_dialog != null:
		delete_dialog.dialog_text = "Are you sure you want to permanently delete save slot %d?" % slot_num
		delete_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	if CampaignManager.has_method("delete_game"):
		CampaignManager.delete_game(pending_delete_slot)
	await get_tree().create_timer(0.10).timeout
	_refresh_save_ui()
	if not continue_button.visible:
		new_game_button.grab_focus()
		slots_container.visible = false
