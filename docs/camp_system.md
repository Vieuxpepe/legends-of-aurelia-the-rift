# Explore Camp system architecture

## Coordination

Parallel work: `docs/agent_master_handoff.md`, `docs/agent1_systems.md`, `docs/agent2_narrative.md`, `docs/agent3_docs_qa.md`. Regression: `docs/camp_regression_checklist.md`.

## Scene entry

- **Scene:** Camp explore is a walkable `Node2D` driven by `Scripts/CampExplore.gd` (header comment: entered from `camp_menu` via “Explore Camp”; Back/Esc returns to `res://Scenes/camp_menu.tscn` via `SceneTransition.change_scene_to_file`).
- **Composition:** `CampExplore` constructs ref-counted controllers in `_ready()` and wires UI nodes with `get_node_or_null` (player, walkers, dialogue panel, music, etc.).

## Controller responsibilities

| Component | Script | Role |
|-----------|--------|------|
| **Context** | `Scripts/Camp/CampContext.gd` | Walk bounds, walker list, camp zones, `active_time_block`, `active_camp_mood`, `visit_theme`; builds the dictionary passed to narrative DBs (`build_camp_context_dict`); pair stat helpers delegate to `CampaignManager`. |
| **Spawn** | `Scripts/Camp/CampSpawnController.gd` | Gathers `camp_behavior_zone` nodes, spawns player and `CampRosterWalker` instances from roster (or debug test roster), assigns behavior from `CampBehaviorDB` + `CampRoutineDB`, picks per-visit **request offer giver** when no active request. |
| **Requests** | `Scripts/Camp/CampRequestController.gd` | Reads/writes `CampaignManager.camp_request_*`, validates giver/target against spawned walkers, request markers on walkers, accept/decline/turn-in, inventory counting for item delivery. |
| **Dialogue** | `Scripts/Camp/CampDialogueController.gd` | Dialogue panel, branching request challenges, **pair overhear** playback, **direct conversations** from `CampConversationDB`, lore/pair snippets, idle lines; visit-local dictionaries for pair/direct repeat limits. |
| **Interactions** | `Scripts/Camp/CampInteractionResolver.gd` | Single-walker priority vs pair listen; `open_dialogue` branching order (requests → special scenes → direct conv → pair snippet → lore → offer → idle). |
| **Ambient** | `Scripts/Camp/CampAmbientDirector.gd` | Rumors, micro-barks, chatter, spontaneous social; pacing hooks into pair listen scoring via `CampDialogueController.bind_pacing_ambient`. |
| **Bubbles** | `Scripts/Camp/CampBubbleController.gd` | Positions/hides ambient speech UI. |

## Major interaction paths

1. **Pair listen (“E Listen”)** — `CampExplore._try_interact` / click path: if `CampDialogueController.get_eligible_pair_scene()` is non-empty and the nearest walker does **not** win single-walker priority, `start_pair_scene` runs. Eligibility uses `CampPairSceneTriggerDB` plus proximity, zones, familiarity, visit theme scoring, and ambient pacing adjustments.
2. **Single walker (“E Talk”)** — `CampInteractionResolver.open_dialogue` selects among camp request flows, `CampRequestContentDB` special scenes, `CampConversationDB` direct conversation, `CampaignManager.get_available_pair_scene_for_unit` (snippet), `CampaignManager.get_available_camp_lore`, pending offer, then `CampExploreDialogueDB` idle.
3. **Camp requests** — Offer appears when `CampSpawnController` sets `CampRequestController.offer_giver_name` from `CampRequestDB.get_offer` scoring; accept/decline/turn-in buttons on the dialogue panel call back into `CampExplore` → `CampRequestController`.

## Where state comes from

| State | Source |
|-------|--------|
| Roster / gold / inventory | `CampaignManager` |
| Camp request fields | `CampaignManager.camp_request_*` |
| Direct conv **once_ever** | `CampaignManager.camp_memory["seen_scene_ids"]` via `has_seen_camp_memory_scene` / `mark_camp_memory_scene_seen` |
| Direct conv **once_per_visit** | `CampDialogueController.direct_conversations_shown_this_visit` (snapshot passed into `CampConversationDB`) |
| Pair **overhear** once_per_visit | `CampDialogueController.pair_scenes_shown_this_visit` |
| Pair **overhear** once_ever (when flagged) | Same **camp memory** scene ids as direct conv (`mark_camp_memory_scene_seen` in `record_pair_scene_completion`) |
| **Pair snippets** (talk-to-unit) | `CampaignManager.seen_camp_pair_scenes` via `has_seen_pair_scene` / `mark_pair_scene_seen` |
| **Lore** | `CampaignManager.seen_camp_lore` |
| Visit index (pair stats, pacing) | `CampaignManager.camp_memory["visit_index"]` incremented in `CampExplore._ready` via `increment_camp_visit` |
| Injury/fatigue for camp | `CampaignManager.camp_unit_condition` + `is_unit_injured` / `is_unit_fatigued`; updated on explore load (`ensure_camp_unit_condition`, `advance_camp_condition_recovery_on_visit`, `apply_post_battle_camp_condition`) |
| Story flags for DBs | `CampaignManager.get_camp_conversation_story_flags()` merged into context in `CampContext.build_camp_context_dict` |

## Related data files (non-exhaustive)

- `Scripts/Narrative/CampConversationDB.gd` — direct (E) conversations and branching.
- `Scripts/Narrative/CampPairSceneTriggerDB.gd` — overhear pair triggers (referenced from `CampDialogueController`).
- `Scripts/Narrative/CampPairSceneDB.gd` — pair snippets for unit talk (referenced from `CampaignManager.get_available_pair_scene_for_unit`).
- `CampLoreDB`, `CampRumorDB`, `CampMicroBarkDB`, `CampAmbientChatterDB`, `CampAmbientSocialDB` — ambient and lore.

## Debug hooks

- `CampExplore.DEBUG_CAMP_SELECTION_DUMP` + F9: prints `CampConversationDB.build_direct_conversation_debug_report` and micro-bark report for nearest walker.
