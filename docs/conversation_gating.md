# Conversation and content gating (camp)

Authoritative implementation: `Scripts/Narrative/CampConversationDB.gd` (`conversation_match_failure_reason`, `get_best_direct_conversation`) and `Scripts/Core/CampaignManager.gd` (`get_camp_conversation_story_flags`, `_is_camp_lore_flag_satisfied`, lore/pair snippet helpers).

## Direct conversations (`CampConversationDB`)

Entries are dictionaries in the `CONVERSATIONS` array. Selection for a walker uses **`primary_unit`** matching that unit’s name (normalized strip).

### Eligibility pipeline (all must pass)

1. **Script** — non-empty `script` array.
2. **`when`** — optional `when.time_block` must match context `time_block` (`dawn` / `day` / `night`) from `CampContext.build_camp_context_dict`.
3. **`req_level` / `max_progress_level`** — compared to context `progress_level` (= `CampaignManager.camp_request_progress_level`, floored at 0).
4. **`required_story_flags` / `forbidden_story_flags`** — keys looked up in context `story_flags` (see below).
5. **`moods`** — if present, current `camp_mood` must be listed.
6. **`preferred_visit_themes` / `avoided_visit_themes`** — compared to context `visit_theme` (derived in `CampContext.resolve_visit_theme`).
7. **`requires_units_present`** — each named unit (except `"commander"`) must appear in the current walker name list.
8. **Avatar relationship** — optional `req_min_relationship_tier` (tier ladder: stranger → known → trusted → close → bonded), or `req_relationship_tiers` exact match, via `CampaignManager.get_avatar_relationship_tier`.
9. **Personal arc** — optional `min_personal_arc_stage` / `max_personal_arc_stage` via `CampaignManager.get_personal_arc_stage`; optional `required_arc_flags` / `forbidden_arc_flags` via `has_arc_flag`.
10. **`once_ever`** — if true, id `CampaignManager.has_seen_camp_memory_scene(id)` must be false until played; completion calls `mark_camp_memory_scene_seen`.
11. **`once_per_visit`** — if true, id must be absent from `player_state.visit_consumed` (the visit snapshot from `CampDialogueController.get_direct_conversation_visit_snapshot`); completion sets `direct_conversations_shown_this_visit[id]`.

### Winner selection

Among matches, highest `score_conversation` wins: base `priority` plus visit-theme bonus for `preferred_visit_themes`. Tie-break: lexicographically smaller `id` if scores within `0.001`.

### On completion (`CampDialogueController.end_direct_conversation`)

- If the player picked a branch: `choice.effects.add_avatar_relationship` is applied via `apply_direct_conversation_effects`.
- If there were **no** choices: `effects_on_complete.add_avatar_relationship` is applied directly to the primary unit (same channel: `"camp_direct_conversation"`).
- `effects_on_complete` is always passed to `CampaignManager.apply_camp_direct_progression_effects`, which implements arc progression keys (`set_personal_arc_stage`, `advance_personal_arc_stage`, `set_arc_flag`, `clear_arc_flag`, `set_arc_flags`) and **ignores** `add_avatar_relationship` there (relationship is handled only in the two bullets above).
- `once_ever` → `mark_camp_memory_scene_seen(conv_id)`; `once_per_visit` → visit dictionary.

## Story flags in context (`get_camp_conversation_story_flags`)

`CampContext.build_camp_context_dict` merges:

- All true keys from `CampaignManager.encounter_flags`
- All true keys from `CampaignManager.battle_resonance_flags`
- Scripted thresholds from `_is_camp_lore_flag_satisfied` for: `shattered_sanctum_cleared`, `greyspire_hub_established`, `market_of_masks_cleared`, `dawnkeep_siege_cleared`, `echoes_of_the_order_cleared`, `gathering_storms_cleared`, `sunlit_trial_cleared` — either from `encounter_flags` or from **`camp_request_progress_level`** cutoffs (e.g. Greyspire at ≥6), as implemented in `CampaignManager`.

**Implication:** some gates are **progress-level proxies**, not only explicit encounter flags. Content authors must match those keys to avoid dead conversations.

## Camp lore (`CampLoreDB` + `CampaignManager.get_available_camp_lore`)

- Skips entries already in `seen_camp_lore`.
- Relationship threshold vs `get_avatar_relationship_tier` / `_tier_rank`.
- `requires_flags` / `forbidden_flags` use **`_is_camp_lore_flag_satisfied`** (same key rules as above).
- First matching entry wins; marking seen happens on dialogue close via `pending_lore_id` → `mark_camp_lore_seen`.

## Pair content (two systems)

| Mechanism | Data | Persistence | Trigger |
|-----------|------|-------------|---------|
| **Overhear / listen** | `CampPairSceneTriggerDB` | `once_ever` → camp memory scene id; `once_per_visit` → `pair_scenes_shown_this_visit` | Player in range, walkers close, `get_eligible_pair_scene` |
| **Snippet on talk** | `CampPairSceneDB` | `seen_camp_pair_scenes` when `one_time`; relationship thresholds `threshold_a` / `threshold_b` | `get_available_pair_scene_for_unit` inside `open_dialogue` |

Do not confuse **`camp_memory.seen_scene_ids`** with **`seen_camp_pair_scenes`** — different dictionaries and different flows.

## Special relationship scenes (non-`CampConversationDB`)

`CampRequestContentDB.get_special_camp_scene` for tiers `close` and `trusted`, gated by `CampaignManager.get_avatar_relationship_tier` and `special_camp_scenes_seen` / `has_seen_special_scene`. These run **before** direct conversations when request status allows side stories.

## Side stories vs active requests

`CampInteractionResolver._side_stories_allowed_for_request_status` returns false for `active`, `ready_to_turn_in`, and `failed`. While blocked, direct conversations, pair snippets, and lore **do not** open; quest-related lines take precedence when applicable.
