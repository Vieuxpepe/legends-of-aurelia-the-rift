# Agent 1 — Systems (camp + camp-facing core)

## Owned scope

- **Explore Camp runtime:** `Scripts/CampExplore.gd`
- **Camp controllers:** `Scripts/Camp/CampContext.gd`, `CampSpawnController.gd`, `CampRequestController.gd`, `CampDialogueController.gd`, `CampInteractionResolver.gd`, `CampAmbientDirector.gd`, `CampBubbleController.gd`
- **Shared singleton:** `Scripts/Core/CampaignManager.gd` — camp request fields, `camp_memory`, `seen_camp_lore`, `seen_camp_pair_scenes`, `camp_unit_condition`, `get_camp_conversation_story_flags`, save/load for those keys, `apply_camp_direct_progression_effects`, pair/lore helpers used by camp UI; rune item serialization + persisted `runesmithing_unlock_tier` synced from `camp_request_progress_level` (separate from `blacksmith_unlocked`)

## Touched files (typical edits)

- Above `.gd` paths; optionally `Scenes/` for camp explore / walker if wiring changes
- **Avoid** large edits to narrative DB `.gd` files unless fixing a bug Agent 2 cannot do without you (coordinate first)

## Current task

**Rune tier progression hooks merged:** `_sync_runesmithing_unlock_tier_from_camp_progress` + `raise_runesmithing_unlock_tier_to_at_least` (basic ≥6, advanced ≥11 on `camp_request_progress_level`); runs on `load_game` after tier restore and in `load_next_level` after `camp_request_progress_level` bumps. No UI/combat enablement wiring yet; `blacksmith_unlocked` unchanged.

## Blockers

*— fill in —*

## Touched this sprint

- `Scripts/Camp/CampInteractionResolver.gd` — blocked stale `offer_giver_name` / `pending_offer` from surfacing during `active` / `ready_to_turn_in` / `failed`; aligned peek, `would_single_walker_priority`, and `open_dialogue` so prompt priority and dialogue open match.
- `Scripts/Core/CampaignManager.gd` — `runesmithing_unlock_tier` persisted; `get_runesmithing_unlock_tier` / `set_runesmithing_unlock_tier` / `is_runesmithing_unlocked` / `has_advanced_runesmithing` (`3585e5a`; independent of `blacksmith_unlocked`).
- `Scripts/Core/CampaignManager.gd` — camp-progress sync for runesmithing tier (`load_next_level` after `camp_request_progress_level += 1`, `load_game` after persisted tier load); `raise_runesmithing_unlock_tier_to_at_least` / `_sync_runesmithing_unlock_tier_from_camp_progress`.

## Merge risks

- **`CampInteractionResolver`:** changing one of `peek_walker_interaction_kind`, `would_single_walker_priority`, `get_interact_prompt_primary_line`, or `open_dialogue` without updating the others breaks prompts vs behavior.
- **`CampaignManager` save/load:** missing a key = lost camp progress or stale flags.
- **Ambient ↔ dialogue:** `CampDialogueController.bind_pacing_ambient` couples `CampAmbientDirector` to pair listen scoring.

## Next recommended systems task

- Run one **explore camp** smoke after any `CampaignManager` or `CampInteractionResolver` change; verify prompts match `open_dialogue` (see `docs/camp_regression_checklist.md`).
