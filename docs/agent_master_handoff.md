# Agent master handoff (coordination)

**Source of truth for camp runtime:** `docs/camp_system.md`, `docs/conversation_gating.md`, and the scripts they name.

**Rule:** After any merge that touches camp or `CampaignManager` camp fields, update the **Latest completed** lines below and skim `docs/camp_regression_checklist.md` for the affected areas.

**Reading / editing:** Each agent reads `docs/agent_master_handoff.md` plus **only** its own `agent1_systems.md` / `agent2_narrative.md` / `agent3_docs_qa.md`. Do **not** edit another agent’s handoff file (those three); use `agent_master_handoff.md` or out-of-band coordination for cross-agent notes.

## Current priorities (shared)

1. Keep **interaction resolution** consistent (`CampInteractionResolver` — four functions in one file header).
2. Avoid desync between **pair overhear** (`camp_memory` / trigger DB) and **pair snippets** (`seen_camp_pair_scenes` / `CampPairSceneDB`).
3. Any new **persisted** camp field → `CampaignManager` save, load, and `reset_campaign_data`.

## Branch ownership (by file area)

| Agent | Primary ownership |
|-------|-------------------|
| **Agent 1 — Systems** | `Scripts/CampExplore.gd`, `Scripts/Camp/*.gd`, camp-related scenes that only wire UI/movement (coordinate if shared with narrative). |
| **Agent 2 — Narrative** | `Scripts/Narrative/CampConversationDB.gd`, `CampLoreDB`, `CampPairSceneDB`, `CampPairSceneTriggerDB`, `CampRumorDB`, `CampMicroBarkDB`, `CampAmbientChatterDB`, `CampAmbientSocialDB`, `CampRequestContentDB` (content), `CampRequestDB`, `CampBehaviorDB`, `CampRoutineDB`, `NARRATIVE PLAN/` (reference only). |
| **Agent 3 — Docs / QA** | `docs/*`, `README.md` camp links, checklist maintenance; does **not** own gameplay code unless fixing doc-driven inaccuracies. |

**Shared / merge-hot:** `Scripts/Core/CampaignManager.gd` (camp persistence, flags, requests, memory). Prefer **Agent 1** for structural/API changes; **Agent 2** for flag/key semantics tied to content; **Agent 3** documents outcomes.

## Merge order (when conflicts)

1. **CampaignManager** persistence / API shape (Agent 1 + narrative review if keys change).
2. **Camp controllers** (`Scripts/Camp/*`, `CampExplore.gd`).
3. **Narrative DB** content batches (Agent 2).
4. **Docs** last (Agent 3) so they match merged behavior.

## Known overlap risks

- **`get_camp_conversation_story_flags` / `_is_camp_lore_flag_satisfied`** — Agent 2 content keys must match Agent 1 / Manager implementation.
- **Battle → camp** — `BattleField` / `REFACTOR_PULSE.md` work touches `CampaignManager`; camp entry after battle is a smoke-test intersection.
- **Offer giver selection** — `CampSpawnController` + `CampRequestDB`; both systems and narrative DBs can affect feel/eligibility.

## Latest completed task (not in git — update manually)

| Agent | Last completed (describe + PR/branch if any) |
|-------|-----------------------------------------------|
| Agent 1 | **Pass 1 — weapon rune persistence** (`727d1e4`, `4fbcc04`): item serialization for `rune_slot_count` / `socketed_runes`, `duplicate_item` / `make_unique_item`, equipped + camp shop + co-op wire + mock co-op roster hydrate. **Rune unlock-gating foundation** (`3585e5a`): persists `runesmithing_unlock_tier` (0 locked, 1 basic, 2 advanced); getters/setters + `is_runesmithing_unlocked` / `has_advanced_runesmithing`. **Rune tier from camp progress:** `raise_runesmithing_unlock_tier_to_at_least`, `_sync_runesmithing_unlock_tier_from_camp_progress` — basic at `camp_request_progress_level >= 6`, advanced at `>= 11`; sync after `load_game` (older saves catch up) and in `load_next_level` after `camp_request_progress_level += 1`. Monotonic; **not** `blacksmith_unlocked` (unchanged). No UI wiring; no combat enablement changes. |
| Agent 2 | *— update after merge —* |
| Agent 3 | *— update after merge —* |
