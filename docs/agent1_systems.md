# Agent 1 — Systems (camp + camp-facing core)

## Owned scope

- **Explore Camp runtime:** `Scripts/CampExplore.gd`
- **Camp controllers:** `Scripts/Camp/CampContext.gd`, `CampSpawnController.gd`, `CampRequestController.gd`, `CampDialogueController.gd`, `CampInteractionResolver.gd`, `CampAmbientDirector.gd`, `CampBubbleController.gd`
- **Shared singleton:** `Scripts/Core/CampaignManager.gd` — camp request fields, `camp_memory`, `seen_camp_lore`, `seen_camp_pair_scenes`, `camp_unit_condition`, `get_camp_conversation_story_flags`, save/load for those keys, `apply_camp_direct_progression_effects`, pair/lore helpers used by camp UI

## Touched files (typical edits)

- Above `.gd` paths; optionally `Scenes/` for camp explore / walker if wiring changes
- **Avoid** large edits to narrative DB `.gd` files unless fixing a bug Agent 2 cannot do without you (coordinate first)

## Current task

*— fill in per sprint —*

## Blockers

*— fill in —*

## Touched this sprint

*— none —*

## Merge risks

- **`CampInteractionResolver`:** changing one of `peek_walker_interaction_kind`, `would_single_walker_priority`, `get_interact_prompt_primary_line`, or `open_dialogue` without updating the others breaks prompts vs behavior.
- **`CampaignManager` save/load:** missing a key = lost camp progress or stale flags.
- **Ambient ↔ dialogue:** `CampDialogueController.bind_pacing_ambient` couples `CampAmbientDirector` to pair listen scoring.

## Next recommended systems task

- Run one **explore camp** smoke after any `CampaignManager` or `CampInteractionResolver` change; verify prompts match `open_dialogue` (see `docs/camp_regression_checklist.md`).
