# Legends of Aurelia: The Rift

Godot 4.6 tactical RPG project (`config/name` and `config/version` in `project.godot`). Main entry scene: `res://Scenes/studio_intro.tscn`.

## Documentation

| Doc | Purpose |
|-----|---------|
| [docs/current_focus.md](docs/current_focus.md) | What is actively changing vs stable |
| [docs/camp_system.md](docs/camp_system.md) | Explore Camp runtime architecture |
| [docs/conversation_gating.md](docs/conversation_gating.md) | Direct conversations, lore, pair content gates |
| [docs/camp_regression_checklist.md](docs/camp_regression_checklist.md) | Manual QA for camp iteration |

## Repo map (high level)

- **Campaign / meta:** `Scripts/Core/CampaignManager.gd` (autoload), saves, roster, camp request state, camp memory, lore/pair scene flags.
- **Explore Camp scene:** `Scripts/CampExplore.gd` plus `Scripts/Camp/*.gd` controllers.
- **Authored camp narrative data:** `Scripts/Narrative/CampConversationDB.gd`, `CampLoreDB`, `CampPairSceneDB`, `CampPairSceneTriggerDB`, `CampRumorDB`, `CampMicroBarkDB`, etc.
- **Ongoing refactor notes:** `REFACTOR_PULSE.md` (BattleField extraction — not camp-specific).
- **Design / production writing:** `NARRATIVE PLAN/` (may drift from shipped gates; verify against code when gating content).

## Editor addons

This project enables third-party editor plugins (see `project.godot` → **EditorPlugins**). The **Copy All Errors** addon adds debugger utilities; it is not the game product described by this repository.

## License

See repository `LICENSE` if present.
