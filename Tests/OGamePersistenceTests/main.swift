import OGamePersistence

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError(message)
    }
}

require(OGamePersistencePackageAnchor.self == OGamePersistencePackageAnchor.self, "OGamePersistence package anchor should exist")
print("OGamePersistenceTests passed")
