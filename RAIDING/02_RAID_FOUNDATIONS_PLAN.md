# Raid foundations — implementation plan (draft)

**Goal:** Design and later implement a **fee-based cooperative raid**: large battle map, **raid boss + adds**, up to **4 human players**, **2 controllable units per player** (one **must** be the player’s custom avatar; the other **any roster unit**), using **Steam** where helpful.

This file is the **architecture / sequencing** plan. It assumes the codebase state described in `01_ABILITY_SYSTEM_VERIFICATION.md` (especially co-op + active-ability limitations).

---

## Phase 0 — Product locks (decide once, avoid rework)

| Decision | Options | Notes |
|----------|---------|--------|
| Authority | Host-authoritative battle vs relay server | Steam P2P + host is the smallest step; dedicated headless server is a different product. |
| Turn model | Strict I-go-you-go vs phase-based shared player phase | Current SRPG is likely sequential; 4×2 units exaggerates wait time — consider **sub-phase** (each player acts twice?) or **simultaneous planning** later. |
| Failure | Wipe = fee lost? Retry token? | Affects economy and toxicity. |
| Matchmaking | Steam Lobby + friends-only first | Fastest path after LAN; public matchmaking is extra UX + abuse surface. |

---

## Phase 1 — Content & economy (no new netcode)

1. **Raid definition resource** (new): `raid_id`, `entry_fee_gold`, `min_players`, `max_players` (=4), `battlefield_scene` or `encounter_id`, `return_scene`, `loot_table_id`, `unlock_flag` (campaign progress).
2. **CampaignManager** (or new `RaidProgressService`): persist `raids_completed`, `free_weekly_entry`, etc., in save dict — mirror patterns used for `narrative_beats_seen` / expedition flags.
3. **Fee transaction:** atomic check + deduct gold (or item cost) **before** scene handoff; on disconnect before battle start, define refund policy.
4. **Encounter / map:** one authored “raid” layout: boss unit(s) + spawn tables; reuse existing enemy / boss `UnitData` where possible.

**Exit criterion:** Solo player can pay fee, load raid map, beat encounter, get rewards, return to hub — **no multiplayer**.

---

## Phase 2 — Session model (extend co-op, still 2 players if needed first)

**Current baseline (from prior exploration):** `CoopExpeditionSessionManager` is **two-role** (`HOST` / `GUEST`), ENet-style transport, battle RNG lock, handoff into `BattleField`.

### 2a. Minimum viable raid party (recommended stepping stone)

- **2 players**, each brings **2 units** → **4 player-side units** on the map (fits “small raid” feel, less sync than 4×2).
- Session payload extended from `local_player_payload` / `remote_player_payload` to structured **per-player roster slice**: `{ "commander_id", "avatar_unit_ref", "partner_unit_ref" }` (exact wire format TBD — JSON-safe, path strings to `UnitData` or stable instance ids).

### 2b. Full 4-player party

- Generalize session to **N peers** (1 host + 3 guests), or **star topology** (all guests connect to host).
- **Lobby:** Steam Lobby API — create/join, metadata (`raid_id`, `fee_paid`, `ready`), host migration policy (host disconnect = abort or migrate).
- **Ready gate:** all clients acknowledge same `raid_id` + seed + roster before `SceneTransition` to battle.

**Exit criterion:** LAN or Steam friends: 2–4 players sit in lobby, ready-up, host launches raid scene with agreed handoff package.

---

## Phase 3 — Battlefield integration

1. **Spawn layout:** deterministic slots for each player’s two units (config on raid resource). Avatar slot enforced by validation on host.
2. **Command ownership:** map `unit_instance_id` → `steam_id` (or local seat index). Input ignored for units not owned by local seat (except host debug).
3. **Turn / action sync:** extend existing `BattleFieldCoop*` snapshot / delegation paths:
   - Today: guest delegation + **data-driven actives disabled** on guest (see ability verification doc).
   - **Raid requirement:** either replicate actives + strike outcomes, or **restrict raid** to weapon attacks until fixed — document explicitly.
4. **Enemy AI:** run **only on host**; broadcast resulting HP / positions / deaths; guests apply authoritative deltas (already directionally similar to coop helpers).

**Exit criterion:** Full raid fight completes with 2+ humans without desync on happy path; host migration still optional.

---

## Phase 4 — Steam-specific

- **Rich Presence** (already in `SteamService`): optional tokens `InRaid`, `RaidLobbyOpen`.
- **Lobbies:** create with `max_members = 4`, set joinable flag, expose `connect` / invite UI from camp or main menu.
- **Networking:** Steam’s relay / P2P session for packet transport **or** keep ENet if everyone uses IP (worse for consumers). GodotSteam APIs wrap this — implementation detail in `Scripts/Coop/` new transport implementing `CoopSessionTransport` (`set_transport` already exists on `CoopExpeditionSessionManager`).

**Exit criterion:** Two households can complete a raid without manual port forwarding.

---

## Phase 5 — UX & ops

- Raid browser UI, fee display, insufficient funds handling, disconnect mid-raid messaging, post-raid scoreboard / loot reveal.
- Telemetry hooks (optional): duration, wipes, ability usage counts — helps balance **after** ability systems are consistent in co-op.

---

## Folder layout (suggested when coding starts)

```
RAIDING/                    ← design docs (this tree)
Scripts/Raid/               ← new code (autoload optional: RaidService.gd)
Resources/Raids/            ← RaidDefinition.tres + tables
```

Keep **design** in `RAIDING/` and **shippable resources** under `res://Resources/` per project conventions.

---

## Risk register (short)

| Risk | Mitigation |
|------|------------|
| Actives broken for guests | Fix delegation + active replication **before** marketing raid actives. |
| 8 units × animations × VFX | Cap VFX, LOD, or raid-specific simplified rules for turn 1. |
| Save exploits (fee duping) | Fee deduct only on host commit; server validates roster hashes. |
| Steam review / disconnect | Clear “host left = raid ended” copy + optional reconnect window (hard). |

---

## Suggested order of implementation

1. `01` ability / co-op gaps acknowledged in task tracker.  
2. Phase 1 solo raid loop.  
3. Phase 2 two-player × two units.  
4. Phase 3 battle sync hardening + active ability co-op fix in parallel.  
5. Phase 4 Steam lobby + relay.  
6. Scale to 4 players × 2 units + polish.

---

*End of raid foundations plan.*
