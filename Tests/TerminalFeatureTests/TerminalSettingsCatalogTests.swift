import AinkradAppKit
import XCTest

@testable import TerminalFeature

private final class MemoryDocs: PluginDocumentStore {
    private var storage: [String: Data] = [:]
    func data(forKey key: String) -> Data? { storage[key] }
    func setData(_ data: Data?, forKey key: String) { storage[key] = data }
}

@MainActor
final class TerminalSettingsCatalogTests: XCTestCase {
    private func page(_ store: TerminalSettingsStore, _ state: TerminalSettingsPageState = .init()) -> SettingsPage {
        TerminalSettingsCatalog.page(store: store, state: state, theme: HostTheme(tokens(themeID: "test")))
    }

    /// Declared, no custom rows; "Appearance" is merged by the host into its tab.
    func testPageIsDeclared() {
        let p = page(TerminalSettingsStore(documents: MemoryDocs()))
        XCTAssertEqual(p.groups.map(\.title), ["Appearance", "Behavior"])
        XCTAssertFalse(p.groups.flatMap(\.fields).contains { if case .custom = $0.kind { true } else { false } })
    }

    /// Saved only when it names a real shell — a half-typed path never is.
    func testShellIsSavedOnlyWhenValid() {
        let store = TerminalSettingsStore(documents: MemoryDocs())
        let state = TerminalSettingsPageState()
        state.setShell("/bin/nope", in: store)
        XCTAssertNil(store.settings.defaultShell)
        XCTAssertTrue(state.shellInvalid)
        state.setShell("/bin/zsh", in: store)
        XCTAssertEqual(store.settings.defaultShell, "/bin/zsh")
        XCTAssertFalse(state.shellInvalid)
        state.setShell("", in: store)
        XCTAssertNil(store.settings.defaultShell)
    }

    /// The slider reads as transparency: right is more see-through.
    func testTransparencySliderIsInverted() throws {
        let store = TerminalSettingsStore(documents: MemoryDocs())
        let field = try XCTUnwrap(page(store).groups[0].fields.first { $0.label == "Background transparency" })
        guard case .slider(_, _, let value) = field.kind else { return XCTFail("not a slider") }
        XCTAssertEqual(value.wrappedValue, 0.2, accuracy: 0.0001)  // opaque = far left
        value.wrappedValue = 1.0
        XCTAssertEqual(store.settings.backgroundOpacity, 0.2, accuracy: 0.0001)
    }
}
