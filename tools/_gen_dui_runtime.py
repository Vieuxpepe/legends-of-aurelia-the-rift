from pathlib import Path
import re

p = Path(__file__).resolve().parent.parent / "Scripts/Core/BattleField.gd"
lines = p.read_text(encoding="utf-8").splitlines()
chunk = lines[1588:2453]

no_field_funcs = {"unit_info_primary_bar_definitions", "unit_info_stat_definitions"}

out_lines = []
header = """extends RefCounted
class_name DetailedUnitInfoRuntimeHelpers

## Tactical unit info panel (bottom bar): primary HP/Poise/XP rows, stat mini-bars, tier FX, layout, refresh, animation.

"""
out_lines.append(header.strip())

for line in chunk:
    m = re.match(r"^func (_[a-zA-Z0-9_]+)\((.*)\) -> (.+):$", line)
    if m:
        name, params, ret = m.group(1), m.group(2).strip(), m.group(3).strip()
        pub = name[1:]
        if pub in no_field_funcs:
            out_lines.append("static func %s(%s) -> %s:" % (pub, params, ret))
        elif params == "":
            out_lines.append("static func %s(field) -> %s:" % (pub, ret))
        else:
            out_lines.append("static func %s(field, %s) -> %s:" % (pub, params, ret))
    else:
        out_lines.append(line)

text = "\n".join(out_lines) + "\n"

repls = [
    (r"\bunit_info_panel\b", "field.unit_info_panel"),
    (r"\b_unit_info_primary_widgets\b", "field._unit_info_primary_widgets"),
    (r"\b_unit_info_stat_widgets\b", "field._unit_info_stat_widgets"),
    (r"\b_unit_info_primary_anim_tween\b", "field._unit_info_primary_anim_tween"),
    (r"\b_unit_info_primary_animating\b", "field._unit_info_primary_animating"),
    (r"\b_unit_info_primary_anim_source_id\b", "field._unit_info_primary_anim_source_id"),
    (r"\b_unit_info_stat_anim_tween\b", "field._unit_info_stat_anim_tween"),
    (r"\b_unit_info_stat_animating\b", "field._unit_info_stat_animating"),
    (r"\b_unit_info_stat_anim_source_id\b", "field._unit_info_stat_anim_source_id"),
    (r"\bui_root\b", "field.ui_root"),
    (r"\bcreate_tween\(\)", "field.create_tween()"),
    (r"\bUNIT_INFO_STAT_", "field.UNIT_INFO_STAT_"),
    (r"\bTACTICAL_UI_", "field.TACTICAL_UI_"),
    (r"_forecast_hp_fill_color\(", "field._forecast_hp_fill_color("),
    (r"_style_tactical_label\(", "field._style_tactical_label("),
    (r"_style_tactical_panel\(", "field._style_tactical_panel("),
]
for pat, rep in repls:
    text = re.sub(pat, rep, text)

text = text.replace("_unit_info_primary_bar_definitions()", "unit_info_primary_bar_definitions()")
text = text.replace("_unit_info_stat_definitions()", "unit_info_stat_definitions()")

INTERNAL = [
    "unit_info_primary_fill_color",
    "style_unit_info_primary_bar",
    "attach_unit_info_bar_sheen",
    "animate_unit_info_bar_sheen",
    "ensure_unit_info_primary_widgets",
    "layout_unit_info_primary_widgets",
    "set_unit_info_primary_widgets_visible",
    "animate_unit_info_primary_widgets_in",
    "refresh_unit_info_primary_widgets",
    "unit_info_stat_tier_index",
    "unit_info_stat_fill_color",
    "style_unit_info_stat_bar",
    "ensure_unit_info_stat_fx_nodes",
    "get_unit_info_stat_arcs_root",
    "position_unit_info_stat_fx_nodes",
    "stop_unit_info_stat_tier_fx",
    "unit_info_stat_arc_count_for_tier",
    "unit_info_stat_arc_perimeter_length",
    "unit_info_stat_arc_perimeter_point",
    "unit_info_stat_arc_perimeter_normal",
    "set_unit_info_stat_arc_progress",
    "play_unit_info_stat_tier_flash",
    "start_unit_info_stat_tier_loop",
    "play_unit_info_stat_tier_fx",
    "ensure_unit_info_stat_widgets",
    "layout_unit_info_stat_widgets",
    "set_unit_info_stat_widgets_visible",
    "unit_info_stat_display_value",
    "animate_unit_info_stat_widgets_in",
    "refresh_unit_info_stat_widgets",
]
for name in INTERNAL:
    text = re.sub(r"\b_" + name + r"\(", name + r"(field, ", text)

text = text.replace(
    'Callable(self, "_set_unit_info_stat_arc_progress").bind',
    'Callable(DetailedUnitInfoRuntimeHelpers, "set_unit_info_stat_arc_progress").bind',
)

text = re.sub(
    r"static func set_unit_info_stat_arc_progress\(field, progress: float",
    "static func set_unit_info_stat_arc_progress(progress: float",
    text,
    count=1,
)

# Calls wrongly got field as first arg to set_unit_info_stat_arc_progress
text = re.sub(
    r"set_unit_info_stat_arc_progress\(field, start_offset,",
    "set_unit_info_stat_arc_progress(start_offset,",
    text,
)

outp = p.parent / "BattleField" / "BattleFieldDetailedUnitInfoRuntimeHelpers.gd"
outp.write_text(text, encoding="utf-8")
print("written", len(text.splitlines()))
