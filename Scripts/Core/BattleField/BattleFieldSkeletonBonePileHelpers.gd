extends RefCounted

const UNIT_SCENE: PackedScene = preload("res://Resources/Unit.tscn")
const BONE_PILE_TEXTURE: Texture2D = preload("res://Assets/Sprites/Pile Of Bones.png")


static func build_revive_snapshot(unit: Unit) -> Dictionary:
	var inv: Array = []
	if CampaignManager.has_method("duplicate_item"):
		for it in unit.inventory:
			if it != null:
				inv.append(CampaignManager.duplicate_item(it))
			else:
				inv.append(null)
	else:
		inv = unit.inventory.duplicate()

	var eq_dup: Resource = null
	if unit.equipped_weapon != null and CampaignManager.has_method("duplicate_item"):
		eq_dup = CampaignManager.duplicate_item(unit.equipped_weapon)

	return {
		"data": unit.data,
		"unit_name": unit.unit_name,
		"experience": unit.experience,
		"level": unit.level,
		"max_hp": unit.max_hp,
		"strength": unit.strength,
		"magic": unit.magic,
		"defense": unit.defense,
		"resistance": unit.resistance,
		"speed": unit.speed,
		"agility": unit.agility,
		"move_range": unit.move_range,
		"class_data": unit.active_class_data,
		"inventory": inv,
		"equipped_weapon": eq_dup,
		"ai_intelligence": unit.ai_intelligence,
		"ai_behavior": int(unit.ai_behavior),
		"base_color": unit.base_color,
		"enemy_modulate": unit.modulate,
	}


static func register_pending_death_if_applicable(field, unit: Node2D, _killer: Node2D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if field.has_method("is_coop_remote_combat_replay_active") and field.is_coop_remote_combat_replay_active():
		return
	if not (unit is Unit):
		return
	var u: Unit = unit as Unit
	if u.get_parent() != field.enemy_container:
		return
	if u.data == null:
		return
	if int(u.data.bone_pile_reform_rounds) <= 0:
		return
	var last_st: int = int(u.get_meta("last_damage_subtype", -999))
	if last_st == int(WeaponData.PhysicalSubtype.BLUDGEONING):
		return

	var rounds: int = maxi(1, int(u.data.bone_pile_reform_rounds))
	var snap: Dictionary = build_revive_snapshot(u)
	var grid: Vector2i = field.get_grid_pos(u)
	var reform_at: int = int(field.current_turn) + rounds
	var payload: Dictionary = {
		"grid": grid,
		"reform_at_turn": reform_at,
		"snapshot": snap,
		"pile_node": null,
	}
	field._skeleton_bone_pile_death_payloads[u.get_instance_id()] = payload


static func take_death_payload(field, unit_iid: int) -> Variant:
	if not field._skeleton_bone_pile_death_payloads.has(unit_iid):
		return null
	var p: Variant = field._skeleton_bone_pile_death_payloads[unit_iid]
	field._skeleton_bone_pile_death_payloads.erase(unit_iid)
	return p


static func spawn_bone_pile_visual(field, payload: Dictionary, unit_world_corner: Vector2) -> void:
	_ensure_root(field)
	var spr := Sprite2D.new()
	spr.texture = BONE_PILE_TEXTURE
	spr.centered = true
	var ts: Vector2 = BONE_PILE_TEXTURE.get_size()
	var final_scale := Vector2.ONE
	if ts.x > 0.0 and ts.y > 0.0:
		var target := minf(float(field.CELL_SIZE.x) / ts.x, float(field.CELL_SIZE.y) / ts.y) * 0.92
		final_scale = Vector2(target, target)
	spr.scale = final_scale * 0.14
	spr.modulate.a = 0.0
	spr.set_meta("_bone_pile_final_scale", final_scale)
	field._skeleton_bone_piles_root.add_child(spr)
	spr.global_position = unit_world_corner + Vector2(float(field.CELL_SIZE.x), float(field.CELL_SIZE.y)) * 0.5
	spr.z_index = 5
	payload["pile_node"] = spr
	field._skeleton_bone_pile_entries.append(payload)
	field.rebuild_grid()


## Crossfade / squash skeleton sprite into the bone pile (call after [signal died] spawned the pile).
static func animate_skeleton_collapse_into_bone_pile(field, unit: Node2D) -> void:
	if unit == null or not is_instance_valid(unit) or not (unit is Unit):
		return
	var u: Unit = unit as Unit
	var spr: Sprite2D = u.sprite
	var pile: Sprite2D = _find_bone_pile_sprite_for_grid(field, field.get_grid_pos(u))
	if spr == null or pile == null:
		if spr != null:
			spr.visible = false
		return

	var p0: Vector2 = spr.global_position
	var sc0: Vector2 = spr.scale
	var rot0: float = spr.rotation
	var mod0: Color = spr.modulate

	var final_scale: Vector2 = pile.get_meta("_bone_pile_final_scale", pile.scale / maxf(0.001, pile.scale.x))

	var t: Tween = field.create_tween().set_parallel(true)
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(spr, "global_position", p0 + Vector2(0.0, 10.0), 0.38)
	t.tween_property(spr, "scale", Vector2(sc0.x * 1.12, sc0.y * 0.28), 0.38)
	t.tween_property(spr, "rotation", rot0 + deg_to_rad(7.0), 0.38)
	t.tween_property(spr, "modulate:a", 0.0, 0.34).from(mod0.a)

	t.tween_property(pile, "modulate:a", 1.0, 0.34).from(0.0)
	var tw_scale: Tween = field.create_tween()
	tw_scale.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_scale.tween_property(pile, "scale", final_scale, 0.45).from(final_scale * 0.14)

	await t.finished
	await tw_scale.finished
	if is_instance_valid(spr):
		spr.visible = false
		spr.scale = sc0
		spr.rotation = rot0
		spr.global_position = p0
		spr.modulate = Color(mod0.r, mod0.g, mod0.b, 1.0)


static func _find_bone_pile_sprite_for_grid(field, grid: Vector2i) -> Sprite2D:
	for i in range(field._skeleton_bone_pile_entries.size() - 1, -1, -1):
		var e: Dictionary = field._skeleton_bone_pile_entries[i]
		if e.get("grid", Vector2i(-99999, -99999)) == grid:
			var n: Node = e.get("pile_node", null)
			if n is Sprite2D and is_instance_valid(n):
				return n as Sprite2D
	return null


static func tick_async(field) -> void:
	if field._skeleton_bone_pile_entries.is_empty():
		return
	var keep: Array = []
	for entry in field._skeleton_bone_pile_entries:
		if int(field.current_turn) >= int(entry.get("reform_at_turn", 999999)):
			await _reform_one_animated(field, entry)
		else:
			keep.append(entry)
	field._skeleton_bone_pile_entries.clear()
	for e in keep:
		field._skeleton_bone_pile_entries.append(e)


static func _reform_one_animated(field, entry: Dictionary) -> void:
	var pile_node: Node = entry.get("pile_node", null)
	var pile_spr: Sprite2D = pile_node as Sprite2D if pile_node is Sprite2D else null

	var snap: Dictionary = entry.get("snapshot", {})
	var data: Resource = snap.get("data", null)
	if data == null:
		if pile_spr != null and is_instance_valid(pile_spr):
			pile_spr.queue_free()
		return
	var grid: Vector2i = entry.get("grid", Vector2i.ZERO)
	var cell_center: Vector2 = Vector2(
		float(grid.x) * field.CELL_SIZE.x + float(field.CELL_SIZE.x) * 0.5,
		float(grid.y) * field.CELL_SIZE.y + float(field.CELL_SIZE.y) * 0.5
	)

	if pile_spr != null and is_instance_valid(pile_spr):
		var t_out: Tween = field.create_tween().set_parallel(true)
		t_out.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var p_end: Vector2 = pile_spr.global_position + Vector2(0.0, 16.0)
		t_out.tween_property(pile_spr, "modulate:a", 0.0, 0.28)
		t_out.tween_property(pile_spr, "scale", pile_spr.scale * 0.45, 0.28)
		t_out.tween_property(pile_spr, "global_position", p_end, 0.28)
		await t_out.finished
		if is_instance_valid(pile_spr):
			pile_spr.queue_free()

	var nu: Unit = UNIT_SCENE.instantiate() as Unit
	if nu == null:
		return
	nu.data = data as UnitData
	field.enemy_container.add_child(nu)
	nu.position = Vector2(grid.x * field.CELL_SIZE.x, grid.y * field.CELL_SIZE.y)

	var save_bits: Dictionary = {
		"experience": snap.get("experience", 0),
		"level": snap.get("level", 1),
		"max_hp": snap.get("max_hp", 1),
		"current_hp": snap.get("max_hp", 1),
		"strength": snap.get("strength", 1),
		"magic": snap.get("magic", 0),
		"defense": snap.get("defense", 0),
		"resistance": snap.get("resistance", 0),
		"speed": snap.get("speed", 1),
		"agility": snap.get("agility", 1),
		"move_range": snap.get("move_range", 4),
		"class_data": snap.get("class_data", null),
		"inventory": snap.get("inventory", []),
	}
	nu.setup_from_save_data(save_bits)
	nu.unit_name = str(snap.get("unit_name", nu.unit_name))
	nu.ai_intelligence = int(snap.get("ai_intelligence", nu.ai_intelligence))
	nu.ai_behavior = int(snap.get("ai_behavior", int(nu.ai_behavior)))
	nu.base_color = snap.get("base_color", nu.base_color)
	nu.modulate = snap.get("enemy_modulate", nu.modulate)

	var eq: Resource = snap.get("equipped_weapon", null)
	if eq != null:
		nu.equipped_weapon = eq

	if nu.get_node_or_null("AIController") == null:
		var ai := AIController.new()
		nu.add_child(ai)

	if nu.has_signal("died") and not nu.died.is_connected(field._on_unit_died):
		nu.died.connect(field._on_unit_died)
	if nu.has_signal("leveled_up") and not nu.leveled_up.is_connected(field._on_unit_leveled_up):
		nu.leveled_up.connect(field._on_unit_leveled_up)

	var u_spr: Sprite2D = nu.sprite
	var s0: Vector2 = u_spr.scale if u_spr != null else Vector2.ONE
	if u_spr != null:
		u_spr.scale = s0 * 0.18
		nu.modulate.a = 0.0

	field.rebuild_grid()

	var t_in: Tween = field.create_tween().set_parallel(true)
	t_in.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if u_spr != null:
		t_in.tween_property(u_spr, "scale", s0, 0.55)
	t_in.tween_property(nu, "modulate:a", 1.0, 0.38)
	await t_in.finished

	if u_spr != null:
		u_spr.scale = s0
	nu.modulate.a = 1.0

	var risen: String = str(snap.get("unit_name", "Skeleton"))
	field.add_combat_log(risen + " rises from the bones!", "silver")
	field.spawn_loot_text(
		"REVIVED!",
		Color(0.78, 0.94, 1.0),
		cell_center + Vector2(0.0, -44.0),
		{
			"stack_anchor": nu,
			"font_size": 24,
			"text_scale": 2.45,
			"rise_px": 56.0,
			"scatter_amount": 10.0,
			"hold_time": 0.52,
			"fade_time": 0.42,
		}
	)
	field.update_fog_of_war()
	field.update_objective_ui(true)
	field._danger_zone_recalc_dirty = true


static func _ensure_root(field) -> void:
	if field._skeleton_bone_piles_root != null and is_instance_valid(field._skeleton_bone_piles_root):
		return
	var r := Node2D.new()
	r.name = "SkeletonBonePiles"
	field.add_child(r)
	field.move_child(r, 0)
	field._skeleton_bone_piles_root = r
