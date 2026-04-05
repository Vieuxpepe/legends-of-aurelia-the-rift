# Agent 2 — Narrative (camp-authored data)

## Owned scope

- **Direct conversations:** `Scripts/Narrative/CampConversationDB.gd` (`CONVERSATIONS`, `conversation_match_failure_reason` contract)
- **Lore / pair / ambient data:** `CampLoreDB`, `CampPairSceneDB`, `CampPairSceneTriggerDB`, `CampRumorDB`, `CampMicroBarkDB`, `CampAmbientChatterDB`, `CampAmbientSocialDB` (paths under `Scripts/Narrative/` unless otherwise placed)
- **Request / explore copy hooks:** `CampRequestContentDB`, `CampRequestDB`, `CampExploreDialogueDB`, `CampDirectTalkProgressionDB`, `CampBehaviorDB`, `CampRoutineDB` as used by camp spawn/dialogue
- **Design reference:** `NARRATIVE PLAN/` — not authoritative for gates; verify against `docs/conversation_gating.md` and code

## Touched files (typical edits)

- Large dictionary/array content in the DB scripts above; minimal logic changes unless adding a new gate field **already supported** by `CampConversationDB` / `CampaignManager`

## Current content batch

*— e.g. “Kaelen arc dc_* pass” — fill in —*

## Gating / continuity notes

- **Story flags** in context come from `CampaignManager.get_camp_conversation_story_flags()` — includes `encounter_flags`, `battle_resonance_flags`, and progress-level thresholds via `_is_camp_lore_flag_satisfied` (see `docs/conversation_gating.md`).
- **`once_ever`** uses **camp memory** scene ids (`mark_camp_memory_scene_seen`); **pair snippets** use **`seen_camp_pair_scenes`** — different storage.
- **`req_level`** uses `camp_request_progress_level`, not map index directly unless you align keys with Manager.
- Side stories **blocked** while camp request is `active`, `ready_to_turn_in`, or `failed` (`CampInteractionResolver._side_stories_allowed_for_request_status`).

## Blockers

*— fill in —*

## Touched this sprint

*— none —*

## Next recommended narrative batch

- Pick one **primary_unit** or one **story_flag milestone**; run eligibility mentally against `conversation_gating.md`; use `CampExplore.DEBUG_CAMP_SELECTION_DUMP` + F9 in-engine when debugging selection.
