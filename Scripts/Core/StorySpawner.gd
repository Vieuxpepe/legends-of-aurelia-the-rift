extends Node2D

@export_category("Story Event Settings")
@export var unit_scene: PackedScene # Drag Unit.tscn here!
@export var character_data: Resource # Drag branik.tres here!
@export var activation_distance: int = 5
@export var event_faction: int = 0 # 0 = Enemy Phase

@export_category("Dialogue")
# You can now add your 4 lines directly in the Inspector!
@export_multiline var event_dialogue: Array[String] = [
	"Hold it right there. We don't want any bloodshed.",
	"Just leave the merchant's cart and you can pass safely."
]

var has_triggered: bool = false

func _ready() -> void:
	visible = false

func process_turn(battlefield: Node2D, active_faction: int) -> void:
	if has_triggered or active_faction != event_faction:
		return
		
	var target = battlefield.vip_target
	if target == null or not is_instance_valid(target):
		return 
		
	var dist = battlefield.get_distance(self, target)
	if dist <= activation_distance:
		await _trigger_event(battlefield)

func _trigger_event(bf: Node2D) -> void:
	has_triggered = true
	
	# 1. THE CINEMATIC CAMERA PAN
	var cam = bf.main_camera
	if cam:
		var target_cam_pos = global_position + Vector2(32, 32)
		if cam.anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT:
			target_cam_pos -= (bf.get_viewport_rect().size * 0.5) / cam.zoom
			
		var c_tween = create_tween()
		c_tween.tween_property(cam, "global_position", target_cam_pos, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await c_tween.finished
		await get_tree().create_timer(0.3).timeout
		
	# 2. SPAWN THE CHARACTER (AND FIX STATS/NAME/VISUALS)
	var char_node = unit_scene.instantiate()
	
	# THE FIX 1: Turn off the Avatar override!
	if char_node.get("is_custom_avatar") != null:
		char_node.set("is_custom_avatar", false)
	
	if character_data != null:
		char_node.data = character_data.duplicate()
		
		# THE FIX 2: Force the name update
		if char_node.get("unit_name") != null:
			var d_name = character_data.get("display_name")
			char_node.unit_name = d_name if d_name != null and d_name != "" else "Bandit"
			
		# THE FIX 3: Apply the visual battle sprite so he doesn't look like Cathaldus!
		var spr = char_node.get_node_or_null("Sprite")
		if spr == null: spr = char_node.get_node_or_null("Sprite2D")
		var d_sprite = character_data.get("unit_sprite")
		if spr and d_sprite != null:
			spr.texture = d_sprite
			
		# Load his base stats safely
		var d_hp = character_data.get("max_hp")
		char_node.max_hp = d_hp if d_hp != null else 15
		char_node.current_hp = char_node.max_hp
		
		var d_str = character_data.get("strength")
		char_node.strength = d_str if d_str != null else 5
		
		var d_def = character_data.get("defense")
		char_node.defense = d_def if d_def != null else 5
		
		var d_spd = character_data.get("speed")
		char_node.speed = d_spd if d_spd != null else 2
		
		var d_agi = character_data.get("agility")
		char_node.agility = d_agi if d_agi != null else 2
		
		# Give him his weapon!
		if character_data.get("starting_weapon") != null:
			char_node.equipped_weapon = character_data.starting_weapon.duplicate()
			
	char_node.position = position
	bf.enemy_container.add_child(char_node)
	
	# Start invisible and fade in smoothly
	char_node.modulate.a = 0.0
	var spawn_tween = create_tween()
	spawn_tween.tween_property(char_node, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	
	bf.screen_shake(4.0, 0.2)
	if bf.has_method("add_combat_log"):
		bf.add_combat_log(char_node.unit_name + " steps out from the trees!", "tomato")
		
	await spawn_tween.finished
	await get_tree().create_timer(0.2).timeout
	
	# 3. TRIGGER THE DIALOGUE WITH THE CORRECT PORTRAIT
	# Pull the portrait directly from the resource file to be 100% safe
	var port = character_data.get("portrait") if character_data != null else null
	
	if event_dialogue.size() > 0:
		await bf.play_cinematic_dialogue(char_node.unit_name, port, event_dialogue)
	
	# 4. CLEANUP AND RESUME GAME
	bf.rebuild_grid()
	if bf.has_method("update_fog_of_war"):
		bf.update_fog_of_war()
		
	queue_free()
