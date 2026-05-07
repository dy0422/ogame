# Milestones 2-3 Verification

Milestones 2 and 3 turn the native macOS foundation into a playable fast-session economy loop with offline universe progression.

## Expected Commands

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

All commands should complete successfully from the repository root.

## Implemented Capabilities

- Fast-skirmish balance tables for buildings, research, production, energy, duration, and AI priority.
- Resource math helpers for affordability, scaling, clamping, and storage display.
- Building and research queue models with older-save compatibility and strict current-save decoding.
- Resource production tick with mine output, solar energy, energy shortage scaling, storage caps, and bounded event generation.
- Construction and research queue actions with cost validation, one active queue per planet/faction, deterministic completion, and energy recomputation.
- SwiftUI economy controls for upgrading buildings, starting research, viewing rates, queues, and energy state.
- Offline catch-up that advances the universe in bounded chunks, caps one pass to 24 hours, summarizes generated activity, and preserves event-feed sanity.
- AI economic growth for non-player factions, using deterministic strategy-weighted building/research choices.
- App load-time catch-up from save wall-clock timestamps, applied in memory with an explicit pending-save state to avoid silent autosave replacement.

## Safety And Review Highlights

- Rule-derived costs and durations are validated before queueing, preventing invalid balance data from crediting resources.
- Queue fields decode missing older-save keys as empty arrays but reject explicit null for non-optional current fields.
- Queue completions due before a tick are applied before production so completed mines and solar plants affect that tick.
- AI research affordability uses the same owned-planet payment order as the queue engine.
- Offline catch-up strips per-chunk noise and appends one deterministic summary event.
- Startup catch-up does not overwrite existing autosaves until the player explicitly saves.

## Deferred To Later Milestones

- Fleet construction costs, missions, colonization, scouting, recycling, and combat.
- Battle reports, debris fields, loot, and defense recovery.
- Star map interaction, rankings, victory conditions, exploration events, and diplomacy-lite relations.
- Dedicated balancing tools, settings, onboarding, packaging, and performance instrumentation.
