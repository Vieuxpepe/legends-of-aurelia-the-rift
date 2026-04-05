extends Resource
class_name CombatStatusData

## Canonical id stored on units ([code]combat_statuses[].id[/code]) and in co-op [code]cstat[/code] wire.
@export var status_id: String = ""

@export var display_name: String = ""
@export_multiline var description: String = ""

## Max stacks for this status (1 = no stacking). Use a high value (e.g. 99) for effectively unlimited stacks.
@export var stack_cap: int = 1

## When the status is cleared automatically at the start of the unit’s next activation ([method Unit.reset_turn]).
@export var expires_next_activation: bool = false

@export_category("UI")
## Short tag shown in the tactical unit strip (uppercased in UI if you use the default formatter).
@export var hud_tag: String = ""
## BBCode color name or [code]#RRGGBB[/code] for RichTextLabel badges.
@export var hud_bbcode_color: String = "silver"
## Hover-tooltip grouping for battlefield status columns.
@export_enum("debuff", "buff") var hover_group: String = "debuff"
## Shown in the tactical unit’s status icon row when set; leave empty to omit on the map.
@export var tactical_icon: Texture2D
