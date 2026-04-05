# Explore Camp — manual regression checklist

Run in a **debug** build when you need F9 diagnostics or `CampExplore` debug prints. Use a save that has roster variety, mid-campaign progress, and optionally an active camp request.

## Entry / shell

- [ ] From camp menu, **Explore Camp** loads walkable scene; **Back** returns to `camp_menu`.
- [ ] **Esc** / cancel action returns to camp menu when dialogue is closed.
- [ ] **Movement** clamps inside bounds; music starts (if `CampMusic` + tracks present).
- [ ] **J** / `ui_task_log` / `camp_task_log` opens task log when implemented; movement/input does not fight dialogue.

## Interact prompts

- [ ] Near walker with **quest priority**: prompt shows **E Hear them out** / **E Turn in** / **E Quest update** / **E Quest: speak** per `CampInteractionResolver.get_interact_prompt_primary_line`.
- [ ] When a pair overhear is eligible and single-walker priority does **not** override: prompt shows **E Listen**.
- [ ] Generic talk: **E Talk** / **E Request offered** when applicable.
- [ ] Left-click on walker within range triggers same resolution as keyboard interact.

## Pair overhear (trigger DB)

- [ ] With two eligible units positioned within trigger `pair_radius` and player within `PAIR_LISTEN_RADIUS` (~120), **Listen** starts line-by-line playback; **Continue** advances; wander pauses resume on end.
- [ ] `once_per_visit` trigger does not re-fire same id after completion until a **new** explore visit (new `CampExplore._ready`).
- [ ] `once_ever` trigger does not repeat after completion across saves (camp memory `seen_scene_ids`).
- [ ] After overhear, pair **familiarity/tension/last_visit_spoke** update via `record_pair_scene_completion` when scene data provides grants.

## Camp requests

- [ ] **Offer**: unit with `offer` marker (or `offer_personal`) shows offer panel; **Accept** sets `camp_request_status` active and clears offer marker; **Decline** sets `camp_request_unit_next_eligible_level` and recent giver list.
- [ ] While `camp_request_status` is `active`, `ready_to_turn_in`, or `failed`, stale `offer_giver_name` / `pending_offer` must not surface: no **E Request offered**, no `request_offer` resolution, no unrelated offer panel (`CampInteractionResolver` gating).
- [ ] **Item delivery**: progress line shows counts; when satisfied, giver promotes to turn-in; **Turn in** removes items, awards gold/affinity, clears request state.
- [ ] **Talk-to-unit**: speaking to target at progress 0 advances to ready_to_turn_in (or branching if `branching_check`); branching success/fail updates status and markers.
- [ ] **Failed** request: giver shows failure reaction; state clears; relationship penalty paths execute as authored.
- [ ] `validate_camp_request_roster`: if giver or target missing from spawned walkers, request state clears without soft-lock.

## Direct conversations (`CampConversationDB`)

- [ ] With no blocking request, eligible unit opens scripted lines; **Commander** label uses `CampaignManager.custom_avatar.unit_name` when set.
- [ ] Branching: at `branch_at`, choice buttons appear; **Continue** hidden until choice; response lines play; **Close** ends session.
- [ ] **`once_ever`**: after full completion, conversation does not reappear on future visits/saves.
- [ ] **`once_per_visit`**: can fire again next explore session; same visit cannot consume twice.
- [ ] Effects: relationship changes and `effects_on_complete` arc flags / stage changes persist (verify in save or follow-up dialogue gates).

## Pair snippets vs lore (single talk)

- [ ] With side stories allowed, if no higher-priority line fires, **pair snippet** shows `CampPairSceneDB` text; closing dialogue marks `seen_camp_pair_scenes` when `one_time`.
- [ ] **Lore** snippet marks `seen_camp_lore` on close; next talk does not repeat same lore id.
- [ ] Order preserved: special scene → direct conv → pair snippet → lore → offer → idle (per `open_dialogue`).

## Ambient layer

- [ ] Rumor label can appear near zones/units; does not overlap critical dialogue (bubble hidden while `dialogue_active`).
- [ ] Micro-barks / chatter / social events eventually fire with pacing; no runaway spam after long idle (spot-check ~3–5 minutes).

## Persistence (save / load)

- [ ] After completing **once_ever** direct conv or pair overhear, **save** and **load**: content stays consumed.
- [ ] `seen_camp_lore`, `seen_camp_pair_scenes`, `camp_memory`, `camp_unit_condition`, `camp_request_progress_level`, and request fields restore; explore session visit-only flags reset (new visit can use `once_per_visit` again).
- [ ] Load older save: `load_game` infers some story flags from `camp_request_progress_level` (see `CampaignManager` load path) — spot-check conversations that depend on those flags.

## Rune-capable weapon persistence (Pass 1 scaffolding)

Use a **rune-capable** `WeaponData` (non-zero `rune_slot_count`, at least one socketed rune). Exercise only **Pass 1** surfaces below.

- [ ] **Save / load:** After save + load, weapon still has correct `rune_slot_count` and `socketed_runes` (count respected; no truncation beyond slot cap — see `CampaignManager._serialize_socketed_runes_for_item` / deserialize).
- [ ] **`duplicate_item` / `make_unique_item`:** Duplicated weapon keeps rune socket state independent of the source (no shared mutation when editing one copy).
- [ ] **Equipped weapon restore:** Unit with runed weapon equipped: after load, equipped weapon matches pre-save rune state (path goes through `make_unique_item` / weapon hydrate in `CampaignManager` load).
- [ ] **Camp shop stock restore:** If shop stock includes a runed weapon instance, after load the same item (or equivalent deserialized instance) retains sockets/runes (`camp_shop_stock` load path).
- [ ] **Co-op wire / mock handoff:** Items rebuilt from co-op wire data (e.g. `BattleFieldCoopHelpers.coop_wire_deserialize_items` string-path branch using `duplicate_item`) preserve rune fields when the template loads as `WeaponData`.

## Injury / fatigue / visit theme

- [ ] Units with camp condition **injured/fatigued** show appropriate walker visuals if implemented.
- [ ] `resolve_visit_theme` shifts toward **recovery** when roster has injured/fatigued; **tense** when request active/ready — spot-check ambient or DB lines that depend on `visit_theme`.

## Debug (optional)

- [ ] Set `CampExplore.DEBUG_CAMP_SELECTION_DUMP := true`, F9 near walker: console prints direct conv and micro-bark debug reports without crash.
