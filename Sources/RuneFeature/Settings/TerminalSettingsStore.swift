import AinkradAppKit
import Foundation
import Observation

/// Observable owner of `TerminalSettings`, backed by the app-scoped
/// `HostServices.documents`. Editing persists immediately AND publishes to
/// observers, so the Settings UI and every running Terminal restyle live.
@MainActor
@Observable
final class TerminalSettingsStore {
    private(set) var settings: TerminalSettings
    private let documents: PluginDocumentStore
    private var canSave = true
    private static let key = TerminalSettings.documentID

    init(documents: PluginDocumentStore) {
        self.documents = documents
        let loaded = loadDocument(
            TerminalSettings.self, key: Self.key, from: documents)
        self.settings = loaded.value ?? TerminalSettings()
        self.canSave = loaded.canSave
    }

    /// Mutates the settings, publishes to observers, and persists immediately.
    func update(_ mutate: (inout TerminalSettings) -> Void) {
        var updated = settings
        mutate(&updated)
        settings = updated
        guard canSave else {
            Log.persistence.error("saving is off: the loaded document did not decode and could not be set aside")
            return
        }
        guard let data = try? JSONEncoder().encode(updated) else {
            Log.persistence.error("could not encode terminal settings; not saving")
            return
        }
        documents.setData(data, forKey: Self.key)
    }
}
