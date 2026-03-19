extends Panel

@onready var enclosure: Control = $EnclosureArea
@onready var close_btn: Button = $CloseRanchButton
@onready var shake_root: Control = get_node_or_null("ShakeRoot") if has_node("ShakeRoot") else enclosure

# --- NEW REFERENCES ---
@onready var favorite_label: Label = get_node_or_null("FavoriteDragonLabel")
# Debug Buttons
@onready var debug_anger_btn: Button = get_node_or_null("DebugMorgraPanel/BtnAnger")
@onready var debug_neutral_btn: Button = get_node_or_null("DebugMorgraPanel/BtnNeutral")
@onready var debug_adore_btn: Button = get_node_or_null("DebugMorgraPanel/BtnAdore")
@onready var debug_reset_btn: Button = get_node_or_null("DebugMorgraPanel/BtnReset")

# --- INFO CARD UI ---
@onready var info_card: Control = $DragonInfoCard
@onready var name_input: LineEdit = $DragonInfoCard/VBoxContainer/HBoxContainer/NameInput
@onready var save_name_btn: Button = $DragonInfoCard/VBoxContainer/HBoxContainer/SaveNameBtn
@onready var details_label: RichTextLabel = $DragonInfoCard/VBoxContainer/DetailsLabel
@onready var traits_label: RichTextLabel = $DragonInfoCard/VBoxContainer/TraitsLabel
@onready var growth_label: RichTextLabel = $DragonInfoCard/VBoxContainer/GrowthLabel
@onready var feed_btn: Button = $DragonInfoCard/VBoxContainer/FeedButton
@onready var close_card_btn: Button = $DragonInfoCard/VBoxContainer/CloseCardBtn
@onready var stats_dragon_label: RichTextLabel = $DragonInfoCard/VBoxContainer/StatsDragonLabel

@onready var parent_a_sprite = $BreedPanel/ParentABtn/Sprite
@onready var parent_b_sprite = $BreedPanel/ParentBBtn/Sprite

const SOCIAL_INTERACTION_MIN_DELAY: float = 4.0
const SOCIAL_INTERACTION_MAX_DELAY: float = 8.0
const SOCIAL_PAIR_COOLDOWN: float = 12.0
const SOCIAL_MIN_DISTANCE_BIAS: float = 420.0

var social_interaction_timer: float = 0.0
var social_pair_cooldowns: Dictionary = {}
var is_social_animating: bool = false

var breed_preview_fx_root: Control
var breed_prediction_backplate: ColorRect
var breed_compat_bar_bg: ColorRect
var breed_compat_bar_fill: ColorRect
var breed_compat_value_label: Label
var breed_mutation_label: RichTextLabel
var breed_resonance_glow: ColorRect
var breed_resonance_ring: ColorRect

var breed_parent_a_tween: Tween
var breed_parent_b_tween: Tween
var breed_resonance_tween: Tween
var breed_confirm_tween: Tween

@onready var training_status_label: RichTextLabel = get_node_or_null("DragonInfoCard/VBoxContainer/TrainingStatusLabel")
@onready var training_program_option: OptionButton = get_node_or_null("DragonInfoCard/VBoxContainer/TrainingProgramOption")
@onready var training_intensity_option: OptionButton = get_node_or_null("DragonInfoCard/VBoxContainer/TrainingIntensityOption")
@onready var training_preview_label: RichTextLabel = get_node_or_null("DragonInfoCard/VBoxContainer/TrainingPreviewLabel")
@onready var train_dragon_btn: Button = get_node_or_null("DragonInfoCard/VBoxContainer/TrainDragonBtn")
@onready var rest_dragon_btn: Button = get_node_or_null("DragonInfoCard/VBoxContainer/RestDragonBtn")

var is_training_animating: bool = false
var training_program_ids: Array[String] = []

# --- BREEDING UI REFERENCES ---
@onready var open_breed_btn = $OpenBreedBtn # Adjust paths if you put them in containers!
@onready var breed_panel = $BreedPanel
@onready var close_breed_btn = $BreedPanel/CloseBreedBtn
@onready var parent_a_btn = $BreedPanel/ParentABtn
@onready var parent_b_btn = $BreedPanel/ParentBBtn
@onready var prediction_label = $BreedPanel/PredictionLabel
@onready var confirm_breed_btn = $BreedPanel/ConfirmBreedBtn

@onready var breed_selection_popup = $BreedSelectionPopup
@onready var close_selection_btn = $BreedSelectionPopup/CloseSelectionBtn
@onready var selection_vbox = $BreedSelectionPopup/ScrollContainer/SelectionVBox

# Memory for the currently selected parents
var selected_parent_a_index: int = -1
var selected_parent_b_index: int = -1
var selecting_for_slot: String = "" # Will be "A" or "B"

var is_hatch_animating: bool = false

const DRAGON_ACTOR_SCENE: PackedScene = preload("res://Scenes/DragonActor.tscn")
const MEAT_ICON: Texture2D = preload("res://Assets/Sprites/UI/meat_icon.png")

@onready var hatch_btn: Button = get_node_or_null("HatchEggButton")
const EGG_ICON: Texture2D = preload("res://Assets/Sprites/UI/egg_icon.png") # UPDATE THIS PATH to your egg sprite!

@onready var hunt_btn: Button = get_node_or_null("DragonInfoCard/VBoxContainer/HuntRabbitBtn")
const RABBIT_COST: int = 15
var is_hunt_animating: bool = false


var selected_dragon_uid: String = ""
var is_feed_animating: bool = false
var actor_by_uid: Dictionary = {}

var is_pet_animating: bool = false

func _ready() -> void:
	close_btn.pressed.connect(func(): hide())
	visibility_changed.connect(_on_visibility_changed)

	save_name_btn.pressed.connect(_on_save_name_pressed)
	close_card_btn.pressed.connect(func():
		info_card.hide()
		selected_dragon_uid = ""
		_refresh_actor_selection()
	)
	feed_btn.pressed.connect(_on_feed_pressed)

	# --- BREEDING CONNECTIONS ---
	if open_breed_btn:
		open_breed_btn.pressed.connect(_open_breeding_station)
	if close_breed_btn:
		close_breed_btn.pressed.connect(_close_breeding_station)
	if close_selection_btn:
		close_selection_btn.pressed.connect(func(): breed_selection_popup.hide())

	if parent_a_btn:
		parent_a_btn.pressed.connect(func(): _open_parent_selector("A"))
	if parent_b_btn:
		parent_b_btn.pressed.connect(func(): _open_parent_selector("B"))
	if confirm_breed_btn:
		confirm_breed_btn.pressed.connect(_on_confirm_breed_pressed)

	stats_dragon_label.fit_content = true
	stats_dragon_label.scroll_active = false
	stats_dragon_label.custom_minimum_size = Vector2(0, 120)
	growth_label.custom_minimum_size = Vector2(0, 80)

	# Connect Debug Buttons
	if debug_anger_btn: debug_anger_btn.pressed.connect(_debug_force_anger)
	if debug_neutral_btn: debug_neutral_btn.pressed.connect(_debug_force_neutral)
	if debug_adore_btn: debug_adore_btn.pressed.connect(_debug_force_adore)
	if debug_reset_btn: debug_reset_btn.pressed.connect(_debug_reset_morgra)
	
	_update_favorite_display()

	if hatch_btn != null:
		hatch_btn.pressed.connect(_on_hatch_pressed)
		hatch_btn.disabled = is_feed_animating or is_pet_animating or is_hunt_animating or is_hatch_animating or is_training_animating

	if hunt_btn != null:
		hunt_btn.pressed.connect(_on_hunt_pressed)

	if training_program_option != null:
		training_program_option.item_selected.connect(_on_training_selection_changed)

	if training_intensity_option != null:
		training_intensity_option.item_selected.connect(_on_training_selection_changed)

	if train_dragon_btn != null:
		train_dragon_btn.pressed.connect(_on_train_pressed)

	if rest_dragon_btn != null:
		rest_dragon_btn.pressed.connect(_on_rest_pressed)

	_setup_training_ui()

	_ensure_breeding_station_fx_ui()
	set_process(true)
	social_interaction_timer = _roll_next_social_time()

	# --- CHEAT: GIVE ME A DRAGON ROSE ---
	var debug_rose = ConsumableData.new()
	debug_rose.item_name = "Dragon Rose"
	CampaignManager.global_inventory.append(debug_rose)

	# --- CHEAT: INSTANT ADULTS ---
	for d in DragonManager.player_dragons:
		d["stage"] = 3 # Force to Adult!

func _on_visibility_changed() -> void:
	if visible:
		_spawn_dragons()
		_refresh_training_controls()
		_update_favorite_display()
	else:
		info_card.hide()
		selected_dragon_uid = ""
		is_feed_animating = false
		is_training_animating = false
		_clear_dragons()
		is_social_animating = false
		social_pair_cooldowns.clear()
		social_interaction_timer = _roll_next_social_time()
func _spawn_dragons() -> void:
	_clear_dragons()

	if not DragonManager or DragonManager.player_dragons.is_empty():
		return

	for d_data in DragonManager.player_dragons:
		var uid: String = str(d_data.get("uid", ""))
		if uid == "":
			continue

		var actor: DragonActor = DRAGON_ACTOR_SCENE.instantiate()
		actor.set_meta("is_dragon", true)

		enclosure.add_child(actor)
		actor.setup(d_data)

		actor.position = Vector2(
			randf_range(0.0, max(0.0, enclosure.size.x - actor.size.x)),
			randf_range(0.0, max(0.0, enclosure.size.y - actor.size.y))
		)

		actor_by_uid[uid] = actor

		actor.gui_input.connect(_on_dragon_input.bind(uid))
		actor.mouse_entered.connect(_on_actor_mouse_entered.bind(uid))
		actor.mouse_exited.connect(_on_actor_mouse_exited.bind(uid))

	_refresh_actor_selection()

func _clear_dragons() -> void:
	actor_by_uid.clear()

	for child in enclosure.get_children():
		if child.has_meta("is_dragon"):
			child.queue_free()

func _get_dragon_index_by_uid(uid: String) -> int:
	if uid == "":
		return -1

	for i in range(DragonManager.player_dragons.size()):
		var d: Dictionary = DragonManager.player_dragons[i]
		if str(d.get("uid", "")) == uid:
			return i

	return -1

func _get_selected_index() -> int:
	return _get_dragon_index_by_uid(selected_dragon_uid)

func _get_actor_by_uid(uid: String) -> DragonActor:
	if not actor_by_uid.has(uid):
		return null

	var actor: Variant = actor_by_uid[uid]
	if actor is DragonActor and is_instance_valid(actor):
		return actor

	actor_by_uid.erase(uid)
	return null

func _refresh_actor_selection() -> void:
	for uid in actor_by_uid.keys():
		var actor: DragonActor = _get_actor_by_uid(str(uid))
		if actor != null:
			actor.set_selected(str(uid) == selected_dragon_uid)

func _on_actor_mouse_entered(uid: String) -> void:
	var actor: DragonActor = _get_actor_by_uid(uid)
	if actor != null:
		actor.set_hovered(true)

func _on_actor_mouse_exited(uid: String) -> void:
	var actor: DragonActor = _get_actor_by_uid(uid)
	if actor != null:
		actor.set_hovered(false)

# ==========================================
# INFO CARD LOGIC
# ==========================================

func _on_dragon_input(event: InputEvent, uid: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			selected_dragon_uid = uid
			_update_info_card()
			_refresh_actor_selection()
			info_card.show()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			selected_dragon_uid = uid
			_update_info_card()
			_refresh_actor_selection()
			info_card.show()
			_pet_dragon(uid)

func _update_info_card() -> void:
	var selected_index: int = _get_selected_index()
	if selected_index < 0 or selected_index >= DragonManager.player_dragons.size():
		return

	var d: Dictionary = DragonManager.player_dragons[selected_index]

	name_input.text = str(d["name"])

	var stage_str: String = "Egg"
	if d["stage"] == 1:
		stage_str = "Baby"
	elif d["stage"] == 2:
		stage_str = "Juvenile"
	elif d["stage"] == 3:
		stage_str = "Adult"

	details_label.text = (
		"Gen " + str(d.get("generation", 1)) + " " + str(d["element"]) + " " + stage_str +
		"\nBond: " + str(int(d.get("bond", 0))) + " | Mood: " + str(d.get("mood", "Curious"))
	)

	var traits_array: Array = d.get("traits", [])

	if traits_array.is_empty():
		traits_label.text = "Traits: None"
	else:
		var joined_traits: String = ", ".join(traits_array)
		if traits_array.size() >= 2:
			traits_label.text = "⭐ Traits: " + joined_traits + " ⭐"
		else:
			traits_label.text = "Traits: " + joined_traits

	var happiness_value: int = int(d.get("happiness", 50))
	var happiness_meter: String = _make_meter(happiness_value, 100, 10)
	var happiness_state: String = DragonManager.get_happiness_state_name(happiness_value)
	var growth_mult: float = DragonManager.get_happiness_growth_multiplier_for_value(happiness_value)
	var growth_bonus_pct: int = int(round((growth_mult - 1.0) * 100.0))
	var growth_bonus_text: String = ("+" if growth_bonus_pct >= 0 else "") + str(growth_bonus_pct) + "% GP"
	var pet_cd_remaining: int = max(0, int(d.get("pet_cooldown_until", 0)) - int(Time.get_unix_time_from_system()))
	var ability_text: String = str(d.get("ability", "None"))

	stats_dragon_label.text = (
		"LV: %d | EXP: %d | BOND: %d | HAPPY: %d\n" +
		"HP: %d | STR: %d | MAG: %d\n" +
		"DEF: %d | RES: %d | SPD: %d | AGI: %d\n" +
		"MOV: %d | ABIL: %s\n" +
		"PET CD: %ds"
	) % [
		int(d.get("level", 1)),
		int(d.get("experience", 0)),
		int(d.get("bond", 0)),
		happiness_value,
		int(d.get("max_hp", 0)),
		int(d.get("strength", 0)),
		int(d.get("magic", 0)),
		int(d.get("defense", 0)),
		int(d.get("resistance", 0)),
		int(d.get("speed", 0)),
		int(d.get("agility", 0)),
		int(d.get("move_range", 0)),
		ability_text,
		pet_cd_remaining
	]

	if d["stage"] == 3:
		growth_label.text = (
			"Growth: MAX LEVEL\n" +
			"Happiness: %s %d/100 (%s)\n" +
			"Growth Bonus: %s"
		) % [
			happiness_meter,
			happiness_value,
			happiness_state,
			growth_bonus_text
		]
		feed_btn.disabled = true
		feed_btn.text = "Fully Grown"
	else:
		var required_gp: int = 50 if d["stage"] == 1 else 150
		growth_label.text = (
			"Growth: %d / %d\n" +
			"Happiness: %s %d/100 (%s)\n" +
			"Growth Bonus: %s"
		) % [
			int(d.get("growth_points", 0)),
			required_gp,
			happiness_meter,
			happiness_value,
			happiness_state,
			growth_bonus_text
		]
		feed_btn.disabled = is_feed_animating or is_pet_animating or is_hunt_animating or is_training_animating
		feed_btn.text = "Feed (Use Meat)"

	if hunt_btn != null:
		hunt_btn.disabled = is_feed_animating or is_pet_animating or is_hunt_animating or is_training_animating or int(d.get("stage", 1)) <= 0
		hunt_btn.text = "Throw Rabbit (%d Gold)" % RABBIT_COST

	var fatigue_value: int = int(d.get("fatigue", 0))
	var fatigue_meter: String = _make_meter(fatigue_value, 100, 10)
	var sessions_value: int = int(d.get("training_sessions", 0))
	var ranch_action_used: bool = _dragon_has_used_ranch_action(d)
	var ranch_action_text: String = "USED" if ranch_action_used else "READY"

	if training_status_label != null:
		training_status_label.bbcode_enabled = true
		training_status_label.fit_content = true
		training_status_label.scroll_active = false
		training_status_label.text = (
			"[b]Training[/b]\n" +
			"Fatigue: %s %d/100\n" % [fatigue_meter, fatigue_value] +
			"Sessions: %d\n" % sessions_value +
			"Level Action: [color=%s]%s[/color]" % [
				"orange" if ranch_action_used else "lime",
				ranch_action_text
			]
		)

	_refresh_training_controls()
func _on_save_name_pressed() -> void:
	var selected_index: int = _get_selected_index()
	if selected_index < 0 or selected_index >= DragonManager.player_dragons.size():
		return

	var new_name: String = name_input.text.strip_edges()
	if new_name == "":
		return

	DragonManager.player_dragons[selected_index]["name"] = new_name

	var actor: DragonActor = _get_actor_by_uid(selected_dragon_uid)
	if actor != null:
		actor.refresh_name_only()

	_update_info_card()
	_refresh_actor_selection()

func _on_feed_pressed() -> void:
	if is_feed_animating or is_pet_animating or is_hatch_animating or is_training_animating:
		return

	var selected_index: int = _get_selected_index()
	if selected_index < 0 or selected_index >= DragonManager.player_dragons.size():
		return

	var actor: DragonActor = _get_actor_by_uid(selected_dragon_uid)
	if actor == null:
		return

	var meat_index: int = -1
	for i in range(CampaignManager.global_inventory.size()):
		var item = CampaignManager.global_inventory[i]
		if item is ConsumableData:
			var i_name: String = item.item_name
			if "Meat" in i_name or "meat" in i_name:
				meat_index = i
				break

	if meat_index == -1:
		feed_btn.text = "No Meat in Inventory!"
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(feed_btn):
				feed_btn.text = "Feed (Use Meat)"
		)
		return

	is_feed_animating = true
	feed_btn.disabled = true

	CampaignManager.global_inventory.remove_at(meat_index)
	var result: Dictionary = DragonManager.feed_dragon(selected_index, 25)
	_update_info_card()

	await _play_feed_projectile(actor)

	if result.get("evolved", false):
		_shake_enclosure(10.0, 0.22)

		var updated_data: Dictionary = DragonManager.player_dragons[selected_index]
		actor.play_evolution_fx(
			updated_data,
			int(result.get("old_stage", -1)),
			int(result.get("new_stage", -1))
		)

		await get_tree().create_timer(0.12).timeout
		_shake_enclosure(6.0, 0.15)
	else:
		actor.refresh_from_data(DragonManager.player_dragons[selected_index])
		actor.play_feed_bounce(int(result.get("growth_added", 25)))
		_shake_enclosure(3.0, 0.10)

	await get_tree().create_timer(0.20).timeout

	is_feed_animating = false
	_update_info_card()
	_trigger_morgra("feed")
	
# ==========================================
# JUICE / FX
# ==========================================

func _play_feed_projectile(target_actor: DragonActor) -> void:
	if target_actor == null or not is_instance_valid(target_actor):
		return

	var meat: TextureRect = TextureRect.new()
	meat.texture = MEAT_ICON
	meat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	meat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	meat.size = Vector2(28, 28)
	meat.scale = Vector2.ONE
	meat.rotation = 0.0
	meat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meat.z_index = 100

	enclosure.add_child(meat)

	var start_global: Vector2 = feed_btn.global_position + (feed_btn.size * 0.5)
	var end_global: Vector2 = target_actor.global_position + Vector2(target_actor.size.x * 0.55, target_actor.size.y * 0.35)
	var mid_global: Vector2 = (start_global + end_global) * 0.5 + Vector2(0, -70)

	meat.global_position = start_global - (meat.size * 0.5)

	var tw: Tween = create_tween()
	tw.tween_property(meat, "global_position", mid_global - (meat.size * 0.5), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(meat, "scale", Vector2(1.15, 1.15), 0.16)
	tw.parallel().tween_property(meat, "rotation", deg_to_rad(-12.0), 0.16)

	tw.tween_property(meat, "global_position", end_global - (meat.size * 0.5), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(meat, "scale", Vector2(0.85, 0.85), 0.14)
	tw.parallel().tween_property(meat, "rotation", deg_to_rad(10.0), 0.14)

	await tw.finished

	if is_instance_valid(meat):
		meat.queue_free()

func _shake_enclosure(power: float = 8.0, duration: float = 0.18) -> void:
	if shake_root == null or not is_instance_valid(shake_root):
		return

	var original: Vector2 = shake_root.position
	var tw: Tween = create_tween()

	for i in range(4):
		var offset: Vector2 = Vector2(
			randf_range(-power, power),
			randf_range(-power * 0.55, power * 0.55)
		)
		tw.tween_property(shake_root, "position", original + offset, duration / 8.0)

	tw.tween_property(shake_root, "position", original, duration / 4.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _pet_dragon(uid: String) -> void:
	if is_feed_animating or is_pet_animating or is_hatch_animating or is_training_animating:
		return

	var actor: DragonActor = _get_actor_by_uid(uid)
	if actor == null:
		return

	var index: int = _get_dragon_index_by_uid(uid)
	if index == -1:
		return

	is_pet_animating = true

	var result: Dictionary = DragonManager.pet_dragon(index)

	actor.refresh_from_data(DragonManager.player_dragons[index])
	_update_info_card()

	if bool(result.get("on_cooldown", false)):
		actor._spawn_float_text(str(result.get("float_text", "Wait")), Color(1.0, 0.75, 0.25))
		await get_tree().create_timer(0.15).timeout
		is_pet_animating = false
		_update_info_card()
		return

	actor.play_pet_reaction(result)

	if str(result.get("reaction", "")) == "annoyed":
		_shake_enclosure(2.0, 0.08)

	await get_tree().create_timer(0.15).timeout

	is_pet_animating = false
	_update_info_card()
	
func _make_meter(value: int, max_value: int = 100, segments: int = 10) -> String:
	var filled: int = int(round((float(value) / float(max_value)) * float(segments)))
	filled = clamp(filled, 0, segments)

	var meter: String = "["
	for i in range(segments):
		meter += "#" if i < filled else "-"
	meter += "]"
	return meter
	
func _on_hunt_pressed() -> void:
	if is_feed_animating or is_pet_animating or is_hunt_animating or is_hatch_animating or is_training_animating:
		return

	var selected_index: int = _get_selected_index()
	if selected_index < 0 or selected_index >= DragonManager.player_dragons.size():
		return

	var actor: DragonActor = _get_actor_by_uid(selected_dragon_uid)
	if actor == null:
		return

	if _get_player_gold() < RABBIT_COST:
		if hunt_btn != null:
			hunt_btn.text = "Need %d Gold!" % RABBIT_COST
			get_tree().create_timer(1.2).timeout.connect(func():
				if is_instance_valid(hunt_btn):
					hunt_btn.text = "Throw Rabbit (%d Gold)" % RABBIT_COST
			)
		else:
			actor.show_float_text("Need %d Gold" % RABBIT_COST, Color(1.0, 0.55, 0.25))
		return

	if not _spend_player_gold(RABBIT_COST):
		return

	is_hunt_animating = true
	_update_info_card()
	_trigger_morgra("hunt")
	var throw_result: Dictionary = await _play_rabbit_throw(actor)
	var rabbit_node: Control = throw_result.get("rabbit", null)

	if rabbit_node != null and is_instance_valid(rabbit_node):
		await _run_hunt_chase_simultaneous(actor, rabbit_node)
	else:
		var fallback_target: Vector2 = actor.position + Vector2(actor.size.x * 0.5, actor.size.y * 0.35)
		var fallback_time: float = actor.begin_hunt_step(fallback_target, true)
		await get_tree().create_timer(fallback_time).timeout

	var result: Dictionary = DragonManager.throw_rabbit_for_hunt(selected_index)

	actor.refresh_from_data(DragonManager.player_dragons[selected_index])
	actor.end_hunt_chase(result)
	_update_info_card()

	if rabbit_node != null and is_instance_valid(rabbit_node):
		rabbit_node.queue_free()

	await get_tree().create_timer(0.15).timeout
	is_hunt_animating = false
	_update_info_card()
	
func _play_rabbit_escape_step(rabbit: Control, next_pos: Vector2) -> float:
	var current_pos: Vector2 = rabbit.position
	var rise_time: float = 0.07
	var fall_time: float = 0.08
	var settle_time: float = 0.04

	var peak_pos: Vector2 = (current_pos + next_pos) * 0.5 + Vector2(0.0, -12.0)

	var facing_sign: float = sign(next_pos.x - current_pos.x)
	if facing_sign == 0.0:
		facing_sign = -1.0 if randf() < 0.5 else 1.0

	var shadow: Control = _get_rabbit_shadow(rabbit)
	var foot_pos: Vector2 = current_pos + Vector2(rabbit.size.x * 0.5, rabbit.size.y * 0.78)
	_spawn_rabbit_dust(foot_pos, 0.7)

	var tw: Tween = create_tween()
	tw.tween_property(rabbit, "position", peak_pos, rise_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rabbit, "rotation", deg_to_rad(-10.0 * facing_sign), rise_time)
	tw.parallel().tween_property(rabbit, "scale", Vector2(1.06, 0.94), rise_time)

	if shadow != null:
		tw.parallel().tween_property(shadow, "scale", Vector2(0.72, 0.72), rise_time)
		tw.parallel().tween_property(shadow, "modulate:a", 0.12, rise_time)

	tw.tween_property(rabbit, "position", next_pos, fall_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(rabbit, "rotation", deg_to_rad(8.0 * facing_sign), fall_time)
	tw.parallel().tween_property(rabbit, "scale", Vector2(0.96, 1.04), fall_time)

	if shadow != null:
		tw.parallel().tween_property(shadow, "scale", Vector2.ONE, fall_time)
		tw.parallel().tween_property(shadow, "modulate:a", 0.22, fall_time)

	tw.tween_callback(func() -> void:
		_spawn_rabbit_dust(next_pos + Vector2(rabbit.size.x * 0.5, rabbit.size.y * 0.78), 0.9)
	)

	tw.tween_property(rabbit, "rotation", 0.0, settle_time)
	tw.parallel().tween_property(rabbit, "scale", Vector2.ONE, settle_time)

	return rise_time + fall_time + settle_time

func _run_hunt_chase_simultaneous(actor: DragonActor, rabbit: Control) -> void:
	if actor == null or rabbit == null:
		return

	var current_pos: Vector2 = rabbit.position
	var hop_count: int = randi_range(3, 5)

	var rabbit_center: Vector2 = current_pos + rabbit.size * 0.5
	var dragon_center: Vector2 = actor.position + actor.size * 0.5
	var away_vec: Vector2 = rabbit_center - dragon_center

	if away_vec.length() <= 0.001:
		away_vec = Vector2(randf_range(-1.0, 1.0), randf_range(-0.7, 0.7))

	var heading: Vector2 = (
		away_vec.normalized() * 0.30 +
		Vector2(randf_range(-1.0, 1.0), randf_range(-0.8, 0.8)).normalized() * 0.70
	).normalized()

	for i in range(hop_count):
		if current_pos.x < 35.0:
			heading.x = abs(heading.x)
		elif current_pos.x > enclosure.size.x - rabbit.size.x - 35.0:
			heading.x = -abs(heading.x)

		if current_pos.y < 20.0:
			heading.y = abs(heading.y)
		elif current_pos.y > enclosure.size.y - rabbit.size.y - 20.0:
			heading.y = -abs(heading.y)

		var jitter: Vector2 = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-0.9, 0.9)
		)

		var chase_heading: Vector2 = heading
		var did_double_back: bool = randf() < 0.24 and i < hop_count - 1

		# Normal panicked wobble
		heading = (heading * 0.45 + jitter * 0.55).normalized()

		# Occasional sharp panic reversal
		if did_double_back:
			var old_heading: Vector2 = heading
			heading = Vector2(
				-old_heading.x + randf_range(-0.35, 0.35),
				(old_heading.y * randf_range(-0.35, 0.35)) + randf_range(-0.45, 0.45)
			).normalized()

			if heading.length() <= 0.001:
				heading = Vector2(-1.0 if randf() < 0.5 else 1.0, randf_range(-0.4, 0.4)).normalized()

			# Dragon commits to the previous direction and overshoots a little.
			chase_heading = old_heading.normalized()
		else:
			chase_heading = heading

		if randf() < 0.18:
			heading.y *= -1.0

		var step_len: float = randf_range(48.0, 92.0)

		var next_pos: Vector2 = current_pos + Vector2(
			heading.x * step_len,
			heading.y * step_len * 0.55
		)

		next_pos.x = float(clamp(next_pos.x, 0.0, max(0.0, enclosure.size.x - rabbit.size.x)))
		next_pos.y = float(clamp(next_pos.y, 0.0, max(0.0, enclosure.size.y - rabbit.size.y)))

		if next_pos.distance_to(current_pos) < 16.0:
			next_pos.x = float(clamp(
				current_pos.x + (-45.0 if randf() < 0.5 else 45.0),
				0.0,
				max(0.0, enclosure.size.x - rabbit.size.x)
			))

		var chase_pos: Vector2 = current_pos + Vector2(
			chase_heading.x * step_len * 0.90,
			chase_heading.y * step_len * 0.40
		)

		chase_pos.x = float(clamp(chase_pos.x, 0.0, max(0.0, enclosure.size.x - rabbit.size.x)))
		chase_pos.y = float(clamp(chase_pos.y, 0.0, max(0.0, enclosure.size.y - rabbit.size.y)))

		var rabbit_target_center: Vector2 = next_pos + rabbit.size * 0.5
		var dragon_target_center: Vector2 = rabbit_target_center
		var overshoot_bonus: float = 0.0
		var is_final: bool = i == hop_count - 1

		if did_double_back:
			dragon_target_center = chase_pos + rabbit.size * 0.5
			overshoot_bonus = 22.0

		var rabbit_time: float = _play_rabbit_escape_step(rabbit, next_pos)
		var dragon_time: float = actor.begin_hunt_step(dragon_target_center, is_final, overshoot_bonus)

		await get_tree().create_timer(max(rabbit_time, dragon_time) + 0.02).timeout
		current_pos = next_pos
		
func _make_rabbit_decoy() -> Control:
	var root: Control = Control.new()
	root.size = Vector2(26, 20)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 90

	var shadow: ColorRect = ColorRect.new()
	shadow.name = "Shadow"
	shadow.color = Color(0.0, 0.0, 0.0, 0.22)
	shadow.position = Vector2(7, 15)
	shadow.size = Vector2(12, 4)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shadow)

	var body: ColorRect = ColorRect.new()
	body.color = Color(0.92, 0.92, 0.92, 1.0)
	body.position = Vector2(6, 8)
	body.size = Vector2(14, 8)
	root.add_child(body)

	var head: ColorRect = ColorRect.new()
	head.color = Color(0.95, 0.95, 0.95, 1.0)
	head.position = Vector2(1, 6)
	head.size = Vector2(8, 7)
	root.add_child(head)

	var ear1: ColorRect = ColorRect.new()
	ear1.color = Color(0.95, 0.95, 0.95, 1.0)
	ear1.position = Vector2(2, 0)
	ear1.size = Vector2(2, 7)
	root.add_child(ear1)

	var ear2: ColorRect = ColorRect.new()
	ear2.color = Color(0.95, 0.95, 0.95, 1.0)
	ear2.position = Vector2(5, 1)
	ear2.size = Vector2(2, 6)
	root.add_child(ear2)

	return root
	
func _play_rabbit_throw(target_actor: DragonActor) -> Dictionary:
	var rabbit: Control = _make_rabbit_decoy()
	enclosure.add_child(rabbit)

	var shadow: Control = _get_rabbit_shadow(rabbit)

	var start_global: Vector2
	if hunt_btn != null:
		start_global = hunt_btn.global_position + (hunt_btn.size * 0.5)
	else:
		start_global = global_position + Vector2(size.x * 0.5, 40.0)

	var landing_local: Vector2 = target_actor.position + Vector2(
		randf_range(-70.0, 70.0),
		randf_range(15.0, 55.0)
	)

	landing_local.x = float(clamp(landing_local.x, 0.0, max(0.0, enclosure.size.x - rabbit.size.x)))
	landing_local.y = float(clamp(landing_local.y, 0.0, max(0.0, enclosure.size.y - rabbit.size.y)))

	var landing_global: Vector2 = enclosure.global_position + landing_local
	var mid_global: Vector2 = (start_global + landing_global) * 0.5 + Vector2(0, -80)

	rabbit.global_position = start_global - (rabbit.size * 0.5)

	if shadow != null:
		shadow.scale = Vector2(0.85, 0.85)
		shadow.modulate.a = 0.18

	var tw: Tween = create_tween()
	tw.tween_property(rabbit, "global_position", mid_global - (rabbit.size * 0.5), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rabbit, "rotation", deg_to_rad(-12.0), 0.18)

	if shadow != null:
		tw.parallel().tween_property(shadow, "scale", Vector2(0.68, 0.68), 0.18)
		tw.parallel().tween_property(shadow, "modulate:a", 0.10, 0.18)

	tw.tween_property(rabbit, "global_position", landing_global - (rabbit.size * 0.5), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(rabbit, "rotation", deg_to_rad(8.0), 0.16)

	if shadow != null:
		tw.parallel().tween_property(shadow, "scale", Vector2.ONE, 0.16)
		tw.parallel().tween_property(shadow, "modulate:a", 0.22, 0.16)

	await tw.finished

	_spawn_rabbit_dust(rabbit.position + Vector2(rabbit.size.x * 0.5, rabbit.size.y * 0.78), 0.9)

	var settle: Tween = create_tween()
	settle.tween_property(rabbit, "position:y", rabbit.position.y - 8.0, 0.08).set_trans(Tween.TRANS_SINE)
	settle.tween_property(rabbit, "position:y", rabbit.position.y, 0.10).set_trans(Tween.TRANS_BOUNCE)
	await settle.finished

	return {
		"rabbit": rabbit,
		"target_pos": landing_local
	}
		
func _get_camp_menu() -> Node:
	var p: Node = get_parent()
	if p != null and p.has_method("get_party_gold") and p.has_method("spend_party_gold"):
		return p
	return null

func _get_player_gold() -> int:
	var camp_menu := _get_camp_menu()
	if camp_menu != null:
		return int(camp_menu.get_party_gold())

	return int(CampaignManager.global_gold)

func _spend_player_gold(amount: int) -> bool:
	var camp_menu := _get_camp_menu()
	if camp_menu != null:
		return bool(camp_menu.spend_party_gold(amount))

	if CampaignManager.global_gold < amount:
		return false

	CampaignManager.global_gold -= amount
	return true
func _get_rabbit_shadow(rabbit: Control) -> Control:
	if rabbit == null:
		return null
	return rabbit.get_node_or_null("Shadow")


func _spawn_rabbit_dust(at_pos: Vector2, strength: float = 1.0) -> void:
	for i in range(4):
		var puff: ColorRect = ColorRect.new()
		puff.color = Color(0.82, 0.74, 0.62, 0.78)
		puff.size = Vector2(4, 4)
		puff.pivot_offset = puff.size * 0.5
		puff.position = at_pos + Vector2(
			randf_range(-7.0, 7.0),
			randf_range(-3.0, 2.0)
		)
		puff.mouse_filter = Control.MOUSE_FILTER_IGNORE
		puff.z_index = 84
		enclosure.add_child(puff)

		var drift: Vector2 = Vector2(
			randf_range(-16.0, 16.0),
			randf_range(-16.0, -6.0)
		) * strength

		var tw: Tween = puff.create_tween()
		tw.tween_property(puff, "position", puff.position + drift, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(puff, "scale", Vector2(1.8, 1.8), 0.24)
		tw.parallel().tween_property(puff, "modulate:a", 0.0, 0.24)
		tw.finished.connect(func() -> void:
			if is_instance_valid(puff):
				puff.queue_free()
		)
# ==========================================
# EPIC EGG HATCHING
# ==========================================
func _find_egg_index() -> int:
	for i in range(CampaignManager.global_inventory.size()):
		var item = CampaignManager.global_inventory[i]
		if item is ConsumableData:
			var i_name: String = str(item.item_name).to_lower()
			if "egg" in i_name:
				return i
	return -1

func _set_hatch_btn_temp_text(text: String, reset_text: String = "Hatch Egg", delay: float = 1.5) -> void:
	if hatch_btn == null: return
	hatch_btn.text = text
	get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(hatch_btn):
			hatch_btn.text = reset_text
	)

func _get_element_reveal_color(element_name: String) -> Color:
	match element_name:
		"Fire": return Color(1.0, 0.45, 0.08, 1.0)
		"Ice": return Color(0.72, 0.92, 1.0, 1.0)
		"Lightning": return Color(1.0, 0.92, 0.22, 1.0)
		"Earth": return Color(0.52, 0.36, 0.18, 1.0)
		"Wind": return Color(0.82, 1.0, 0.92, 1.0)
		_: return Color.WHITE

func _on_hatch_pressed() -> void:
	if is_feed_animating or is_pet_animating or is_hunt_animating or is_hatch_animating or is_training_animating:
		return
		
	_trigger_morgra("hatch")
	
	# Find ALL eggs in the inventory
	var found_eggs = []
	for i in range(CampaignManager.global_inventory.size()):
		var item = CampaignManager.global_inventory[i]
		if item is ConsumableData:
			var i_name = str(item.item_name).to_lower()
			if "egg" in i_name:
				found_eggs.append({"index": i, "item": item})

	if found_eggs.is_empty():
		_set_hatch_btn_temp_text("No Eggs in Inventory!")
		return

		
	# --- OPEN THE EGG SELECTOR MENU ---
	selecting_for_slot = "EGG"
	for child in selection_vbox.get_children():
		child.queue_free()
		
	var title = Label.new()
	title.text = "--- CHOOSE AN EGG ---"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.GOLD)
	selection_vbox.add_child(title)
		
	for egg_data in found_eggs:
		var idx = egg_data["index"]
		var item = egg_data["item"]
		
		var btn = Button.new()
		btn.text = str(item.item_name)
		btn.custom_minimum_size = Vector2(0, 60)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		style.border_width_bottom = 2
		style.border_color = Color.GOLD if "Bred" in item.item_name else Color.GRAY
		btn.add_theme_stylebox_override("normal", style)
		
		if item.get("icon") != null:
			btn.icon = item.icon
			btn.expand_icon = true
			
		btn.pressed.connect(func(): _on_egg_chosen(idx))
		selection_vbox.add_child(btn)
		
	breed_selection_popup.show()

func _on_egg_chosen(egg_index: int) -> void:
	breed_selection_popup.hide()
	is_hatch_animating = true
	info_card.hide()
	
	# Grab the exact item data
	var egg_item = CampaignManager.global_inventory[egg_index]
	var is_bred_egg = "bred" in str(egg_item.item_name).to_lower()
	var egg_uid = egg_item.get_meta("egg_uid", "")
	
	# Consume the exact egg
	CampaignManager.global_inventory.remove_at(egg_index)

	# --- PULL FROM QUEUE IF BRED, OTHERWISE ROLL WILD ---
	var new_baby: Dictionary
	if is_bred_egg:
		new_baby = DragonManager.hatch_bred_egg(egg_uid)
	else:
		new_baby = DragonManager.hatch_egg()

	if new_baby.is_empty():
		is_hatch_animating = false
		_set_hatch_btn_temp_text("Hatch Failed!")
		return

	# ==========================================
	# THE CINEMATIC LOGIC
	# ==========================================
	var traits_array: Array = new_baby.get("traits", [])
	var is_rare_hatch: bool = traits_array.size() >= 2
	var elem_color: Color = _get_element_reveal_color(str(new_baby.get("element", "")))
	var bg_glow_color: Color = Color(1.0, 0.85, 0.2, 1.0) if is_rare_hatch else elem_color

	var camp_music: AudioStreamPlayer = get_node_or_null("../CampMusic")
	var masterwork_sound: AudioStreamPlayer = get_node_or_null("../MasterworkSound")

	var hatch_layer := CanvasLayer.new()
	hatch_layer.layer = 150
	add_child(hatch_layer)

	var vp_size: Vector2 = get_viewport_rect().size
	var center: Vector2 = vp_size * 0.5

	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.0)
	dimmer.size = vp_size
	hatch_layer.add_child(dimmer)

	var glow := ColorRect.new()
	glow.color = bg_glow_color
	glow.size = Vector2(260, 260)
	glow.pivot_offset = glow.size * 0.5
	glow.position = center - glow.size * 0.5
	glow.modulate.a = 0.0
	hatch_layer.add_child(glow)

	var temp_egg := TextureRect.new()
	temp_egg.texture = EGG_ICON
	temp_egg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	temp_egg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	temp_egg.custom_minimum_size = Vector2(128, 160)
	temp_egg.size = Vector2(128, 160)
	temp_egg.pivot_offset = temp_egg.size * 0.5
	temp_egg.position = center - temp_egg.size * 0.5 + Vector2(0, 130)
	temp_egg.modulate.a = 0.0
	hatch_layer.add_child(temp_egg)

	var flash := ColorRect.new()
	flash.size = vp_size
	flash.color = Color(1, 1, 1, 0.0)
	hatch_layer.add_child(flash)

	var orig_vol: float = 0.0
	if camp_music != null and camp_music.playing:
		orig_vol = camp_music.volume_db
		create_tween().tween_property(camp_music, "volume_db", -15.0, 0.8)

	var intro_tw := create_tween().set_parallel(true)
	intro_tw.tween_property(dimmer, "color:a", 0.88, 1.2)
	intro_tw.tween_property(glow, "modulate:a", 0.20, 1.0)
	intro_tw.tween_property(temp_egg, "position:y", center.y - (temp_egg.size.y * 0.5), 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(temp_egg, "modulate:a", 1.0, 0.8)
	await intro_tw.finished

	for i in range(3):
		var pulse_tw := create_tween().set_parallel(true)
		pulse_tw.tween_property(glow, "scale", Vector2(1.12, 1.12), 0.16).set_trans(Tween.TRANS_SINE)
		pulse_tw.tween_property(glow, "modulate:a", 0.34, 0.16)
		pulse_tw.tween_property(temp_egg, "scale", Vector2(1.06, 1.06), 0.16).set_trans(Tween.TRANS_SINE)
		pulse_tw.tween_property(temp_egg, "rotation", deg_to_rad(7.0), 0.08)
		pulse_tw.chain().tween_property(temp_egg, "rotation", deg_to_rad(-7.0), 0.08)
		await pulse_tw.finished

		var release_tw := create_tween().set_parallel(true)
		release_tw.tween_property(glow, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE)
		release_tw.tween_property(glow, "modulate:a", 0.18, 0.14)
		release_tw.tween_property(temp_egg, "scale", Vector2.ONE, 0.14)
		release_tw.tween_property(temp_egg, "rotation", 0.0, 0.14)
		await release_tw.finished

	var shake_tw := create_tween()
	for i in range(8):
		var x_off: float = randf_range(-14.0, 14.0)
		var y_off: float = randf_range(-6.0, 6.0)
		shake_tw.tween_property(temp_egg, "position", (center - temp_egg.size * 0.5) + Vector2(x_off, y_off), 0.035)
		shake_tw.parallel().tween_property(temp_egg, "rotation", deg_to_rad(randf_range(-20.0, 20.0)), 0.035)
		shake_tw.parallel().tween_property(temp_egg, "modulate", Color(1.6, 1.6, 1.6, 1.0), 0.035)

	shake_tw.tween_property(temp_egg, "position", center - temp_egg.size * 0.5, 0.04)
	shake_tw.parallel().tween_property(temp_egg, "rotation", 0.0, 0.04)
	await shake_tw.finished

	if masterwork_sound != null and masterwork_sound.stream != null:
		var boom := AudioStreamPlayer.new()
		boom.stream = masterwork_sound.stream
		boom.pitch_scale = 0.72
		boom.volume_db = -10.0
		add_child(boom)
		boom.play()
		boom.finished.connect(boom.queue_free)

	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = false
	burst.explosiveness = 0.95
	burst.amount = 140
	burst.lifetime = 1.15
	burst.spread = 180.0
	burst.initial_velocity_min = 260.0
	burst.initial_velocity_max = 520.0
	burst.scale_amount_min = 6.0
	burst.scale_amount_max = 12.0
	burst.color = elem_color
	burst.position = center
	hatch_layer.add_child(burst)

	var rare_burst: CPUParticles2D = null
	if is_rare_hatch:
		rare_burst = CPUParticles2D.new()
		rare_burst.one_shot = true
		rare_burst.emitting = false
		rare_burst.explosiveness = 0.85
		rare_burst.amount = 80
		rare_burst.lifetime = 1.5
		rare_burst.spread = 180.0
		rare_burst.initial_velocity_min = 400.0
		rare_burst.initial_velocity_max = 850.0
		rare_burst.scale_amount_min = 5.0
		rare_burst.scale_amount_max = 16.0
		rare_burst.color = Color(1.0, 0.85, 0.2, 1.0)
		rare_burst.position = center
		hatch_layer.add_child(rare_burst)

	var pop_tw := create_tween().set_parallel(true)
	pop_tw.tween_property(flash, "color:a", 1.0, 0.07)
	pop_tw.tween_property(glow, "modulate:a", 0.65, 0.07)
	await pop_tw.finished

	burst.emitting = true
	if rare_burst != null:
		rare_burst.emitting = true

	_shake_enclosure(14.0, 0.30)

	if is_instance_valid(temp_egg):
		temp_egg.queue_free()

	var showcase_actor: DragonActor = DRAGON_ACTOR_SCENE.instantiate()
	hatch_layer.add_child(showcase_actor)

	if showcase_actor != null and is_instance_valid(showcase_actor):
		showcase_actor.setup(new_baby)
		showcase_actor.set_cinematic_mode(true)
		showcase_actor.position = center - (showcase_actor.size * 0.5)
		showcase_actor.scale = Vector2(0.12, 0.12)
		showcase_actor.modulate.a = 0.0
	else:
		is_hatch_animating = false
		return

	var name_lbl := Label.new()
	if is_rare_hatch:
		name_lbl.text = "⭐ RARE HATCH! ⭐\n" + str(new_baby.get("name", "DRAGON")).to_upper()
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0)) 
	else:
		name_lbl.text = "YOU HATCHED A " + str(new_baby.get("name", "DRAGON")).to_upper() + "!"
		name_lbl.add_theme_color_override("font_color", elem_color)
		
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 44)
	name_lbl.add_theme_constant_override("outline_size", 10)
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	name_lbl.position = Vector2(0, center.y - 280.0)
	name_lbl.size.x = vp_size.x
	name_lbl.modulate.a = 0.0
	hatch_layer.add_child(name_lbl)

	var trait_lbl := Label.new()
	if traits_array.is_empty():
		trait_lbl.text = "No special traits."
		trait_lbl.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	else:
		trait_lbl.text = "Traits: " + ", ".join(traits_array)
		trait_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0) if is_rare_hatch else Color.GOLD)

	trait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trait_lbl.add_theme_font_size_override("font_size", 30)
	trait_lbl.add_theme_constant_override("outline_size", 8)
	trait_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	trait_lbl.position = Vector2(0, center.y + 145.0)
	trait_lbl.size.x = vp_size.x
	trait_lbl.modulate.a = 0.0
	hatch_layer.add_child(trait_lbl)

	var element_lbl := Label.new()
	element_lbl.text = str(new_baby.get("element", "Unknown")) + " Element"
	element_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	element_lbl.add_theme_font_size_override("font_size", 26)
	element_lbl.add_theme_color_override("font_color", Color.WHITE)
	element_lbl.add_theme_constant_override("outline_size", 8)
	element_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	element_lbl.position = Vector2(0, center.y + 108.0)
	element_lbl.size.x = vp_size.x
	element_lbl.modulate.a = 0.0
	hatch_layer.add_child(element_lbl)

	var reveal_tw := create_tween().set_parallel(true)
	reveal_tw.tween_property(flash, "color:a", 0.0, 0.35)
	reveal_tw.tween_property(glow, "modulate:a", 0.26, 0.45)
	reveal_tw.tween_property(showcase_actor, "scale", Vector2(2.35, 2.35), 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	reveal_tw.tween_property(showcase_actor, "modulate:a", 1.0, 0.25)
	reveal_tw.tween_property(name_lbl, "modulate:a", 1.0, 0.35)
	reveal_tw.tween_property(trait_lbl, "modulate:a", 1.0, 0.45)
	reveal_tw.tween_property(element_lbl, "modulate:a", 1.0, 0.40)
	await reveal_tw.finished

	var pride_tw := create_tween()
	pride_tw.tween_property(showcase_actor, "scale", Vector2(2.48, 2.48), 0.16).set_trans(Tween.TRANS_SINE)
	pride_tw.tween_property(showcase_actor, "scale", Vector2(2.35, 2.35), 0.18).set_trans(Tween.TRANS_BOUNCE)
	await pride_tw.finished

	await get_tree().create_timer(3.0).timeout

	var cleanup_tw := create_tween().set_parallel(true)
	cleanup_tw.tween_property(dimmer, "color:a", 0.0, 0.55)
	cleanup_tw.tween_property(glow, "modulate:a", 0.0, 0.45)
	cleanup_tw.tween_property(showcase_actor, "modulate:a", 0.0, 0.45)
	cleanup_tw.tween_property(name_lbl, "modulate:a", 0.0, 0.45)
	cleanup_tw.tween_property(trait_lbl, "modulate:a", 0.0, 0.45)
	cleanup_tw.tween_property(element_lbl, "modulate:a", 0.0, 0.45)

	if camp_music != null:
		cleanup_tw.tween_property(camp_music, "volume_db", orig_vol, 0.7)

	await cleanup_tw.finished

	if is_instance_valid(hatch_layer):
		hatch_layer.queue_free()

	# If the ranch was closed during the cinematic, abort safely.
	if not is_instance_valid(self) or not visible:
		is_hatch_animating = false
		return

	_spawn_dragons()

	# Let the freshly spawned actors enter the tree properly.
	await get_tree().process_frame

	if not is_instance_valid(self) or not visible:
		is_hatch_animating = false
		return

	selected_dragon_uid = str(new_baby.get("uid", ""))
	_refresh_actor_selection()

	var final_actor: DragonActor = _get_actor_by_uid(selected_dragon_uid)
	if final_actor != null and is_instance_valid(final_actor):
		final_actor.position = (enclosure.size - final_actor.size) * 0.5
		final_actor.scale = Vector2.ZERO

		if is_instance_valid(final_actor):
			final_actor.set_cinematic_mode(true)

		var final_tw := create_tween()
		final_tw.tween_property(final_actor, "scale", Vector2(1.18, 1.18), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		final_tw.tween_property(final_actor, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BOUNCE)
		await final_tw.finished

		if final_actor != null and is_instance_valid(final_actor):
			final_actor.set_cinematic_mode(false)

	_update_info_card()
	info_card.show()
	is_hatch_animating = false
	
# ==========================================
# BREEDING STATION UI
# ==========================================

func _open_breeding_station() -> void:
	selected_parent_a_index = -1
	selected_parent_b_index = -1
	_ensure_breeding_station_fx_ui()
	_refresh_breeding_ui()
	breed_panel.show()

func _open_parent_selector(slot: String) -> void:
	selecting_for_slot = slot
	
	# Clear the old list
	for child in selection_vbox.get_children():
		child.queue_free()
		
	# Populate with valid Adult dragons
	var found_any = false
	for i in range(DragonManager.player_dragons.size()):
		var d = DragonManager.player_dragons[i]
		
		# Rule: Must be Adult, and must not be on cooldown
		if d.get("stage", 0) < DragonManager.DragonStage.ADULT: continue
		if d.get("breed_cooldown", 0) > 0: continue
		
		# Prevent selecting the same dragon for both slots
		if slot == "A" and selected_parent_b_index == i: continue
		if slot == "B" and selected_parent_a_index == i: continue
		
		found_any = true
		var btn = Button.new()
		var d_name = str(d.get("name", "Dragon"))
		var d_gen = str(d.get("generation", 1))
		var d_elem = str(d.get("element", "Unknown"))
		
		btn.text = "Gen " + d_gen + " " + d_name + " (" + d_elem + ")"
		btn.custom_minimum_size = Vector2(0, 50)
		btn.pressed.connect(func(): _on_parent_chosen(i))
		selection_vbox.add_child(btn)
		
	if not found_any:
		var lbl = Label.new()
		lbl.text = "No eligible adult dragons available!"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		selection_vbox.add_child(lbl)
		
	breed_selection_popup.show()

func _on_parent_chosen(dragon_index: int) -> void:
	if selecting_for_slot == "A":
		selected_parent_a_index = dragon_index
	elif selecting_for_slot == "B":
		selected_parent_b_index = dragon_index
		
	breed_selection_popup.hide()
	_refresh_breeding_ui()

func _refresh_breeding_ui() -> void:
	_ensure_breeding_station_fx_ui()
	_layout_breeding_station_fx_ui()

	var has_rose: bool = DragonManager._find_inventory_consumable_index_by_name(DragonManager.BREED_REQUIRED_ITEM_NAME) != -1

	# Parent A
	if selected_parent_a_index != -1:
		var pA: Dictionary = DragonManager.player_dragons[selected_parent_a_index]
		var elem_a: String = str(pA.get("element", "Unknown"))
		var color_a: Color = _get_element_reveal_color(elem_a)

		parent_a_btn.text = "\n\n%s\nGen %d • Bond %d • Happy %d" % [
			str(pA.get("name", "Dragon")),
			int(pA.get("generation", 1)),
			int(pA.get("bond", 0)),
			int(pA.get("happiness", 50))
		]
		_set_parent_button_style(parent_a_btn, color_a, true)

		if parent_a_sprite != null:
			parent_a_sprite.texture = load("res://Assets/Sprites/" + elem_a.to_lower() + "_dragon_sprite.png")
			parent_a_sprite.show()

		_start_parent_slot_pulse("A", parent_a_sprite, parent_a_btn, color_a)
	else:
		parent_a_btn.text = "Select\nParent A"
		_set_parent_button_style(parent_a_btn, Color.WHITE, false)
		if parent_a_sprite != null:
			parent_a_sprite.hide()

		_kill_breed_ui_tween(breed_parent_a_tween)
		if parent_a_sprite != null:
			parent_a_sprite.scale = Vector2.ONE
			parent_a_sprite.modulate = Color.WHITE

	# Parent B
	if selected_parent_b_index != -1:
		var pB: Dictionary = DragonManager.player_dragons[selected_parent_b_index]
		var elem_b: String = str(pB.get("element", "Unknown"))
		var color_b: Color = _get_element_reveal_color(elem_b)

		parent_b_btn.text = "\n\n%s\nGen %d • Bond %d • Happy %d" % [
			str(pB.get("name", "Dragon")),
			int(pB.get("generation", 1)),
			int(pB.get("bond", 0)),
			int(pB.get("happiness", 50))
		]
		_set_parent_button_style(parent_b_btn, color_b, true)

		if parent_b_sprite != null:
			parent_b_sprite.texture = load("res://Assets/Sprites/" + elem_b.to_lower() + "_dragon_sprite.png")
			parent_b_sprite.show()

		_start_parent_slot_pulse("B", parent_b_sprite, parent_b_btn, color_b)
	else:
		parent_b_btn.text = "Select\nParent B"
		_set_parent_button_style(parent_b_btn, Color.WHITE, false)
		if parent_b_sprite != null:
			parent_b_sprite.hide()

		_kill_breed_ui_tween(breed_parent_b_tween)
		if parent_b_sprite != null:
			parent_b_sprite.scale = Vector2.ONE
			parent_b_sprite.modulate = Color.WHITE

	if selected_parent_a_index == -1 or selected_parent_b_index == -1:
		prediction_label.text = "[center][color=gray]Select two adult dragons to see resonance, compatibility, and predicted quality.[/color][/center]"
		confirm_breed_btn.disabled = true
		confirm_breed_btn.text = "Waiting for parents..."
		breed_compat_bar_fill.size.x = 0.0
		breed_compat_value_label.text = "Compatibility: --"
		breed_mutation_label.text = "[center][color=gray]No bloodline preview yet.[/color][/center]"
		breed_prediction_backplate.color = Color(0.08, 0.08, 0.12, 0.84)
		_stop_breeding_preview_fx()
		return

	var preview: Dictionary = DragonManager.get_breeding_preview(selected_parent_a_index, selected_parent_b_index)

	if not bool(preview.get("success", false)):
		prediction_label.text = "[center][color=red]%s[/color][/center]" % str(preview.get("error", "Preview failed."))
		confirm_breed_btn.disabled = true
		confirm_breed_btn.text = "Cannot breed"
		breed_compat_bar_fill.size.x = 0.0
		breed_compat_value_label.text = "Compatibility: 0"
		breed_mutation_label.text = "[center][color=gray]Breeding preview unavailable.[/color][/center]"
		breed_prediction_backplate.color = Color(0.20, 0.08, 0.08, 0.90)
		_stop_breeding_preview_fx()
		return

	var quality: String = str(preview.get("quality", "Common"))
	var quality_color: Color = _get_quality_color(quality)
	var quality_hex: String = quality_color.to_html(false)

	var score: int = int(preview.get("compatibility_score", 0))
	var tier: String = str(preview.get("compatibility_tier", "Unknown"))
	var generation: int = int(preview.get("generation", 1))
	var element_text: String = str(preview.get("element_text", "Unknown"))
	var mutated_traits: Array = preview.get("mutated_traits", [])
	var guaranteed_traits: Array = preview.get("guaranteed_traits", [])
	var possible_traits: Array = preview.get("possible_traits", [])
	var resonance_tags: Array = preview.get("resonance_tags", [])

	var tag_text: String = "None"
	if not resonance_tags.is_empty():
		tag_text = " • ".join(resonance_tags)

	var mutation_text: String = "None"
	if not mutated_traits.is_empty():
		mutation_text = ", ".join(mutated_traits)

	var guaranteed_text: String = "None"
	if not guaranteed_traits.is_empty():
		guaranteed_text = ", ".join(guaranteed_traits)

	var possible_text: String = "None"
	if not possible_traits.is_empty():
		possible_text = ", ".join(possible_traits)

	prediction_label.text = (
		"[center]" +
		"[color=%s][b]%s OFFSPRING[/b][/color]\n" % [quality_hex, quality] +
		"Generation: [color=lime]%d[/color]\n" % generation +
		"Element: [color=cyan]%s[/color]\n" % element_text +
		"Tier: [color=white]%s[/color]\n" % tier +
		"[color=gray]%s[/color]" % tag_text +
		"[/center]"
	)

	breed_mutation_label.text = (
		"[center]" +
		"[color=gold]Mutations:[/color] %s\n" % mutation_text +
		"[color=lime]Guaranteed:[/color] %s\n" % guaranteed_text +
		"[color=white]Possible Pool:[/color] %s" % possible_text +
		"[/center]"
	)

	var bar_width: float = breed_compat_bar_bg.size.x * (float(score) / 100.0)
	breed_compat_bar_fill.color = quality_color
	breed_compat_bar_fill.size = Vector2(bar_width, breed_compat_bar_bg.size.y)
	breed_compat_value_label.text = "Compatibility: %d / 100" % score

	var backplate_color: Color = quality_color.darkened(0.78)
	backplate_color.a = 0.92
	breed_prediction_backplate.color = backplate_color

	if has_rose:
		confirm_breed_btn.disabled = false
		confirm_breed_btn.text = "BREED DRAGONS\n(-1 Dragon Rose)"
	else:
		confirm_breed_btn.disabled = true
		confirm_breed_btn.text = "MISSING DRAGON ROSE"

	_start_breeding_preview_fx(preview)
	
func _resource_has_property(obj: Object, prop_name: String) -> bool:
	if obj == null:
		return false

	for prop in obj.get_property_list():
		if str(prop.get("name", "")) == prop_name:
			return true

	return false


func _infer_breed_quality(result: Dictionary) -> String:
	if result.has("quality"):
		return str(result.get("quality", "Common"))

	var gen: int = int(result.get("generation", 1))
	var mutated: Array = result.get("mutated_traits", [])
	var inherited: Array = result.get("inherited_traits", [])

	var score: int = 0
	score += gen * 10
	score += mutated.size() * 24
	score += inherited.size() * 6

	if score >= 95:
		return "Legendary"
	elif score >= 70:
		return "Epic"
	elif score >= 45:
		return "Rare"
	return "Common"


func _get_breed_quality_color(quality: String) -> Color:
	match quality:
		"Legendary":
			return Color(1.0, 0.86, 0.25, 1.0)
		"Epic":
			return Color(0.82, 0.58, 1.0, 1.0)
		"Rare":
			return Color(0.45, 0.85, 1.0, 1.0)
		_:
			return Color(0.92, 0.92, 0.92, 1.0)


func _get_breed_element_mix_color(parent_a: Dictionary, parent_b: Dictionary) -> Color:
	var color_a: Color = _get_element_reveal_color(str(parent_a.get("element", "")))
	var color_b: Color = _get_element_reveal_color(str(parent_b.get("element", "")))
	return color_a.lerp(color_b, 0.5)


func _spawn_breeding_cinematic_actor(
	stage_root: Control,
	dragon_data: Dictionary,
	start_pos: Vector2,
	face_dir: float,
	z_idx: int = 20
) -> DragonActor:
	var actor: DragonActor = DRAGON_ACTOR_SCENE.instantiate()
	actor.facing = -1.0 if face_dir < 0.0 else 1.0
	stage_root.add_child(actor)
	actor.z_index = z_idx
	actor.setup(dragon_data)
	actor.set_cinematic_mode(true)
	actor.position = start_pos
	actor.scale = Vector2(0.95, 0.95)
	actor.modulate.a = 0.0
	return actor


func _spawn_magic_burst(
	stage_root: Control,
	at_pos: Vector2,
	color: Color,
	amount: int = 90,
	lifetime: float = 1.0,
	speed_min: float = 160.0,
	speed_max: float = 360.0,
	spread: float = 180.0,
	scale_min: float = 5.0,
	scale_max: float = 12.0
) -> CPUParticles2D:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = false
	burst.explosiveness = 0.90
	burst.amount = amount
	burst.lifetime = lifetime
	burst.spread = spread
	burst.initial_velocity_min = speed_min
	burst.initial_velocity_max = speed_max
	burst.scale_amount_min = scale_min
	burst.scale_amount_max = scale_max
	burst.color = color
	burst.position = at_pos
	stage_root.add_child(burst)
	burst.emitting = true

	get_tree().create_timer(lifetime + 0.6).timeout.connect(func() -> void:
		if is_instance_valid(burst):
			burst.queue_free()
	)

	return burst


func _build_bred_egg_item(result: Dictionary, parent_a: Dictionary, parent_b: Dictionary) -> ConsumableData:
	var egg := ConsumableData.new()
	var quality: String = _infer_breed_quality(result)
	var generation: int = int(result.get("generation", 1))
	var baby: Dictionary = result.get("baby", {})
	var mutated_traits: Array = result.get("mutated_traits", [])
	var inherited_traits: Array = result.get("inherited_traits", [])

	var all_traits: Array = []
	for t in baby.get("traits", []):
		if not all_traits.has(t):
			all_traits.append(t)

	var trait_string: String = "None"
	if not all_traits.is_empty():
		trait_string = ", ".join(all_traits)

	var mutation_string: String = "None"
	if not mutated_traits.is_empty():
		mutation_string = ", ".join(mutated_traits)

	var inherited_string: String = "None"
	if not inherited_traits.is_empty():
		inherited_string = ", ".join(inherited_traits)

	egg.item_name = "%s Bred Egg (Gen %d)" % [quality, generation]
	egg.description = (
		"A carefully bred dragon egg.\n" +
		"Parents: %s & %s\n" % [str(parent_a.get("name", "Unknown")), str(parent_b.get("name", "Unknown"))] +
		"Element: %s\n" % str(result.get("element", "Unknown")) +
		"Generation: %d\n" % generation +
		"Traits: %s\n" % trait_string +
		"Mutations: %s\n" % mutation_string +
		"Inherited: %s" % inherited_string
	)
	egg.rarity = quality
	egg.gold_cost = 250
	egg.set_meta("baby_uid", str(baby.get("uid", "")))
	egg.set_meta("egg_uid", str(result.get("egg", {}).get("egg_uid", "")))

	if _resource_has_property(egg, "icon"):
		egg.set("icon", EGG_ICON)
	elif _resource_has_property(egg, "texture"):
		egg.set("texture", EGG_ICON)

	return egg


func _play_breeding_cinematic(result: Dictionary, parent_a: Dictionary, parent_b: Dictionary) -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var center: Vector2 = vp_size * 0.5

	var quality: String = _infer_breed_quality(result)
	var quality_color: Color = _get_breed_quality_color(quality)
	var mix_color: Color = _get_breed_element_mix_color(parent_a, parent_b)
	var accent_color: Color = mix_color.lerp(quality_color, 0.45)

	var layer := CanvasLayer.new()
	layer.layer = 160
	add_child(layer)

	var stage_root := Control.new()
	stage_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_root.size = vp_size
	layer.add_child(stage_root)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.01, 0.04, 0.0)
	dimmer.size = vp_size
	stage_root.add_child(dimmer)

	var center_glow := ColorRect.new()
	center_glow.color = accent_color
	center_glow.size = Vector2(240, 240)
	center_glow.pivot_offset = center_glow.size * 0.5
	center_glow.position = center - center_glow.size * 0.5
	center_glow.scale = Vector2(0.5, 0.5)
	center_glow.modulate.a = 0.0
	stage_root.add_child(center_glow)

	var beam := ColorRect.new()
	beam.color = accent_color
	beam.size = Vector2(46, 250)
	beam.pivot_offset = beam.size * 0.5
	beam.position = center - beam.size * 0.5 + Vector2(0, -20)
	beam.scale = Vector2(0.3, 0.2)
	beam.modulate.a = 0.0
	stage_root.add_child(beam)

	var left_actor: DragonActor = _spawn_breeding_cinematic_actor(
		stage_root,
		parent_a.duplicate(true),
		Vector2(-260.0, center.y - 120.0),
		1.0,
		22
	)

	var right_actor: DragonActor = _spawn_breeding_cinematic_actor(
		stage_root,
		parent_b.duplicate(true),
		Vector2(vp_size.x + 60.0, center.y - 120.0),
		-1.0,
		22
	)

	left_actor.set_facing_immediate(1.0)
	right_actor.set_facing_immediate(-1.0)

	var left_target: Vector2 = Vector2(center.x - 285.0 - left_actor.size.x * 0.5, center.y - 120.0)
	var right_target: Vector2 = Vector2(center.x + 285.0 - right_actor.size.x * 0.5, center.y - 120.0)

	var intro_tw := create_tween().set_parallel(true)
	intro_tw.tween_property(dimmer, "color:a", 0.86, 0.55)
	intro_tw.tween_property(center_glow, "modulate:a", 0.18, 0.55)
	intro_tw.tween_property(center_glow, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(left_actor, "position", left_target, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(right_actor, "position", right_target, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(left_actor, "modulate:a", 1.0, 0.25)
	intro_tw.tween_property(right_actor, "modulate:a", 1.0, 0.25)
	await intro_tw.finished

	left_actor.play_cinematic_pulse(0.7)
	right_actor.play_cinematic_pulse(0.7)

	var stance_tw := create_tween().set_parallel(true)
	stance_tw.tween_property(left_actor, "scale", Vector2(1.03, 1.03), 0.14).set_trans(Tween.TRANS_SINE)
	stance_tw.tween_property(right_actor, "scale", Vector2(1.03, 1.03), 0.14).set_trans(Tween.TRANS_SINE)
	stance_tw.chain().tween_property(left_actor, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BOUNCE)
	stance_tw.parallel().tween_property(right_actor, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BOUNCE)
	await stance_tw.finished

	left_actor.play_cinematic_roar(0.92, 1.00, 1.0)
	await get_tree().create_timer(0.14).timeout
	right_actor.play_cinematic_roar(0.94, 1.02, 1.0)

	for i in range(3):
		left_actor.play_cinematic_pulse(0.85 + i * 0.15)
		right_actor.play_cinematic_pulse(0.85 + i * 0.15)

		var charge_tw := create_tween().set_parallel(true)
		charge_tw.tween_property(center_glow, "modulate:a", 0.26 + float(i) * 0.08, 0.16)
		charge_tw.tween_property(center_glow, "scale", Vector2(1.08 + float(i) * 0.10, 1.08 + float(i) * 0.10), 0.16)
		charge_tw.tween_property(beam, "modulate:a", 0.22 + float(i) * 0.12, 0.16)
		charge_tw.tween_property(beam, "scale", Vector2(0.6 + float(i) * 0.22, 0.6 + float(i) * 0.22), 0.16)
		await charge_tw.finished

		_spawn_magic_burst(stage_root, center + Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0)), accent_color, 20, 0.55, 45.0, 120.0, 180.0, 2.0, 5.0)

		var release_tw := create_tween().set_parallel(true)
		release_tw.tween_property(center_glow, "modulate:a", 0.18, 0.12)
		release_tw.tween_property(beam, "modulate:a", 0.10, 0.12)
		await release_tw.finished

	var egg := TextureRect.new()
	egg.texture = EGG_ICON
	egg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	egg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	egg.size = Vector2(112, 140)
	egg.pivot_offset = egg.size * 0.5
	egg.position = center - egg.size * 0.5 + Vector2(0, 30)
	egg.scale = Vector2(0.18, 0.18)
	egg.modulate = Color(1, 1, 1, 0.0)
	egg.z_index = 30
	stage_root.add_child(egg)

	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.0)
	flash.size = vp_size
	stage_root.add_child(flash)

	_spawn_magic_burst(stage_root, center, accent_color, 140, 1.0, 220.0, 520.0, 180.0, 5.0, 12.0)

	if quality == "Epic" or quality == "Legendary":
		_spawn_magic_burst(stage_root, center, quality_color, 90, 1.2, 320.0, 720.0, 180.0, 4.0, 14.0)

	var materialize_tw := create_tween().set_parallel(true)
	materialize_tw.tween_property(flash, "color:a", 1.0, 0.06)
	materialize_tw.tween_property(center_glow, "modulate:a", 0.62, 0.06)
	materialize_tw.tween_property(beam, "modulate:a", 0.58, 0.06)
	await materialize_tw.finished

	var reveal_tw := create_tween().set_parallel(true)
	reveal_tw.tween_property(flash, "color:a", 0.0, 0.26)
	reveal_tw.tween_property(egg, "modulate:a", 1.0, 0.16)
	reveal_tw.tween_property(egg, "scale", Vector2(1.35, 1.35), 0.44).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	reveal_tw.tween_property(egg, "position:y", egg.position.y - 28.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal_tw.tween_property(center_glow, "modulate:a", 0.28, 0.36)
	reveal_tw.tween_property(beam, "modulate:a", 0.0, 0.26)
	await reveal_tw.finished

	var egg_settle_tw := create_tween()
	egg_settle_tw.tween_property(egg, "position:y", egg.position.y + 18.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	egg_settle_tw.tween_property(egg, "position:y", egg.position.y, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	egg_settle_tw.parallel().tween_property(egg, "scale", Vector2(1.20, 1.20), 0.26).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await egg_settle_tw.finished

	left_actor.play_cinematic_pulse(1.0)
	right_actor.play_cinematic_pulse(1.0)
	if quality == "Epic" or quality == "Legendary":
		left_actor.play_cinematic_roar(0.96, 1.06, 1.0)
		right_actor.play_cinematic_roar(0.96, 1.08, 1.0)

	var title := Label.new()
	title.text = "%s EGG CREATED!" % quality.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_color_override("font_color", quality_color)
	title.position = Vector2(0, center.y - 280.0)
	title.size.x = vp_size.x
	title.modulate.a = 0.0
	stage_root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Gen %d • %s Bloodline" % [
		int(result.get("generation", 1)),
		str(result.get("element", "Unknown"))
	]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_constant_override("outline_size", 8)
	subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	subtitle.add_theme_color_override("font_color", Color.WHITE)
	subtitle.position = Vector2(0, center.y + 145.0)
	subtitle.size.x = vp_size.x
	subtitle.modulate.a = 0.0
	stage_root.add_child(subtitle)

	var mutation_note := Label.new()
	var mutation_list: Array = result.get("mutated_traits", [])
	if mutation_list.is_empty():
		mutation_note.text = "Inherited traits are sleeping inside the egg."
	else:
		mutation_note.text = "Mutation Surge: " + ", ".join(mutation_list)
	mutation_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mutation_note.add_theme_font_size_override("font_size", 24)
	mutation_note.add_theme_constant_override("outline_size", 6)
	mutation_note.add_theme_color_override("font_outline_color", Color.BLACK)
	mutation_note.add_theme_color_override("font_color", accent_color)
	mutation_note.position = Vector2(0, center.y + 182.0)
	mutation_note.size.x = vp_size.x
	mutation_note.modulate.a = 0.0
	stage_root.add_child(mutation_note)

	var text_tw := create_tween().set_parallel(true)
	text_tw.tween_property(title, "modulate:a", 1.0, 0.28)
	text_tw.tween_property(subtitle, "modulate:a", 1.0, 0.34)
	text_tw.tween_property(mutation_note, "modulate:a", 1.0, 0.40)
	await text_tw.finished

	await get_tree().create_timer(2.7).timeout

	var outro_tw := create_tween().set_parallel(true)
	outro_tw.tween_property(dimmer, "color:a", 0.0, 0.50)
	outro_tw.tween_property(center_glow, "modulate:a", 0.0, 0.40)
	outro_tw.tween_property(left_actor, "modulate:a", 0.0, 0.40)
	outro_tw.tween_property(right_actor, "modulate:a", 0.0, 0.40)
	outro_tw.tween_property(egg, "modulate:a", 0.0, 0.40)
	outro_tw.tween_property(title, "modulate:a", 0.0, 0.40)
	outro_tw.tween_property(subtitle, "modulate:a", 0.0, 0.40)
	outro_tw.tween_property(mutation_note, "modulate:a", 0.0, 0.40)
	await outro_tw.finished

	if is_instance_valid(layer):
		layer.queue_free()
			
func _on_confirm_breed_pressed() -> void:
	if selected_parent_a_index == -1 or selected_parent_b_index == -1:
		return

	confirm_breed_btn.disabled = true

	var parent_a_snapshot: Dictionary = DragonManager.player_dragons[selected_parent_a_index].duplicate(true)
	var parent_b_snapshot: Dictionary = DragonManager.player_dragons[selected_parent_b_index].duplicate(true)

	var result: Dictionary = DragonManager.breed_dragons(selected_parent_a_index, selected_parent_b_index)

	if not bool(result.get("success", false)):
		prediction_label.text = "[center][color=red]ERROR: " + str(result.get("error", "Unknown error")) + "[/color][/center]"
		_refresh_breeding_ui()
		return
		
	_close_breeding_station()
	
	var bred_egg: ConsumableData = _build_bred_egg_item(result, parent_a_snapshot, parent_b_snapshot)
	CampaignManager.global_inventory.append(bred_egg)

	breed_panel.hide()

	await _play_breeding_cinematic(result, parent_a_snapshot, parent_b_snapshot)

	_spawn_dragons()
	_refresh_actor_selection()

	if selected_dragon_uid != "":
		_update_info_card()

	_refresh_breeding_ui()
	_trigger_morgra("breed")
	
func _kill_breed_ui_tween(tw: Tween) -> void:
	if tw != null and is_instance_valid(tw):
		tw.kill()


func _close_breeding_station() -> void:
	_stop_breeding_preview_fx()
	if breed_panel != null:
		breed_panel.hide()


func _get_quality_color(quality: String) -> Color:
	match quality:
		"Legendary":
			return Color(1.0, 0.86, 0.24, 1.0)
		"Epic":
			return Color(0.82, 0.58, 1.0, 1.0)
		"Rare":
			return Color(0.40, 0.82, 1.0, 1.0)
		_:
			return Color(0.92, 0.92, 0.92, 1.0)


func _get_element_mix_color(element_a: String, element_b: String) -> Color:
	var c1: Color = _get_element_reveal_color(element_a)
	var c2: Color = _get_element_reveal_color(element_b)
	return c1.lerp(c2, 0.5)


func _ensure_breeding_station_fx_ui() -> void:
	if breed_panel == null:
		return

	if breed_preview_fx_root != null and is_instance_valid(breed_preview_fx_root):
		return

	breed_preview_fx_root = Control.new()
	breed_preview_fx_root.name = "BreedPreviewFXRoot"
	breed_preview_fx_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breed_preview_fx_root.size = breed_panel.size
	breed_panel.add_child(breed_preview_fx_root)

	breed_prediction_backplate = ColorRect.new()
	breed_prediction_backplate.color = Color(0.08, 0.08, 0.12, 0.84)
	breed_prediction_backplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breed_prediction_backplate.z_index = -1
	breed_preview_fx_root.add_child(breed_prediction_backplate)

	breed_compat_bar_bg = ColorRect.new()
	breed_compat_bar_bg.color = Color(0.12, 0.12, 0.16, 0.95)
	breed_compat_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breed_preview_fx_root.add_child(breed_compat_bar_bg)

	breed_compat_bar_fill = ColorRect.new()
	breed_compat_bar_fill.color = Color(0.7, 0.7, 0.7, 1.0)
	breed_compat_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breed_preview_fx_root.add_child(breed_compat_bar_fill)

	breed_compat_value_label = Label.new()
	breed_compat_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breed_compat_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breed_compat_value_label.add_theme_font_size_override("font_size", 18)
	breed_compat_value_label.add_theme_color_override("font_color", Color.WHITE)
	breed_preview_fx_root.add_child(breed_compat_value_label)

	breed_mutation_label = RichTextLabel.new()
	breed_mutation_label.bbcode_enabled = true
	breed_mutation_label.fit_content = true
	breed_mutation_label.scroll_active = false
	breed_mutation_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breed_preview_fx_root.add_child(breed_mutation_label)

	breed_resonance_glow = ColorRect.new()
	breed_resonance_glow.color = Color(1, 1, 1, 0.18)
	breed_resonance_glow.size = Vector2(90, 90)
	breed_resonance_glow.pivot_offset = breed_resonance_glow.size * 0.5
	breed_resonance_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breed_preview_fx_root.add_child(breed_resonance_glow)

	breed_resonance_ring = ColorRect.new()
	breed_resonance_ring.color = Color(1, 1, 1, 0.08)
	breed_resonance_ring.size = Vector2(124, 124)
	breed_resonance_ring.pivot_offset = breed_resonance_ring.size * 0.5
	breed_resonance_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breed_preview_fx_root.add_child(breed_resonance_ring)

	_layout_breeding_station_fx_ui()


func _layout_breeding_station_fx_ui() -> void:
	if breed_preview_fx_root == null or prediction_label == null:
		return

	breed_preview_fx_root.size = breed_panel.size

	var card_pos: Vector2 = prediction_label.position - Vector2(14, 14)
	var card_size: Vector2 = Vector2(max(prediction_label.size.x + 28.0, 380.0), 210.0)

	breed_prediction_backplate.position = card_pos
	breed_prediction_backplate.size = card_size

	breed_compat_bar_bg.position = card_pos + Vector2(18.0, 132.0)
	breed_compat_bar_bg.size = Vector2(card_size.x - 36.0, 16.0)

	breed_compat_bar_fill.position = breed_compat_bar_bg.position
	breed_compat_bar_fill.size = Vector2(0.0, breed_compat_bar_bg.size.y)

	breed_compat_value_label.position = breed_compat_bar_bg.position + Vector2(0.0, -28.0)
	breed_compat_value_label.size = Vector2(breed_compat_bar_bg.size.x, 24.0)

	breed_mutation_label.position = card_pos + Vector2(18.0, 154.0)
	breed_mutation_label.size = Vector2(card_size.x - 36.0, 52.0)

	if parent_a_btn != null and parent_b_btn != null:
		var left_center: Vector2 = parent_a_btn.position + parent_a_btn.size * 0.5
		var right_center: Vector2 = parent_b_btn.position + parent_b_btn.size * 0.5
		var mid: Vector2 = (left_center + right_center) * 0.5 + Vector2(0.0, 8.0)

		breed_resonance_glow.position = mid - breed_resonance_glow.size * 0.5
		breed_resonance_ring.position = mid - breed_resonance_ring.size * 0.5


func _set_parent_button_style(btn: Button, color: Color, active: bool) -> void:
	if btn == null:
		return

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2

	if active:
		style.bg_color = color.darkened(0.72)
		style.border_color = color
		btn.modulate = Color(1.05, 1.05, 1.05, 1.0)
	else:
		style.bg_color = Color(0.13, 0.13, 0.16, 0.92)
		style.border_color = Color(0.35, 0.35, 0.40, 1.0)
		btn.modulate = Color.WHITE

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)


func _start_parent_slot_pulse(slot_name: String, sprite_node: TextureRect, btn: Button, color: Color) -> void:
	if sprite_node == null or btn == null:
		return

	sprite_node.pivot_offset = sprite_node.size * 0.5
	sprite_node.modulate = color.lerp(Color.WHITE, 0.35)
	sprite_node.scale = Vector2.ONE

	var tw: Tween = create_tween().set_loops()
	tw.tween_property(sprite_node, "scale", Vector2(1.08, 1.08), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(sprite_node, "modulate", color.lerp(Color.WHITE, 0.55), 0.42)
	tw.tween_property(sprite_node, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(sprite_node, "modulate", color.lerp(Color.WHITE, 0.30), 0.42)

	if slot_name == "A":
		_kill_breed_ui_tween(breed_parent_a_tween)
		breed_parent_a_tween = tw
	else:
		_kill_breed_ui_tween(breed_parent_b_tween)
		breed_parent_b_tween = tw


func _stop_breeding_preview_fx() -> void:
	_kill_breed_ui_tween(breed_parent_a_tween)
	_kill_breed_ui_tween(breed_parent_b_tween)
	_kill_breed_ui_tween(breed_resonance_tween)
	_kill_breed_ui_tween(breed_confirm_tween)

	if parent_a_sprite != null:
		parent_a_sprite.scale = Vector2.ONE
		parent_a_sprite.modulate = Color.WHITE
	if parent_b_sprite != null:
		parent_b_sprite.scale = Vector2.ONE
		parent_b_sprite.modulate = Color.WHITE
	if confirm_breed_btn != null:
		confirm_breed_btn.modulate = Color.WHITE

	if breed_resonance_glow != null:
		breed_resonance_glow.scale = Vector2.ONE
		breed_resonance_glow.modulate.a = 0.0
	if breed_resonance_ring != null:
		breed_resonance_ring.scale = Vector2.ONE
		breed_resonance_ring.modulate.a = 0.0


func _start_breeding_preview_fx(preview: Dictionary) -> void:
	_layout_breeding_station_fx_ui()

	var score: float = float(int(preview.get("compatibility_score", 0))) / 100.0
	var quality: String = str(preview.get("quality", "Common"))
	var quality_color: Color = _get_quality_color(quality)
	var mix_color: Color = _get_element_mix_color(
		str(preview.get("element_a", "")),
		str(preview.get("element_b", ""))
	)
	var final_color: Color = mix_color.lerp(quality_color, 0.40)

	if breed_resonance_glow != null:
		breed_resonance_glow.color = final_color
		breed_resonance_glow.scale = Vector2(0.75, 0.75)
		breed_resonance_glow.modulate.a = 0.12

	if breed_resonance_ring != null:
		breed_resonance_ring.color = quality_color
		breed_resonance_ring.scale = Vector2(0.85, 0.85)
		breed_resonance_ring.modulate.a = 0.08

	_kill_breed_ui_tween(breed_resonance_tween)
	breed_resonance_tween = create_tween().set_loops()

	var pulse_scale: float = 1.05 + (score * 0.35)
	var pulse_alpha: float = 0.18 + (score * 0.22)
	var ring_scale: float = 1.18 + (score * 0.28)

	breed_resonance_tween.tween_property(breed_resonance_glow, "scale", Vector2(pulse_scale, pulse_scale), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breed_resonance_tween.parallel().tween_property(breed_resonance_glow, "modulate:a", pulse_alpha, 0.45)
	breed_resonance_tween.parallel().tween_property(breed_resonance_ring, "scale", Vector2(ring_scale, ring_scale), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	breed_resonance_tween.parallel().tween_property(breed_resonance_ring, "modulate:a", 0.16 + (score * 0.12), 0.45)

	breed_resonance_tween.tween_property(breed_resonance_glow, "scale", Vector2(0.85, 0.85), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breed_resonance_tween.parallel().tween_property(breed_resonance_glow, "modulate:a", 0.12, 0.45)
	breed_resonance_tween.parallel().tween_property(breed_resonance_ring, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breed_resonance_tween.parallel().tween_property(breed_resonance_ring, "modulate:a", 0.06, 0.45)

	if confirm_breed_btn != null and not confirm_breed_btn.disabled:
		_kill_breed_ui_tween(breed_confirm_tween)
		breed_confirm_tween = create_tween().set_loops()
		breed_confirm_tween.tween_property(confirm_breed_btn, "modulate", Color(1.08, 1.08, 1.08, 1.0), 0.42)
		breed_confirm_tween.tween_property(confirm_breed_btn, "modulate", Color.WHITE, 0.42)

func _process(delta: float) -> void:
	_tick_social_pair_cooldowns(delta)

	if not visible:
		return

	if _is_ranch_busy_for_social():
		return

	if actor_by_uid.size() < 2:
		return

	social_interaction_timer -= delta
	if social_interaction_timer > 0.0:
		return

	social_interaction_timer = _roll_next_social_time()
	call_deferred("_try_start_social_interaction")


func _tick_social_pair_cooldowns(delta: float) -> void:
	if social_pair_cooldowns.is_empty():
		return

	var to_erase: Array = []
	for pair_key in social_pair_cooldowns.keys():
		var new_value: float = float(social_pair_cooldowns[pair_key]) - delta
		if new_value <= 0.0:
			to_erase.append(pair_key)
		else:
			social_pair_cooldowns[pair_key] = new_value

	for pair_key in to_erase:
		social_pair_cooldowns.erase(pair_key)


func _roll_next_social_time() -> float:
	return randf_range(SOCIAL_INTERACTION_MIN_DELAY, SOCIAL_INTERACTION_MAX_DELAY)


func _is_ranch_busy_for_social() -> bool:
	return is_feed_animating or is_pet_animating or is_hunt_animating or is_hatch_animating or is_social_animating or is_training_animating

func _make_social_pair_key(uid_a: String, uid_b: String) -> String:
	if uid_a < uid_b:
		return uid_a + "|" + uid_b
	return uid_b + "|" + uid_a


func _try_start_social_interaction() -> void:
	if not visible:
		return
	if _is_ranch_busy_for_social():
		return
	if actor_by_uid.size() < 2:
		return

	var picked: Dictionary = _pick_social_pair()
	if picked.is_empty():
		return

	await _run_social_interaction(
		str(picked.get("uid_a", "")),
		str(picked.get("uid_b", "")),
		str(picked.get("type", "greet"))
	)

func _pick_social_pair() -> Dictionary:
	var valid_uids: Array = []

	for uid in actor_by_uid.keys():
		var actor: DragonActor = _get_actor_by_uid(str(uid))
		if actor != null:
			valid_uids.append(str(uid))

	if valid_uids.size() < 2:
		return {}

	var entries: Array = []
	var total_weight: float = 0.0

	for i in range(valid_uids.size()):
		for j in range(i + 1, valid_uids.size()):
			var uid_a: String = str(valid_uids[i])
			var uid_b: String = str(valid_uids[j])

			var pair_key: String = _make_social_pair_key(uid_a, uid_b)
			if social_pair_cooldowns.has(pair_key):
				continue

			var actor_a: DragonActor = _get_actor_by_uid(uid_a)
			var actor_b: DragonActor = _get_actor_by_uid(uid_b)
			if actor_a == null or actor_b == null:
				continue

			var dragon_a: Dictionary = DragonManager.get_dragon_by_uid(uid_a)
			var dragon_b: Dictionary = DragonManager.get_dragon_by_uid(uid_b)
			if dragon_a.is_empty() or dragon_b.is_empty():
				continue

			var weight: float = _get_social_pair_weight(actor_a, actor_b, dragon_a, dragon_b)
			if weight <= 0.0:
				continue

			var social_score: int = DragonManager.get_social_score(uid_a, uid_b)
			var interaction_type: String = _determine_social_interaction_type(dragon_a, dragon_b, social_score)

			entries.append({
				"uid_a": uid_a,
				"uid_b": uid_b,
				"type": interaction_type,
				"weight": weight
			})
			total_weight += weight

	if entries.is_empty() or total_weight <= 0.0:
		return {}

	var roll: float = randf() * total_weight
	var running: float = 0.0

	for entry in entries:
		running += float(entry["weight"])
		if roll <= running:
			return entry

	return entries[entries.size() - 1]


func _get_social_pair_weight(actor_a: DragonActor, actor_b: DragonActor, dragon_a: Dictionary, dragon_b: Dictionary) -> float:
	var center_a: Vector2 = actor_a.position + actor_a.size * 0.5
	var center_b: Vector2 = actor_b.position + actor_b.size * 0.5
	var distance: float = center_a.distance_to(center_b)

	var distance_bias: float = clampf(1.0 - (distance / SOCIAL_MIN_DISTANCE_BIAS), 0.15, 1.0)
	var stage_a: int = int(dragon_a.get("stage", 2))
	var stage_b: int = int(dragon_b.get("stage", 2))
	# Babies seek interaction more; adults slightly less often.
	if stage_a == 1 or stage_b == 1:
		distance_bias *= 1.20
	elif stage_a == 3 and stage_b == 3:
		distance_bias *= 0.85
	distance_bias = clampf(distance_bias, 0.10, 1.25)
	var avg_happiness: float = (
		float(int(dragon_a.get("happiness", 50))) +
		float(int(dragon_b.get("happiness", 50)))
	) / 2.0

	var social_score: int = DragonManager.get_social_score(
		str(dragon_a.get("uid", "")),
		str(dragon_b.get("uid", ""))
	)

	var weight: float = 0.35
	weight += distance_bias * 0.90
	weight += (avg_happiness / 100.0) * 0.65
	weight += (abs(float(social_score)) / 100.0) * 0.55

	if str(dragon_a.get("element", "")) == str(dragon_b.get("element", "")):
		weight += 0.25

	var mood_a: String = str(dragon_a.get("mood", ""))
	var mood_b: String = str(dragon_b.get("mood", ""))

	if mood_a == "Affectionate" or mood_b == "Affectionate":
		weight += 0.25
	if mood_a == "Irritated" or mood_b == "Irritated":
		weight += 0.20

	return max(weight, 0.0)


func _traits_have_any(traits: Array, wanted: Array) -> bool:
	if traits == null or wanted == null:
		return false
	for t in traits:
		if wanted.has(t):
			return true
	return false


func _stage_social_bias(stage: int) -> Dictionary:
	# Weight nudges based on life stage.
	# 1 = Baby (more playful), 2 = Juvenile (balanced), 3 = Adult (calmer).
	match stage:
		1:
			return {"play": 1.6, "greet": 1.2, "mock_chase": 1.3, "rival_stare": 0.7}
		2:
			return {"play": 1.0, "greet": 1.0, "mock_chase": 1.0, "rival_stare": 1.0}
		3:
			return {"play": 0.55, "greet": 1.15, "mock_chase": 0.65, "rival_stare": 0.9, "nuzzle": 1.2}
		_:
			return {"play": 0.8, "greet": 1.0, "mock_chase": 0.85, "rival_stare": 1.0}


func _determine_social_interaction_type(dragon_a: Dictionary, dragon_b: Dictionary, social_score: int) -> String:
	var avg_happiness: float = (
		float(int(dragon_a.get("happiness", 50))) +
		float(int(dragon_b.get("happiness", 50)))
	) / 2.0

	var traits_a: Array = dragon_a.get("traits", [])
	var traits_b: Array = dragon_b.get("traits", [])
	var stage_a: int = int(dragon_a.get("stage", 2))
	var stage_b: int = int(dragon_b.get("stage", 2))
	var bias_a: Dictionary = _stage_social_bias(stage_a)
	var bias_b: Dictionary = _stage_social_bias(stage_b)
	var bias_play: float = (float(bias_a.get("play", 1.0)) + float(bias_b.get("play", 1.0))) * 0.5
	var bias_greet: float = (float(bias_a.get("greet", 1.0)) + float(bias_b.get("greet", 1.0))) * 0.5
	var bias_mock: float = (float(bias_a.get("mock_chase", 1.0)) + float(bias_b.get("mock_chase", 1.0))) * 0.5
	var bias_rival: float = (float(bias_a.get("rival_stare", 1.0)) + float(bias_b.get("rival_stare", 1.0))) * 0.5
	var bias_nuzzle: float = (float(bias_a.get("nuzzle", 1.0)) + float(bias_b.get("nuzzle", 1.0))) * 0.5

	var gentle: bool = (
		_traits_have_any(traits_a, ["Loyal", "Gentle Soul", "Guardian", "Heartbound", "Soulkeeper", "Warden"]) or
		_traits_have_any(traits_b, ["Loyal", "Gentle Soul", "Guardian", "Heartbound", "Soulkeeper", "Warden"])
	)

	var aggressive: bool = (
		_traits_have_any(traits_a, ["Fierce", "Vicious", "Dominant", "Savage", "Blood Frenzy", "Tyrant"]) or
		_traits_have_any(traits_b, ["Fierce", "Vicious", "Dominant", "Savage", "Blood Frenzy", "Tyrant"])
	)

	var playful: bool = (
		_traits_have_any(traits_a, ["Swift", "Keen Hunter", "Sky Dancer", "Lightning Reflexes", "Apex Hunter", "Zephyr Lord"]) or
		_traits_have_any(traits_b, ["Swift", "Keen Hunter", "Sky Dancer", "Lightning Reflexes", "Apex Hunter", "Zephyr Lord"])
	)

	var mood_a: String = str(dragon_a.get("mood", ""))
	var mood_b: String = str(dragon_b.get("mood", ""))

	# Age-stage integration:
	# - Babies skew playful and less confrontational.
	# - Adults skew calmer (more greet/nuzzle, less chase/zoom-style play).
	var rival_trigger_chance: float = clampf(0.65 * bias_rival, 0.15, 0.85)
	if social_score <= -25 or ((mood_a == "Irritated" or mood_b == "Irritated") and aggressive and randf() < rival_trigger_chance):
		return "rival_stare"

	var nuzzle_bonus_chance: float = clampf(0.65 * bias_nuzzle, 0.20, 0.90)
	if social_score >= 30 and gentle and randf() < nuzzle_bonus_chance:
		return "nuzzle"

	var play_chance: float = clampf(0.55 * bias_play, 0.15, 0.85)
	if playful and avg_happiness >= 50.0 and randf() < play_chance:
		return "play"

	var mock_chance: float = clampf(0.35 * bias_mock, 0.10, 0.70)
	if aggressive and avg_happiness >= 45.0 and randf() < mock_chance:
		return "mock_chase"

	var affectionate_nuzzle_chance: float = clampf(0.55 * bias_nuzzle, 0.15, 0.90)
	if (mood_a == "Affectionate" or mood_b == "Affectionate") and randf() < affectionate_nuzzle_chance:
		return "nuzzle"

	# Default: greeting, slightly boosted for older stages.
	if randf() < clampf(0.10 * bias_greet, 0.0, 0.25):
		return "nuzzle"
	return "greet"
	
func _run_social_interaction(uid_a: String, uid_b: String, interaction_type: String) -> void:
	if uid_a == "" or uid_b == "" or uid_a == uid_b:
		return
	if _is_ranch_busy_for_social():
		return

	var actor_a: DragonActor = _get_actor_by_uid(uid_a)
	var actor_b: DragonActor = _get_actor_by_uid(uid_b)
	if actor_a == null or actor_b == null:
		return

	var dragon_a: Dictionary = DragonManager.get_dragon_by_uid(uid_a)
	var dragon_b: Dictionary = DragonManager.get_dragon_by_uid(uid_b)
	if dragon_a.is_empty() or dragon_b.is_empty():
		return

	is_social_animating = true
	social_pair_cooldowns[_make_social_pair_key(uid_a, uid_b)] = SOCIAL_PAIR_COOLDOWN

	var start_a: Vector2 = actor_a.position
	var start_b: Vector2 = actor_b.position

	actor_a.set_cinematic_mode(true)
	actor_b.set_cinematic_mode(true)

	var center_a: Vector2 = actor_a.position + actor_a.size * 0.5
	var center_b: Vector2 = actor_b.position + actor_b.size * 0.5
	var meet_center: Vector2 = (center_a + center_b) * 0.5 + Vector2(randf_range(-20.0, 20.0), randf_range(-12.0, 12.0))

	var spacing: float = max(actor_a.size.x, actor_b.size.x) * 0.55

	var target_a: Vector2 = meet_center - actor_a.size * 0.5 + Vector2(-spacing, 0.0)
	var target_b: Vector2 = meet_center - actor_b.size * 0.5 + Vector2(spacing, 0.0)

	target_a = _clamp_actor_target_to_enclosure(target_a, actor_a)
	target_b = _clamp_actor_target_to_enclosure(target_b, actor_b)

	if target_a.x < target_b.x:
		actor_a.set_facing_immediate(1.0)
		actor_b.set_facing_immediate(-1.0)
	else:
		actor_a.set_facing_immediate(-1.0)
		actor_b.set_facing_immediate(1.0)

	var meet_tw := create_tween().set_parallel(true)
	meet_tw.tween_property(actor_a, "position", target_a, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	meet_tw.tween_property(actor_b, "position", target_b, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await meet_tw.finished

	match interaction_type:
		"greet":
			await _play_social_greet(actor_a, actor_b)
			_apply_social_interaction_effects(uid_a, uid_b, "greet")

		"nuzzle":
			await _play_social_nuzzle(actor_a, actor_b)
			_apply_social_interaction_effects(uid_a, uid_b, "nuzzle")

		"play":
			await _play_social_play(actor_a, actor_b)
			_apply_social_interaction_effects(uid_a, uid_b, "play")

		"mock_chase":
			await _play_social_mock_chase(actor_a, actor_b)
			_apply_social_interaction_effects(uid_a, uid_b, "mock_chase")

		"rival_stare":
			await _play_social_rival_stare(actor_a, actor_b)
			_apply_social_interaction_effects(uid_a, uid_b, "rival_stare")

		_:
			await _play_social_greet(actor_a, actor_b)
			_apply_social_interaction_effects(uid_a, uid_b, "greet")

	actor_a.refresh_from_data(DragonManager.get_dragon_by_uid(uid_a))
	actor_b.refresh_from_data(DragonManager.get_dragon_by_uid(uid_b))

	if selected_dragon_uid == uid_a or selected_dragon_uid == uid_b:
		_update_info_card()

	await get_tree().create_timer(0.20).timeout

	var return_tw := create_tween().set_parallel(true)
	return_tw.tween_property(actor_a, "position", _clamp_actor_target_to_enclosure(start_a, actor_a), 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return_tw.tween_property(actor_b, "position", _clamp_actor_target_to_enclosure(start_b, actor_b), 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await return_tw.finished

	actor_a.set_cinematic_mode(false)
	actor_b.set_cinematic_mode(false)

	is_social_animating = false
	
func _clamp_actor_target_to_enclosure(target: Vector2, actor: DragonActor) -> Vector2:
	var out: Vector2 = target
	out.x = clampf(out.x, 0.0, max(0.0, enclosure.size.x - actor.size.x))
	out.y = clampf(out.y, 0.0, max(0.0, enclosure.size.y - actor.size.y))
	return out


func _play_social_greet(actor_a: DragonActor, actor_b: DragonActor) -> void:
	actor_a.play_cinematic_pulse(0.65)
	actor_b.play_cinematic_pulse(0.65)

	if actor_a.has_method("show_float_text"):
		actor_a.show_float_text("Chirp!", Color(0.85, 1.0, 0.90))
	if actor_b.has_method("show_float_text"):
		actor_b.show_float_text("Chirp!", Color(0.85, 1.0, 0.90))

	await get_tree().create_timer(0.55).timeout


func _play_social_nuzzle(actor_a: DragonActor, actor_b: DragonActor) -> void:
	var orig_a: Vector2 = actor_a.position
	var orig_b: Vector2 = actor_b.position

	var dir: Vector2 = (actor_b.position - actor_a.position).normalized()
	if dir.length() <= 0.001:
		dir = Vector2.RIGHT

	var tw := create_tween().set_parallel(true)
	tw.tween_property(actor_a, "position", orig_a + dir * 10.0, 0.12)
	tw.tween_property(actor_b, "position", orig_b - dir * 10.0, 0.12)
	tw.tween_property(actor_a, "scale", Vector2(1.04, 1.04), 0.12)
	tw.tween_property(actor_b, "scale", Vector2(1.04, 1.04), 0.12)
	await tw.finished

	if actor_a.has_method("show_float_text"):
		actor_a.show_float_text("♥", Color(1.0, 0.70, 0.88))
	if actor_b.has_method("show_float_text"):
		actor_b.show_float_text("♥", Color(1.0, 0.70, 0.88))

	var back_tw := create_tween().set_parallel(true)
	back_tw.tween_property(actor_a, "position", orig_a, 0.14).set_trans(Tween.TRANS_BOUNCE)
	back_tw.tween_property(actor_b, "position", orig_b, 0.14).set_trans(Tween.TRANS_BOUNCE)
	back_tw.tween_property(actor_a, "scale", Vector2.ONE, 0.14)
	back_tw.tween_property(actor_b, "scale", Vector2.ONE, 0.14)
	await back_tw.finished


func _play_social_play(actor_a: DragonActor, actor_b: DragonActor) -> void:
	var orig_a: Vector2 = actor_a.position
	var orig_b: Vector2 = actor_b.position

	actor_a.play_cinematic_pulse(0.85)
	actor_b.play_cinematic_pulse(0.85)

	var mid: Vector2 = (orig_a + orig_b) * 0.5

	var tw := create_tween().set_parallel(true)
	tw.tween_property(actor_a, "position", mid + Vector2(-34.0, -18.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(actor_b, "position", mid + Vector2(34.0, 18.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished

	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(actor_a, "position", orig_b, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(actor_b, "position", orig_a, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw2.finished

	if actor_a.has_method("show_float_text"):
		actor_a.show_float_text("!", Color(0.95, 0.95, 0.60))
	if actor_b.has_method("show_float_text"):
		actor_b.show_float_text("!", Color(0.95, 0.95, 0.60))

	var tw3 := create_tween().set_parallel(true)
	tw3.tween_property(actor_a, "position", orig_a, 0.20).set_trans(Tween.TRANS_BOUNCE)
	tw3.tween_property(actor_b, "position", orig_b, 0.20).set_trans(Tween.TRANS_BOUNCE)
	await tw3.finished


func _play_social_mock_chase(actor_a: DragonActor, actor_b: DragonActor) -> void:
	var start_b: Vector2 = actor_b.position
	var flee_target: Vector2 = _clamp_actor_target_to_enclosure(
		start_b + Vector2(randf_range(-70.0, 70.0), randf_range(-30.0, 30.0)),
		actor_b
	)

	actor_a.play_cinematic_pulse(0.80)
	actor_b.play_cinematic_pulse(0.60)

	if actor_a.has_method("show_float_text"):
		actor_a.show_float_text("Rrr!", Color(1.0, 0.62, 0.62))

	var tw := create_tween().set_parallel(true)
	tw.tween_property(actor_b, "position", flee_target, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(actor_a, "position", _clamp_actor_target_to_enclosure(flee_target + Vector2(-24.0, 0.0), actor_a), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished

	await get_tree().create_timer(0.16).timeout


func _play_social_rival_stare(actor_a: DragonActor, actor_b: DragonActor) -> void:
	actor_a.play_cinematic_roar(0.85, 1.00, 1.0)
	await get_tree().create_timer(0.08).timeout
	actor_b.play_cinematic_roar(0.88, 1.02, 1.0)

	if actor_a.has_method("show_float_text"):
		actor_a.show_float_text("Hss!", Color(1.0, 0.50, 0.50))
	if actor_b.has_method("show_float_text"):
		actor_b.show_float_text("Hss!", Color(1.0, 0.50, 0.50))

	_shake_enclosure(2.0, 0.10)
	await get_tree().create_timer(0.55).timeout
	
func _apply_social_interaction_effects(uid_a: String, uid_b: String, interaction_type: String) -> void:
	var index_a: int = _get_dragon_index_by_uid(uid_a)
	var index_b: int = _get_dragon_index_by_uid(uid_b)
	if index_a == -1 or index_b == -1:
		return

	var dragon_a: Dictionary = DragonManager.player_dragons[index_a]
	var dragon_b: Dictionary = DragonManager.player_dragons[index_b]

	var social_delta: int = 0
	var happy_delta_a: int = 0
	var happy_delta_b: int = 0

	match interaction_type:
		"greet":
			social_delta = 1
			happy_delta_a = 1
			happy_delta_b = 1

		"nuzzle":
			social_delta = 3
			happy_delta_a = 2
			happy_delta_b = 2

		"play":
			social_delta = 2
			happy_delta_a = 3
			happy_delta_b = 3

		"mock_chase":
			social_delta = 1
			happy_delta_a = 2
			happy_delta_b = 1

		"rival_stare":
			social_delta = -2
			happy_delta_a = -1
			happy_delta_b = -1

		_:
			social_delta = 0

	# Age-stage tuning: babies react more strongly; adults are more even-keeled.
	var stage_a: int = int(dragon_a.get("stage", 2))
	var stage_b: int = int(dragon_b.get("stage", 2))
	if interaction_type == "play":
		if stage_a == 1: happy_delta_a += 1
		if stage_b == 1: happy_delta_b += 1
		if stage_a == 3: happy_delta_a = max(happy_delta_a - 1, 0)
		if stage_b == 3: happy_delta_b = max(happy_delta_b - 1, 0)
	elif interaction_type == "mock_chase":
		if stage_a == 1: happy_delta_a += 1
		if stage_b == 1: happy_delta_b += 1
		if stage_a == 3: happy_delta_a = max(happy_delta_a - 1, -2)
		if stage_b == 3: happy_delta_b = max(happy_delta_b - 1, -2)
	elif interaction_type == "rival_stare":
		# Babies get less upset by staring contests.
		if stage_a == 1: happy_delta_a = min(happy_delta_a + 1, 0)
		if stage_b == 1: happy_delta_b = min(happy_delta_b + 1, 0)

	DragonManager.change_social_score(uid_a, uid_b, social_delta)

	dragon_a["happiness"] = clampi(int(dragon_a.get("happiness", 50)) + happy_delta_a, 0, 100)
	dragon_b["happiness"] = clampi(int(dragon_b.get("happiness", 50)) + happy_delta_b, 0, 100)

	DragonManager._refresh_dragon_mood(dragon_a)
	DragonManager._refresh_dragon_mood(dragon_b)	
	
func _setup_training_ui() -> void:
	if training_program_option == null or training_intensity_option == null:
		return

	training_program_ids.clear()
	training_program_option.clear()

	var programs: Array = DragonManager.get_training_program_list()
	for program_var in programs:
		var program: Dictionary = program_var
		var program_id: String = str(program.get("id", ""))
		var display_name: String = str(program.get("display_name", program_id))
		if program_id == "":
			continue

		training_program_ids.append(program_id)
		training_program_option.add_item(display_name)

	if training_program_option.item_count > 0:
		training_program_option.select(0)

	training_intensity_option.clear()
	training_intensity_option.add_item("Light")
	training_intensity_option.add_item("Normal")
	training_intensity_option.add_item("Intense")
	training_intensity_option.select(DragonManager.TRAINING_INTENSITY_NORMAL)

	if training_preview_label != null:
		training_preview_label.bbcode_enabled = true
		training_preview_label.fit_content = true
		training_preview_label.scroll_active = false

	_refresh_training_controls()


func _get_selected_training_program_id() -> String:
	if training_program_option == null:
		return ""

	var selected_idx: int = training_program_option.get_selected()
	if selected_idx < 0 or selected_idx >= training_program_ids.size():
		return ""

	return training_program_ids[selected_idx]


func _get_selected_training_intensity() -> int:
	if training_intensity_option == null:
		return DragonManager.TRAINING_INTENSITY_NORMAL

	var selected_idx: int = training_intensity_option.get_selected()

	match selected_idx:
		DragonManager.TRAINING_INTENSITY_LIGHT:
			return DragonManager.TRAINING_INTENSITY_LIGHT
		DragonManager.TRAINING_INTENSITY_INTENSE:
			return DragonManager.TRAINING_INTENSITY_INTENSE
		_:
			return DragonManager.TRAINING_INTENSITY_NORMAL


func _on_training_selection_changed(_index: int) -> void:
	_refresh_training_controls()


func _refresh_training_controls() -> void:
	if training_preview_label == null and train_dragon_btn == null and rest_dragon_btn == null:
		return

	var selected_index: int = _get_selected_index()
	if selected_index < 0 or selected_index >= DragonManager.player_dragons.size():
		if training_preview_label != null:
			training_preview_label.text = "[color=gray]Select a dragon first.[/color]"
		if train_dragon_btn != null:
			train_dragon_btn.disabled = true
			train_dragon_btn.text = "Train"
		if rest_dragon_btn != null:
			rest_dragon_btn.disabled = true
			rest_dragon_btn.text = "Rest Dragon"
		if training_program_option != null:
			training_program_option.disabled = true
		if training_intensity_option != null:
			training_intensity_option.disabled = true
		return

	var dragon: Dictionary = DragonManager.player_dragons[selected_index]
	var already_used: bool = _dragon_has_used_ranch_action(dragon)

	var controls_busy: bool = (
		is_feed_animating or
		is_pet_animating or
		is_hunt_animating or
		is_hatch_animating or
		is_training_animating
	)

	if training_program_option != null:
		training_program_option.disabled = controls_busy or already_used

	if training_intensity_option != null:
		training_intensity_option.disabled = controls_busy or already_used

	if already_used:
		if training_preview_label != null:
			training_preview_label.text = "[color=orange]This dragon already used its ranch action for this level.[/color]"

		if train_dragon_btn != null:
			train_dragon_btn.disabled = true
			train_dragon_btn.text = "Already Used"

		if rest_dragon_btn != null:
			rest_dragon_btn.disabled = true
			rest_dragon_btn.text = "Already Used"

		return

	var program_id: String = _get_selected_training_program_id()
	var intensity: int = _get_selected_training_intensity()

	if program_id == "":
		if training_preview_label != null:
			training_preview_label.text = "[color=gray]No training program selected.[/color]"
		if train_dragon_btn != null:
			train_dragon_btn.disabled = true
			train_dragon_btn.text = "Train"
		if rest_dragon_btn != null:
			rest_dragon_btn.disabled = true
			rest_dragon_btn.text = "Rest Dragon"
		return

	var preview: Dictionary = DragonManager.get_training_preview(selected_index, program_id, intensity)

	if training_preview_label != null:
		if bool(preview.get("ok", false)):
			var possible_stats: Array = preview.get("possible_stats", [])
			var stat_text: String = "None"
			if not possible_stats.is_empty():
				stat_text = ", ".join(possible_stats)

			training_preview_label.text = (
				"[b]%s[/b]\n" % str(preview.get("program_name", "Training")) +
				"Cost: [color=gold]%d Gold[/color]\n" % int(preview.get("gold_cost", 0)) +
				"Happiness: [color=salmon]-%d[/color]  |  Fatigue: [color=orange]+%d[/color]\n" % [
					int(preview.get("happiness_loss", 0)),
					int(preview.get("fatigue_gain", 0))
				] +
				"Possible gains: [color=cyan]%s[/color]" % stat_text
			)
		else:
			training_preview_label.text = "[color=red]%s[/color]" % str(preview.get("error", "Training unavailable."))

	if train_dragon_btn != null:
		train_dragon_btn.disabled = controls_busy or not bool(preview.get("ok", false))
		train_dragon_btn.text = "Train (%d Gold)" % int(preview.get("gold_cost", 0))

	if rest_dragon_btn != null:
		var fatigue_value: int = int(dragon.get("fatigue", 0))
		rest_dragon_btn.disabled = controls_busy or fatigue_value <= 0
		rest_dragon_btn.text = "Rest Dragon"

func _set_train_btn_temp_text(text: String, delay: float = 1.2) -> void:
	if train_dragon_btn == null:
		return

	train_dragon_btn.text = text
	get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(train_dragon_btn):
			_refresh_training_controls()
	)


func _on_train_pressed() -> void:
	if is_feed_animating or is_pet_animating or is_hunt_animating or is_hatch_animating or is_training_animating:
		return

	var selected_index: int = _get_selected_index()
	if selected_index < 0 or selected_index >= DragonManager.player_dragons.size():
		return

	var program_id: String = _get_selected_training_program_id()
	var intensity: int = _get_selected_training_intensity()
	var preview: Dictionary = DragonManager.get_training_preview(selected_index, program_id, intensity)

	if not bool(preview.get("ok", false)):
		_set_train_btn_temp_text(str(preview.get("error", "Training failed.")))
		_refresh_training_controls()
		return

	var actor: DragonActor = _get_actor_by_uid(selected_dragon_uid)
	is_training_animating = true
	_refresh_training_controls()
	_update_info_card()

	var result: Dictionary = DragonManager.train_dragon(selected_index, program_id, intensity)

	if not bool(result.get("ok", false)):
		is_training_animating = false
		_refresh_training_controls()
		_update_info_card()
		_set_train_btn_temp_text(str(result.get("error", "Training failed.")))
		return
	
	_mark_selected_dragon_ranch_action_used()

	if actor != null:
		await _play_training_fx(actor, result)
		actor.refresh_from_data(DragonManager.player_dragons[selected_index])

	is_training_animating = false
	_update_info_card()
	_refresh_training_controls()


func _on_rest_pressed() -> void:
	if is_feed_animating or is_pet_animating or is_hunt_animating or is_hatch_animating or is_training_animating:
		return

	var selected_index: int = _get_selected_index()
	if selected_index < 0 or selected_index >= DragonManager.player_dragons.size():
		return

	var dragon: Dictionary = DragonManager.player_dragons[selected_index]
	if _dragon_has_used_ranch_action(dragon):
		_refresh_training_controls()
		return

	is_training_animating = true
	_refresh_training_controls()

	var result: Dictionary = DragonManager.rest_dragon(selected_index, 25)
	var actor: DragonActor = _get_actor_by_uid(selected_dragon_uid)

	if bool(result.get("ok", false)):
		_mark_selected_dragon_ranch_action_used()

		if actor != null:
			actor.set_cinematic_mode(true)
			actor.play_cinematic_pulse(0.55)
			if actor.has_method("show_float_text"):
				actor.show_float_text("Rested", Color(0.70, 1.0, 0.85))
			await get_tree().create_timer(0.35).timeout
			actor.set_cinematic_mode(false)
			actor.refresh_from_data(DragonManager.player_dragons[selected_index])

	is_training_animating = false
	_update_info_card()
	_refresh_training_controls()

func _play_training_fx(actor: DragonActor, result: Dictionary) -> void:
	if actor == null or not is_instance_valid(actor):
		return
		
	_trigger_morgra("train")
	actor.set_cinematic_mode(true)
	actor.play_cinematic_pulse(0.90)

	if actor.has_method("show_float_text"):
		actor.show_float_text("Training!", Color(0.65, 0.90, 1.0))

	_shake_enclosure(3.0, 0.10)
	await get_tree().create_timer(0.30).timeout

	var stat_gains: Dictionary = result.get("stat_gains", {})
	for stat_key in stat_gains.keys():
		var amount: int = int(stat_gains.get(stat_key, 0))
		if amount > 0 and actor.has_method("show_float_text"):
			actor.show_float_text("+" + str(amount) + " " + str(stat_key).capitalize(), Color(1.0, 0.90, 0.55))
			await get_tree().create_timer(0.18).timeout

	if bool(result.get("breakthrough", false)):
		actor.play_cinematic_roar(0.92, 1.04, 1.0)
		if actor.has_method("show_float_text"):
			actor.show_float_text("Breakthrough!", Color(1.0, 0.78, 0.30))
		_shake_enclosure(6.0, 0.15)
		await get_tree().create_timer(0.35).timeout

	actor.set_cinematic_mode(false)

func _dragon_has_used_ranch_action(dragon: Dictionary) -> bool:
	return bool(dragon.get("ranch_action_used_this_level", false))


func _mark_selected_dragon_ranch_action_used() -> void:
	var selected_index: int = _get_selected_index()
	if selected_index < 0 or selected_index >= DragonManager.player_dragons.size():
		return

	DragonManager.player_dragons[selected_index]["ranch_action_used_this_level"] = true

# ==========================================
# MORGRA DIALOGUE TRIGGER
# ==========================================
func _trigger_morgra(category: String) -> void:
	var camp_menu = get_parent()
	if camp_menu.has_method("_update_herder_text"):
		camp_menu._update_herder_text(category)

# Call this inside _on_visibility_changed() or whenever a dragon is hatched/removed
func _update_favorite_display() -> void:
	if not favorite_label: return
	
	var fav_uid = CampaignManager.morgra_favorite_dragon_uid
	if fav_uid == "":
		favorite_label.text = "Morgra's Favorite: None"
		favorite_label.modulate = Color.GRAY
		return
		
	var fav_name = ""
	for d in DragonManager.player_dragons:
		if str(d.get("uid", "")) == fav_uid:
			fav_name = str(d.get("name", "Unknown"))
			break
			
	if fav_name != "":
		favorite_label.text = "Morgra's Favorite: " + fav_name
		favorite_label.modulate = Color.GOLD # Make it pop!
	else:
		favorite_label.text = "Morgra's Favorite: Missing"

# ==========================================
# DEBUG TESTING FUNCTIONS
# ==========================================

func _debug_force_anger() -> void:
	CampaignManager.morgra_anger_duration = 3
	CampaignManager.morgra_neutral_duration = 0
	_trigger_morgra("welcome") # Refresh her dialogue immediately
	print("DEBUG: Morgra is now Furious.")

func _debug_force_neutral() -> void:
	CampaignManager.morgra_anger_duration = 0
	CampaignManager.morgra_neutral_duration = 2
	_trigger_morgra("welcome")
	print("DEBUG: Morgra is now Neutral.")

func _debug_force_adore() -> void:
	CampaignManager.morgra_anger_duration = 0
	CampaignManager.morgra_neutral_duration = 0
	# Ensure she has a favorite to adore!
	if CampaignManager.morgra_favorite_dragon_uid == "" and DragonManager.player_dragons.size() > 0:
		CampaignManager.morgra_favorite_dragon_uid = str(DragonManager.player_dragons[0].get("uid", ""))
	
	CampaignManager.morgra_favorite_survived_battles = 10
	_update_favorite_display()
	_trigger_morgra("welcome")
	print("DEBUG: Morgra is now Adoring.")

func _debug_reset_morgra() -> void:
	CampaignManager.morgra_anger_duration = 0
	CampaignManager.morgra_neutral_duration = 0
	CampaignManager.morgra_favorite_survived_battles = 0
	_trigger_morgra("welcome")
	print("DEBUG: Morgra states reset.")
