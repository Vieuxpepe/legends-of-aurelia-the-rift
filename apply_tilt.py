import os

def replace_in_file(path, old_str, new_str):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    if old_str in content:
        content = content.replace(old_str, new_str)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Replaced string in {path}")
    else:
        print(f"Could not find old_str in {path}")

def append_to_file(path, new_str):
    with open(path, 'a', encoding='utf-8') as f:
        f.write(new_str)
    print("Appended to " + path)

old_layout_intel = '''		_set_control_rect(intel_panel, Vector2(right_x, right_top), intel_size)
		if intel_card != null:'''
new_layout_intel = '''		_set_control_rect(intel_panel, Vector2(right_x, right_top), intel_size)
		intel_panel.pivot_offset = intel_size * 0.5
		if intel_card != null:'''

old_layout_dispatch = '''			_set_control_rect(dispatch_panel, dispatch_pos, dispatch_size)
			if dispatch_card != null:'''
new_layout_dispatch = '''			_set_control_rect(dispatch_panel, dispatch_pos, dispatch_size)
			dispatch_panel.pivot_offset = dispatch_size * 0.5
			if dispatch_card != null:'''

old_layout_main = '''		_set_control_rect(main_vbox, Vector2((vp_size.x - main_size.x) * 0.5, clampf(vp_size.y * 0.21, 175.0, 255.0)), main_size)'''
new_layout_main = '''		_set_control_rect(main_vbox, Vector2((vp_size.x - main_size.x) * 0.5, clampf(vp_size.y * 0.21, 175.0, 255.0)), main_size)
		main_vbox.pivot_offset = main_size * 0.5'''

replace_in_file('MainMenu.gd', old_layout_intel, new_layout_intel)
replace_in_file('MainMenu.gd', old_layout_dispatch, new_layout_dispatch)
replace_in_file('MainMenu.gd', old_layout_main, new_layout_main)

process_script = '''

func _process(delta: float) -> void:
\tvar vp_size = get_viewport_rect().size
\tvar mouse_pos = get_global_mouse_position()
\tvar center = vp_size * 0.5
\t
\tvar offset_ratio_x = clampf((mouse_pos.x - center.x) / center.x, -1.0, 1.0)
\tvar offset_ratio_y = clampf((mouse_pos.y - center.y) / center.y, -1.0, 1.0)
\t
\t# 3D Tilt Parameters
\tvar target_rot = (offset_ratio_x * 0.015) + (offset_ratio_y * 0.008)
\tvar target_skew = offset_ratio_x * 0.02
\t
\tfor panel in [main_vbox, intel_panel, dispatch_panel]:
\t\tif panel == null: continue
\t\tpanel.rotation = lerp(panel.rotation, target_rot, 4.0 * delta)
\t\tpanel.skew = lerp(panel.skew, target_skew, 4.0 * delta)
'''
append_to_file('MainMenu.gd', process_script)
