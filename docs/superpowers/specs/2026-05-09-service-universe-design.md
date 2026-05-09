# Service-Style Universe Design

## Goal

Upgrade the native single-player OGame from a small fixed sandbox into a service-style universe simulation inspired by OGame and the bundled XNova server code.

## References

- OGame describes a universe with galaxies, solar systems, 15 planet slots per system, and an outer-space expedition slot.
- The bundled XNova server defaults to `99` galaxies, `499` systems per galaxy, `15` planet positions per system, and `8` player planets.
- XNova places new homeworlds in positions `4...12`, varies planet fields and temperature by slot, and creates moons from battle debris with `100,000` debris per `1%` chance capped at `20%`.

## Scope

This pass starts all eight requested systems with a playable first slice:

1. Parameterized universe topology.
2. Slot-based planet fields and temperature.
3. Wider colony target pool instead of three fixed targets.
4. Service-style moon chance calculation.
5. Expedition slot `16` handling.
6. AI expansion targets drawn from the same universe pool.
7. Existing combat/fleet systems wired to the new rules.
8. Star map UI that shows a solar-system style `1...16` view.

It does not generate every possible empty coordinate up front. The game keeps deterministic occupied and discovered records only, while topology helpers can create new neutral colony targets near active regions.

## Core Architecture

Create `UniverseTopologyEngine` in `OGameCore`. It owns:

- Universe constants for fast single-player play.
- Coordinate validation.
- Planet-slot profiles: temperature, fields, and broad habitat type.
- Colony target generation around an origin coordinate.
- Moon chance calculation and deterministic moon roll.

`StarterUniverseFactory` uses this engine for all starting planets and neutral targets. `FleetEngine` uses it when a colony is established. `CombatEngine` uses it for moon probability. `AIStrategyEngine` uses it to seed expansion targets when no neutral world is currently visible.

The macOS layer keeps its current `NavigationSplitView`, but the star map page adds a system panel showing slots `1...15` plus slot `16` for expedition.

## Testing

Add core tests first:

- Topology constants and coordinate validation.
- Slot ecology: inner planets hotter, outer planets colder, middle slots generally larger.
- Starter universe exposes many neutral colony targets.
- Colonization refreshes the claimed planet with topology-derived fields and temperature.
- Moon chance follows service-style thresholds and cap.
- Expedition coordinate uses position `16` and is not a normal colony slot.

Verification uses:

- `swift run OGameCoreTests`
- `swift run OGamePersistenceTests`
- `swift build`
- `./script/build_and_run.sh --verify`
