# ==============================================================================
# Script Name: LysanderInteraction.gd
# Purpose: Handles Lysander's full interaction flow (dialogue -> tiered combo QTE -> rewards).
# Overall Goal: Deliver a centered, readable, replay-safe NPC minigame with stronger game feel,
#	multiple reward tiers, combo-based timing, moving/randomized hit zones, and robust input
#	handling that prevents accidental immediate reopening.
# Project Fit: Attach this directly to the Lysander TextureButton in the Grand Tavern.
# Dependencies:
#	- ConsumableData (Resource used for each reward disc).
#	- CampaignManager (Global singleton with add_item_to_inventory()).
# AI/Code Reviewer Guidance:
#	- Entry points:
#		1. _on_lysander_pressed() starts the interaction.
#		2. _input() advances dialogue, resolves each QTE press, and closes the interaction.
#		3. _process() drives the live QTE cursor motion and sweet-spot feedback.
#	- Core logic:
#		1. _build_dynamic_ui() creates all runtime-only UI under a full-screen UI root.
#		2. _layout_dynamic_ui() keeps dialogue and QTE correctly positioned on any viewport size.
#		3. _start_qte(), _resolve_qte(), _on_feedback_timer_timeout(), and _continue_qte_chain()
#		   form the combo-QTE loop.
#		4. _randomize_sweet_spot() enforces a fresh target location each beat.
#		5. Tier helpers (_get_current_tier_speed(), _get_current_tier_width(),
#		   _get_current_tier_required_hits()) scale difficulty.
#	- Admin logic:
#		1. _consume_current_input() prevents the focused TextureButton from re-triggering.
#		2. current_tier_index gates rewards so discs cannot be farmed.
#		3. _reset_qte_visuals() and _close_interaction() restore clean state between runs.
# ==============================================================================

extends TextureButton

# --- EXPORTS ---
@export_category("Lysander Settings")
@export var reward_discs: Array[ConsumableData] = []
@export var fallback_reward_name: String = "Music Disc"

@export_category("Dialogue UI")
@export var dialogue_font_size: int = 42
@export var dialogue_side_margin: float = 60.0
@export var dialogue_bottom_margin: float = 30.0
@export var dialogue_panel_height: float = 260.0

@export_category("QTE UI")
@export var qte_bar_size: Vector2 = Vector2(1200.0, 120.0)
@export var qte_vertical_offset: float = 60.0
@export var cursor_width: float = 18.0
@export var cursor_height_padding: float = 20.0

@export_category("QTE Randomization")
@export var sweet_spot_left_padding: float = 220.0
@export var sweet_spot_right_padding: float = 40.0
@export var min_sweet_spot_move_distance: float = 180.0
@export var sweet_spot_random_retry_count: int = 12

@export_category("Tier Difficulty")
@export var base_qte_speed: float = 500.0
@export var base_sweet_spot_width: float = 260.0
@export var tier_speeds: PackedFloat32Array = PackedFloat32Array([500.0, 620.0, 760.0, 900.0])
@export var tier_sweet_spot_widths: PackedFloat32Array = PackedFloat32Array([260.0, 190.0, 140.0, 100.0])
@export var tier_required_hits: PackedInt32Array = PackedInt32Array([2, 3, 4, 5])
@export var qte_speed_per_chain_hit: float = 55.0

@export_category("Feedback")
@export var qte_feedback_duration: float = 0.14
@export var qte_shake_amount: float = 12.0

# --- INTERNAL STATE ---
enum State {
	IDLE,
	DIALOGUE_INTRO,
	QTE_ACTIVE,
	QTE_RESOLVING,
	DIALOGUE_OUTRO_WIN,
	DIALOGUE_OUTRO_LOSE,
	DIALOGUE_POST_ALL_TIERS
}

var current_state: State = State.IDLE
var current_tier_index: int = 0
var current_qte_hits: int = 0
var pending_qte_success: bool = false
var pending_qte_completed_tier: bool = false
var active_qte_speed: float = 0.0

# --- DYNAMIC UI REFERENCES ---
var ui_layer: CanvasLayer = null
var ui_root: Control = null
var dialogue_panel: Panel = null
var dialogue_text: RichTextLabel = null
var qte_container: Control = null
var timing_bar: ColorRect = null
var sweet_spot: ColorRect = null
var cursor: ColorRect = null
var flash_rect: ColorRect = null
var feedback_timer: Timer = null

# --- QTE VARIABLES ---
var moving_right: bool = true
var cursor_is_in_sweet_spot: bool = false
var qte_base_position: Vector2 = Vector2.ZERO
var previous_sweet_spot_x: float = -1.0
var feedback_tween: Tween = null

# --- VISUAL TUNING ---
const CURSOR_COLOR_DEFAULT: Color = Color(0.20, 0.90, 1.00, 1.00)
const CURSOR_COLOR_HOT: Color = Color(0.45, 1.00, 0.45, 1.00)
const CURSOR_COLOR_SUCCESS: Color = Color(0.55, 1.00, 0.55, 1.00)
const CURSOR_COLOR_FAIL: Color = Color(1.00, 0.35, 0.35, 1.00)

const SWEET_SPOT_COLOR_DEFAULT: Color = Color(0.80, 0.60, 0.20, 1.00)
const SWEET_SPOT_COLOR_HOT: Color = Color(1.00, 0.90, 0.35, 1.00)
const SWEET_SPOT_COLOR_FAIL: Color = Color(0.85, 0.30, 0.25, 1.00)

const FLASH_COLOR_SUCCESS: Color = Color(0.55, 1.00, 0.55, 0.70)
const FLASH_COLOR_FAIL: Color = Color(1.00, 0.35, 0.35, 0.70)

# Purpose: Connects the button signal, builds the runtime UI, and applies initial layout.
# Inputs: None.
# Outputs: None.
# Side effects: Instantiates UI nodes, connects signals, randomizes RNG, and positions the UI correctly.
func _ready() -> void:
	randomize()
	pressed.connect(_on_lysander_pressed)
	_build_dynamic_ui()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	call_deferred("_layout_dynamic_ui")

# Purpose: Constructs the full dialogue/QTE UI entirely in code using a full-screen UI root.
# Inputs: None.
# Outputs: None.
# Side effects: Creates and configures a CanvasLayer, root Control, dialogue widgets, QTE visuals, and a timer.
func _build_dynamic_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 100
	ui_layer.hide()
	add_child(ui_layer)

	ui_root = Control.new()
	ui_root.anchor_left = 0.0
	ui_root.anchor_top = 0.0
	ui_root.anchor_right = 0.0
	ui_root.anchor_bottom = 0.0
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui_root)

	dialogue_panel = Panel.new()
	dialogue_panel.anchor_left = 0.0
	dialogue_panel.anchor_top = 0.0
	dialogue_panel.anchor_right = 0.0
	dialogue_panel.anchor_bottom = 0.0
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.10, 0.10, 0.92)
	panel_style.set_border_width_all(4)
	panel_style.border_color = Color(0.80, 0.60, 0.20, 1.00)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	dialogue_panel.add_theme_stylebox_override("panel", panel_style)
	ui_root.add_child(dialogue_panel)

	dialogue_text = RichTextLabel.new()
	dialogue_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialogue_text.offset_left = 28.0
	dialogue_text.offset_top = 24.0
	dialogue_text.offset_right = -28.0
	dialogue_text.offset_bottom = -24.0
	dialogue_text.bbcode_enabled = true
	dialogue_text.scroll_active = false
	dialogue_text.fit_content = false
	dialogue_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_text.add_theme_font_size_override("normal_font_size", dialogue_font_size)
	dialogue_text.add_theme_constant_override("line_separation", 8)
	dialogue_panel.add_child(dialogue_text)

	qte_container = Control.new()
	qte_container.anchor_left = 0.0
	qte_container.anchor_top = 0.0
	qte_container.anchor_right = 0.0
	qte_container.anchor_bottom = 0.0
	qte_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qte_container.hide()
	ui_root.add_child(qte_container)

	timing_bar = ColorRect.new()
	timing_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	timing_bar.color = Color(0.16, 0.16, 0.18, 1.0)
	qte_container.add_child(timing_bar)

	sweet_spot = ColorRect.new()
	sweet_spot.position = Vector2.ZERO
	sweet_spot.size = Vector2(base_sweet_spot_width, qte_bar_size.y)
	sweet_spot.custom_minimum_size = sweet_spot.size
	sweet_spot.color = SWEET_SPOT_COLOR_DEFAULT
	qte_container.add_child(sweet_spot)

	cursor = ColorRect.new()
	cursor.position = Vector2(0.0, -cursor_height_padding * 0.5)
	cursor.size = Vector2(cursor_width, qte_bar_size.y + cursor_height_padding)
	cursor.custom_minimum_size = cursor.size
	cursor.color = CURSOR_COLOR_DEFAULT
	qte_container.add_child(cursor)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = FLASH_COLOR_SUCCESS
	flash_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	flash_rect.hide()
	qte_container.add_child(flash_rect)

	feedback_timer = Timer.new()
	feedback_timer.one_shot = true
	feedback_timer.wait_time = qte_feedback_duration
	feedback_timer.timeout.connect(_on_feedback_timer_timeout)
	add_child(feedback_timer)

# Purpose: Recalculates all runtime UI layout from the current viewport size.
# Inputs: None.
# Outputs: None.
# Side effects: Resizes the root UI and repositions the dialogue panel and QTE container.
func _layout_dynamic_ui() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	ui_root.position = Vector2.ZERO
	ui_root.size = viewport_size

	dialogue_panel.position = Vector2(
		dialogue_side_margin,
		viewport_size.y - dialogue_panel_height - dialogue_bottom_margin
	)
	dialogue_panel.size = Vector2(
		viewport_size.x - (dialogue_side_margin * 2.0),
		dialogue_panel_height
	)
	dialogue_panel.custom_minimum_size = dialogue_panel.size

	qte_base_position = Vector2(
		(viewport_size.x - qte_bar_size.x) * 0.5,
		((viewport_size.y - qte_bar_size.y) * 0.5) + qte_vertical_offset
	)

	qte_container.position = qte_base_position
	qte_container.size = qte_bar_size
	qte_container.custom_minimum_size = qte_bar_size

	timing_bar.size = qte_bar_size

	cursor.size = Vector2(cursor_width, qte_bar_size.y + cursor_height_padding)
	cursor.custom_minimum_size = cursor.size

	if current_state != State.QTE_ACTIVE and current_state != State.QTE_RESOLVING:
		qte_container.position = qte_base_position

# Purpose: Refreshes the layout when the viewport size changes.
# Inputs: None.
# Outputs: None.
# Side effects: Reflows the dynamic UI to stay centered and readable after resize.
func _on_viewport_size_changed() -> void:
	_layout_dynamic_ui()

# Purpose: Starts Lysander's interaction flow when the player presses the NPC button.
# Inputs: None.
# Outputs: None.
# Side effects: Clears focus/input state, shows the UI, and routes to tier intro or post-completion dialogue.
func _on_lysander_pressed() -> void:
	if current_state != State.IDLE:
		return

	_consume_current_input()
	_layout_dynamic_ui()
	ui_layer.show()
	qte_container.hide()

	if _has_remaining_tiers():
		_show_intro_dialogue()
	else:
		_show_post_all_tiers_dialogue()

# Purpose: Handles accept-button input for dialogue advancement, QTE resolution, and closing.
# Inputs: event (InputEvent) - The raw input event delivered by the engine.
# Outputs: None.
# Side effects: Progresses the interaction state machine and consumes handled accept input.
func _input(event: InputEvent) -> void:
	if current_state == State.IDLE:
		return

	if event is InputEventKey and event.is_echo():
		return

	if not event.is_action_pressed("ui_accept"):
		return

	_consume_current_input()

	match current_state:
		State.DIALOGUE_INTRO:
			_start_qte()
		State.QTE_ACTIVE:
			_resolve_qte()
		State.DIALOGUE_OUTRO_WIN, State.DIALOGUE_OUTRO_LOSE, State.DIALOGUE_POST_ALL_TIERS:
			_close_interaction()
		State.QTE_RESOLVING:
			pass
		_:
			pass

# Purpose: Drives the live cursor motion while the QTE is active and updates "inside zone" visuals.
# Inputs: delta (float) - Frame time step in seconds.
# Outputs: None.
# Side effects: Moves the cursor, flips direction at bar edges, and updates cursor/sweet-spot colors.
func _process(delta: float) -> void:
	if current_state != State.QTE_ACTIVE:
		return

	var max_cursor_x: float = qte_bar_size.x - cursor.size.x

	if moving_right:
		cursor.position.x += active_qte_speed * delta
		if cursor.position.x >= max_cursor_x:
			cursor.position.x = max_cursor_x
			moving_right = false
	else:
		cursor.position.x -= active_qte_speed * delta
		if cursor.position.x <= 0.0:
			cursor.position.x = 0.0
			moving_right = true

	_apply_cursor_zone_feedback()

# Purpose: Shows the current tier's challenge dialogue before the combo QTE begins.
# Inputs: None.
# Outputs: None.
# Side effects: Sets state and updates the dialogue panel text.
func _show_intro_dialogue() -> void:
	current_state = State.DIALOGUE_INTRO

	var tier_number: int = current_tier_index + 1
	var tier_total: int = _get_total_tiers()
	var intro_line: String = "Ah, a traveler. Music is the purest expression of focus. Can you match my tempo?"

	if current_tier_index > 0:
		intro_line = "Back again? Good. The next phrase bites harder than the last. Keep your nerve and follow the pulse."

	dialogue_text.text = "[font_size=%d][color=cyan]Lysander:[/color] %s[/font_size]\n\n[font_size=%d][color=gold]Disc Trial %d / %d[/color][/font_size]\n\n[font_size=%d][color=gray][i](Press SPACE to continue)[/i][/color][/font_size]" % [
		dialogue_font_size,
		intro_line,
		dialogue_font_size - 2,
		tier_number,
		tier_total,
		dialogue_font_size - 10
	]

# Purpose: Shows the final repeat dialogue after all reward tiers have been completed.
# Inputs: None.
# Outputs: None.
# Side effects: Sets state and updates the dialogue panel text without starting the QTE.
func _show_post_all_tiers_dialogue() -> void:
	current_state = State.DIALOGUE_POST_ALL_TIERS
	dialogue_text.text = "[font_size=%d][color=cyan]Lysander:[/color] Hear that? The room still remembers every rhythm we forged together. You've taken the full set now—what remains is not reward, but style.[/font_size]\n\n[font_size=%d][color=gray][i](Press SPACE to close)[/i][/color][/font_size]" % [
		dialogue_font_size,
		dialogue_font_size - 10
	]

# Purpose: Transitions from intro dialogue into the active combo QTE for the current reward tier.
# Inputs: None.
# Outputs: None.
# Side effects: Resets combo progress and starts the first press in the tier sequence.
func _start_qte() -> void:
	current_state = State.QTE_ACTIVE
	current_qte_hits = 0
	pending_qte_success = false
	pending_qte_completed_tier = false
	previous_sweet_spot_x = -1.0
	_prepare_next_qte_press()

# Purpose: Updates the active QTE prompt so the player can read current combo progress.
# Inputs: None.
# Outputs: None.
# Side effects: Rewrites the dialogue panel text while the QTE is active.
func _update_qte_prompt() -> void:
	var required_hits: int = _get_current_tier_required_hits()
	var next_hit_number: int = current_qte_hits + 1
	var tier_number: int = current_tier_index + 1
	var tier_total: int = _get_total_tiers()

	dialogue_text.text = "[font_size=%d][color=cyan]Lysander:[/color] Focus...[/font_size]\n\n[font_size=%d][color=gold]Disc Trial %d / %d  |  Beat %d / %d[/color][/font_size]\n\n[font_size=%d][color=gray][i](Press SPACE when the blue line is inside the Gold zone!)[/i][/color][/font_size]" % [
		dialogue_font_size,
		dialogue_font_size - 2,
		tier_number,
		tier_total,
		next_hit_number,
		required_hits,
		dialogue_font_size - 10
	]

# Purpose: Prepares the next press in the combo chain for the active tier.
# Inputs: None.
# Outputs: None.
# Side effects: Resets visuals, reapplies current difficulty, randomizes the sweet spot, and restarts cursor motion.
func _prepare_next_qte_press() -> void:
	_reset_qte_visuals()
	_apply_current_tier_sweet_spot()
	_randomize_sweet_spot()

	active_qte_speed = _get_current_tier_speed() + (float(current_qte_hits) * qte_speed_per_chain_hit)

	var start_from_left: bool = randf() < 0.5
	if start_from_left:
		cursor.position = Vector2(0.0, -cursor_height_padding * 0.5)
		moving_right = true
	else:
		cursor.position = Vector2(qte_bar_size.x - cursor.size.x, -cursor_height_padding * 0.5)
		moving_right = false

	qte_container.position = qte_base_position
	qte_container.show()

	_update_qte_prompt()

# Purpose: Finalizes the player's current timing input and determines whether the combo continues, wins, or fails.
# Inputs: None.
# Outputs: None.
# Side effects: Locks progression, stores current hit result, plays feedback, and starts the resolution timer.
func _resolve_qte() -> void:
	current_state = State.QTE_RESOLVING
	pending_qte_success = _is_cursor_in_sweet_spot()
	pending_qte_completed_tier = false

	if pending_qte_success:
		var required_hits: int = _get_current_tier_required_hits()
		var projected_hits: int = current_qte_hits + 1
		pending_qte_completed_tier = projected_hits >= required_hits

	_play_qte_hit_feedback(pending_qte_success)

	feedback_timer.stop()
	feedback_timer.wait_time = qte_feedback_duration
	feedback_timer.start()

# Purpose: Applies a flash/shake burst so the player's button press feels immediate and readable.
# Inputs: was_successful (bool) - Whether the cursor landed inside the sweet spot.
# Outputs: None.
# Side effects: Changes colors, animates the QTE bar position, and fades in/out a flash overlay.
func _play_qte_hit_feedback(was_successful: bool) -> void:
	if feedback_tween != null and feedback_tween.is_valid():
		feedback_tween.kill()

	if was_successful:
		cursor.color = CURSOR_COLOR_SUCCESS
		sweet_spot.color = SWEET_SPOT_COLOR_HOT
		flash_rect.color = FLASH_COLOR_SUCCESS
	else:
		cursor.color = CURSOR_COLOR_FAIL
		sweet_spot.color = SWEET_SPOT_COLOR_FAIL
		flash_rect.color = FLASH_COLOR_FAIL

	flash_rect.modulate = Color(1.0, 1.0, 1.0, 0.85)
	flash_rect.show()

	feedback_tween = create_tween()
	feedback_tween.set_trans(Tween.TRANS_SINE)
	feedback_tween.set_ease(Tween.EASE_OUT)

	for _i in range(4):
		var shake_offset: Vector2 = Vector2(
			randf_range(-qte_shake_amount, qte_shake_amount),
			randf_range(-qte_shake_amount * 0.30, qte_shake_amount * 0.30)
		)
		feedback_tween.tween_property(qte_container, "position", qte_base_position + shake_offset, 0.02)

	feedback_tween.tween_property(qte_container, "position", qte_base_position, 0.03)
	feedback_tween.parallel().tween_property(flash_rect, "modulate", Color(1.0, 1.0, 1.0, 0.0), qte_feedback_duration)

# Purpose: Converts the stored press result into either combo continuation, tier completion, or failure dialogue.
# Inputs: None.
# Outputs: None.
# Side effects: Advances combo count, continues the chain, or ends the interaction branch.
func _on_feedback_timer_timeout() -> void:
	if pending_qte_success:
		current_qte_hits += 1

		if pending_qte_completed_tier:
			qte_container.hide()
			_show_win_dialogue()
		else:
			_continue_qte_chain()
	else:
		qte_container.hide()
		_show_lose_dialogue()

# Purpose: Continues the QTE after a successful intermediate hit that did not yet clear the tier.
# Inputs: None.
# Outputs: None.
# Side effects: Returns the interaction to QTE_ACTIVE and starts the next combo step.
func _continue_qte_chain() -> void:
	current_state = State.QTE_ACTIVE
	_prepare_next_qte_press()

# Purpose: Shows the success dialogue, grants exactly one disc for the current tier, and advances progression.
# Inputs: None.
# Outputs: None.
# Side effects: Adds one reward to inventory, increments current_tier_index, and updates dialogue text.
func _show_win_dialogue() -> void:
	current_state = State.DIALOGUE_OUTRO_WIN

	var awarded_name: String = fallback_reward_name
	var tier_to_award: int = current_tier_index
	var required_hits: int = _get_current_tier_required_hits()

	if tier_to_award < reward_discs.size():
		var reward_disc_for_tier: ConsumableData = reward_discs[tier_to_award]
		if reward_disc_for_tier != null:
			awarded_name = reward_disc_for_tier.item_name
			if CampaignManager.has_method("add_item_to_inventory"):
				CampaignManager.add_item_to_inventory(reward_disc_for_tier)

	current_tier_index += 1

	if _has_remaining_tiers():
		dialogue_text.text = "[font_size=%d][color=cyan]Lysander:[/color] Cleanly struck. You held the phrase for %d beats and earned another composition.[/font_size]\n\n[font_size=%d][color=gold][i]Obtained: %s![/i][/color][/font_size]\n\n[font_size=%d][color=gray][i](Press SPACE to close)[/i][/color][/font_size]" % [
			dialogue_font_size,
			required_hits,
			dialogue_font_size - 2,
			awarded_name,
			dialogue_font_size - 10
		]
	else:
		dialogue_text.text = "[font_size=%d][color=cyan]Lysander:[/color] Flawless. You carried the final phrase to its end, and the last disc is yours.[/font_size]\n\n[font_size=%d][color=gold][i]Obtained: %s![/i][/color][/font_size]\n\n[font_size=%d][color=gray][i](Press SPACE to close)[/i][/color][/font_size]" % [
			dialogue_font_size,
			dialogue_font_size - 2,
			awarded_name,
			dialogue_font_size - 10
		]

# Purpose: Shows the failure dialogue so the player can retry the same tier after missing during the combo.
# Inputs: None.
# Outputs: None.
# Side effects: Sets the loss state and updates dialogue text with combo progress.
func _show_lose_dialogue() -> void:
	current_state = State.DIALOGUE_OUTRO_LOSE

	var tier_number: int = current_tier_index + 1
	var tier_total: int = _get_total_tiers()
	var required_hits: int = _get_current_tier_required_hits()

	dialogue_text.text = "[font_size=%d][color=cyan]Lysander:[/color] You broke the phrase. You held %d of %d beats, but the next disc stays with me until the rhythm is unbroken.[/font_size]\n\n[font_size=%d][color=gold]Current Trial: %d / %d[/color][/font_size]\n\n[font_size=%d][color=gray][i](Press SPACE to close)[/i][/color][/font_size]" % [
		dialogue_font_size,
		current_qte_hits,
		required_hits,
		dialogue_font_size - 2,
		tier_number,
		tier_total,
		dialogue_font_size - 10
	]

# Purpose: Applies the sweet-spot width for the active tier before random placement.
# Inputs: None.
# Outputs: None.
# Side effects: Resizes the sweet spot to match the current difficulty tier.
func _apply_current_tier_sweet_spot() -> void:
	var active_width: float = _get_current_tier_width()
	sweet_spot.size = Vector2(active_width, qte_bar_size.y)
	sweet_spot.custom_minimum_size = sweet_spot.size

# Purpose: Randomizes the sweet spot location so each QTE press is a fresh timing challenge.
# Inputs: None.
# Outputs: None.
# Side effects: Moves the sweet spot horizontally within the timing bar while avoiding the
#	start edge and positions too close to the previous sweet spot.
func _randomize_sweet_spot() -> void:
	var min_x: float = sweet_spot_left_padding
	var max_x: float = qte_bar_size.x - sweet_spot.size.x - sweet_spot_right_padding

	if max_x < min_x:
		min_x = 0.0
		max_x = maxf(0.0, qte_bar_size.x - sweet_spot.size.x)

	var chosen_x: float = min_x

	if previous_sweet_spot_x < 0.0:
		chosen_x = randf_range(min_x, max_x)
	else:
		var found_far_enough: bool = false

		for _attempt in range(sweet_spot_random_retry_count):
			var candidate_x: float = randf_range(min_x, max_x)
			if absf(candidate_x - previous_sweet_spot_x) >= min_sweet_spot_move_distance:
				chosen_x = candidate_x
				found_far_enough = true
				break

		if not found_far_enough:
			if previous_sweet_spot_x < ((min_x + max_x) * 0.5):
				chosen_x = max_x
			else:
				chosen_x = min_x

	sweet_spot.position.x = chosen_x
	sweet_spot.position.y = 0.0
	previous_sweet_spot_x = chosen_x

# Purpose: Updates the cursor/sweet-spot colors when the cursor enters or exits the scoring zone.
# Inputs: None.
# Outputs: None.
# Side effects: Changes UI colors to provide immediate "you're on target" feedback.
func _apply_cursor_zone_feedback() -> void:
	var is_inside_now: bool = _is_cursor_in_sweet_spot()

	if is_inside_now == cursor_is_in_sweet_spot:
		return

	cursor_is_in_sweet_spot = is_inside_now

	if is_inside_now:
		cursor.color = CURSOR_COLOR_HOT
		sweet_spot.color = SWEET_SPOT_COLOR_HOT
	else:
		cursor.color = CURSOR_COLOR_DEFAULT
		sweet_spot.color = SWEET_SPOT_COLOR_DEFAULT

# Purpose: Evaluates whether the cursor center currently overlaps the sweet spot bounds.
# Inputs: None.
# Outputs: bool - True if the cursor center is inside the sweet spot, otherwise false.
# Side effects: None.
func _is_cursor_in_sweet_spot() -> bool:
	var cursor_center: float = cursor.position.x + (cursor.size.x * 0.5)
	var spot_start: float = sweet_spot.position.x
	var spot_end: float = sweet_spot.position.x + sweet_spot.size.x
	return cursor_center >= spot_start and cursor_center <= spot_end

# Purpose: Returns whether there are still unearned reward tiers remaining.
# Inputs: None.
# Outputs: bool - True if another tier reward is available, otherwise false.
# Side effects: None.
func _has_remaining_tiers() -> bool:
	return current_tier_index < _get_total_tiers()

# Purpose: Returns how many reward tiers exist based on the configured disc array.
# Inputs: None.
# Outputs: int - The total number of reward tiers.
# Side effects: None.
func _get_total_tiers() -> int:
	return reward_discs.size()

# Purpose: Returns the active cursor speed for the current tier.
# Inputs: None.
# Outputs: float - The current tier's QTE cursor speed.
# Side effects: None.
func _get_current_tier_speed() -> float:
	if tier_speeds.size() == 0:
		return base_qte_speed

	if current_tier_index < tier_speeds.size():
		return tier_speeds[current_tier_index]

	return tier_speeds[tier_speeds.size() - 1]

# Purpose: Returns the active sweet-spot width for the current tier.
# Inputs: None.
# Outputs: float - The current tier's sweet-spot width.
# Side effects: None.
func _get_current_tier_width() -> float:
	if tier_sweet_spot_widths.size() == 0:
		return base_sweet_spot_width

	if current_tier_index < tier_sweet_spot_widths.size():
		return tier_sweet_spot_widths[current_tier_index]

	return tier_sweet_spot_widths[tier_sweet_spot_widths.size() - 1]

# Purpose: Returns how many successful presses are required to clear the current tier.
# Inputs: None.
# Outputs: int - The required successful hit count for the active tier.
# Side effects: None.
func _get_current_tier_required_hits() -> int:
	if tier_required_hits.size() == 0:
		return 1

	var required_hits: int

	if current_tier_index < tier_required_hits.size():
		required_hits = tier_required_hits[current_tier_index]
	else:
		required_hits = tier_required_hits[tier_required_hits.size() - 1]

	if required_hits < 1:
		required_hits = 1

	return required_hits

# Purpose: Restores the QTE visuals to a clean neutral state before starting a new press.
# Inputs: None.
# Outputs: None.
# Side effects: Resets bar position, colors, overlays, and transient resolution flags.
func _reset_qte_visuals() -> void:
	if feedback_tween != null and feedback_tween.is_valid():
		feedback_tween.kill()

	feedback_timer.stop()
	qte_container.position = qte_base_position
	cursor_is_in_sweet_spot = false
	pending_qte_success = false
	pending_qte_completed_tier = false

	sweet_spot.color = SWEET_SPOT_COLOR_DEFAULT
	cursor.color = CURSOR_COLOR_DEFAULT

	flash_rect.hide()
	flash_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)

# Purpose: Consumes the current interaction input so it cannot propagate back into the button.
# Inputs: None.
# Outputs: None.
# Side effects: Removes keyboard focus from this TextureButton and marks the current input handled.
func _consume_current_input() -> void:
	release_focus()
	get_viewport().set_input_as_handled()

# Purpose: Closes the interaction UI and restores Lysander to a stable idle-ready state.
# Inputs: None.
# Outputs: None.
# Side effects: Hides UI, resets transient QTE visuals and combo progress, and returns the state machine to IDLE.
func _close_interaction() -> void:
	_consume_current_input()
	_reset_qte_visuals()

	current_qte_hits = 0
	active_qte_speed = 0.0
	previous_sweet_spot_x = -1.0

	ui_layer.hide()
	qte_container.hide()
	current_state = State.IDLE
