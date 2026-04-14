extends Control

## Camp overlay: lists enemy [UnitData] entries the player has encountered ([member CampaignManager.beastiary_seen]).

const CampMenuMotionT := preload("res://Scripts/UI/CampMenuMotion.gd")
const UnitDataT := preload("res://Scripts/Core/UnitData.gd")
const DetailedUnitInfoRuntimeHelpersT := preload("res://Scripts/Core/BattleField/BattleFieldDetailedUnitInfoRuntimeHelpers.gd")
const DetailedUnitInfoContentHelpersT := preload("res://Scripts/Core/BattleField/BattleFieldDetailedUnitInfoContentHelpers.gd")
const BattleFieldCombatForecastHelpersT := preload("res://Scripts/Core/BattleField/BattleFieldCombatForecastHelpers.gd")

const SCHOLAR_NAME := "Elara Wyn"
const SCHOLAR_BLURB_FACED := "Field catalogue — everything here is something your company has actually faced."
const SCHOLAR_BLURB_COMPANY := "Your roster — who you've sworn in. Sheets match their unit files; live stats stay on the squad."
const SCHOLAR_BLURB_ALLIES := "Allied fighters you've fought beside. Elara records them when they deploy with you in battle."

const CATALOGUE_MODE_FACED: int = 0
const CATALOGUE_MODE_COMPANY: int = 1
const CATALOGUE_MODE_ALLIES: int = 2

const MAP01_KIT_LABELS: Array[String] = [
	"None",
	"Soul Reaver",
	"Cinder Archer",
	"Pyre Disciple",
	"Ash Cultist",
]

const FIELD_NOTES_INTRO_ACCENT := "#d8b456"
## Same cadence as camp merchant dialogue (~0.04 s per character).
const FIELD_NOTES_INTRO_TYPEWRITER_SEC_PER_CHAR := 0.04
const FIELD_NOTES_INTRO_BTN_NEXT := "Next"
const FIELD_NOTES_INTRO_BTN_ENTER := "Enter the catalogue"

const FIELD_NOTES_LEAD_IN_KICKER := "Camp · your ledger"
const FIELD_NOTES_LEAD_IN_TITLE := "Opening Field Notes"
const FIELD_NOTES_LEAD_IN_BTN := "Turn toward her"
const FIELD_NOTES_LEAD_IN_BBCODE := (
	"[center]“Mind the binding! [color="
	+ FIELD_NOTES_INTRO_ACCENT
	+ "]Bartholomew[/color] nearly traded it for a mildly cursed soup ladle yesterday, the absolute fool.” "
	+ "Elara leans right over your shoulder, practically humming with energy. “Go on, then. Crack it open!”[/center]"
)

## Female mumbles from res://Assets/Voices (thoughtful / approbation; skips combat barks).
const ELARA_FIELD_NOTES_MUMBLE_PATHS: PackedStringArray = [
	"res://Assets/Voices/hmmmmm_sound_female.mp3",
	"res://Assets/Voices/mmm_question_female.mp3",
	"res://Assets/Voices/mmm_question_female2.mp3",
	"res://Assets/Voices/mm_mm_approbation_female.mp3",
	"res://Assets/Voices/mm_mm_approbation_female2.mp3",
]

## Short beats, no [b] — emphasis via [color] only (bold reads poorly with this font).
const FIELD_NOTES_INTRO_PAGES: Array[String] = [
	(
		"This beauty right here? These are our [color=" + FIELD_NOTES_INTRO_ACCENT + "]Field Notes[/color]. "
		+ "A proper, living record of every fascinating soul we cross paths with.\n\n"
		+ "Bartholomew chases his odd little baubles and cracked pottery, bless him. I chase histories and combat forms! "
		+ "I handle the main entries, naturally, but I've left the margins wonderfully wide so you can scribble in your own tactical… whatever it is you do."
	),
	(
		"I've sorted the catalogue so we aren't just leafing through blind. Your first section is [color=" + FIELD_NOTES_INTRO_ACCENT + "]Faced[/color].\n\n"
		+ "Anyone who actively tries to skewer, scorch, or drop a boulder on us goes right in there. "
		+ "If you've met them in battle, they get a page! It's a rather wonderful way to study local hostility."
	),
	(
		"Flip past that, and you'll find the [color=" + FIELD_NOTES_INTRO_ACCENT + "]Company[/color]. Our sworn roster. "
		+ "The illustrious, slightly battered crew currently fighting under your banner. "
		+ "I left the commander out, by the way—you hardly need me analyzing your every move.\n\n"
		+ "Then we have the [color=" + FIELD_NOTES_INTRO_ACCENT + "]Allies[/color]. The capable darlings who fought right beside us, "
		+ "but haven't actually signed their lives over to your direct orders. A critical distinction, legal and otherwise!"
	),
	(
		"One last vital detail! If you dig up any [color=" + FIELD_NOTES_INTRO_ACCENT + "]knowledge scrolls[/color] "
		+ "or bits of raw intel out there, hand them over. They let me keep these entries perfectly up to date.\n\n"
		+ "And if you ever want to debate the merits of marsh sage, or just listen to Bartholomew complain about his knees, "
		+ "poke around and [color=" + FIELD_NOTES_INTRO_ACCENT + "]Explore camp[/color]. We're always lingering about. "
		+ "Now, dig in! The ink on the margins is still a bit damp."
	),
]

var _paths_sorted: Array[String] = []
var _intro_tween: Tween = null
var _field_notes_typewriter_tween: Tween = null
var _field_notes_typewriter_target: RichTextLabel = null
var _field_notes_intro_dismissing: bool = false
var _intro_dialogue_index: int = 0
var _catalogue_mode: int = CATALOGUE_MODE_FACED
var _notes_active_path: String = ""
var _notes_suppress_edit_signal: bool = false
var _notes_save_timer: Timer = null
var _elara_mumble_streams: Array[AudioStream] = []

@onready var _main_dimmer: ColorRect = $Dimmer
@onready var _field_notes_typewriter_blip: AudioStreamPlayer = $FieldNotesTypewriterBlip
@onready var _elara_mumble_player: AudioStreamPlayer = $ElaraMumblePlayer
@onready var _root_panel: PanelContainer = $RootPanel
@onready var _intro_lead_in: Control = $IntroLeadIn
@onready var _intro_lead_kicker: Label = $IntroLeadIn/LeadInCenter/LeadInColumn/LeadInKicker
@onready var _intro_lead_title: Label = $IntroLeadIn/LeadInCenter/LeadInColumn/LeadInTitle
@onready var _intro_lead_body: RichTextLabel = $IntroLeadIn/LeadInCenter/LeadInColumn/LeadInBody
@onready var _intro_lead_continue_btn: Button = $IntroLeadIn/LeadInCenter/LeadInColumn/LeadInContinueBtn
@onready var _intro_overlay: Control = $IntroOverlay
@onready var _intro_scroll: ScrollContainer = $IntroOverlay/IntroPage/IntroSplit/IntroRight/IntroScroll
@onready var _intro_body: RichTextLabel = $IntroOverlay/IntroPage/IntroSplit/IntroRight/IntroScroll/IntroBody
@onready var _intro_continue_btn: Button = $IntroOverlay/IntroPage/IntroSplit/IntroRight/IntroContinueBtn
@onready var _intro_portrait: TextureRect = $IntroOverlay/IntroPage/IntroSplit/IntroLeft/IntroPortraitFrame/IntroPortraitPad/IntroPortrait
@onready var _title: Label = $RootPanel/Margin/VBox/HeaderRow/TitleLabel
@onready var _scholar_name: Label = $RootPanel/Margin/VBox/HeaderRow/ScholarBlock/ScholarName
@onready var _scholar_blurb: Label = $RootPanel/Margin/VBox/HeaderRow/ScholarBlock/ScholarBlurb
@onready var _scholar_portrait: TextureRect = $RootPanel/Margin/VBox/HeaderRow/ScholarPortrait
@onready var _btn_catalogue_faced: Button = get_node_or_null("RootPanel/Margin/VBox/Body/CatalogueModeRow/BtnCatalogueFaced") as Button
@onready var _btn_catalogue_company: Button = get_node_or_null("RootPanel/Margin/VBox/Body/CatalogueModeRow/BtnCatalogueCompany") as Button
@onready var _btn_catalogue_allies: Button = get_node_or_null("RootPanel/Margin/VBox/Body/CatalogueModeRow/BtnCatalogueAllies") as Button
@onready var _list: ItemList = $RootPanel/Margin/VBox/Body/Split/EntryList
@onready var _entry_portrait: TextureRect = $RootPanel/Margin/VBox/Body/Split/DetailColumn/PortraitRow/EntryPortrait
@onready var _entry_battle_sprite: TextureRect = $RootPanel/Margin/VBox/Body/Split/DetailColumn/PortraitRow/EntryBattleSprite
@onready var _tab_stats: RichTextLabel = $RootPanel/Margin/VBox/Body/Split/DetailColumn/DetailTabs/Stats/StatsScroll/StatsText
@onready var _tab_features: RichTextLabel = $RootPanel/Margin/VBox/Body/Split/DetailColumn/DetailTabs/Features/FeaturesScroll/FeaturesText
@onready var _tab_description: RichTextLabel = $RootPanel/Margin/VBox/Body/Split/DetailColumn/DetailTabs/Description/DescriptionScroll/DescriptionText
@onready var _tab_loot: RichTextLabel = $RootPanel/Margin/VBox/Body/Split/DetailColumn/DetailTabs/Loot/LootScroll/LootText
@onready var _tab_maps: RichTextLabel = $RootPanel/Margin/VBox/Body/Split/DetailColumn/DetailTabs/Maps/MapsScroll/MapsText
@onready var _notes_section: VBoxContainer = $RootPanel/Margin/VBox/Body/Split/DetailColumn/NotesSection
@onready var _notes_edit: TextEdit = $RootPanel/Margin/VBox/Body/Split/DetailColumn/NotesSection/PlayerNotesEdit
@onready var _empty: Label = $RootPanel/Margin/VBox/Body/EmptyLabel
@onready var _close_button: Button = $RootPanel/Margin/VBox/CloseRow/CloseButton


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 1000
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if _title:
		_title.text = "Field Notes"
	if _scholar_name:
		_scholar_name.text = SCHOLAR_NAME
	if _btn_catalogue_faced:
		_btn_catalogue_faced.toggled.connect(_on_catalogue_mode_button_toggled)
	if _btn_catalogue_company:
		_btn_catalogue_company.toggled.connect(_on_catalogue_mode_button_toggled)
	if _btn_catalogue_allies:
		_btn_catalogue_allies.toggled.connect(_on_catalogue_mode_button_toggled)
	_sync_catalogue_mode_from_buttons()
	_apply_scholar_blurb_for_mode()
	if _close_button:
		_close_button.pressed.connect(_on_close_pressed)
	if _intro_lead_kicker:
		_intro_lead_kicker.text = FIELD_NOTES_LEAD_IN_KICKER
	if _intro_lead_title:
		_intro_lead_title.text = FIELD_NOTES_LEAD_IN_TITLE
	if _intro_lead_body:
		_intro_lead_body.text = ""
	if _intro_lead_continue_btn:
		_intro_lead_continue_btn.text = FIELD_NOTES_LEAD_IN_BTN
		_intro_lead_continue_btn.pressed.connect(_on_intro_lead_in_continue_pressed)
	if _intro_continue_btn:
		_intro_continue_btn.pressed.connect(_on_field_notes_intro_primary_pressed)
	if _list:
		_list.item_selected.connect(_on_item_selected)
	_setup_player_notes_autosave()
	_cache_elara_mumble_streams()
	_clear_detail_tabs("[i]Select an entry.[/i]")
	_refresh()


func _cache_elara_mumble_streams() -> void:
	_elara_mumble_streams.clear()
	for path in ELARA_FIELD_NOTES_MUMBLE_PATHS:
		var res: Resource = load(path)
		if res is AudioStream:
			_elara_mumble_streams.append(res as AudioStream)


func _play_elara_field_notes_mumble() -> void:
	if _elara_mumble_player == null or _elara_mumble_streams.is_empty():
		return
	var stream: AudioStream = _elara_mumble_streams.pick_random()
	_elara_mumble_player.stream = stream
	_elara_mumble_player.pitch_scale = randf_range(0.92, 1.08)
	_elara_mumble_player.play()


func _play_intro_elara_portrait_bob() -> void:
	if _intro_portrait == null or not is_instance_valid(_intro_portrait):
		return
	if _intro_overlay == null or not _intro_overlay.visible:
		return
	CampMenuMotionT.field_notes_elara_portrait_bob(self, _intro_portrait)


func _setup_player_notes_autosave() -> void:
	if _notes_edit == null:
		return
	_notes_save_timer = Timer.new()
	_notes_save_timer.one_shot = true
	_notes_save_timer.wait_time = 0.5
	add_child(_notes_save_timer)
	_notes_save_timer.timeout.connect(_persist_active_note_to_disk)
	_notes_edit.text_changed.connect(_on_player_notes_text_changed)


func _sync_catalogue_mode_from_buttons() -> void:
	if _btn_catalogue_faced == null:
		return
	if _btn_catalogue_company != null and _btn_catalogue_company.button_pressed:
		_catalogue_mode = CATALOGUE_MODE_COMPANY
	elif _btn_catalogue_allies != null and _btn_catalogue_allies.button_pressed:
		_catalogue_mode = CATALOGUE_MODE_ALLIES
	else:
		_catalogue_mode = CATALOGUE_MODE_FACED


func _apply_scholar_blurb_for_mode() -> void:
	if _scholar_blurb == null:
		return
	match _catalogue_mode:
		CATALOGUE_MODE_COMPANY:
			_scholar_blurb.text = SCHOLAR_BLURB_COMPANY
		CATALOGUE_MODE_ALLIES:
			_scholar_blurb.text = SCHOLAR_BLURB_ALLIES
		_:
			_scholar_blurb.text = SCHOLAR_BLURB_FACED


func _on_catalogue_mode_button_toggled(pressed: bool) -> void:
	if not pressed:
		return
	_sync_catalogue_mode_from_buttons()
	_refresh()


func _on_player_notes_text_changed() -> void:
	if _notes_suppress_edit_signal:
		return
	if _notes_active_path.is_empty():
		return
	if _notes_save_timer != null:
		_notes_save_timer.start()


func _persist_active_note_to_disk() -> void:
	if _notes_active_path.is_empty() or BeastiaryPlayerNotes == null or _notes_edit == null:
		return
	BeastiaryPlayerNotes.set_note(_notes_active_path, _notes_edit.text)


func _commit_active_player_note() -> void:
	if _notes_save_timer != null and not _notes_save_timer.is_stopped():
		_notes_save_timer.stop()
	_persist_active_note_to_disk()


func _set_notes_ui_for_path(unit_path: String, editable: bool) -> void:
	_commit_active_player_note()
	_notes_active_path = unit_path.strip_edges()
	if _notes_edit == null:
		return
	_notes_suppress_edit_signal = true
	if _notes_active_path.is_empty() or not editable:
		_notes_edit.text = ""
		_notes_edit.editable = false
	else:
		var stored: String = BeastiaryPlayerNotes.get_note(_notes_active_path) if BeastiaryPlayerNotes != null else ""
		_notes_edit.text = stored
		_notes_edit.editable = true
	_notes_suppress_edit_signal = false
	if _notes_section != null:
		_notes_section.visible = editable and not _notes_active_path.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _intro_lead_in != null and _intro_lead_in.visible:
		if event.is_action_pressed("ui_cancel"):
			_skip_field_notes_intro_to_catalogue()
			get_viewport().set_input_as_handled()
		return
	if _intro_overlay != null and _intro_overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			_dismiss_field_notes_intro()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _field_notes_intro_should_show() -> bool:
	if CampaignManager == null:
		return false
	return not bool(CampaignManager.field_notes_intro_seen)


func _kill_intro_tween() -> void:
	if _intro_tween != null:
		_intro_tween.kill()
	_intro_tween = null


func _kill_field_notes_typewriter_tween() -> void:
	if _field_notes_typewriter_tween != null:
		_field_notes_typewriter_tween.kill()
	_field_notes_typewriter_tween = null


func _complete_field_notes_typewriter_target() -> void:
	if _field_notes_typewriter_target != null and is_instance_valid(_field_notes_typewriter_target):
		_field_notes_typewriter_target.visible_characters = -1
	_field_notes_typewriter_target = null


func _finish_field_notes_typewriter_now() -> void:
	_kill_field_notes_typewriter_tween()
	_complete_field_notes_typewriter_target()


func _field_notes_typewriter_is_active() -> bool:
	return (
		_field_notes_typewriter_tween != null
		and _field_notes_typewriter_tween.is_valid()
		and _field_notes_typewriter_tween.is_running()
	)


func _field_notes_intro_char_count_for_typewriter(rtl: RichTextLabel) -> int:
	if rtl.has_method("get_total_character_count"):
		return int(rtl.get_total_character_count())
	return rtl.get_parsed_text().length()


func _field_notes_typewriter_step(count: int) -> void:
	var rtl: RichTextLabel = _field_notes_typewriter_target
	if rtl == null or not is_instance_valid(rtl):
		return
	var n: int = _field_notes_intro_char_count_for_typewriter(rtl)
	var ic: int = clampi(count, 0, n)
	var prev: int = rtl.visible_characters
	if ic > prev and ic > 0:
		var parsed: String = rtl.get_parsed_text()
		if ic <= parsed.length():
			var ch: String = parsed.substr(ic - 1, 1)
			if (
				ch != " "
				and ch != "\n"
				and ch != "\t"
				and _field_notes_typewriter_blip != null
				and _field_notes_typewriter_blip.stream != null
			):
				_field_notes_typewriter_blip.play()
	rtl.visible_characters = ic


func _on_field_notes_typewriter_finished() -> void:
	_field_notes_typewriter_tween = null
	_complete_field_notes_typewriter_target()


func _play_field_notes_intro_typewriter(rtl: RichTextLabel, play_elara_mumble: bool = true) -> void:
	if rtl == null or not is_instance_valid(rtl):
		return
	_kill_field_notes_typewriter_tween()
	_field_notes_typewriter_target = rtl
	var n: int = _field_notes_intro_char_count_for_typewriter(rtl)
	if n <= 0:
		rtl.visible_characters = -1
		_field_notes_typewriter_target = null
		return
	if rtl == _intro_body and play_elara_mumble:
		_play_elara_field_notes_mumble()
	rtl.visible_characters = 0
	var duration: float = maxf(float(n) * FIELD_NOTES_INTRO_TYPEWRITER_SEC_PER_CHAR, 0.12)
	_field_notes_typewriter_tween = create_tween()
	_field_notes_typewriter_tween.tween_method(_field_notes_typewriter_step, 0, n, duration).set_trans(Tween.TRANS_LINEAR)
	_field_notes_typewriter_tween.finished.connect(_on_field_notes_typewriter_finished, CONNECT_ONE_SHOT)


func _start_field_notes_intro_lead_in() -> void:
	_finish_field_notes_typewriter_now()
	_kill_intro_tween()
	_field_notes_intro_dismissing = false
	_intro_dialogue_index = 0
	_prepare_field_notes_intro_page()
	if _intro_lead_body != null:
		_intro_lead_body.text = FIELD_NOTES_LEAD_IN_BBCODE
		_intro_lead_body.visible_characters = 0
	if _root_panel != null:
		_root_panel.visible = false
	if _intro_overlay != null:
		_intro_overlay.visible = false
		_intro_overlay.modulate = Color.WHITE
	if _intro_lead_in != null:
		_intro_lead_in.visible = true
		_intro_lead_in.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if _main_dimmer != null:
		_main_dimmer.visible = true
		_main_dimmer.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_intro_tween = create_tween()
	_intro_tween.set_parallel(true)
	_intro_tween.tween_property(_main_dimmer, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_intro_tween.tween_property(_intro_lead_in, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_intro_tween.set_parallel(false)
	_intro_tween.tween_callback(func() -> void:
		if _intro_lead_continue_btn != null and is_instance_valid(_intro_lead_continue_btn):
			_intro_lead_continue_btn.grab_focus()
		_play_field_notes_intro_typewriter(_intro_lead_body)
	)


func _on_intro_lead_in_continue_pressed() -> void:
	if not visible or _field_notes_intro_dismissing:
		return
	if _intro_lead_in == null or not _intro_lead_in.visible:
		return
	if _field_notes_typewriter_is_active():
		_finish_field_notes_typewriter_now()
		return
	_kill_intro_tween()
	_intro_tween = create_tween()
	_intro_tween.set_parallel(true)
	_intro_tween.tween_property(_intro_lead_in, "modulate:a", 0.0, 0.28).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_intro_tween.tween_property(_main_dimmer, "modulate:a", 0.0, 0.28).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_intro_tween.set_parallel(false)
	_intro_tween.tween_callback(_finish_field_notes_lead_in_transition)


func _finish_field_notes_lead_in_transition() -> void:
	_finish_field_notes_typewriter_now()
	_kill_intro_tween()
	if _intro_lead_in != null:
		_intro_lead_in.visible = false
		_intro_lead_in.modulate = Color.WHITE
	if _main_dimmer != null:
		_main_dimmer.visible = false
		_main_dimmer.modulate = Color.WHITE
	_show_field_notes_intro()


func _skip_field_notes_intro_to_catalogue() -> void:
	_finish_field_notes_typewriter_now()
	_kill_intro_tween()
	_field_notes_intro_dismissing = false
	if CampaignManager != null:
		CampaignManager.field_notes_intro_seen = true
	if _intro_lead_in != null:
		_intro_lead_in.visible = false
		_intro_lead_in.modulate = Color.WHITE
	if _intro_overlay != null:
		_intro_overlay.visible = false
		_intro_overlay.modulate = Color.WHITE
	if _main_dimmer != null:
		_main_dimmer.visible = true
		_main_dimmer.modulate = Color.WHITE
	if _root_panel != null:
		_root_panel.visible = true
	_grab_main_focus_after_open()


func _prepare_field_notes_intro_page() -> void:
	if _intro_body == null:
		return
	_kill_field_notes_typewriter_tween()
	var i: int = clampi(_intro_dialogue_index, 0, FIELD_NOTES_INTRO_PAGES.size() - 1)
	_intro_body.text = FIELD_NOTES_INTRO_PAGES[i]
	_intro_body.visible_characters = 0
	_intro_body.queue_redraw()
	call_deferred("_field_notes_intro_scroll_top")
	if _intro_continue_btn != null:
		_intro_continue_btn.text = (
			FIELD_NOTES_INTRO_BTN_ENTER
			if i >= FIELD_NOTES_INTRO_PAGES.size() - 1
			else FIELD_NOTES_INTRO_BTN_NEXT
		)


func _field_notes_intro_scroll_top() -> void:
	if _intro_scroll != null and is_instance_valid(_intro_scroll):
		_intro_scroll.scroll_vertical = 0


func _on_field_notes_intro_primary_pressed() -> void:
	if _intro_overlay == null or not _intro_overlay.visible or _field_notes_intro_dismissing:
		return
	if _field_notes_typewriter_is_active():
		_finish_field_notes_typewriter_now()
		_play_intro_elara_portrait_bob()
		return
	if _intro_dialogue_index >= FIELD_NOTES_INTRO_PAGES.size() - 1:
		_play_intro_elara_portrait_bob()
		_dismiss_field_notes_intro()
		return
	_play_intro_elara_portrait_bob()
	_intro_dialogue_index += 1
	_prepare_field_notes_intro_page()
	_play_field_notes_intro_typewriter(_intro_body)
	if _intro_continue_btn != null and is_instance_valid(_intro_continue_btn):
		_intro_continue_btn.grab_focus()


func _show_field_notes_intro() -> void:
	_finish_field_notes_typewriter_now()
	_kill_intro_tween()
	_field_notes_intro_dismissing = false
	_intro_dialogue_index = 0
	_prepare_field_notes_intro_page()
	if _main_dimmer != null:
		_main_dimmer.visible = false
	if _root_panel != null:
		_root_panel.visible = false
	if _intro_overlay == null:
		return
	_intro_overlay.visible = true
	_intro_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_intro_tween = create_tween()
	_intro_tween.tween_property(_intro_overlay, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_intro_tween.tween_callback(func() -> void:
		if _intro_continue_btn != null and is_instance_valid(_intro_continue_btn):
			_intro_continue_btn.grab_focus()
		_play_field_notes_intro_typewriter(_intro_body, false)
	)


func _dismiss_field_notes_intro() -> void:
	if _field_notes_intro_dismissing:
		return
	if _intro_overlay == null or not _intro_overlay.visible:
		return
	_field_notes_intro_dismissing = true
	if CampaignManager != null:
		CampaignManager.field_notes_intro_seen = true
	_finish_field_notes_typewriter_now()
	_kill_intro_tween()
	_intro_tween = create_tween()
	_intro_tween.tween_property(_intro_overlay, "modulate:a", 0.0, 0.32).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_intro_tween.tween_callback(_finish_field_notes_intro_transition)


func _finish_field_notes_intro_transition() -> void:
	_kill_intro_tween()
	if _intro_overlay != null:
		_intro_overlay.visible = false
		_intro_overlay.modulate = Color.WHITE
	if _main_dimmer != null:
		_main_dimmer.visible = true
	if _root_panel != null:
		_root_panel.visible = true
	_field_notes_intro_dismissing = false
	_grab_main_focus_after_open()


func _grab_main_focus_after_open() -> void:
	if _list != null and _list.item_count > 0:
		_list.grab_focus()
		if _list.is_item_selectable(0):
			_list.select(0)
	elif _close_button != null:
		_close_button.grab_focus()


func open_and_refresh() -> void:
	_refresh()
	visible = true
	if _field_notes_intro_should_show():
		_start_field_notes_intro_lead_in()
	else:
		if _intro_lead_in != null:
			_intro_lead_in.visible = false
			_intro_lead_in.modulate = Color.WHITE
		if _root_panel != null:
			_root_panel.visible = true
		if _intro_overlay != null:
			_intro_overlay.visible = false
		_grab_main_focus_after_open()


func _on_close_pressed() -> void:
	if _intro_lead_in != null and _intro_lead_in.visible:
		_skip_field_notes_intro_to_catalogue()
		return
	if _intro_overlay != null and _intro_overlay.visible:
		_dismiss_field_notes_intro()
		return
	_commit_active_player_note()
	_notes_active_path = ""
	visible = false


func _set_entry_visuals_from_unit(u: UnitDataT) -> void:
	if _entry_portrait != null:
		_entry_portrait.texture = u.portrait
		_entry_portrait.visible = u.portrait != null
	if _entry_battle_sprite != null:
		_entry_battle_sprite.texture = u.unit_sprite
		_entry_battle_sprite.visible = u.unit_sprite != null


func _clear_entry_visuals() -> void:
	if _entry_portrait != null:
		_entry_portrait.texture = null
		_entry_portrait.visible = false
	if _entry_battle_sprite != null:
		_entry_battle_sprite.texture = null
		_entry_battle_sprite.visible = false


func _clear_detail_tabs(placeholder: String = "") -> void:
	var p: String = placeholder if not placeholder.is_empty() else ""
	for lbl in [_tab_stats, _tab_features, _tab_description, _tab_loot, _tab_maps]:
		if lbl == null:
			continue
		lbl.bbcode_enabled = true
		lbl.text = p


## [i]Tactica: Undead Remains[/i] scroll — gates bone-pile reform and bone toxin in Features (intel id [code]undead_blunt_bone_pile[/code]).
func _undead_remains_tactica_unlocked() -> bool:
	if CampaignManager == null:
		return false
	return CampaignManager.has_beastiary_intel("undead_blunt_bone_pile")


func _passive_is_bone_pile_reform(p: PassiveCombatAbilityData) -> bool:
	if p == null:
		return false
	if p.effect_kind == PassiveCombatAbilityData.EffectKind.BONE_PILE_REFORM_ON_DEATH:
		return true
	return str(p.ability_id).strip_edges() == "bone_pile_reform"


func _passive_is_bone_toxin(p: PassiveCombatAbilityData) -> bool:
	if p == null:
		return false
	if str(p.ability_id).strip_edges() == "bone_toxin_strike":
		return true
	return (
		p.effect_kind == PassiveCombatAbilityData.EffectKind.APPLY_STATUS_ON_WEAPON_HIT
		and str(p.status_id_to_apply).strip_edges() == "bone_toxin"
	)


func _map01_kit_display(idx: int) -> String:
	var i: int = clampi(idx, 0, MAP01_KIT_LABELS.size() - 1)
	return str(MAP01_KIT_LABELS[i])


func _catalogue_color_hex_rgb(c: Color) -> String:
	return "#" + c.to_html(false)


func _catalogue_hp_name_bbcode(max_hp: int) -> String:
	var mh: int = maxi(max_hp, 1)
	var c: Color = BattleFieldCombatForecastHelpersT.forecast_hp_fill_color(mh, mh)
	return "[color=%s]HP[/color]" % _catalogue_color_hex_rgb(c)


func _catalogue_stat_name_bbcode(unit_stat_key: String, label: String, value: int) -> String:
	var c: Color = DetailedUnitInfoRuntimeHelpersT.unit_info_stat_fill_color_standalone(unit_stat_key, value)
	return "[color=%s]%s[/color]" % [_catalogue_color_hex_rgb(c), label]


func _catalogue_growth_name_bbcode(unit_growth_property: String, label: String, value: int) -> String:
	var c: Color = DetailedUnitInfoContentHelpersT.detailed_unit_info_growth_fill_color_standalone(unit_growth_property, value)
	return "[color=%s]%s[/color]" % [_catalogue_color_hex_rgb(c), label]


func _loot_item_display_name(item: Resource) -> String:
	if item == null:
		return "?"
	if "weapon_name" in item:
		var w: Variant = item.get("weapon_name")
		if w != null and str(w).strip_edges() != "":
			return str(w).strip_edges()
	if "item_name" in item:
		var n: Variant = item.get("item_name")
		if n != null and str(n).strip_edges() != "":
			return str(n).strip_edges()
	var rp: String = item.resource_path
	if rp.is_empty():
		return "Item"
	return rp.get_file().get_basename().replace("_", " ")


func _build_stats_bbcode(u: UnitDataT, em: String, catalogue_mode: int = CATALOGUE_MODE_FACED) -> String:
	var lines: PackedStringArray = []
	if catalogue_mode == CATALOGUE_MODE_COMPANY:
		lines.append("[color=#888888][i]These numbers come from the unit file; your roster screen has live levels and gear.[/i][/color]")
		lines.append("")
	lines.append("[color=%s]%s[/color]" % [em, u.display_name])
	var cls: String = ""
	if u.character_class != null:
		cls = str(u.character_class.job_name).strip_edges()
	if cls != "":
		lines.append("Class: [color=%s]%s[/color]" % [em, cls])
	var species: String = UnitDataT.unit_type_display_name(u.unit_type)
	if species != "":
		lines.append("Type: [color=%s]%s[/color]" % [em, species])
	if u.starting_weapon != null:
		var wpn: String = str(u.starting_weapon.weapon_name).strip_edges()
		if wpn != "":
			lines.append("Weapon: [color=%s]%s[/color]" % [em, wpn])
	lines.append("")
	lines.append("[color=%s]Base stats[/color]" % em)
	lines.append(
		("%s %d   %s %d   %s %d\n" + "%s %d   %s %d   %s %d   %s %d")
		% [
			_catalogue_hp_name_bbcode(u.max_hp),
			u.max_hp,
			_catalogue_stat_name_bbcode("strength", "Str", u.strength),
			u.strength,
			_catalogue_stat_name_bbcode("magic", "Mag", u.magic),
			u.magic,
			_catalogue_stat_name_bbcode("defense", "Def", u.defense),
			u.defense,
			_catalogue_stat_name_bbcode("resistance", "Res", u.resistance),
			u.resistance,
			_catalogue_stat_name_bbcode("speed", "Spd", u.speed),
			u.speed,
			_catalogue_stat_name_bbcode("agility", "Agi", u.agility),
			u.agility,
		]
	)
	lines.append("")
	lines.append("[color=%s]Growth rates (%)[/color]" % em)
	lines.append(
		("%s %d · %s %d · %s %d · %s %d · %s %d · %s %d · %s %d")
		% [
			_catalogue_growth_name_bbcode("hp_growth", "HP", u.hp_growth),
			u.hp_growth,
			_catalogue_growth_name_bbcode("str_growth", "Str", u.str_growth),
			u.str_growth,
			_catalogue_growth_name_bbcode("mag_growth", "Mag", u.mag_growth),
			u.mag_growth,
			_catalogue_growth_name_bbcode("def_growth", "Def", u.def_growth),
			u.def_growth,
			_catalogue_growth_name_bbcode("res_growth", "Res", u.res_growth),
			u.res_growth,
			_catalogue_growth_name_bbcode("spd_growth", "Spd", u.spd_growth),
			u.spd_growth,
			_catalogue_growth_name_bbcode("agi_growth", "Agi", u.agi_growth),
			u.agi_growth,
		]
	)
	_append_damage_aptitudes_section(lines, u, em)
	return "\n".join(lines)


func _build_features_bbcode(u: UnitDataT, em: String) -> String:
	var lines: PackedStringArray = []
	if u.ability.strip_edges() != "":
		lines.append("[color=%s]Signature[/color]" % em)
		lines.append(u.ability.strip_edges())
		lines.append("")
	for pa in u.passive_combat_abilities:
		if pa is PassiveCombatAbilityData:
			var p: PassiveCombatAbilityData = pa as PassiveCombatAbilityData
			if (_passive_is_bone_pile_reform(p) or _passive_is_bone_toxin(p)) and not _undead_remains_tactica_unlocked():
				lines.append("???")
				lines.append("")
				continue
			var dn: String = str(p.display_name).strip_edges()
			if dn.is_empty():
				dn = str(p.ability_id).strip_edges()
			if dn.is_empty():
				dn = "Passive"
			lines.append("[color=%s]%s[/color]" % [em, dn])
			var dsc: String = str(p.description).strip_edges()
			if dsc != "":
				lines.append(dsc)
			else:
				lines.append("[i](No description.)[/i]")
			lines.append("")
	for aa in u.active_combat_abilities:
		if aa is ActiveCombatAbilityData:
			var a: ActiveCombatAbilityData = aa as ActiveCombatAbilityData
			var dn2: String = str(a.display_name).strip_edges()
			if dn2.is_empty():
				dn2 = str(a.ability_id).strip_edges()
			if dn2.is_empty():
				dn2 = "Active"
			lines.append("[color=%s]%s[/color] (cooldown %d)" % [em, dn2, a.cooldown_turns])
			var dsc2: String = str(a.description).strip_edges()
			if dsc2 != "":
				lines.append(dsc2)
			else:
				lines.append("[i](No description.)[/i]")
			lines.append("")
	if u.map01_enemy_kit > 0:
		lines.append("[color=%s]Ash-cult kit[/color]" % em)
		lines.append(_map01_kit_display(u.map01_enemy_kit))
		lines.append("")
	if u.counts_as_civilian_escort_target:
		lines.append("[color=%s]Target profile[/color]" % em)
		lines.append("Counts as a civilian / escort-style target for certain enemy effects.")
		lines.append("")
	if u.bone_pile_reform_rounds > 0:
		if _undead_remains_tactica_unlocked():
			lines.append("[color=%s]Bone pile (legacy)[/color]" % em)
			lines.append("Reform timer (rounds): %d — see passives for bludgeon rules." % u.bone_pile_reform_rounds)
			lines.append("")
		else:
			lines.append("???")
			lines.append("")
	if lines.is_empty():
		return "[i]No combat features recorded for this entry.[/i]"
	while lines.size() > 0 and str(lines[lines.size() - 1]).strip_edges() == "":
		lines.remove_at(lines.size() - 1)
	return "\n".join(lines)


func _phys_mult_non_default(u: UnitDataT) -> bool:
	return (
		absf(u.phys_mult_slashing - 1.0) > 0.001
		or absf(u.phys_mult_piercing - 1.0) > 0.001
		or absf(u.phys_mult_bludgeoning - 1.0) > 0.001
	)


func _magic_mult_non_default(u: UnitDataT) -> bool:
	return (
		absf(u.mag_mult_arcane - 1.0) > 0.001
		or absf(u.mag_mult_fire - 1.0) > 0.001
		or absf(u.mag_mult_frost - 1.0) > 0.001
		or absf(u.mag_mult_lightning - 1.0) > 0.001
		or absf(u.mag_mult_divine - 1.0) > 0.001
		or absf(u.mag_mult_necrotic - 1.0) > 0.001
	)


func _aptitude_mult_epsilon() -> float:
	return 0.001


func _aptitude_qualifier_for_mult(mult: float) -> String:
	var e: float = _aptitude_mult_epsilon()
	if mult < 1.0 - e:
		return "resistant"
	if mult > 1.0 + e:
		return "vulnerable"
	return "neutral"


func _append_aptitude_line_if_deviant(lines: PackedStringArray, label: String, mult: float, em: String) -> void:
	if absf(mult - 1.0) <= _aptitude_mult_epsilon():
		return
	var q: String = _aptitude_qualifier_for_mult(mult)
	lines.append("  • [color=%s]%s[/color]: ×%.2f (%s)" % [em, label, mult, q])


## Stats tab (and any other caller): lists only non-1.0 channels. Full numbers when [code]intel_damage_type_readout[/code] is unlocked; otherwise a single locked blurb.
func _append_damage_aptitudes_section(lines: PackedStringArray, u: UnitDataT, em: String) -> void:
	var has_phys: bool = _phys_mult_non_default(u)
	var has_magic: bool = _magic_mult_non_default(u)
	if not has_phys and not has_magic:
		return
	if CampaignManager == null:
		return
	CampaignManager.ensure_beastiary_intel_unlocked()
	var intel_ok: bool = CampaignManager.has_beastiary_intel("intel_damage_type_readout")
	lines.append("")
	lines.append("[color=%s]Resistances & vulnerabilities[/color]" % em)
	if not intel_ok:
		lines.append(
			"[color=#888888]Find intel on your travels — then Elara can list what this foe resists and what it's weak to.[/color]"
		)
		lines.append("")
		return
	if has_phys:
		lines.append("[color=%s]Physical[/color]" % em)
		_append_aptitude_line_if_deviant(lines, "Slashing", u.phys_mult_slashing, em)
		_append_aptitude_line_if_deviant(lines, "Piercing", u.phys_mult_piercing, em)
		_append_aptitude_line_if_deviant(lines, "Bludgeoning", u.phys_mult_bludgeoning, em)
	if has_magic:
		lines.append("[color=%s]Magic channels[/color]" % em)
		_append_aptitude_line_if_deviant(lines, "Arcane", u.mag_mult_arcane, em)
		_append_aptitude_line_if_deviant(lines, "Fire", u.mag_mult_fire, em)
		_append_aptitude_line_if_deviant(lines, "Frost", u.mag_mult_frost, em)
		_append_aptitude_line_if_deviant(lines, "Lightning", u.mag_mult_lightning, em)
		_append_aptitude_line_if_deviant(lines, "Divine", u.mag_mult_divine, em)
		_append_aptitude_line_if_deviant(lines, "Necrotic", u.mag_mult_necrotic, em)
	lines.append("[color=#888888](×1.0 is normal. Lower takes less damage; higher takes more.)[/color]")
	lines.append("")


func _build_description_bbcode(unit_path: String, u: UnitDataT, em: String) -> String:
	var lines: PackedStringArray = []
	var quotes: PackedStringArray = u.pre_battle_quote
	if quotes.size() > 0:
		lines.append("[color=%s]Battle lines[/color]" % em)
		for q in quotes:
			var qs: String = str(q).strip_edges()
			if qs != "":
				lines.append("• [i]%s[/i]" % qs)
		lines.append("")
	var deaths: PackedStringArray = u.death_quotes
	if deaths.size() > 0:
		lines.append("[color=%s]Death / defeat lines[/color]" % em)
		var shown: int = mini(6, deaths.size())
		for i in range(shown):
			var ds: String = str(deaths[i]).strip_edges()
			if ds != "":
				lines.append("• [i]%s[/i]" % ds)
		if deaths.size() > shown:
			lines.append("[color=#888888](+%d more in data)[/color]" % (deaths.size() - shown))
		lines.append("")
	var intel_entries: Array = BeastiaryIntelRegistry.get_entries_for_unit_data_path(unit_path)
	if not intel_entries.is_empty():
		lines.append("[color=%s]Tactical notes[/color]" % em)
		if CampaignManager != null:
			CampaignManager.ensure_beastiary_intel_unlocked()
		for entry in intel_entries:
			if not (entry is Dictionary):
				continue
			var eid: String = str(entry.get("id", "")).strip_edges()
			var body: String = str(entry.get("body_bbcode", ""))
			if CampaignManager != null and CampaignManager.has_beastiary_intel(eid):
				lines.append(body)
			else:
				lines.append("???")
			lines.append("")
	if lines.is_empty():
		return "[i]No narrative or tactical write-up yet.[/i]"
	while lines.size() > 0 and str(lines[lines.size() - 1]).strip_edges() == "":
		lines.remove_at(lines.size() - 1)
	return "\n".join(lines)


func _build_loot_bbcode(u: UnitDataT, em: String) -> String:
	var lines: PackedStringArray = []
	lines.append("[color=%s]Gold[/color]" % em)
	if u.max_gold_drop <= 0 and u.min_gold_drop <= 0:
		lines.append("None")
	else:
		lines.append("%d – %d" % [u.min_gold_drop, u.max_gold_drop])
	lines.append("")
	lines.append("[color=%s]Equipped weapon[/color]" % em)
	if u.drops_equipped_weapon:
		lines.append("Can drop starting weapon (%d%% chance)." % clampi(u.equipped_weapon_chance, 0, 100))
	else:
		lines.append("Does not drop equipped weapon.")
	lines.append("")
	lines.append("[color=%s]Extra drops[/color]" % em)
	if u.extra_loot.is_empty():
		lines.append("None listed.")
	else:
		for ld in u.extra_loot:
			if ld == null:
				continue
			if ld is LootDrop:
				var drop: LootDrop = ld as LootDrop
				var nm: String = _loot_item_display_name(drop.item)
				lines.append("• %s — %.0f%%" % [nm, clampf(drop.drop_chance, 0.0, 100.0)])
			else:
				lines.append("• [i](Invalid drop entry)[/i]")
	return "\n".join(lines)


func _build_maps_bbcode(unit_path: String, em: String) -> String:
	var maps: PackedStringArray = BeastiaryMapIndex.maps_for_unit_data_path(unit_path)
	if maps.is_empty():
		return "[i]No scripted spawns found under [code]Scenes/Levels[/code] for this unit file.\n(Bosses or spawners embedded in other scenes may not appear here yet.)[/i]"
	var lines: PackedStringArray = []
	lines.append("[color=%s]Levels referencing this unit data[/color]" % em)
	lines.append("[color=#888888]Detected from level .tscn files (hand-placed units’ Data field, spawner fields, overrides).[/color]")
	lines.append("")
	for mname in maps:
		lines.append("• %s" % mname)
	return "\n".join(lines)


func _populate_detail_tabs(unit_path: String, u: UnitDataT) -> void:
	var em: String = BeastiaryIntelRegistry.INTEL_EMPHASIS_COLOR
	if _tab_stats:
		_tab_stats.text = _build_stats_bbcode(u, em, _catalogue_mode)
	if _tab_features:
		_tab_features.text = _build_features_bbcode(u, em)
	if _tab_description:
		_tab_description.text = _build_description_bbcode(unit_path, u, em)
	if _tab_loot:
		_tab_loot.text = _build_loot_bbcode(u, em)
	if _tab_maps:
		_tab_maps.text = _build_maps_bbcode(unit_path, em)


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _paths_sorted.size():
		_clear_entry_visuals()
		_set_notes_ui_for_path("", false)
		_clear_detail_tabs("[i]Select an entry.[/i]")
		return
	var path: String = _paths_sorted[index]
	_set_notes_ui_for_path(path, true)
	var ud: Resource = load(path) as Resource
	if ud == null or not (ud is UnitDataT):
		_clear_entry_visuals()
		_clear_detail_tabs("[i]Could not load entry.[/i]")
		return
	var u := ud as UnitDataT
	_set_entry_visuals_from_unit(u)
	_populate_detail_tabs(path, u)


func _pair_for_unit_path(p: String) -> Dictionary:
	var path_s: String = str(p).strip_edges()
	var list_label: String = path_s.get_file().get_basename().replace("_", " ")
	if path_s != "" and ResourceLoader.exists(path_s):
		var ud: Resource = load(path_s) as Resource
		if ud != null and ud is UnitDataT:
			var dn: String = str((ud as UnitDataT).display_name).strip_edges()
			if dn != "":
				list_label = dn
	return {"path": path_s, "sort_key": list_label.to_lower(), "list_label": list_label}


func _collect_faced_catalogue_pairs() -> Array:
	var pairs: Array = []
	CampaignManager.ensure_beastiary_seen()
	for k in CampaignManager.beastiary_seen.keys():
		if not bool(CampaignManager.beastiary_seen.get(k, false)):
			continue
		var p: String = str(k).strip_edges()
		if p == "":
			continue
		pairs.append(_pair_for_unit_path(p))
	return pairs


func _company_roster_entry_is_custom_avatar(unit_dict: Dictionary) -> bool:
	if bool(unit_dict.get("is_custom_avatar", false)):
		return true
	if CampaignManager == null:
		return false
	var un: String = str(unit_dict.get("unit_name", "")).strip_edges()
	var av_name: String = str(CampaignManager.custom_avatar.get("name", "")).strip_edges()
	var av_unit: String = str(CampaignManager.custom_avatar.get("unit_name", "")).strip_edges()
	if un != "" and av_name != "" and un == av_name:
		return true
	if un != "" and av_unit != "" and un == av_unit:
		return true
	return false


func _collect_company_catalogue_pairs() -> Array:
	var pairs: Array = []
	for unit_dict in CampaignManager.player_roster:
		if typeof(unit_dict) != TYPE_DICTIONARY:
			continue
		if _company_roster_entry_is_custom_avatar(unit_dict):
			continue
		var p: String = str(unit_dict.get("data_path_hint", "")).strip_edges()
		if p == "" or not p.begins_with("res://") or not ResourceLoader.exists(p):
			continue
		var pair: Dictionary = _pair_for_unit_path(p)
		var roster_name: String = str(unit_dict.get("unit_name", "")).strip_edges()
		if roster_name != "":
			pair["list_label"] = roster_name
			var lv: int = int(unit_dict.get("level", 0))
			if lv > 0:
				pair["list_label"] = "%s — Lv %d" % [roster_name, lv]
			pair["sort_key"] = str(pair["list_label"]).to_lower()
		pairs.append(pair)
	return pairs


func _collect_allies_catalogue_pairs() -> Array:
	var pairs: Array = []
	CampaignManager.ensure_beastiary_neutral_seen()
	for k in CampaignManager.beastiary_neutral_seen.keys():
		if not bool(CampaignManager.beastiary_neutral_seen.get(k, false)):
			continue
		var p: String = str(k).strip_edges()
		if p == "":
			continue
		pairs.append(_pair_for_unit_path(p))
	return pairs


func _refresh() -> void:
	_sync_catalogue_mode_from_buttons()
	_commit_active_player_note()
	_notes_active_path = ""
	if _notes_edit != null:
		_notes_suppress_edit_signal = true
		_notes_edit.text = ""
		_notes_edit.editable = false
		_notes_suppress_edit_signal = false
	if _notes_section != null:
		_notes_section.visible = false
	_paths_sorted.clear()
	if _list:
		_list.clear()
	if CampaignManager == null:
		_clear_entry_visuals()
		if _empty:
			_empty.visible = true
			_empty.text = "No campaign data."
		_clear_detail_tabs("")
		return
	var pairs: Array = []
	match _catalogue_mode:
		CATALOGUE_MODE_COMPANY:
			pairs = _collect_company_catalogue_pairs()
		CATALOGUE_MODE_ALLIES:
			pairs = _collect_allies_catalogue_pairs()
		_:
			pairs = _collect_faced_catalogue_pairs()
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("sort_key", "")) < str(b.get("sort_key", "")))
	for item in pairs:
		_paths_sorted.append(str(item.get("path", "")))
		if _list:
			_list.add_item(str(item.get("list_label", "???")))
	var has_any: bool = not _paths_sorted.is_empty()
	if _empty:
		_empty.visible = not has_any
		match _catalogue_mode:
			CATALOGUE_MODE_COMPANY:
				_empty.text = "No one is on the roster yet."
			CATALOGUE_MODE_ALLIES:
				_empty.text = "No allied fighters catalogued yet. Deploy with them in battle to add them here."
			_:
				_empty.text = "No creatures catalogued yet. Fight a battle to record what you have faced."
	if not has_any:
		_clear_entry_visuals()
		_clear_detail_tabs("")
	_apply_scholar_blurb_for_mode()
	if _list and has_any and _list.item_count > 0:
		_list.select(0)
		_on_item_selected(0)
