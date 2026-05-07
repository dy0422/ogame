# Milestones 4-6 Verification

Milestones 4 through 6 complete the first playable native macOS OGame sandbox slice: fleets and conflict, strategic progress, settings, save management, and final polish around offline catch-up.

## Expected Commands

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

All commands should complete successfully from the repository root.

## Fleet And Conflict

- Ship and defense construction use fast-skirmish rules, paid queue items, deterministic completion, and inventory updates.
- Fleet launch validates origin/target, mission, ships, cargo capacity, cargo resources, fuel, and travel duration before mutating the universe.
- Transport, recycle, explore, colonize, attack, espionage, and return phases resolve through the simulation tick and offline catch-up paths.
- Combat produces deterministic battle reports with participants, before/after units, losses, loot, debris, defense recovery, and relation memory.
- Espionage and exploration create reports without exposing unrelated hidden state or creating hostility memory.

## Strategic Sandbox

- Star map state groups owned, AI, neutral, and unknown systems, with debris and fleet contact markers.
- Exploration records are faction-scoped and feed exploration victory progress.
- Rankings summarize economy, fleet, research, planet, defense, and victory progress.
- Victory routes cover economy, technology, domination, and exploration; victory announces once and simulation continues afterward.
- A 24-hour offline stress scenario covers AI economy decisions, fleet resolution, reports, victory, and summarized event feed behavior in bounded chunks.

## Settings And Save Management

- Settings persist through save envelopes: offline intensity, game speed, autosave, and difficulty.
- Older saves default missing settings and strategic fields without schema drift.
- Autosave load failures keep saving disabled until a new game starts, protecting the existing save file.
- Save slots list autosave plus backups only, backup creation copies the current autosave, and backup deletion refuses non-backup names.
- Startup offline catch-up applies in memory and requires an explicit save before replacing persisted state.

## UI Polish

- The macOS shell remains a dense `NavigationSplitView` management app with dashboard, planets, fleets, star map, rankings, victory, relations, research, and settings.
- Dashboard and Victory views show a victory banner, including completed-victory state.
- Recent events and reports are grouped by type so combat, intelligence, exploration, economy, system, and victory activity scan cleanly.
- Empty states cover idle queues, missing saves, missing reports, missing relations, missing rankings, and unpopulated lists.
- Disabled save, advance, launch, queue, settings, backup, and delete controls expose state through disabled buttons and short help text.
- Compact text uses line limits, scaling, and wrapped detail lines to avoid overflow in the management shell.

## Known Simplifications

- The sandbox is single-player with deterministic AI factions, not a networked multiplayer server.
- Combat is intentionally compact and deterministic, not formula-parity with legacy PHP combat.
- Diplomacy is relation memory rather than full alliances, ACS, treaties, or messaging.
- The map is a curated fast-skirmish sector, not a full OGame universe scale.
- No moons, jump gates, missiles, phalanx, officers, premium economy, or marketplace loop are included.
- Save management is local JSON autosave/backups only; packaging and notarization are outside this milestone.
