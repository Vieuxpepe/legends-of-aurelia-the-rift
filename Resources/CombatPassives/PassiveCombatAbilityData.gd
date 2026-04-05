extends Resource
class_name PassiveCombatAbilityData

## Inspector-authored passive combat rules. Read at runtime from [member UnitData.passive_combat_abilities]
## (and optional legacy [member UnitData.map01_enemy_kit] presets) via [CombatPassiveAbilityHelpers].

enum EffectKind {
	NONE = 0,
	## Enemy death: spawn a weak fire tile on death cell or deterministic neighbor.
	ASH_BURST_ON_DEATH = 1,
	## Ranged attacks: bonus HIT when LOS segment crosses burning tiles (range > 1).
	ASH_SIGHT_HIT = 2,
	## Successful magic tome hit: spawn short-lived fire near target.
	EMBER_WAKE_FIRE_TILE = 3,
	## Successful weapon hit: apply [member status_id_to_apply] (respect gates below).
	APPLY_STATUS_ON_WEAPON_HIT = 4,
	## Bonus HIT vs [member UnitData.counts_as_civilian_escort_target] and/or isolated targets (no ortho ally).
	PANIC_HUNGER_HIT = 5,
	## Enemy undead: non-bludgeoning death leaves a bone pile; unit reforms after N full battle turn increments (see [member BattleFieldSkeletonBonePileHelpers]).
	BONE_PILE_REFORM_ON_DEATH = 6,
}

@export var ability_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export var effect_kind: EffectKind = EffectKind.NONE

@export_category("Hit / panic tuning")
@export var hit_bonus: int = 0
@export var panic_civilian_hit_bonus: int = 15
@export var panic_isolated_hit_bonus: int = 10

@export_category("Fire tile (ashburst / ember wake)")
@export var fire_tile_damage: int = 1
@export var fire_tile_duration_turns: int = 1

@export_category("Bone pile reform (undead)")
## Battle turn increments before reform (enemy phase ticks); same meaning as legacy [member UnitData.bone_pile_reform_rounds].
@export var reform_after_battle_turn_increments: int = 2
## If true, killing blow with bludgeoning prevents bone pile / reform (skulls stay crushed).
@export var suppress_reform_if_bludgeoning_kill: bool = true

@export_category("Apply status on hit")
@export var status_id_to_apply: String = ""
@export var require_magic_weapon: bool = false
@export var require_tome_weapon_family: bool = false
## If true, only when attacker–defender Manhattan distance ≤ 1.
@export var require_adjacent_melee_range: bool = false
