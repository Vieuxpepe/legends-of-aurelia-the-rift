# ==============================================================================
# Script Name: Unit.gd
# Purpose:
#   Tactical RPG unit entity: stats, movement, combat, leveling, poise, and
#   persistence. Used by BattleField for both player and enemy units.
#
# Project Role:
#   Core gameplay node for map units. Handles HP/EXP bars, defend state,
#   promotion aura, dash effects, and integration with CampaignManager (avatar,
#   difficulty scaling, save/load).
#
# Dependencies:
#   - UnitData, ClassData, WeaponData resources
#   - CampaignManager autoload (custom_avatar, difficulty, unit_move_speed)
#
# AI / Reviewer Notes:
#   - Main init: _ready() (data-driven stats, avatar override, difficulty boost)
#   - Turn lifecycle: reset_turn(), finish_turn(), trigger_defend()
#   - Combat: take_damage(), die(), get_max_poise(), update_poise_visuals()
#   - Persistence: setup_from_save_data(), get_exp_required()
# ==============================================================================

extends Node2D
class_name Unit

# ------------------------------------------------------------------------------
# Constants (match BattleField cell size when converting grid <-> world)
# ------------------------------------------------------------------------------
const DEFAULT_CELL_SIZE: int = 64
const HEALTH_BAR_TWEEN_DURATION: float = 0.2
const DAMAGE_FLASH_DURATION: float = 0.1
const EXP_BAR_TWEEN_DURATION: float = 0.2
const POISE_BAR_TWEEN_DURATION: float = 0.2

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal moved(target_grid_pos: Vector2i)
signal finished_turn(unit: Node2D)
signal damaged(current_hp: int)
signal died(unit: Node2D, killer: Node2D)
signal leveled_up(unit: Node2D, gains: Dictionary)

# ------------------------------------------------------------------------------
# AI Configuration
# ------------------------------------------------------------------------------
# 1 = Dumb (Attacks nearest) | 2 = Bloodthirsty | 3 = Tactical
@export var ai_intelligence: int = 1
enum AIBehavior { DEFAULT, THIEF, SUPPORT, COWARD, AGGRESSIVE, MINION }
@export var ai_behavior: AIBehavior = AIBehavior.DEFAULT

# ------------------------------------------------------------------------------
# Visual / Promotion
# ------------------------------------------------------------------------------
@export var lightning_bolt_texture: Texture2D
@export var is_promoted: bool = false
var promo_aura: Sprite2D = null

var active_class_data: ClassData = null
@onready var death_sound_player: AudioStreamPlayer = $DeathSound
@onready var sprite: Sprite2D = $Sprite

var selection_tween: Tween
var stagger_tween: Tween
var _poise_bar_tween: Tween

# ------------------------------------------------------------------------------
# Identity & Data
# ------------------------------------------------------------------------------
@export var data: UnitData
@export var is_custom_avatar: bool = false
var is_arena_ghost: bool = false

var unit_name: String = ""
var unit_class_name: String = ""
var unit_tags: Array = []  # Relationship Web: e.g. undead, cultist, holy, beast

# ------------------------------------------------------------------------------
# Stats & Growth
# ------------------------------------------------------------------------------
var level: int = 1
var experience: int = 0
var move_type: int = 0
var max_hp: int
var current_hp: int
var strength: int
var defense: int
var speed: int
var agility: int
var magic: int
var resistance: int
var equipped_weapon: WeaponData
var inventory: Array[Resource] = []
var inventory_mapping: Array[Dictionary] = []
var move_range: int
var ability: String = ""
var unlocked_abilities: Array = []
var skill_points: int = 0
var unlocked_skills: Array = []

# ------------------------------------------------------------------------------
# Turn State
# ------------------------------------------------------------------------------
var has_moved: bool = false
## Move cost (terrain-weighted) spent on the main move before combat this turn; used for Canto (cav/flier).
var move_points_used_this_turn: float = 0.0
## After an action, flying/cavalry may pivot with this remaining budget (move only, no second attack).
var in_canto_phase: bool = false
var canto_move_budget: float = 0.0
var is_exhausted: bool = false
var base_color: Color = Color.WHITE
var is_defending: bool = false
var defense_bonus: int = 3  # Flat bonus to DEF/RES when defending

# ------------------------------------------------------------------------------
# Thief / Loot
# ------------------------------------------------------------------------------
var stolen_gold: int = 0
var stolen_loot: Array[Resource] = []

# ------------------------------------------------------------------------------
# Trade UI State
# ------------------------------------------------------------------------------
var trade_unit_a: Node2D = null
var trade_unit_b: Node2D = null
var trade_selected_side: String = ""
var trade_selected_index: int = -1

# ------------------------------------------------------------------------------
# UI References (nullable for scene variants)
# ------------------------------------------------------------------------------
@onready var health_bar: ProgressBar = $HealthBar
@onready var exp_bar: ProgressBar = $ExpBar
@onready var team_glow: ColorRect = $TeamGlow
@onready var defend_icon: Node = get_node_or_null("DefendIcon")

func _ready() -> void:
	if data == null:
		push_warning("Unit has no UnitData assigned; stats and visuals will not initialize.")
		return
	if data.unit_sprite != null and sprite != null:
		sprite.texture = data.unit_sprite
		var texture_size: Vector2 = sprite.texture.get_size()
		var target_size := Vector2(DEFAULT_CELL_SIZE, DEFAULT_CELL_SIZE)
		var base_factor: float = minf(target_size.x / texture_size.x, target_size.y / texture_size.y)
		var final_scale: float = base_factor * data.visual_scale
		sprite.scale = Vector2(final_scale, final_scale)

	# 1. INITIALIZE CLASS DATA
	active_class_data = data.character_class

	# --- CUSTOM AVATAR LOGIC ---
	if is_custom_avatar and not is_arena_ghost and CampaignManager.custom_avatar.has("stats"):
		var avatar = CampaignManager.custom_avatar
		unit_name = avatar["name"]
		unit_class_name = avatar["class_name"]
		if avatar.has("class_data") and avatar["class_data"] != null:
			active_class_data = avatar["class_data"]
		if avatar.has("portrait") and data:
			var p = avatar["portrait"]
			if p is String and ResourceLoader.exists(p): data.portrait = load(p)
			elif p is Texture2D: data.portrait = p
		ability = avatar.get("ability", "")
		var c_stats = avatar["stats"]
		max_hp = c_stats["hp"]
		strength = c_stats["str"]
		magic = c_stats["mag"]
		defense = c_stats["def"]
		resistance = c_stats["res"]
		speed = c_stats["spd"]
		agility = c_stats["agi"]
		if avatar.has("move_range"):
			move_range = avatar["move_range"]
		elif active_class_data:
			move_range = active_class_data.move_range
		else:
			move_range = 4
	# --- STANDARD UNIT LOGIC ---
	else:
		unit_name = data.display_name
		unit_class_name = active_class_data.job_name if active_class_data else "Unknown"
		if active_class_data:
			move_type = active_class_data.move_type
			max_hp = data.max_hp + active_class_data.hp_bonus
			strength = data.strength + active_class_data.str_bonus
			magic = data.magic + active_class_data.mag_bonus
			defense = data.defense + active_class_data.def_bonus
			resistance = data.resistance + active_class_data.res_bonus
			speed = data.speed + active_class_data.spd_bonus
			agility = data.agility + active_class_data.agi_bonus
			move_range = active_class_data.move_range
		else:
			max_hp = data.max_hp
			strength = data.strength
			magic = data.magic
			defense = data.defense
			resistance = data.resistance
			speed = data.speed
			agility = data.agility
			move_range = 4
		if get_parent() != null and get_parent().name == "EnemyUnits":
			var multiplier: float = 1.0
			match CampaignManager.current_difficulty:
				CampaignManager.Difficulty.HARD:
					multiplier = 1.25
				CampaignManager.Difficulty.MADDENING:
					multiplier = 1.5
					ai_intelligence += 1
			if multiplier > 1.0:
				max_hp = int(max_hp * multiplier)
				strength = int(strength * multiplier)
				magic = int(magic * multiplier)
				defense = int(defense * multiplier)
				resistance = int(resistance * multiplier)
				speed = int(speed * multiplier)
				agility = int(agility * multiplier)
		ability = data.ability

	# Equip starting weapon and set bars
	if data.starting_weapon != null and CampaignManager.has_method("duplicate_item"):
		equipped_weapon = CampaignManager.duplicate_item(data.starting_weapon)
	else:
		equipped_weapon = null
	current_hp = max_hp
	if health_bar != null:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
	if exp_bar != null:
		exp_bar.max_value = get_exp_required()
		exp_bar.value = experience
	if sprite != null:
		sprite.centered = true
		sprite.position = Vector2(DEFAULT_CELL_SIZE / 2, DEFAULT_CELL_SIZE / 2)
	if equipped_weapon != null and inventory.is_empty():
		inventory.append(equipped_weapon)

	if team_glow != null and get_parent() != null:
		var parent_name: String = get_parent().name
		if parent_name == "PlayerUnits":
			team_glow.color = Color(0.2, 0.5, 1.0, 0.3)
		elif parent_name == "EnemyUnits":
			team_glow.color = Color(1.0, 0.2, 0.2, 0.3)
		else:
			team_glow.color = Color(1.0, 1.0, 1.0, 0.0)

func gain_exp(amount: int) -> void:
	experience += amount
	var required_exp = get_exp_required()
	
	if experience >= required_exp:
		# Loop in case they gained enough EXP to level up multiple times!
		while experience >= required_exp:
			# 1. Animate filling the bar to the max
			var fill_tween = create_tween()
			fill_tween.tween_property(exp_bar, "value", required_exp, EXP_BAR_TWEEN_DURATION)
			await fill_tween.finished
			
			# 2. Level up and deduct the cost
			experience -= required_exp
			level_up()
			
			# 3. Recalculate the NEW, higher requirement for the next level
			required_exp = get_exp_required()
			
			# 4. Reset the bar visually for the next loop
			exp_bar.max_value = required_exp
			exp_bar.value = 0
			
		# Animate whatever leftover EXP remains
		var remainder_tween = create_tween()
		remainder_tween.tween_property(exp_bar, "value", experience, EXP_BAR_TWEEN_DURATION)
	else:
		var tween: Tween = create_tween()
		tween.tween_property(exp_bar, "value", experience, EXP_BAR_TWEEN_DURATION)
		
func level_up() -> void:
	level += 1
	skill_points += 1
	
	# IMPORTANT: Use active_class_data so custom classes work correctly
	var cls = active_class_data
	
	# 1. Calculate Total Growth Rates (Unit + Class)
	var h_gr = data.hp_growth + (cls.hp_growth_bonus if cls else 0)
	var s_gr = data.str_growth + (cls.str_growth_bonus if cls else 0)
	var d_gr = data.def_growth + (cls.def_growth_bonus if cls else 0)
	var sp_gr = data.spd_growth + (cls.spd_growth_bonus if cls else 0)
	var a_gr = data.agi_growth + (cls.agi_growth_bonus if cls else 0)
	var m_gr = data.mag_growth + (cls.mag_growth_bonus if cls else 0)
	var r_gr = data.res_growth + (cls.res_growth_bonus if cls else 0)
	
	var gains = {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}
	var total_gains = 0
	
	# 2. Roll for Stats with "Epic Proc" Logic
	# Logic: If we pass the main check, we roll AGAIN against (Growth / 5).
	# If we pass that too, we get +2. Otherwise +1.
	
	if randi() % 100 < h_gr: 
		gains["hp"] = 2 if (randi() % 100 < (h_gr / 5)) else 1
		total_gains += gains["hp"]
		
	if randi() % 100 < s_gr: 
		gains["str"] = 2 if (randi() % 100 < (s_gr / 5)) else 1
		total_gains += gains["str"]
		
	if randi() % 100 < d_gr: 
		gains["def"] = 2 if (randi() % 100 < (d_gr / 5)) else 1
		total_gains += gains["def"]
		
	if randi() % 100 < sp_gr: 
		gains["spd"] = 2 if (randi() % 100 < (sp_gr / 5)) else 1
		total_gains += gains["spd"]
		
	if randi() % 100 < a_gr: 
		gains["agi"] = 2 if (randi() % 100 < (a_gr / 5)) else 1
		total_gains += gains["agi"]
		
	if randi() % 100 < m_gr: 
		gains["mag"] = 2 if (randi() % 100 < (m_gr / 5)) else 1
		total_gains += gains["mag"]
		
	if randi() % 100 < r_gr: 
		gains["res"] = 2 if (randi() % 100 < (r_gr / 5)) else 1
		total_gains += gains["res"]

	# 3. The Pity System (Guarantees at least one +1 if you were super unlucky)
	if total_gains == 0:
		var fallback_stats = ["hp", "str", "mag", "def", "res", "spd", "agi"]
		var lucky_stat = fallback_stats[randi() % fallback_stats.size()]
		gains[lucky_stat] = 1
		
	# BattleField.gd will automatically read the +2 and display it correctly!
	emit_signal("leveled_up", self, gains)

func move_along_path(path: Array[Vector2i]) -> void:
	# We check <= 1 so the wind doesn't spawn if they just click themselves to wait
	if path.size() <= 1:
		return
		
	# --- NEW: SPAWN THE DASH EFFECT ---
	# The Unit is inside the 'PlayerUnits' folder, so get_parent().get_parent() finds the Battlefield!
	var battlefield: Node = get_parent().get_parent() if get_parent() != null else null
	if battlefield != null and battlefield.has_method("spawn_dash_effect"):
		var cs: int = DEFAULT_CELL_SIZE
		var start_pixel := Vector2(path[0].x * cs, path[0].y * cs)
		var end_pixel := Vector2(path[-1].x * cs, path[-1].y * cs)
		battlefield.spawn_dash_effect(start_pixel, end_pixel)
	# ----------------------------------
		
	has_moved = true

	# One step at a time so hazards (e.g. fire tiles) resolve on real entry, not path preview.
	for i in range(1, path.size()):
		if not is_instance_valid(self):
			return
		var grid_pos: Vector2i = path[i]
		look_at_pos(grid_pos)
		var world_target := Vector2(grid_pos.x * DEFAULT_CELL_SIZE, grid_pos.y * DEFAULT_CELL_SIZE)
		var step_tween: Tween = create_tween()
		step_tween.tween_property(self, "position", world_target, CampaignManager.unit_move_speed)
		await step_tween.finished
		if not is_instance_valid(self):
			return
		if battlefield != null and battlefield.has_method("on_unit_committed_move_enter_cell"):
			await battlefield.on_unit_committed_move_enter_cell(self, grid_pos)
		if not is_instance_valid(self):
			return

	emit_signal("moved", path[path.size() - 1])
	
## Emits [signal died], hides visuals, optionally waits for death sound, then [method Node.queue_free].
func die(killer: Node2D = null) -> void:
	if data != null and data.death_sound != null and death_sound_player != null:
		death_sound_player.stream = data.death_sound
		death_sound_player.pitch_scale = randf_range(0.9, 1.1)
		death_sound_player.play()
	emit_signal("died", self, killer)
	if sprite != null:
		sprite.visible = false
	if health_bar != null:
		health_bar.visible = false
	if exp_bar != null:
		exp_bar.visible = false
	if team_glow != null:
		team_glow.visible = false
	if defend_icon != null:
		defend_icon.visible = false
	if death_sound_player != null and death_sound_player.stream != null:
		await death_sound_player.finished
	queue_free()

## Reduces current_hp by [amount], plays bar/flash tweens, grants EXP to [attacker]. Calls [method die] if HP reaches 0.
func take_damage(amount: int, attacker: Node2D = null) -> void:
	current_hp -= amount
	if current_hp < 0:
		current_hp = 0
		
	var bar_tween: Tween = null
	if health_bar != null:
		bar_tween = create_tween()
		bar_tween.tween_property(health_bar, "value", current_hp, HEALTH_BAR_TWEEN_DURATION)
	var flash: Tween = create_tween()
	flash.tween_property(self, "modulate", Color.RED, DAMAGE_FLASH_DURATION)
	flash.tween_property(self, "modulate", base_color, DAMAGE_FLASH_DURATION)
	if bar_tween != null:
		await bar_tween.finished
	else:
		await flash.finished
	
	if current_hp <= 0:
		if attacker != null and attacker.has_method("gain_exp"):
			attacker.gain_exp(50) 
		
		# --- CHANGED: Call the dedicated die() function instead of queue_free ---
		die(attacker)
	else:
		if attacker != null and attacker.has_method("gain_exp"):
			attacker.gain_exp(15)
		emit_signal("damaged", current_hp)

## Clears has_moved, is_exhausted, is_defending; resets poise meta and stagger visuals.
func reset_turn() -> void:
	has_moved = false
	move_points_used_this_turn = 0.0
	in_canto_phase = false
	canto_move_budget = 0.0
	is_exhausted = false
	is_defending = false
	if defend_icon != null:
		defend_icon.visible = false
	modulate = base_color
	
	# --- POISE RECOVERY ---
	if has_meta("current_poise"):
		remove_meta("current_poise")
	if has_meta("is_staggered_this_combat"):
		remove_meta("is_staggered_this_combat")
		
	set_staggered_visuals(false)	
	update_poise_visuals()
	
func finish_turn() -> void:
	in_canto_phase = false
	canto_move_budget = 0.0
	is_exhausted = true
	
	# Turn off ALL selection visuals
	set_selected(false) 
	set_selected_glow(false) # <--- ADD THIS LINE
	
	# Force the sprite color to update immediately
	if is_exhausted:
		modulate = Color(0.3, 0.3, 0.3)
	
	emit_signal("finished_turn", self)

func look_at_pos(target_grid_pos: Vector2i) -> void:
	var current_grid_pos := Vector2i(int(position.x / DEFAULT_CELL_SIZE), int(position.y / DEFAULT_CELL_SIZE))
	if target_grid_pos.x > current_grid_pos.x:
		sprite.flip_h = false 
	elif target_grid_pos.x < current_grid_pos.x:
		sprite.flip_h = true  
		
func set_selected(is_selected: bool) -> void:
	if selection_tween:
		selection_tween.kill()
	
	if is_selected:
		selection_tween = create_tween().set_loops()
		selection_tween.tween_property(team_glow, "color:a", 0.7, 0.5)
		selection_tween.tween_property(team_glow, "color:a", 0.3, 0.5)
	else:
		team_glow.color.a = 0.3
		modulate = Color(0.3, 0.3, 0.3) if is_exhausted else Color.WHITE

# Call this function with true to start glowing, false to stop.
func set_selected_glow(is_selected: bool) -> void:
	# Kill any existing tween so they don't fight each other
	if selection_tween and selection_tween.is_valid():
		selection_tween.kill()
	
	if is_selected:
		# Create a new tween that loops infinitely
		selection_tween = create_tween().set_loops()
		# Tween modulate to be brighter than usual (Color values > 1 make it glow)
		selection_tween.tween_property(sprite, "modulate", Color(1.3, 1.3, 1.3), 0.6).set_trans(Tween.TRANS_SINE)
		# Tween back to normal white
		selection_tween.tween_property(sprite, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)
	else:
		# Ensure the unit returns to normal color when deselected
		sprite.modulate = Color.WHITE
		
func trigger_defend() -> void:
	is_defending = true
	if defend_icon != null:
		defend_icon.visible = true
	update_poise_visuals()
	finish_turn()

func setup_from_save_data(save_dict: Dictionary) -> void:
	# 1. Restore Stats
	experience = save_dict.get("experience", 0)
	level = save_dict.get("level", 1)
	current_hp = save_dict.get("current_hp", max_hp)
	max_hp = save_dict.get("max_hp", max_hp)
	strength = save_dict.get("strength", strength)
	magic = save_dict.get("magic", magic)
	defense = save_dict.get("defense", defense)
	resistance = save_dict.get("resistance", resistance)
	speed = save_dict.get("speed", speed)
	agility = save_dict.get("agility", agility)
	
	# 2. Restore Movement (Boots)
	if save_dict.has("move_range"):
		move_range = save_dict["move_range"]

	# 3. Restore Class (Crucial for Promotions!)
	if save_dict.has("class_data") and save_dict["class_data"] != null:
		active_class_data = save_dict["class_data"]
		# Update the class name string too
		if active_class_data:
			unit_class_name = active_class_data.job_name
			
	if save_dict.has("inventory"):
		inventory.clear()
		inventory.append_array(save_dict["inventory"])		
		
	# 4. Update Bars
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
	if exp_bar:
		exp_bar.max_value = get_exp_required()
		exp_bar.value = experience
	# 5. Restore Skill Tree Data
	if save_dict.has("skill_points"):
		skill_points = save_dict["skill_points"]
	if save_dict.has("unlocked_skills"):
		unlocked_skills.clear()
		unlocked_skills.append_array(save_dict["unlocked_skills"])
	# --- Restore Unlocked Abilities ---
	if save_dict.has("unlocked_abilities"):
		unlocked_abilities.clear()
		unlocked_abilities.append_array(save_dict["unlocked_abilities"])
			
# --- NEW: PHYSICALLY UPDATE VISUALS ---
func apply_custom_visuals(sprite_tex: Texture2D, portrait_tex: Texture2D) -> void:
	if sprite_tex:
		# Update the actual 2D sprite node on the map
		if sprite:
			sprite.texture = sprite_tex
		
	if portrait_tex and data:
		# Update the internal resource so the HUD info panel finds it
		data.portrait = portrait_tex

## EXP required for the next level (base + scaling per level). Used for bar max and level-up loop.
func get_exp_required() -> int:
	# Base: 100 EXP for Level 2. 
	# Adds +25 EXP requirement for every level after that.
	# (Lv 1->2 = 100 | Lv 2->3 = 125 | Lv 3->4 = 150 | Lv 10->11 = 325)
	var base_exp = 200
	var scaling_factor = 200
	
	return base_exp + ((level - 1) * scaling_factor)

func apply_promotion_aura() -> void:
	if promo_aura != null: return 
	
	# --- 1. THE PULSATING GLOW (Behind) ---
	promo_aura = Sprite2D.new()
	promo_aura.show_behind_parent = true
	var aura_base_color: Color = Color(1.0, 0.8, 0.2, 0.6)
	var spark_color: Color = Color(1.0, 0.9, 0.5, 1.0)
	
	if get_parent() and get_parent().name == "EnemyUnits":
		aura_base_color = Color(0.8, 0.1, 1.0, 0.6)
		spark_color = Color(0.9, 0.4, 1.0, 1.0)
		
	promo_aura.modulate = aura_base_color
	sprite.add_child(promo_aura)
	
	var pulse = create_tween().set_loops()
	pulse.tween_property(promo_aura, "scale", Vector2(1.15, 1.15), 1.5).set_trans(Tween.TRANS_SINE)
	pulse.parallel().tween_property(promo_aura, "modulate:a", 0.1, 1.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(promo_aura, "scale", Vector2(1.0, 1.0), 1.5).set_trans(Tween.TRANS_SINE)
	pulse.parallel().tween_property(promo_aura, "modulate:a", 0.6, 1.5).set_trans(Tween.TRANS_SINE)

	# --- 2. THE JAGGED ELECTRIC ARCS ---
	var sparks = CPUParticles2D.new()
	add_child(sparks) 
	
	sparks.emitting = false 
	sparks.one_shot = true
	sparks.amount = 4 
	sparks.lifetime = 0.15 
	sparks.explosiveness = 1.0 
	sparks.local_coords = false 
	
	# --- NEW: APPLY THE TEXTURE ---
	if lightning_bolt_texture != null:
		sparks.texture = lightning_bolt_texture
	
	# --- NEW: RANDOM ROTATION ---
	# This makes sure the lightning bolts point in random directions
	sparks.angle_min = 0
	sparks.angle_max = 360
	
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(1, 1) 
	
	sparks.gravity = Vector2(0, 0)
	sparks.spread = 180.0 
	sparks.initial_velocity_min = 30.0 
	sparks.initial_velocity_max = 80.0
	
	sparks.scale_amount_min = 1.0 
	sparks.scale_amount_max = 2.5 # Reduced slightly since textures feel "bigger" than squares
	
	var grad = Gradient.new()
	grad.set_color(0, Color.WHITE) 
	grad.set_color(1, Color(spark_color.r, spark_color.g, spark_color.b, 0.0)) 
	sparks.color_ramp = grad
	
	# --- 3. THE SPORADIC TIMER ---
	var zap_timer = Timer.new()
	add_child(zap_timer) 
	zap_timer.wait_time = randf_range(0.3, 1.5)
	
	zap_timer.timeout.connect(func():
		if is_instance_valid(sparks) and is_instance_valid(sprite):
			var rx = randf_range(-40, 40)
			var ry = randf_range(-55, 25)
			sparks.position = sprite.position + Vector2(rx, ry)
			sparks.restart()
			zap_timer.wait_time = randf_range(0.2, 2.0) 
	)
	zap_timer.start()
	
func _process(_delta: float) -> void:
	if promo_aura != null and sprite != null:
		promo_aura.texture = sprite.texture
		promo_aura.hframes = sprite.hframes
		promo_aura.vframes = sprite.vframes
		promo_aura.frame = sprite.frame
		promo_aura.flip_h = sprite.flip_h
		promo_aura.offset = sprite.offset

# ==========================================
# --- POISE SYSTEM & UI ---
# ==========================================
## Poise cap from HP, DEF (and defend bonus), and temporary meta modifiers. Used by BattleField for stagger.
func get_max_poise() -> int:
	var def_stat = defense + int(get_meta("inner_peace_def_bonus_temp", 0)) - int(get_meta("frenzy_def_penalty_temp", 0))
	if is_defending:
		def_stat += defense_bonus
		
	# --- NERFED MATH: Add Max HP to the baseline! ---
	return max_hp + (def_stat * 2) + (25 if is_defending else 0)

func get_current_poise() -> int:
	return get_meta("current_poise", get_max_poise())

func update_poise_visuals() -> void:
	var max_p := get_max_poise()
	var cur_p := get_current_poise()

	var p_bar = get_node_or_null("DynamicPoiseBar")
	if p_bar == null and health_bar != null:
		p_bar = ProgressBar.new()
		p_bar.name = "DynamicPoiseBar"
		p_bar.show_percentage = false
		p_bar.custom_minimum_size = Vector2(health_bar.size.x, 4)
		p_bar.position = health_bar.position + Vector2(0, health_bar.size.y + 1)
		var bg = StyleBoxFlat.new()
		bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		var fill = StyleBoxFlat.new()
		fill.bg_color = Color(1.0, 0.7, 0.0, 1.0)
		p_bar.add_theme_stylebox_override("background", bg)
		p_bar.add_theme_stylebox_override("fill", fill)
		add_child(p_bar)

	if p_bar != null:
		p_bar.max_value = maxf(1, max_p)
		if _poise_bar_tween != null and _poise_bar_tween.is_valid():
			_poise_bar_tween.kill()
		_poise_bar_tween = create_tween()
		_poise_bar_tween.tween_property(p_bar, "value", float(clampi(cur_p, 0, max_p)), POISE_BAR_TWEEN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		p_bar.visible = (cur_p < max_p and current_hp > 0)

func set_staggered_visuals(is_staggered: bool) -> void:
	if stagger_tween and stagger_tween.is_valid():
		stagger_tween.kill()
		
	if is_staggered:
		stagger_tween = create_tween().set_loops(-1)
		# Pulse from normal to a painful, fleshy reddish-pink
		stagger_tween.tween_property(sprite, "modulate", Color(1.0, 0.4, 0.4), 0.6).set_trans(Tween.TRANS_SINE)
		stagger_tween.tween_property(sprite, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)
	else:
		if sprite:
			sprite.modulate = Color.WHITE

# ==========================================
# ARENA GHOST UI SYNC
# ==========================================
func setup_ghost_ui() -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
	if exp_bar:
		exp_bar.max_value = get_exp_required()
		exp_bar.value = experience
		
	# Optional: Give the ghosts an intimidating purple Arena aura!
	if team_glow:
		team_glow.color = Color(0.8, 0.1, 1.0, 0.4)
