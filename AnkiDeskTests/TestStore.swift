import Foundation

extension UserDefaults {
    /// One shared, emptied store for tests, so they never touch the app's own settings.
    static func testStore() -> UserDefaults {
        let name = "com.weizhi.AnkiDeskTests.store"
        let store = UserDefaults(suiteName: name)!
        store.removePersistentDomain(forName: name)
        return store
    }
}
