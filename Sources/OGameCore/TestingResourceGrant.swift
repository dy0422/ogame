import Foundation

public struct TestingAccessGrantResult: Equatable, Sendable {
    public var updatedPlanetCount: Int
    public var recruitmentTickets: Int
    public var trainingData: Int

    public init(updatedPlanetCount: Int, recruitmentTickets: Int, trainingData: Int) {
        self.updatedPlanetCount = max(updatedPlanetCount, 0)
        self.recruitmentTickets = max(recruitmentTickets, 0)
        self.trainingData = max(trainingData, 0)
    }
}

public enum TestingResourceGrant {
    public static let infiniteResourceAmount = 1_000_000_000_000.0
    public static let infiniteCommanderAmount = 1_000_000_000
    public static let infiniteResourceBundle = ResourceBundle(
        metal: infiniteResourceAmount,
        crystal: infiniteResourceAmount,
        deuterium: infiniteResourceAmount
    )
    public static let infiniteStorage = ResourceStorage(
        metal: infiniteResourceAmount,
        crystal: infiniteResourceAmount,
        deuterium: infiniteResourceAmount
    )

    @discardableResult
    public static func grantInfiniteResources(toPlayerIn universe: inout Universe) -> Int {
        guard let playerFaction = universe.factions.first(where: { $0.id == universe.playerFactionID }) else {
            return 0
        }

        let playerPlanetIDs = Set(playerFaction.ownedPlanetIDs)
        var updatedCount = 0
        for planetIndex in universe.planets.indices
            where playerPlanetIDs.contains(universe.planets[planetIndex].id) &&
                universe.planets[planetIndex].ownerID == playerFaction.id
        {
            universe.planets[planetIndex].resources = infiniteResourceBundle
            universe.planets[planetIndex].storage = infiniteStorage
            updatedCount += 1
        }

        return updatedCount
    }

    @discardableResult
    public static func grantInfiniteTestingAccess(toPlayerIn universe: inout Universe) -> TestingAccessGrantResult {
        let updatedPlanetCount = grantInfiniteResources(toPlayerIn: &universe)
        universe.commanderRoster.recruitmentTickets = max(
            universe.commanderRoster.recruitmentTickets,
            infiniteCommanderAmount
        )
        universe.commanderRoster.trainingData = max(
            universe.commanderRoster.trainingData,
            infiniteCommanderAmount
        )

        return TestingAccessGrantResult(
            updatedPlanetCount: updatedPlanetCount,
            recruitmentTickets: universe.commanderRoster.recruitmentTickets,
            trainingData: universe.commanderRoster.trainingData
        )
    }
}
