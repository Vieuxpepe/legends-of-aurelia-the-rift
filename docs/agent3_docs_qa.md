# Agent 3 — Docs / QA

## Owned scope

- **`docs/`** coordination and camp docs: `agent_master_handoff.md`, `agent1_systems.md`, `agent2_narrative.md`, this file, `current_focus.md`, `camp_system.md`, `conversation_gating.md`, `camp_regression_checklist.md`
- **Root `README.md`** — project overview and links into `docs/` (not gameplay logic)
- **QA process:** maintain checklist accuracy vs code; no feature code unless fixing a documentation-only mistake that requires a one-line comment in code (rare)

## Docs created/updated (log — maintain)

- Pass 1 rune persistence: `agent_master_handoff.md` (Agent 1 completed row), `agent3_docs_qa.md`, `camp_regression_checklist.md` (rune weapon regression section).

## Touched this sprint

- `docs/agent_master_handoff.md`, `docs/agent3_docs_qa.md`, `docs/camp_regression_checklist.md` — Pass 1 rune persistence QA / handoff refresh.

## Architecture risks (watchlist)

1. Two pair pipelines (overhear vs snippet) — easy to document or test the wrong one.
2. `CampInteractionResolver` four-way alignment — regressions are UX-breaking but localized.
3. `CampaignManager` god-object for camp persistence — highest blast radius for save bugs.
4. Story flags from **progress level** vs **encounter_flags** — content writers can assume wrong source.

## Current QA priorities

- **Pass 1 rune weapons:** run `camp_regression_checklist.md` → **Rune-capable weapon persistence (Pass 1)** after any `CampaignManager` item serialize / `duplicate_item` / co-op wire changes.
- After Agent 1 or Manager changes: **prompts + open_dialogue + save/load** rows in `camp_regression_checklist.md`.
- After Agent 2 bulk content: **once_ever / once_per_visit** and branching completion for one sample conversation per batch.

## Next recommended docs/QA task

- Update **`docs/agent_master_handoff.md`** “Latest completed” table after each agent merge; keep `camp_system.md` / `conversation_gating.md` in sync if APIs or gates change.
