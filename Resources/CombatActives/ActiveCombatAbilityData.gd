extends Resource
class_name ActiveCombatAbilityData

## Cooldown-gated combat abilities (enemy AI / future player specials). Runtime state lives on [member Unit.active_ability_cooldowns];
## ticking and readiness are handled by [ActiveCombatAbilityHelpers]. Distinct from [PassiveCombatAbilityData] hook passives.

enum EffectKind {
	NONE = 0,
	## Single target: damage/heal/status within range rules below.
	TARGETED_SCRIPT = 1,
	## AoE: affects units within [member self_radius] (Manhattan) of the caster.
	SELF_CENTERED = 2,
}

@export var ability_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export var effect_kind: EffectKind = EffectKind.NONE

## Full cooldown length applied after a successful use (turns before it becomes ready again).
@export_range(0, 99, 1) var cooldown_turns: int = 3

## If false, the ability starts the battle with [member cooldown_turns] already charged (not ready).
@export var starts_ready: bool = true

@export_category("Targeting (TARGETED_SCRIPT)")
## If true, use equipped weapon min/max range; else use [member ability_min_range] / [member ability_max_range].
@export var use_weapon_range: bool = true
@export_range(0, 10, 1) var ability_min_range: int = 1
@export_range(1, 10, 1) var ability_max_range: int = 2
## If true, ability may target player-side units (enemies use this). If false, targets allies (healing).
@export var target_hostile: bool = true

@export_category("TARGETED effects")
@export_range(0, 100, 1) var magic_damage: int = 0
@export_range(0, 100, 1) var physical_damage: int = 0
@export_range(0, 99, 1) var heal_amount: int = 0
@export var apply_combat_status_id: String = ""

@export_category("SELF_CENTERED effects")
@export_range(0, 5, 1) var self_radius: int = 1
@export_range(0, 100, 1) var self_magic_damage_to_hostiles: int = 0
@export_range(0, 99, 1) var self_heal_allies: int = 0
