import Foundation

public enum UniverseTopologyEngine {
    public enum Habitat: String, Codable, Equatable, Sendable {
        case dry
        case jungle
        case temperate
        case water
        case ice
    }

    public struct PlanetProfile: Equatable, Sendable {
        public var maxFields: Int
        public var temperatureCelsius: Double
        public var habitat: Habitat

        public init(maxFields: Int, temperatureCelsius: Double, habitat: Habitat) {
            self.maxFields = max(maxFields, 1)
            self.temperatureCelsius = temperatureCelsius
            self.habitat = habitat
        }
    }

    public struct ColonySlotProfile: Equatable, Sendable {
        public var position: Int
        public var solarEnergyFactor: Double
        public var deuteriumFactor: Double
        public var fieldFactor: Double
        public var strategyHint: String

        public init(
            position: Int,
            solarEnergyFactor: Double,
            deuteriumFactor: Double,
            fieldFactor: Double,
            strategyHint: String
        ) {
            self.position = min(max(position, 1), UniverseTopologyEngine.planetSlotsPerSystem)
            self.solarEnergyFactor = Self.normalizedFactor(solarEnergyFactor)
            self.deuteriumFactor = Self.normalizedFactor(deuteriumFactor)
            self.fieldFactor = Self.normalizedFactor(fieldFactor)
            self.strategyHint = strategyHint
        }

        private static func normalizedFactor(_ value: Double) -> Double {
            guard value.isFinite else {
                return 1
            }

            return min(max(value, 0), 2)
        }
    }

    public static let defaultGalaxyCount = 9
    public static let defaultSystemsPerGalaxy = 499
    public static let planetSlotsPerSystem = 15
    public static let expeditionPosition = 16
    public static let defaultMaxPlayerPlanets = 8
    public static let serviceMoonDebrisPerPercent = 100_000.0
    public static let maximumMoonChancePercent = 20

    public static func isValidPlanetCoordinate(_ coordinate: Coordinate) -> Bool {
        (1...defaultGalaxyCount).contains(coordinate.galaxy) &&
            (1...defaultSystemsPerGalaxy).contains(coordinate.system) &&
            (1...planetSlotsPerSystem).contains(coordinate.position)
    }

    public static func isExpeditionCoordinate(_ coordinate: Coordinate) -> Bool {
        (1...defaultGalaxyCount).contains(coordinate.galaxy) &&
            (1...defaultSystemsPerGalaxy).contains(coordinate.system) &&
            coordinate.position == expeditionPosition
    }

    public static func planetProfile(for coordinate: Coordinate, universeSeed: UInt64) -> PlanetProfile {
        let slot = min(max(coordinate.position, 1), planetSlotsPerSystem)
        let range = fieldRange(for: slot)
        let span = max(range.upperBound - range.lowerBound, 0)
        let fields = range.lowerBound + deterministicInt(
            payload: "fields|\(universeSeed)|\(coordinate.galaxy)|\(coordinate.system)|\(slot)",
            modulo: span + 1
        )
        let temperature = baseTemperature(for: slot) + Double(
            deterministicInt(
                payload: "temperature|\(universeSeed)|\(coordinate.galaxy)|\(coordinate.system)|\(slot)",
                modulo: 17
            ) - 8
        )

        return PlanetProfile(
            maxFields: fields,
            temperatureCelsius: temperature,
            habitat: habitat(for: slot)
        )
    }

    public static func colonySlotProfile(forPosition position: Int) -> ColonySlotProfile {
        let slot = min(max(position, 1), planetSlotsPerSystem)
        let temperature = baseTemperature(for: slot)
        let fields = fieldRange(for: slot)
        let fieldMidpoint = Double(fields.lowerBound + fields.upperBound) / 2
        let solarFactor = min(max(0.55 + (temperature + 100) / 260, 0.45), 1.45)
        let deuteriumFactor = min(max(0.65 + (90 - temperature) / 230, 0.55), 1.45)
        let fieldFactor = min(max(fieldMidpoint / 220, 0.45), 1.45)
        let hint: String
        switch slot {
        case 1...3:
            hint = "近星位适合太阳能卫星和早期能源，但方圆偏小。"
        case 4...9:
            hint = "中星位方圆更大，适合作为长期主力殖民地。"
        default:
            hint = "远星位温度低，重氢收益更好，但太阳能偏弱。"
        }

        return ColonySlotProfile(
            position: slot,
            solarEnergyFactor: solarFactor,
            deuteriumFactor: deuteriumFactor,
            fieldFactor: fieldFactor,
            strategyHint: hint
        )
    }

    public static func moonChancePercent(forDebris debris: ResourceBundle) -> Int {
        let total = max(safe(debris.metal) + safe(debris.crystal), 0)
        guard total >= serviceMoonDebrisPerPercent else {
            return 0
        }

        return min(Int(floor(total / serviceMoonDebrisPerPercent)), maximumMoonChancePercent)
    }

    public static func moonRollSucceeds(
        chancePercent: Int,
        universeID: UniverseID,
        targetPlanetID: PlanetID,
        reportID: UUID,
        battleTime: TimeInterval
    ) -> Bool {
        guard chancePercent > 0 else {
            return false
        }
        guard chancePercent < maximumMoonChancePercent else {
            return true
        }
        guard chancePercent < 100 else {
            return true
        }

        let payload = [
            "moon-roll",
            universeID.rawValue.uuidString,
            targetPlanetID.rawValue.uuidString,
            reportID.uuidString,
            String(battleTime)
        ].joined(separator: "|")
        let roll = deterministicInt(payload: payload, modulo: 100) + 1
        return roll <= min(chancePercent, maximumMoonChancePercent)
    }

    public static func regionalColonyCoordinates(
        around origin: Coordinate,
        occupied: Set<Coordinate>,
        limit: Int
    ) -> [Coordinate] {
        guard limit > 0 else {
            return []
        }

        let preferredPositions = [5, 8, 11, 14, 2, 6, 9, 12, 15, 3, 4, 7, 10, 13, 1]
        var result: [Coordinate] = []
        let forwardRange = 1...defaultSystemsPerGalaxy
        for offset in forwardRange {
            let system = origin.system + offset
            guard system <= defaultSystemsPerGalaxy else {
                break
            }

            for position in preferredPositions {
                let coordinate = Coordinate(galaxy: origin.galaxy, system: system, position: position)
                guard !occupied.contains(coordinate) else {
                    continue
                }
                result.append(coordinate)
                if result.count >= limit {
                    return result
                }
            }
        }

        for galaxy in 1...defaultGalaxyCount where galaxy != origin.galaxy {
            for system in 1...defaultSystemsPerGalaxy {
                for position in preferredPositions {
                    let coordinate = Coordinate(galaxy: galaxy, system: system, position: position)
                    guard !occupied.contains(coordinate) else {
                        continue
                    }
                    result.append(coordinate)
                    if result.count >= limit {
                        return result
                    }
                }
            }
        }

        return result
    }

    private static func fieldRange(for position: Int) -> ClosedRange<Int> {
        switch position {
        case 1:
            return 80...130
        case 2:
            return 85...135
        case 3:
            return 90...145
        case 4:
            return 180...260
        case 5:
            return 195...285
        case 6:
            return 180...265
        case 7:
            return 165...235
        case 8:
            return 170...240
        case 9:
            return 160...230
        case 10:
            return 125...185
        case 11:
            return 120...180
        case 12:
            return 115...175
        case 13:
            return 90...155
        case 14:
            return 80...145
        case 15:
            return 70...135
        default:
            return 120...180
        }
    }

    private static func baseTemperature(for position: Int) -> Double {
        switch position {
        case 1:
            return 120
        case 2:
            return 100
        case 3:
            return 80
        case 4:
            return 55
        case 5:
            return 40
        case 6:
            return 25
        case 7:
            return 10
        case 8:
            return 0
        case 9:
            return -10
        case 10:
            return -25
        case 11:
            return -35
        case 12:
            return -45
        case 13:
            return -65
        case 14:
            return -80
        case 15:
            return -95
        default:
            return 0
        }
    }

    private static func habitat(for position: Int) -> Habitat {
        switch position {
        case 1...3:
            return .dry
        case 4...6:
            return .jungle
        case 7...9:
            return .temperate
        case 10...12:
            return .water
        default:
            return .ice
        }
    }

    private static func deterministicInt(payload: String, modulo: Int) -> Int {
        guard modulo > 0 else {
            return 0
        }

        return Int(stableHash(payload) % UInt64(modulo))
    }

    private static func safe(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }

    private static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}
