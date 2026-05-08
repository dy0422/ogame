# Native macOS OGame Realtime Loop Design

## Goal

Redesign the native macOS OGame sandbox so time advances continuously while the app is open. The player should no longer press a button to jump the universe forward. Instead, the universe runs in real time by default, with an adjustable speed multiplier for fast single-player sessions.

This design keeps the existing Swift simulation architecture. The core simulation already accepts arbitrary second-based deltas through `SimulationEngine.tick(universe:delta:)`, so the redesign focuses on app runtime behavior, event policy, UI controls, balance targets, and verification.

## Current State

The game currently has a working simulation core:

- Resource production is delta based.
- Building, research, ship, defense, missile, fleet, AI, victory, save, and offline catch-up systems already use simulation time.
- `GameSettings.gameSpeed` exists and is persisted.
- Offline catch-up compares saved wall-clock time against current wall-clock time.

The player-facing problem is the macOS layer. `AppModel.advanceOneMinute()` advances by a derived fixed delta, and the UI exposes this through a manual "advance" button and command menu. This makes the game feel like a turn-step simulator even though the core can support continuous time.

## Design Direction

Use real wall-clock elapsed time as the online simulation driver.

When the app is running:

- 1 second of wall-clock time advances 1 second of game time at 1x speed.
- The speed multiplier scales online elapsed time.
- The player can pause and resume the online simulation.
- Queues, fleets, resources, AI decisions, victory checks, and event summaries update automatically.

When the app is closed:

- Existing offline catch-up remains the source of truth.
- Offline catch-up uses `GameSettings.offlineIntensity`, not the online pause state.
- Offline catch-up remains bounded and throttled to prevent destructive runaway chains.

## Time Model

### Online Time

Online simulation uses this formula:

```swift
let gameDelta = wallClockElapsedSeconds * GameSettings.clampedGameSpeed(settings.gameSpeed)
SimulationEngine.tick(universe: &universe, delta: gameDelta, aiDifficulty: settings.difficulty)
```

The app should ignore non-finite, negative, and tiny wall-clock deltas. A small positive delta is acceptable, but the runtime should avoid excessive tick frequency. The recommended UI driver interval is 0.5 to 1.0 wall-clock seconds.

### Pause Semantics

Pause is a live-session control:

- Paused means the open app stops advancing online simulation.
- Paused does not mean the universe is globally frozen after quitting the app.
- Long-term offline progression is controlled by `offlineIntensity`.

This keeps "pause while inspecting the UI" separate from "turn off offline progress".

### Speed Semantics

The speed multiplier affects online simulation only. It does not multiply offline catch-up because offline catch-up already has its own intensity setting.

Recommended speed presets:

- 0.25x
- 0.5x
- 1x
- 2x
- 4x
- 8x

The existing slider may remain, but segmented presets should be preferred in the main runtime UI because they are easier to read and less fiddly during play.

## Core Gameplay Loop

The revised single-player loop should feel like a compressed OGame server:

1. The player starts with a home planet, basic resources, and visible nearby targets.
2. Mines and power start the economy.
3. Robotics, shipyard, and laboratory unlock parallel strategic choices.
4. Early probes, cargo ships, and fighters open scouting, transport, exploration, and first raids.
5. AI factions grow on the same clock and make visible moves.
6. The player uses scouting, fleet timing, defense, storage, and colonization to survive and snowball.
7. Mid-game systems add colonies, debris recycling, missiles, moons, and stronger fleets.
8. Victory routes reward economy, technology, domination, or exploration.

The redesign should not turn the game into an idle-only app. The player should have meaningful short-term choices every few minutes, especially around build priority, scouting, target selection, and fleet timing.

## Balance Targets

The current balance was built around manual advancement and scripted balance scenarios. Realtime play needs target windows measured in wall-clock minutes at 1x.

Recommended standard-speed targets:

- First meaningful building completion: 15 to 45 seconds.
- First research completion: 1 to 3 minutes.
- First probe or small cargo: 5 to 10 minutes.
- First fleet launch: 8 to 15 minutes.
- First scouting report: 10 to 20 minutes.
- First combat opportunity: 20 to 45 minutes.
- First colony opportunity: 45 to 90 minutes.
- First moon or missile interaction: 60 to 150 minutes.
- First victory route completion: 2 to 4 hours.

At 4x or 8x, the same game should compress into a shorter active session without changing formulas. The speed multiplier should be a pacing preference, not a different ruleset.

## AI Pacing

AI should not make decisions every realtime tick. It should keep deterministic interval gates:

- Economy AI: no more often than every 60 simulated seconds.
- Strategic AI: no more often than every 120 simulated seconds.
- Aggressive actions should be capped during offline catch-up.
- Difficulty should change AI policy, not the user's clock.

Difficulty expectations:

- Easy: scouts before attacking, fewer opportunistic raids, slower defensive recovery.
- Standard: balanced scouting, expansion, defense, and attacks.
- Hard: more ranking-based pressure, stronger defense choices, more opportunistic raids.

## Event Policy

Continuous ticking must not flood the event feed.

The simulation should continue to emit domain events for meaningful changes:

- Construction complete.
- Research complete.
- Unit construction complete.
- Fleet launched.
- Fleet arrived, resolved, or returned.
- Exploration, espionage, combat, missile strike, colony, moon, victory, and major AI events.

Routine realtime ticks should not append "Simulation Advanced" every second. System tick events may remain in tests and explicit debug paths, but the online runtime should either suppress them or aggregate them into occasional economy summaries.

Recommended event policy:

- `SimulationEngine.tick` can keep low-level behavior for compatibility.
- Add an option such as `eventPolicy: .full | .domainOnly | .silentSystem`.
- Online realtime uses `.domainOnly`.
- Offline catch-up already summarizes events and should continue doing so.
- Balance tools can use `.silentSystem` or `.domainOnly` to avoid skewing output.

## UI Design

### Activity Panel

Replace the manual advance button with simulation controls:

- Primary button: pause or resume.
- Status text: running, paused, offline catch-up pending save, or save unavailable.
- Speed display: current multiplier.
- Next event line: closest queue completion or fleet arrival.

The command menu should replace "Advance 1 Minute" with "Pause/Resume Simulation".

### Settings

Update settings language:

- "Game speed" means realtime simulation speed.
- "Offline intensity" means closed-app catch-up intensity.
- Autosave should describe meaningful action saves and periodic realtime saves.

The settings UI can keep the speed slider, but the main surface should expose quick presets.

### Dashboard

The dashboard should surface live timing:

- Current game time.
- Runtime state.
- Next building completion.
- Next research completion.
- Next fleet arrival or return.
- Current speed multiplier.
- Offline catch-up summary if one was applied and not yet saved.

### Queue And Fleet Views

Queue and fleet cards should refresh naturally as simulation time changes. They should not require user actions to update remaining-time text or progress bars.

## Persistence And Autosave

Realtime simulation needs periodic autosave in addition to action autosave.

Recommended policy:

- Save immediately after meaningful player actions when autosave is enabled.
- Save after offline catch-up is applied once the player confirms or when current behavior already marks it pending.
- Save periodically while running, no more often than every 30 to 60 wall-clock seconds.
- Save on app lifecycle changes when possible.

The save wall-clock timestamp should reflect the latest persisted simulation state. This prevents double-counting online time as offline time after relaunch.

## Architecture Changes

### AppModel

Add runtime state:

```swift
@Published private(set) var isSimulationPaused: Bool
@Published private(set) var lastRealtimeTickDate: Date?
@Published private(set) var lastPeriodicAutosaveDate: Date?
```

Add methods:

```swift
func handleRealtimeFrame(now: Date)
func setSimulationPaused(_ isPaused: Bool)
func toggleSimulationPaused()
```

`handleRealtimeFrame(now:)` should:

1. Return if saving is unavailable.
2. Initialize `lastRealtimeTickDate` if missing.
3. Return if paused.
4. Compute positive finite wall-clock elapsed seconds.
5. Clamp unusually large online deltas to a safe maximum, such as 10 to 30 seconds, because longer gaps should be handled by offline catch-up after persistence boundaries.
6. Advance the simulation by elapsed time times online speed.
7. Refresh strategic state.
8. Periodically autosave if enabled.

### SwiftUI Runtime Driver

Use a SwiftUI-friendly driver:

- `TimelineView(.periodic(from: Date(), by: 1))`
- or `Timer.publish(every:on:in:)`

The driver should call `model.handleRealtimeFrame(now:)` from the root view or app scene. The implementation must avoid creating multiple independent tick loops when SwiftUI re-renders.

### Simulation Engine

Keep the existing core delta-based API but add event-control capability if needed. The runtime should be able to advance the universe without recording a system event on every frame.

### Offline Engine

Keep the existing bounded catch-up model. The main adjustment is persistence alignment: online periodic saves must update `lastSavedAt` so relaunches do not treat already-simulated online time as offline elapsed.

## Testing Strategy

Add tests for the new runtime contract.

Core or app-model tests should cover:

- Realtime frame at 1x advances by wall-clock elapsed seconds.
- Realtime frame at 4x advances by four times elapsed seconds.
- Paused runtime does not advance simulation time.
- First frame initializes the realtime clock without advancing.
- Invalid or negative elapsed time is ignored.
- Large online delta is clamped.
- Periodic autosave uses current wall-clock time.
- Updating game speed affects future realtime frames, not offline catch-up.

Simulation tests should cover:

- Domain events still fire under small repeated ticks.
- Routine realtime ticks do not flood system events under the online event policy.
- AI economy and strategy intervals still trigger when enough simulated time passes.

Persistence tests should cover:

- Saved realtime state does not double-count as offline progress on immediate relaunch.
- Offline paused intensity still prevents closed-app catch-up.
- Online pause does not alter persisted offline intensity.

## Risks

### Event Flooding

If each realtime tick records a system event, the save file and UI event feed will grow quickly. This must be fixed before realtime mode is considered complete.

### Duplicate Tick Loops

SwiftUI view rebuilding can accidentally create multiple timers. The runtime driver must live in one stable place.

### Double Counting Time

If autosave timestamps lag behind simulated online time, relaunch may apply offline catch-up for time that was already simulated. Periodic autosave and lifecycle save are required.

### Balance Drift

Moving from manual advancement to realtime play changes perceived pacing even if formulas are unchanged. Balance tooling must use unscripted realtime-style scenarios.

## Implementation Phases

### Phase 1: Realtime Runtime

Add runtime state, realtime frame handling, pause/resume controls, and UI/menu replacement for manual advancement.

### Phase 2: Event Policy

Prevent routine tick event spam while preserving domain events and testability.

### Phase 3: Autosave Alignment

Add periodic realtime autosave and lifecycle save hooks so wall-clock persistence matches simulated state.

### Phase 4: Balance Recalibration

Update balance scenarios to run unscripted realtime windows and tune early, mid, and late game timings.

### Phase 5: Playability Polish

Add next-event summaries, speed presets, clearer runtime status, and queue/fleet refresh polish.

## Acceptance Criteria

- The game advances automatically while open.
- The player can pause and resume the online simulation.
- Speed multiplier affects online simulation continuously.
- The manual "advance one minute" command is removed from primary UI and menus.
- Queue progress and fleet ETA update without manual advancement.
- Offline catch-up still works after quitting and reopening.
- Offline intensity remains independent from online pause.
- Event feed remains readable after at least 30 minutes of realtime running.
- Autosave prevents double-counted elapsed time on relaunch.
- Existing core and persistence tests pass.
