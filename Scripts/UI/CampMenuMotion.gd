## Camp hub micro-animations (staggered layout, hover, shop/blacksmith/jukebox juice).
## Used by `camp_menu.gd` so the scene script stays mostly wiring + game logic.
extends RefCounted


static func play_card_stagger_intro(host: Node, cards: Dictionary) -> void:
	var order: PackedStringArray = PackedStringArray([
		"roster", "commander", "inventory", "merchant", "shop", "nav"
	])
	var delay := 0.0
	for key in order:
		var c: Control = cards.get(key) as Control
		if c == null or not is_instance_valid(c):
			continue
		c.pivot_offset = c.size * 0.5
		c.scale = Vector2(0.94, 0.94)
		var tw: Tween = host.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(c, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		delay += 0.055


static func wire_button_hover_scale(btn: BaseButton, mult: float = 1.038) -> void:
	if btn == null or not is_instance_valid(btn) or btn.get_meta(&"camp_hover_scale_wired", false):
		return
	btn.set_meta(&"camp_hover_scale_wired", true)
	var base := Vector2.ONE
	btn.mouse_entered.connect(func() -> void:
		if not is_instance_valid(btn):
			return
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", base * mult, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func() -> void:
		if not is_instance_valid(btn):
			return
		btn.pivot_offset = btn.size * 0.5
		var tw2 := btn.create_tween()
		tw2.tween_property(btn, "scale", base, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	)


static func wire_hover_scales(buttons: Array) -> void:
	for n in buttons:
		if n is BaseButton:
			wire_button_hover_scale(n as BaseButton)


static func gold_label_delta_pulse(host: Node, label: Label, new_amount: int, last_amount: int) -> void:
	if label == null or not is_instance_valid(host):
		return
	if last_amount >= 0 and new_amount != last_amount:
		label.pivot_offset = label.size * 0.5
		var tw := host.create_tween()
		tw.tween_property(label, "scale", Vector2(1.1, 1.1), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static func flash_inventory_card(host: Node, inv_card: Control) -> void:
	if inv_card == null or not is_instance_valid(host):
		return
	var tw := host.create_tween()
	tw.tween_property(inv_card, "modulate", Color(1.06, 1.03, 0.96, 1.0), 0.08)
	tw.tween_property(inv_card, "modulate", Color.WHITE, 0.2).set_trans(Tween.TRANS_QUAD)


static func merchant_portrait_line_nudge(host: Node, portrait: TextureRect) -> void:
	if portrait == null or not is_instance_valid(host):
		return
	portrait.pivot_offset = portrait.size * 0.5
	var s0 := portrait.scale
	var tw := host.create_tween()
	tw.tween_property(portrait, "scale", s0 * 1.028, 0.09).set_trans(Tween.TRANS_SINE)
	tw.tween_property(portrait, "scale", s0, 0.12).set_trans(Tween.TRANS_SINE)


## Slight vertical “bob” on Elara’s Field Notes intro portrait (Next / Enter).
static func field_notes_elara_portrait_bob(host: Node, portrait: TextureRect) -> void:
	if portrait == null or not is_instance_valid(host):
		return
	var sz: Vector2 = portrait.size
	if sz.y < 1.0:
		sz = portrait.custom_minimum_size
	portrait.pivot_offset = Vector2(sz.x * 0.5, sz.y * 0.88)
	var s0 := portrait.scale
	var tw := host.create_tween()
	tw.tween_property(portrait, "scale", s0 * Vector2(1.02, 1.06), 0.08).set_trans(Tween.TRANS_SINE)
	tw.tween_property(portrait, "scale", s0 * Vector2(1.02, 0.97), 0.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(portrait, "scale", s0, 0.12).set_trans(Tween.TRANS_SINE)


static func shop_deal_sparkle(host: Node, btn: Button) -> void:
	if btn == null or not is_instance_valid(host) or not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	var tw := host.create_tween().set_loops(2)
	tw.tween_property(btn, "modulate", Color(1.22, 1.12, 0.82, 1.0), 0.32).set_trans(Tween.TRANS_SINE)
	tw.tween_property(btn, "modulate", Color.WHITE, 0.32).set_trans(Tween.TRANS_SINE)


static func shake_control(host: Node, c: Control) -> void:
	if c == null or not is_instance_valid(host) or not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	var r0 := c.rotation
	var tw := host.create_tween()
	tw.tween_property(c, "rotation", r0 + 0.07, 0.05)
	tw.tween_property(c, "rotation", r0 - 0.06, 0.06)
	tw.tween_property(c, "rotation", r0, 0.08).set_trans(Tween.TRANS_QUAD)


static func forge_slot_land(
	host: Node,
	slot_control: Control,
	shop_buy_sound: AudioStreamPlayer,
	select_sound: AudioStreamPlayer
) -> void:
	if slot_control == null or not is_instance_valid(host):
		return
	var orig := Vector2.ONE
	slot_control.scale = orig
	var tw := host.create_tween()
	tw.tween_property(slot_control, "scale", orig * 1.14, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(slot_control, "scale", orig, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if shop_buy_sound != null and shop_buy_sound.stream != null:
		shop_buy_sound.pitch_scale = 0.88
		shop_buy_sound.play()
	elif select_sound != null and select_sound.stream != null:
		select_sound.pitch_scale = 1.22
		select_sound.play()


static func craft_result_punch(host: Node, icon: TextureRect) -> void:
	if icon == null or not is_instance_valid(host):
		return
	icon.pivot_offset = icon.size * 0.5
	var tw := host.create_tween()
	tw.tween_property(icon, "scale", Vector2(1.16, 1.16), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func roster_pick_pulse(host: Node, roster_btn: Button) -> void:
	if roster_btn == null or not is_instance_valid(host):
		return
	roster_btn.pivot_offset = roster_btn.size * 0.5
	var tw := host.create_tween()
	tw.tween_property(roster_btn, "scale", Vector2(1.055, 1.055), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(roster_btn, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


static func jukebox_now_playing_tick(host: Node, rtl: RichTextLabel) -> void:
	if rtl == null or not is_instance_valid(host):
		return
	rtl.pivot_offset = rtl.size * 0.5
	var tw := host.create_tween()
	tw.tween_property(rtl, "modulate", Color(1.12, 1.08, 1.0, 1.0), 0.06)
	tw.tween_property(rtl, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_QUAD)


static func jukebox_volume_slider_tick(host: Node, slider: Range) -> void:
	if slider == null or not is_instance_valid(host):
		return
	slider.pivot_offset = slider.size * 0.5
	var tw := host.create_tween()
	tw.tween_property(slider, "scale", Vector2(1.035, 1.035), 0.05)
	tw.tween_property(slider, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_QUAD)


static func save_slot_overwrite_warn_pulse(host: Node, slot_btn: Button) -> void:
	if slot_btn == null or not is_instance_valid(host):
		return
	slot_btn.pivot_offset = slot_btn.size * 0.5
	var tw := host.create_tween()
	for _i in 3:
		tw.tween_property(slot_btn, "modulate", Color(1.0, 0.82, 0.45, 1.0), 0.12)
		tw.tween_property(slot_btn, "modulate", Color.WHITE, 0.12)


static func haggle_resolve_flash(host: Node, won: bool, progress: ProgressBar, shop_card: Control) -> void:
	if not is_instance_valid(host):
		return
	if progress != null and is_instance_valid(progress):
		var peak := Color(0.42, 1.0, 0.62, 1.0) if won else Color(1.0, 0.38, 0.38, 1.0)
		var tw := host.create_tween()
		tw.tween_property(progress, "modulate", peak, 0.1)
		tw.tween_property(progress, "modulate", Color.WHITE, 0.4).set_trans(Tween.TRANS_QUAD)
	if shop_card != null and is_instance_valid(shop_card):
		var tw2 := host.create_tween()
		tw2.tween_property(shop_card, "modulate", Color(1.04, 1.06, 1.0, 1.0), 0.12)
		tw2.tween_property(shop_card, "modulate", Color.WHITE, 0.35).set_trans(Tween.TRANS_QUAD)


static func ensure_fire_flicker_layer(host: Control, insert_after: Control) -> ColorRect:
	var existing := host.get_node_or_null("CampMotionFireFlicker")
	if existing is ColorRect:
		return existing as ColorRect
	var cr := ColorRect.new()
	cr.name = "CampMotionFireFlicker"
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.offset_left = 0.0
	cr.offset_top = 0.0
	cr.offset_right = 0.0
	cr.offset_bottom = 0.0
	cr.color = Color(1.0, 0.48, 0.2, 0.04)
	host.add_child(cr)
	var idx := 0
	if insert_after != null and is_instance_valid(insert_after):
		idx = clampi(insert_after.get_index() + 1, 0, host.get_child_count() - 1)
	host.move_child(cr, idx)
	return cr


static func _set_fire_layer_alpha(layer: ColorRect, rgb: Color, a: float) -> void:
	if layer != null and is_instance_valid(layer):
		layer.color = Color(rgb.r, rgb.g, rgb.b, a)


static func start_campfire_flicker(host: Node, layer: ColorRect) -> void:
	if layer == null or not is_instance_valid(host):
		return
	var old: Variant = layer.get_meta(&"camp_fire_tw", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := host.create_tween().set_loops()
	layer.set_meta(&"camp_fire_tw", tw)
	var c1 := Color(1.0, 0.5, 0.22)
	var c2 := Color(1.0, 0.52, 0.26)
	tw.tween_method(_set_fire_layer_alpha.bind(layer, c1), 0.02, 0.09, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_fire_layer_alpha.bind(layer, c2), 0.09, 0.03, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func start_background_breathe(host: Node, bg: TextureRect) -> void:
	if bg == null or not is_instance_valid(host):
		return
	var old: Variant = bg.get_meta(&"camp_bg_breathe_tw", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := host.create_tween().set_loops()
	bg.set_meta(&"camp_bg_breathe_tw", tw)
	tw.tween_property(bg, "self_modulate", Color(1.035, 0.98, 0.94, 1.0), 5.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(bg, "self_modulate", Color.WHITE, 5.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
