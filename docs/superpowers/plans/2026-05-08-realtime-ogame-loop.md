# Realtime OGame Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace manual time advancement with a continuous realtime simulation loop that supports pause/resume, online speed multipliers, readable events, and autosave alignment.

**Architecture:** Keep `OGameCore` as the testable simulation layer by adding explicit event policy and a small realtime frame helper. `OGameMac` owns user-facing runtime state, periodic frame calls, UI controls, and persistence. Offline catch-up remains unchanged except that online autosave timestamps must stay aligned with simulated time.

**Tech Stack:** Swift 5.9, SwiftPM, SwiftUI macOS, existing executable test runners.

---

### Task 1: Core Event Policy

**Files:**
- Modify: `Sources/OGameCore/SimulationEngine.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [x] **Step 1: Write failing event-policy tests**

Add tests proving `.domainOnly` suppresses routine system tick events while preserving economy/domain events, and `.full` remains backward compatible.

- [x] **Step 2: Run core tests and confirm the new tests fail**

Run: `swift run OGameCoreTests`

Expected: compile failure or test failure because `SimulationEventPolicy` and `eventPolicy:` do not exist yet.

- [x] **Step 3: Implement `SimulationEventPolicy`**

Add a public enum with `.full`, `.domainOnly`, and `.silent`.

- [x] **Step 4: Wire `SimulationEngine.tick`**

Keep default behavior as `.full`; append the "Simulation Advanced" system event only for `.full`.

- [x] **Step 5: Run core tests**

Run: `swift run OGameCoreTests`

Expected: pass.

### Task 2: Realtime Frame Core

**Files:**
- Create: `Sources/OGameCore/RealtimeSimulationEngine.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [x] **Step 1: Write failing realtime tests**

Add tests for first-frame initialization, 1x elapsed advancement, 4x advancement, paused no-op, invalid elapsed no-op, and large-delta clamp.

- [x] **Step 2: Run core tests and confirm failure**

Run: `swift run OGameCoreTests`

Expected: compile failure because `RealtimeSimulationEngine` does not exist yet.

- [x] **Step 3: Implement realtime helper types**

Create `RealtimeSimulationState`, `RealtimeSimulationResult`, and `RealtimeSimulationEngine.advanceFrame(...)`.

- [x] **Step 4: Use domain-only simulation policy**

Realtime advancement calls `SimulationEngine.tick(..., eventPolicy: .domainOnly)`.

- [x] **Step 5: Run core tests**

Run: `swift run OGameCoreTests`

Expected: pass.

### Task 3: App Runtime State And Autosave

**Files:**
- Modify: `Sources/OGameMac/AppModel.swift`

- [x] **Step 1: Add runtime state**

Add published pause state and private realtime/autosave timestamps.

- [x] **Step 2: Replace manual advance model API**

Add `handleRealtimeFrame(now:)`, `toggleSimulationPaused()`, `setSimulationPaused(_:)`, runtime status text, pause button title, and next-event summary.

- [x] **Step 3: Add periodic autosave**

If autosave is enabled and the simulation advanced, save no more than once per 45 wall-clock seconds.

- [x] **Step 4: Update setting copy**

Update speed status text so speed is described as realtime simulation speed, not manual advancement speed.

### Task 4: SwiftUI Realtime Driver And Controls

**Files:**
- Modify: `Sources/OGameMac/ContentView.swift`
- Modify: `Sources/OGameMac/OGameMacApp.swift`

- [x] **Step 1: Add single root realtime driver**

Attach a periodic SwiftUI driver at `ContentView` root that calls `model.handleRealtimeFrame(now:)`.

- [x] **Step 2: Replace advance controls**

Replace "advance" button with pause/resume button and runtime status.

- [x] **Step 3: Replace command menu**

Replace "推进 1 分钟" with "暂停/继续模拟".

- [x] **Step 4: Add speed presets**

Expose common speed presets in the activity panel while keeping the settings slider.

### Task 5: Verification

**Files:**
- No planned source changes.

- [x] **Step 1: Run core tests**

Run: `swift run OGameCoreTests`

- [x] **Step 2: Run persistence tests**

Run: `swift run OGamePersistenceTests`

- [x] **Step 3: Build app**

Run: `swift build`

- [x] **Step 4: Review diff against spec**

Check that automatic advancement, pause/resume, speed multiplier, event-feed throttling, and autosave alignment are all represented.
