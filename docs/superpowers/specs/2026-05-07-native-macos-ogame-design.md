# Native macOS OGame Sandbox Design

## Goal

Rebuild the downloaded PHP OGame/XNova codebase as a native SwiftUI macOS single-player game. The new game should not wrap or embed the old PHP application. It should use the old project as a gameplay reference while rebuilding the rules, simulation, AI, storage, and interface in Swift.

The target experience is a fast-paced offline universe simulation: the player's empire develops alongside AI factions, time can pass while the app is closed, and a single run can reach meaningful expansion, conflict, and victory within a few hours.

## Design Direction

The chosen approach is simulation-first.

The first priority is a deterministic, testable simulation core that can run the universe without UI dependencies. SwiftUI then becomes the player-facing control room for that simulation.

The game keeps OGame's recognizable core:

- Three primary resources: metal, crystal, deuterium.
- Energy as a production constraint.
- Planetary building, research, fleet construction, defense construction, colonization, scouting, combat, recycling, exploration, moons, and late-game strategic systems.
- Fleet missions that resolve over time.
- Reports, events, rankings, and victory progress.

The game does not aim for exact formula compatibility. Core mechanics are retained, but timings, costs, AI behavior, victory pacing, and event frequency are rebalanced for a fast single-player session.

## Product Shape

The app is a modern desktop management game, not a recreation of the old browser UI.

The interface should use:

- A left sidebar for empire navigation, planets, fleets, research, intelligence, and victory progress.
- A central workspace for dashboards, star map, planet management, fleet planning, battle reports, and faction views.
- A right-side activity area for event feed, queues, alerts, and AI faction movement.
- A clear 2D strategic star map in the first production version. A 3D view is not required for the first version.
- Dense but readable management screens suitable for repeated play.

The first version should feel like a complete single-player sandbox, even if some late-game systems are simplified.

## Architecture

The project should be split into clear modules:

- `OGameCore`: pure Swift simulation rules and domain logic.
- `OGamePersistence`: save/load, schema versioning, offline time reconciliation, and migrations.
- `OGameMac`: SwiftUI macOS app, view models, commands, windows, and presentation state.

`OGameCore` must not import SwiftUI. It should be deterministic where practical and testable through unit tests.

The simulation should advance through a single entry point:

```swift
SimulationEngine.tick(universe:inout Universe, delta: TimeInterval)
```

Online play, fast-forward, pause/resume, and offline catch-up should all use this same simulation path.

## Core Data Model

The core model should be serializable and versioned.

- `Universe`: run id, random seed, game clock, factions, star systems, planets, fleets, queued events, victory state, ruleset version, and last saved wall-clock time.
- `Faction`: player or AI identity, strategy profile, known intelligence, technology, owned planets, relations, score, and victory progress.
- `Planet`: coordinates, owner, resources, storage, energy, buildings, production settings, ship inventory, defenses, construction queues, moon state, local modifiers, and recent activity.
- `Fleet`: owner, ships, cargo, mission, origin, target, launch time, arrival time, return time, current phase, visibility, and combat metadata.
- `ResearchState`: technology levels and current research queue.
- `GameEvent`: typed records for battle reports, espionage, colonization, exploration, economy, faction behavior, warnings, and victory milestones.
- `RuleSet`: all balance tables and formulas for costs, production, construction time, research time, travel, combat, AI scoring, and victory thresholds.

## Game Systems

### Resources And Production

Planets produce resources over time based on building levels, energy availability, production settings, local modifiers, and faction bonuses. Storage limits cap production. Energy shortage reduces mine output.

The rebalanced fast-session pacing should make early buildings finish quickly, mid-game require prioritization, and late-game require multi-planet logistics.

### Buildings And Research

Building and research trees should start from the old OGame structure:

- Mines, power, storage, robotics, shipyard, laboratory, nanite-style production acceleration, missile silo, and moon buildings.
- Combat, armor, shield, engines, espionage, computer, energy, hyperspace, exploration, and late-game technology.

The first implementation should support queues and completion events. Exact old formulas can be used as initial reference values, then adjusted in the `RuleSet`.

### Fleet Missions

Fleet missions should include:

- Transport.
- Colonization.
- Espionage.
- Attack.
- Recycling debris.
- Exploration.
- Return.

Later milestone systems can add alliance-like support, moon destruction, jump gates, and missile strikes.

### Combat And Reports

Combat should produce deterministic battle reports from a seeded random source. The combat model should preserve the OGame feel: fleets and defenses have attack, shield, hull, rapid-fire style counters, debris generation, loot, and partial defense recovery.

Battle reports should summarize:

- Attacker and defender.
- Fleet and defense before/after.
- Losses.
- Debris.
- Loot.
- Moon or special event chances where applicable.

### AI Factions

AI factions should use strategy profiles and scored actions rather than scripted steps.

Initial profiles:

- Miner: economy, storage, defenses, stable expansion.
- Raider: espionage, fleets, attacks against weak targets.
- Technologist: laboratories, research, exploration, late-game victory.
- Expansionist: colonization, logistics, forward development.
- Balanced: switches priorities based on current position.

Each AI decision step evaluates possible actions:

- Build or upgrade.
- Research.
- Build ships or defenses.
- Launch transport, espionage, colonization, attack, recycling, or exploration missions.
- Change defensive posture.

The AI should have imperfect information. It can use scouting reports, known scores, proximity, recent events, and threat memory, but should not read hidden player state directly unless a difficulty setting explicitly allows it.

### Offline Simulation

The universe continues when the app is closed.

On launch, the app compares the saved wall-clock time with the current wall-clock time and advances the simulation in bounded chunks. A default chunk size of 5 to 15 simulated minutes is appropriate.

Offline simulation rules:

- Resource production and queues progress normally.
- Fleet arrivals and returns resolve at their scheduled simulation times.
- AI decisions occur once per chunk or at scheduled strategic intervals.
- Event generation is throttled to avoid destructive runaway chains.
- Major wars, fleet wipes, and faction collapses should have caps during offline catch-up.
- The player can choose offline intensity: gentle, standard, or aggressive.

The catch-up screen should summarize what happened while away before returning the player to normal play.

### Victory Conditions

Multiple victory routes should be available:

- Domination: control or neutralize enough of the active universe.
- Technology: complete a late-game research or megastructure objective.
- Economy: reach overwhelming production and infrastructure score.
- Exploration: complete enough deep-space discoveries or anomaly objectives.

Victory progress should be visible throughout the run. The game should support continuing after victory as a sandbox.

## Persistence

The first version should store saves locally in the app's Application Support directory.

Recommended first storage format:

- JSON with explicit schema versioning for early development.
- Deterministic random seed stored in each save.
- Autosave after meaningful actions and periodic simulation ticks.

SQLite can replace or supplement JSON later if the universe state grows too large or query-heavy.

Save data must include:

- Entire `Universe` state.
- `RuleSet` version.
- App version.
- Last saved simulation time.
- Last saved wall-clock time.
- User settings for simulation speed, offline intensity, and UI preferences.

## Testing Strategy

Testing should focus on the simulation core.

Required test areas:

- Resource production under normal, capped, and energy-shortage conditions.
- Building and research queue completion.
- Fleet launch, travel, arrival, return, cargo transfer, and invalid mission handling.
- Combat outcomes with seeded randomness.
- Debris creation and recycling.
- AI decision progression over many ticks.
- Offline catch-up stability.
- Victory condition triggering.
- Save/load round trips and version checks.

UI tests can remain light until the core is stable.

## Milestones

### Milestone 1: Native Project Skeleton

Create the SwiftUI macOS app, core module, persistence module, basic app shell, test target, and empty simulation loop.

### Milestone 2: Empire Economy

Implement resources, planets, buildings, research, queues, online ticking, and local saves.

### Milestone 3: Offline Universe

Implement offline catch-up, AI economic growth, AI profiles, event feed, and catch-up summaries.

### Milestone 4: Fleet And Conflict

Implement fleet construction, missions, colonization, espionage, attack, recycling, battle reports, and debris.

### Milestone 5: Strategic Sandbox

Implement star map, victory conditions, faction rankings, exploration events, diplomacy-lite relations, and balancing tools.

### Milestone 6: Mac Game Polish

Improve SwiftUI layout, keyboard commands, notifications, settings, onboarding, autosave confidence, performance, and packaged app behavior.

## Non-Goals For The First Implementation

- Embedding the PHP app.
- Supporting multiplayer.
- Exact PHP database compatibility.
- Exact browser UI recreation.
- Public server deployment.
- Full 3D star map.
- Exact formula parity with OGame.

## Risks

- Scope creep: a complete OGame-like sandbox is large. Milestones must stay playable and testable.
- AI balance: AI can become too passive, too destructive, or too expensive to simulate. Strategy scoring and offline event caps are required.
- Offline catch-up: long gaps can create surprising outcomes. Summaries, intensity settings, and event throttling are needed.
- Formula migration: old PHP formulas are useful references but should not be copied blindly.
- UI density: the game needs lots of information, but the macOS UI should remain clear and navigable.

## Approval State

The user selected:

- Native SwiftUI macOS rewrite.
- Offline universe simulation as the core experience.
- Preserve OGame's core, but rebalance for single-player.
- Fast-paced runs measured in hours.
- Multiple victory conditions.
- Modern desktop management UI.
- Simulation-first implementation.
