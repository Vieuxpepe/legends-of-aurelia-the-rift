# Raiding — design & foundations

This folder holds **planning and verification** docs for the cooperative **raid** feature (fee, multi-player, large encounter). It is **not** loaded by the game at runtime.

| Doc | Purpose |
|-----|---------|
| [01_ABILITY_SYSTEM_VERIFICATION.md](01_ABILITY_SYSTEM_VERIFICATION.md) | How **passive** vs **active** abilities are implemented today, and why behavior can feel inconsistent (especially in **co-op**). |
| [02_RAID_FOUNDATIONS_PLAN.md](02_RAID_FOUNDATIONS_PLAN.md) | Phased **implementation plan**: solo raid loop → extended session → `BattleField` + Steam. |

When implementation starts, prefer new code under `Scripts/Raid/` and resources under `Resources/Raids/`, and keep this folder updated as decisions change.
