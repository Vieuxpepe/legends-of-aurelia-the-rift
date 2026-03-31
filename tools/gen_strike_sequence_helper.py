# Historical / optional: was used to extract `_run_strike_sequence_impl` from BattleField.gd into
# BattleFieldStrikeSequenceHelpers.gd (milestone 26). After that move, `_run_strike_sequence_impl`
# no longer exists in BattleField.gd — this script will fail unless you temporarily restore that
# function from git history. Source of truth for the strike sequence is now the helper file.
# Run from repo root: python tools/gen_strike_sequence_helper.py

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BATTLEFIELD = ROOT / "Scripts" / "Core" / "BattleField.gd"
OUT = ROOT / "Scripts" / "Core" / "BattleField" / "BattleFieldStrikeSequenceHelpers.gd"

HEADER = '''extends RefCounted

const DefensiveAbilityFlowHelpers = preload("res://Scripts/Core/BattleField/BattleFieldDefensiveAbilityFlowHelpers.gd")
const AttackResolutionHelpers = preload("res://Scripts/Core/BattleField/BattleFieldAttackResolutionHelpers.gd")
const PostStrikeCleanupHelpers = preload("res://Scripts/Core/BattleField/BattleFieldPostStrikeCleanupHelpers.gd")
const ForcedMovementTacticalHelpers = preload("res://Scripts/Core/BattleField/BattleFieldForcedMovementTacticalHelpers.gd")
const CombatCleanupHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCombatCleanupHelpers.gd")

static func run_strike_sequence(
	field,
	attacker: Node2D,
	defender: Node2D,
	force_active_ability: bool = false,
	force_single_attack: bool = false
) -> void:
'''


def transform_body(text: str) -> str:
    # QTEManager.*(self, -> (field,
    text = re.sub(r"QTEManager\.(\w+)\(\s*self\s*,", r"QTEManager.\1(field,", text)

    # Lines that are only `self,` (helper first argument)
    text = re.sub(r"^(\s*)self\s*,\s*$", r"\1field,", text, flags=re.MULTILINE)

    text = re.sub(
        r"await AttackResolutionHelpers\.resolve_phase_e_normal_attack\(\s*self\s*,",
        "await AttackResolutionHelpers.resolve_phase_e_normal_attack(field,",
        text,
    )

    text = re.sub(
        r"CombatCleanupHelpers\.process_phase_h_combat_cleanup\(\s*self\s*,",
        "CombatCleanupHelpers.process_phase_h_combat_cleanup(field,",
        text,
    )

    for name in (
        "ability_triggers_count",
        "loot_recipient",
    ):
        text = re.sub(rf"\b{name}\b", f"field.{name}", text)

    # Dict / .get string keys must stay un-prefixed
    text = text.replace('"field.ability_triggers_count"', '"ability_triggers_count"')
    text = text.replace('"field.loot_recipient"', '"loot_recipient"')

    # Methods / properties — word-boundary replace with field. prefix (avoid double)
    calls = [
        "create_tween",
        "get_tree",
        "add_child",
        "get_adjacency_bonus",
        "get_support_combat_bonus",
        "get_relationship_combat_modifiers",
        "get_terrain_data",
        "get_grid_pos",
        "get_triangle_advantage",
        "get_ability_trigger_chance",
        "get_distance",
        "get_enemy_at",
        "get_unit_at",
        "get_occupant_at",
        "add_combat_log",
        "spawn_loot_text",
        "_compute_rookie_class_passive_mods",
        "_run_melee_crit_lunge",
        "_run_melee_normal_lunge",
        "_is_valid_combat_unit",
        "_attacker_has_attack_skill",
        "_add_support_points_and_check",
        "_award_relationship_event",
        "_can_gain_mentorship",
        "_award_relationship_stat_event",
        "_coop_qte_alloc_event_id",
        "_coop_qte_mirror_read_int",
        "_coop_qte_capture_write",
        "_attack_line_step",
        "_run_focused_strike_minigame",
        "_run_bloodthirster_minigame",
        "_run_hundred_point_strike_minigame",
    ]
    for name in calls:
        text = re.sub(rf"\b{re.escape(name)}\b\(", f"field.{name}(", text)

    # _coop_qte_mirror_active is a property read, not a call
    text = re.sub(r"(?<!\.)_coop_qte_mirror_active\b", "field._coop_qte_mirror_active", text)

    # Member assignments / reads (no paren)
    members = [
        "_support_guard_used_this_sequence",
        "player_container",
        "enemy_container",
        "ally_container",
        "level_up_sound",
        "attack_sound",
    ]
    for m in members:
        # rf"(?<!\.)\\b" is wrong: it becomes literal \\b in the regex, not a word boundary
        pat = r"(?<!\.)" + r"\b" + re.escape(m) + r"\b"
        text = re.sub(pat, f"field.{m}", text)

    while "field.field." in text:
        text = text.replace("field.field.", "field.")

    return text


def main() -> None:
    raw = BATTLEFIELD.read_text(encoding="utf-8")
    lines = raw.splitlines(keepends=True)

    start = None
    end = None
    for i, line in enumerate(lines):
        if line.startswith("func _run_strike_sequence_impl("):
            start = i
        if start is not None and i > start and line.startswith("func screen_shake("):
            end = i
            break
    if start is None or end is None:
        raise SystemExit("Could not find _run_strike_sequence_impl / screen_shake boundaries")

    body_lines = lines[start + 1 : end]
    body = "".join(body_lines)
    body = transform_body(body)

    # Indent body one level (4 spaces) for static func
    indented = ""
    for line in body.splitlines(keepends=True):
        if line.strip() == "":
            indented += "\t" + line
        else:
            indented += "\t" + line

    OUT.write_text(HEADER + indented, encoding="utf-8")
    print(f"Wrote {OUT} ({len(indented.splitlines())} lines)")


if __name__ == "__main__":
    main()
