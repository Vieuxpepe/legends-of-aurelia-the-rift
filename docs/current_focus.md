# Current development focus (repo snapshot)

This file is inferred from **code structure, recent edits, and inline documentation** in the workspace. It is not a product roadmap.

## Multi-agent coordination

- **Start here:** `docs/agent_master_handoff.md` (priorities, merge order, overlap).
- **Per agent:** `docs/agent1_systems.md`, `docs/agent2_narrative.md`, `docs/agent3_docs_qa.md`.

## What looks actively evolving

1. **Explore Camp narrative layer** — `Scripts/CampExplore.gd` and `Scripts/Camp/*.gd` (seven controller scripts) implement movement, ambient systems, dialogue UI, camp requests, pair overhears, and direct conversations.
2. **Authored camp content at scale** — `Scripts/Narrative/Camp*.gd` databases (`CampConversationDB` is the largest); gate mistakes affect eligibility across many lines.
3. **CampaignManager camp state** — `camp_request_*`, `camp_memory`, `seen_camp_lore`, `seen_camp_pair_scenes`, `camp_unit_condition`, and serialization blocks in `Scripts/Core/CampaignManager.gd` are the persistence backbone for the above.

## Parallel heavy work elsewhere

- **`REFACTOR_PULSE.md`** tracks **BattleField** extractions (`Scripts/Core/BattleField.gd` and helpers). That work is orthogonal to camp scripts but shares **CampaignManager** and battle → camp transitions; merges touching both need smoke tests for camp entry after battle.

## Systems that should not be destabilized casually

- **`CampInteractionResolver`** resolution order (documented in its file header) — prompts, `peek_walker_interaction_kind`, and `open_dialogue` must stay aligned; drift produces wrong “E Talk” vs quest flows.
- **Campaign save/load fields** for camp — adding keys requires updates to `save_game` / `load_game` / `reset_campaign_data` in `CampaignManager.gd` or content will reset or silently desync.
- **Autoload singleton contracts** — `CampaignManager`, `SceneTransition`, `ItemDatabase`, etc.; camp code assumes they exist at runtime.

## Stale or misleading repo docs (explicit)

- **`NARRATIVE PLAN/*.md`** is design/production prose; gate logic in shipped scripts (`get_camp_conversation_story_flags`, `_is_camp_lore_flag_satisfied`, `CampConversationDB`) is authoritative for eligibility.
