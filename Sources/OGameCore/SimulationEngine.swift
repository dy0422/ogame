import Foundation

public enum SimulationEngine {
    public static func tick(universe: inout Universe, delta: TimeInterval) {
        guard delta.isFinite, delta > 0 else {
            return
        }

        universe.gameTime += delta

        universe.events.append(
            GameEvent(
                id: simulationEventID(index: universe.events.count + 1),
                time: universe.gameTime,
                kind: .system,
                title: "Simulation Advanced",
                message: "Advanced the universe by \(Int(delta)) seconds."
            )
        )
    }

    private static func simulationEventID(index: Int) -> EventID {
        EventID(UUID(uuidString: String(format: "00000000-0000-0000-0002-%012d", index))!)
    }
}
