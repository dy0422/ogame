import Foundation

public enum TestingResourceGrant {
    public static let infiniteResourceAmount = 1_000_000_000_000.0
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
}
