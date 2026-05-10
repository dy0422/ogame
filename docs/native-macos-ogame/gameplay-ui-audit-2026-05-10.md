# Gameplay and UI Audit - 2026-05-10

## Reference Baseline

Sources reviewed:

- Chinese Wikipedia OGame overview: https://zh.wikipedia.org/wiki/OGame
- OGame Wiki / Fandom OGame overview: https://ogame.fandom.com/wiki/OGame
- OGame Wiki / Fandom fleet missions: https://ogame.fandom.com/wiki/Fleet
- OGame Wiki / Fandom alliance cooperation: https://ogame.fandom.com/wiki/Alliance

The important design baseline is that OGame is not only an economy builder. Its long-running appeal comes from the loop between resource production, energy constraints, research unlocks, fleet missions, colonization, debris recovery, scouting, combat reports, moons, and alliance-style cooperation.

## Current Strengths

- The native macOS version already has a broad single-player foundation: real-time ticks, offline catch-up, resources, queues, fleet missions, combat, exploration, colonization, moons, ACS-like holds, diplomacy pressure, AI factions, and victory routes.
- The UI is already localized and structured around macOS-native navigation: dashboard, planets, fleet, research, star map, rankings, relations, and settings.
- The game has moved beyond a prototype. Most remaining value is in making the systems easier to understand, more replayable, and more strategically legible.

## Key Gaps

1. The game has enough mechanics, but the dashboard does not always explain what deserves attention next.
2. OGame-style economy pressure should be visible before the player notices losses: energy deficit, full storage, idle construction, idle research.
3. Fleet play has more systems than the UI currently surfaces. Players need prompts for debris recovery, colonization windows, expedition slots, and fleet safety.
4. The single-player version should translate multiplayer habits into readable solo goals: scouting, timing, safe fleet movement, colony specialization, and response to AI threat.
5. Combat depth is partly implemented, but reports and post-battle recommendations should become more replayable and educational.
6. Alliance and ACS mechanics exist as systems, but still need stronger UI affordances and scenario goals to matter in a solo game.

## Executed In This Pass

Phase 1 is complete: add a strategic advisor layer.

- Added `StrategicAdvisorEngine` to convert economy, queue, fleet, colonization, and expedition state into prioritized player recommendations.
- Added tests for energy deficits, storage pressure, debris recovery, colonization, and expedition suggestions.
- Added a new dashboard panel named "战略顾问".
- Added click-through routing from advisor rows into the likely relevant screen: planet, research, star map, or fleet.

Phase 2 is complete: add fleet mission planning.

- Added `FleetMissionPlannerEngine` to summarize launch blockers, fuel, travel time, cargo capacity, expected value, risk, and mission notes.
- Added tests for recycler value planning and impossible mission blockers.
- Connected star-map quick launches to the planner so disabled missions have the same reasoning as the preview.
- Added compact mission previews to solar-system slots and richer notes to the fleet dispatch summary.

Phase 3 is complete: add combat review.

- Added `CombatReviewEngine` to turn battle reports into outcome, per-round, rapid-fire, explosion, loot, debris, and moon-chance reviews.
- Added tests for attacker victory reviews, defender holds, insight generation, and non-battle report filtering.
- Added combat review blocks to battle reports in the macOS UI.

Phase 4 is complete: add colony specialization.

- Added `ColonySpecializationEngine` to classify inner, middle, outer, built-up, and moon-backed worlds into readable roles.
- Added tests for solar outposts, core worlds, deuterium worlds, shipyard hubs, moon bases, and field-pressure warnings.
- Added a colony specialization panel to planet detail pages with role, field usage, solar/deuterium factors, temperature, recommended buildings, and warnings.
- Added star-map specialization previews so empty colony slots show their long-term value before the player launches a colony ship.

## Recommended Roadmap

### Phase 2 - Fleet Planner

Goal: make fleet decisions feel intentional.

- Done: add a mission planner model that explains why a mission is available or blocked.
- Done: show fuel, cargo capacity, round-trip time, risk, and expected value before launch.
- Done: add star-map previews for "回收残骸", "殖民该星位", "远征空位", and other primary slot actions.
- Remaining: add a dedicated planner inspector with editable speed/cargo presets directly from the star map.

### Phase 3 - Combat Review

Goal: make battles teach strategy.

- Done: expand battle reports with per-round losses, shield/hull highlights, rapid-fire triggers, debris, loot, and moon chance.
- Done: add "为什么输了/赢了" style summaries for attacker victory, defender hold, fleet wipe, debris recovery, and moon chance.
- Remaining: add simulator presets from actual combat reports.

### Phase 4 - Colony Specialization

Goal: make colonization more than adding another resource tile.

- Done: give star positions clearer tradeoffs: inner solar efficiency, mid-position field size, outer deuterium output.
- Done: add colony role labels: solar outpost, core world, deuterium world, shipyard hub, research campus, moon base, and marginal colony.
- Done: add warnings when a colony has low fields, crowded fields, weak solar, weak deuterium, missing logistics, or no moon.
- Remaining: let the strategic advisor recommend abandoning or replacing weak colonies once the empire reaches the planet cap.

### Phase 5 - Solo Diplomacy and ACS

Goal: adapt alliance mechanics to a single-player universe.

- Convert alliance/ACS into AI relationship goals: invite holds, joint strikes, defensive aid, trade pacts, and reputation.
- Add relation events that create short windows for cooperation or betrayal.
- Let the player receive and evaluate AI calls for help.

### Phase 6 - Knowledge Layer

Goal: reduce hidden-rule friction.

- Add in-game encyclopedia entries for buildings, technologies, ships, defenses, resources, planet positions, moons, expeditions, combat, and fleet safety.
- Link encyclopedia entries from advisor recommendations and locked build requirements.
- Keep entries concise and gameplay-oriented rather than wiki-length.

### Phase 7 - Pace and Balance Pass

Goal: preserve the fast single-player feel while avoiding runaway automation.

- Audit auto-upgrade decisions against the advisor engine.
- Add diminishing returns to repetitive safe loops if they dominate all strategies.
- Ensure normal real-time progression stays readable at 1x while still feeling exciting at accelerated speeds.

### Phase 8 - UI Polish Pass

Goal: make the app easier to scan during long sessions.

- Consolidate dashboard status into three layers: empire health, strategic advisor, active events.
- Improve color semantics: red for immediate losses, orange for avoidable waste, blue for opportunities, green for stable progress.
- Add compact mode for smaller MacBook screens.
