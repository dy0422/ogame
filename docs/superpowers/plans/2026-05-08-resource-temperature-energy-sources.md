# Resource Temperature And Energy Sources Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the single-player economy closer to OGame server behavior by adding planet temperature effects, solar satellite energy, and fusion reactor energy.

**Architecture:** Planet temperature is stored on `Planet` and defaults safely for old saves. `EconomyEngine` remains the source of truth for resource and energy formulas, with optional faction research input for fusion reactor scaling. UI surfaces only the useful player-facing signals: temperature, signed resource rates, and localized energy-source names.

**Tech Stack:** Swift 5.9, SwiftPM, OGameCore domain models, SwiftUI macOS client.

---

### Task 1: Planet Temperature

**Files:**
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGameCore/StarterUniverseFactory.swift`
- Test: `Tests/OGameCoreTests/main.swift`

- [x] Add `temperatureCelsius: Double` to `Planet`, defaulting to `40`.
- [x] Clamp non-finite or extreme values to the supported range `-200...240`.
- [x] Decode missing temperature in old saves as `40`.
- [x] Generate deterministic starting temperatures from planet position.

### Task 2: Deuterium Temperature Formula

**Files:**
- Modify: `Sources/OGameCore/EconomyEngine.swift`
- Modify: `Sources/OGameCore/BalanceRules.swift`
- Test: `Tests/OGameCoreTests/main.swift`

- [x] Change the deuterium synthesizer base coefficient to the server-shaped `10 * 4 = 40`.
- [x] Apply the server temperature factor `-0.002 * temperature + 1.28`.
- [x] Preserve the previous fast-skirmish baseline at `40°C`, where level 1 produces `52.8/h`.

### Task 3: Solar Satellite Energy

**Files:**
- Modify: `Sources/OGameCore/EconomyEngine.swift`
- Modify: `Sources/OGameCore/QueueEngine.swift`
- Test: `Tests/OGameCoreTests/main.swift`

- [x] Count `ShipKind.solarSatellite` inventory as stationary energy infrastructure.
- [x] Use the OGame-style per-satellite formula `floor((temperature + 140) / 6)`.
- [x] Recompute planet energy after ship construction completes so new satellites affect the same simulation state.

### Task 4: Fusion Reactor

**Files:**
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGameCore/BalanceRules.swift`
- Modify: `Sources/OGameCore/EconomyEngine.swift`
- Modify: `Sources/OGameCore/AIEconomyEngine.swift`
- Modify: `Sources/OGameCore/QueueEngine.swift`
- Test: `Tests/OGameCoreTests/main.swift`

- [x] Add `BuildingKind.fusionReactor`.
- [x] Add fast-skirmish building rules requiring energy technology level 3.
- [x] Produce energy using `30 * level * 1.05^level * (1 + energyTech * 0.01)`.
- [x] Consume fast-skirmish deuterium fuel using `-40 * level * 1.1^level`.
- [x] Recompute owned-planet energy after energy research completes.
- [x] Teach AI economy scoring to treat fusion reactor as an energy building.

### Task 5: UI And Verification

**Files:**
- Modify: `Sources/OGameMac/ContentView.swift`
- Modify: `Sources/OGameMac/GameAssets.swift`
- Modify: `Sources/OGameMac/ChineseDisplay.swift`
- Test: SwiftPM executable checks

- [x] Show planet temperature in the economy panel.
- [x] Display resource rates as signed values so fusion fuel appears as negative deuterium.
- [x] Add Chinese names, icons, and server art mapping for fusion reactor and solar satellites.
- [x] Run `swift run OGameCoreTests`.
- [x] Run `swift run OGamePersistenceTests`.
- [x] Run `swift build`.
- [x] Run `swift run OGameBalanceTool`.
- [x] Run `./script/build_and_run.sh --verify`.
