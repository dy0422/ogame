import OGameCore

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError(message)
    }
}

require(OGameCorePackageAnchor.self == OGameCorePackageAnchor.self, "OGameCore package anchor should exist")
print("OGameCoreTests passed")
