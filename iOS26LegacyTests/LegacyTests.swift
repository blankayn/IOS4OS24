import XCTest
@testable import iOS26Legacy

final class LegacyTests: XCTestCase {
    func testPreferencesPersistAndMalformedLayoutIsBounded() {
        let name = "LegacyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = LegacyStore(defaults: defaults)
        store.update { prefs in
            prefs.wallpaper = 99; prefs.columns = 99; prefs.widget = -1
            prefs.pages = Array(repeating: ["notes", "notes", "unknown", "calculator"], count: 8)
            prefs.blur = true
        }
        let restored = LegacyStore(defaults: defaults).preferences
        XCTAssertEqual(restored.wallpaper, 3)
        XCTAssertEqual(restored.columns, 4)
        XCTAssertEqual(restored.widget, 0)
        XCTAssertEqual(restored.pages.count, 5)
        XCTAssertEqual(restored.pages[0], ["notes", "calculator"])
        XCTAssertTrue(restored.blur)
    }
    func testCorruptPreferencesRecoverAndNotesPersist() {
        let name = "LegacyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(Data([0, 1, 2]), forKey: "legacy.preferences")
        let store = LegacyStore(defaults: defaults)
        XCTAssertEqual(store.preferences.pages.count, 2)
        store.note = "A saved thought"
        XCTAssertEqual(LegacyStore(defaults: defaults).note, "A saved thought")
    }
    func testRecentsDeduplicateLimitAndClose() {
        let store = LegacyStore()
        for app in LegacyApp.catalog { store.visit(app) }
        XCTAssertEqual(store.recents.count, 6)
        let notes = LegacyApp.find("notes")!
        store.visit(notes); store.visit(notes)
        XCTAssertEqual(store.recents.filter { $0 == "notes" }.count, 1)
        XCTAssertEqual(store.recents.first, "notes")
        store.closeRecent("notes")
        XCTAssertFalse(store.recents.contains("notes"))
    }
    func testCalculatorChainingDecimalRepeatAndErrorRecovery() {
        var engine = CalculatorEngine()
        for key in ["1", ".", "5", "+", "2", "=", "="] { engine.press(key) }
        XCTAssertEqual(engine.display, "5.5")
        for key in ["AC", "8", "÷", "0", "="] { engine.press(key) }
        XCTAssertEqual(engine.display, "Error")
        engine.press("4"); XCTAssertEqual(engine.display, "4")
        for key in ["AC", "2", "+", "3", "×", "4", "="] { engine.press(key) }
        XCTAssertEqual(engine.display, "20")
    }
    func testAllPermittedLinksHaveAllowlistedSchemes() {
        let declared = Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String] ?? []
        for link in PermittedLink.allCases { XCTAssertTrue(declared.contains(link.url.scheme ?? "")) }
        XCTAssertTrue(declared.contains("tel"))
    }
}
