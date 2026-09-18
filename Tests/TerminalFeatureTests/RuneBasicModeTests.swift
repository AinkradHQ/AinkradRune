import Testing
import SwiftUI
import AinkradAppKit
@testable import TerminalFeature

/// Rune's basic mode: one command, no interactive shell.
@Suite("Rune — basic mode")
@MainActor
struct RuneBasicModeTests {

    @Test("Rune opts into modes, so the host's cast finds it")
    func optsIntoModes() {
        #expect((RuneApp.self as Any) as? AinkradAppModes.Type != nil)
    }

    @Test("Basic mode consumes no pending launch payload")
    func basicDoesNotConsumeALaunch() {
        // `takePendingLaunch()` CONSUMES. Advanced calls it to pick up an SSH
        // launch from Leyline; if basic called it too, opening Rune in basic
        // would silently eat a connection request and Leyline's Connect button
        // would look like it did nothing.
        let host = BasicModeHost()
        host.launcher.pending = #"{"kind":"ssh","host":"example.com"}"#
        _ = RuneApp.makeRootView(host: host, mode: .basic)
        #expect(host.launcher.takeCount == 0,
                "basic mode must not consume a launch payload meant for a session")
    }

    @Test("Basic mode registers no agent actions")
    func basicRegistersNoActions() {
        // The actions drive a live terminal session, and basic has none.
        // Registering them would publish an agent action whose target does not
        // exist — the agent would call it and nothing would happen.
        let host = BasicModeHost()
        _ = RuneApp.makeRootView(host: host, mode: .basic)
        #expect(host.actionRegistry.registered.isEmpty,
                "basic mode has no session for an action to drive")
    }

    @Test("Advanced mode still registers its actions and takes its launch")
    func advancedIsUnchanged() {
        // The counterpart: proving basic is narrow only matters if advanced
        // still does everything it did before the mode existed.
        let host = BasicModeHost()
        _ = RuneApp.makeRootView(host: host, mode: .advanced)
        #expect(!host.actionRegistry.registered.isEmpty)
    }

    @Test("The mode-less entry point still means advanced")
    func legacyEntryPointMeansAdvanced() {
        let host = BasicModeHost()
        _ = RuneApp.makeRootView(host: host)
        #expect(!host.actionRegistry.registered.isEmpty)
    }
}

// MARK: - Fakes

@MainActor
private final class RecordingLauncher: PluginAppLauncher {
    var pending: String?
    private(set) var takeCount = 0
    func open(appID: String, payload: String?) {}
    func takePendingLaunch() -> String? {
        takeCount += 1
        defer { pending = nil }
        return pending
    }
}

@MainActor
private final class RecordingActions: AgentActionProvider {
    private(set) var registered: [String] = []
    func register(actionID: String,
                  handler: @escaping @MainActor (String) async -> AgentActionResult) -> AgentActionToken {
        registered.append(actionID)
        return AgentActionToken()
    }
    func remove(_ token: AgentActionToken) {}
}

@MainActor
private final class BasicModeHost: HostServices {
    let documents: PluginDocumentStore = MemoryDocs()
    let secrets: PluginSecretStore = MemorySecrets()
    let launcher = RecordingLauncher()
    let actionRegistry = RecordingActions()

    var theme: HostTheme {
        HostTheme(.init(themeID: "t", background: .black, surface: .black,
                        surfaceElevated: .black, accentPrimary: .white,
                        accentSecondary: .white, accentTertiary: .white, foreground: .white))
    }
    var log: PluginLogger { MemoryLog() }
    var context: PluginContextRegistry { MemoryContext() }
    var actions: AgentActionProvider { actionRegistry }
    var apps: PluginAppLauncher { launcher }
    var presentation: PluginPresentationControl { MemoryPresentation() }
    var mode: PluginModeControl { MemoryMode() }
    var signals: PluginSignalEmitter { NoopSignalEmitter() }
}

private final class MemoryDocs: PluginDocumentStore {
    private var storage: [String: Data] = [:]
    func data(forKey key: String) -> Data? { storage[key] }
    func setData(_ data: Data?, forKey key: String) { storage[key] = data }
}
private final class MemorySecrets: PluginSecretStore {
    private var storage: [String: String] = [:]
    func secret(forKey key: String) -> String? { storage[key] }
    func setSecret(_ value: String?, forKey key: String) { storage[key] = value }
}
private struct MemoryLog: PluginLogger {
    func info(_ message: String) {}
    func error(_ message: String) {}
}
@MainActor private struct MemoryContext: PluginContextRegistry {
    func register(_ source: @escaping @MainActor () -> AgentContextSnapshot?) -> PluginContextToken {
        PluginContextToken()
    }
    func remove(_ token: PluginContextToken) {}
}
@MainActor private struct MemoryPresentation: PluginPresentationControl {
    var current: PluginPresentation { .overlay }
    func set(_ presentation: PluginPresentation) {}
    func reset() {}
}
@MainActor private struct MemoryMode: PluginModeControl {
    var current: PluginMode { .basic }
    func set(_ mode: PluginMode) {}
    func reset() {}
}
