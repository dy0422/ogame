import Foundation
import OGameCore

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError(message)
    }
}

func requireEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    if actual != expected {
        fatalError("\(message): \(actual) != \(expected)")
    }
}

func testEntityIDsAreCodableAndEquatable() throws {
    let id = FactionID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    let data = try JSONEncoder().encode(id)
    let decoded = try JSONDecoder().decode(FactionID.self, from: data)

    requireEqual(decoded, id, "FactionID should round-trip through JSON")
}

func testResourceBundleClampsToStorageLimits() {
    let resources = ResourceBundle(metal: 120, crystal: 80, deuterium: 40)
    let storage = ResourceStorage(metal: 100, crystal: 100, deuterium: 20)

    requireEqual(
        resources.clamped(to: storage),
        ResourceBundle(metal: 100, crystal: 80, deuterium: 20),
        "ResourceBundle should clamp to storage limits"
    )
}

func testResourceBundleDoesNotClampBelowZeroWhenStorageIsInvalid() {
    let resources = ResourceBundle(metal: -5, crystal: 5, deuterium: 40)
    let storage = ResourceStorage(metal: -1, crystal: -10, deuterium: 20)

    requireEqual(
        resources.clamped(to: storage),
        ResourceBundle(metal: 0, crystal: 0, deuterium: 20),
        "ResourceBundle should never clamp below zero"
    )
}

try testEntityIDsAreCodableAndEquatable()
testResourceBundleClampsToStorageLimits()
testResourceBundleDoesNotClampBelowZeroWhenStorageIsInvalid()
print("OGameCoreTests passed")
