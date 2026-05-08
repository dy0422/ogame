import Foundation

public enum TechnologyEffects {
    public static func level(_ kind: TechnologyKind, in research: ResearchState) -> Int {
        max(research.levels[kind] ?? 0, 0)
    }

    public static func maxFleetSlots(for research: ResearchState) -> Int {
        max(1, 1 + level(.computer, in: research))
    }

    public static func driveTechnology(for ship: ShipKind) -> TechnologyKind? {
        switch ship {
        case .smallCargo, .largeCargo, .recycler:
            return .combustionDrive
        case .lightFighter, .heavyFighter, .cruiser, .colonyShip, .bomber:
            return .impulseDrive
        case .battleship, .destroyer, .deathstar, .battlecruiser:
            return .hyperspaceDrive
        case .espionageProbe, .solarSatellite:
            return nil
        }
    }

    public static func effectiveSpeed(
        for ship: ShipKind,
        baseSpeed: Double,
        research: ResearchState
    ) -> Double {
        guard baseSpeed.isFinite, baseSpeed > 0 else {
            return 0
        }

        guard let drive = driveTechnology(for: ship) else {
            return baseSpeed
        }

        let bonusPerLevel: Double = drive == .hyperspaceDrive ? 0.30 : 0.20
        return baseSpeed * (1 + Double(level(drive, in: research)) * bonusPerLevel)
    }

    public static func researchSpeedFactor(for labLevel: Int) -> Double {
        max(1, 1 + Double(max(labLevel, 0)) * 0.10)
    }

    public static func espionageIntelTier(
        attacker: ResearchState,
        defender: ResearchState,
        probeCount: Int
    ) -> Int {
        let techDelta = level(.espionage, in: attacker) - level(.espionage, in: defender)
        return min(max(1 + techDelta + max(probeCount, 0) / 2, 1), 5)
    }
}
