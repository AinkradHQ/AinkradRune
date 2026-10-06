import AinkradAppKit
import Foundation
import Observation
import Testing

@testable import RuneFeature

private final class FakeDocs: PluginDocumentStore {
    var storage: [String: Data] = [:]
    func data(forKey key: String) -> Data? { storage[key] }
    func setData(_ data: Data?, forKey key: String) { storage[key] = data }
}

/// Reference box so the observation `onChange` closure (which Swift 6 treats as
/// concurrently-executing) can record that it fired without mutating a captured
/// local `var`.
private final class Flag: @unchecked Sendable {
    var fired = false
}

@Suite("TerminalSettingsStore")
@MainActor
struct TerminalSettingsStoreTests {
    @Test("loads defaults when the scoped store is empty")
    func loadsDefaults() {
        let store = TerminalSettingsStore(documents: FakeDocs())
        #expect(store.settings.colorSchemeID == TerminalColorScheme.matchThemeID)
    }

    @Test("an update persists and reloads through the scoped store")
    func updatePersists() {
        let docs = FakeDocs()
        let store = TerminalSettingsStore(documents: docs)
        store.update {
            $0.fontFamily = "Menlo"
            $0.fontSize = 16
        }
        let reloaded = TerminalSettingsStore(documents: docs)
        #expect(reloaded.settings.fontFamily == "Menlo")
        #expect(reloaded.settings.fontSize == 16)
    }

    @Test("an update publishes an observation change")
    func updatePublishes() {
        let store = TerminalSettingsStore(documents: FakeDocs())
        let flag = Flag()
        withObservationTracking {
            _ = store.settings
        } onChange: {
            flag.fired = true
        }
        store.update { $0.cursorBlink = false }
        #expect(flag.fired)
    }

    @Test("corrupt document is set aside, not overwritten")
    func corruptDocumentIsSetAsideNotOverwritten() {
        let seed = Data("{not json".utf8)
        let docs = FakeDocs()
        docs.setData(seed, forKey: TerminalSettings.documentID)
        let store = TerminalSettingsStore(documents: docs)
        store.update { $0.fontSize = 16 }
        let backups = docs.storage.keys.filter {
            $0.hasPrefix("\(TerminalSettings.documentID).corrupt-")
        }
        #expect(backups.count == 1, "corrupt bytes were not set aside")
        #expect(docs.storage[backups.first ?? ""] == seed, "backup does not hold the seed bytes")
    }

    @Test("unverifiable set-aside keeps the original and stops saving")
    func unverifiableSetAsideKeepsOriginalAndStopsSaving() {
        let seed = Data("{not json".utf8)
        let docs = RejectingCorruptDocs()
        docs.setData(seed, forKey: TerminalSettings.documentID)
        let store = TerminalSettingsStore(documents: docs)
        store.update { $0.fontSize = 16 }
        #expect(
            docs.storage[TerminalSettings.documentID] == seed,
            "the only copy of the user's data was overwritten")
    }
}

/// In-memory document store whose `setData` ignores backup keys, simulating a
/// failed verification read-back after the set-aside write.
private final class RejectingCorruptDocs: PluginDocumentStore {
    var storage: [String: Data] = [:]
    func data(forKey key: String) -> Data? { storage[key] }
    func setData(_ data: Data?, forKey key: String) {
        if key.contains(".corrupt-") { return }
        storage[key] = data
    }
}
