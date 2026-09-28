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

    @Test("Basic mode resolves the SAME shell and directory a session would")
    func basicUsesTheRealResolution() {
        // The bug this guards, which shipped once: basic mode hand-rolled
        // `environment["SHELL"] ?? "/bin/zsh"`, so a configured shell and a
        // configured working directory were both ignored and the /etc/shells
        // validation was skipped. Commands ran somewhere the user had not
        // chosen, under a shell they had not picked.
        let directory = FileManager.default.temporaryDirectory
        var settings = TerminalSettings()
        settings.defaultShell = "/bin/bash"
        settings.defaultWorkingDirectory = directory

        let resolved = TerminalSessionFactory(settings: settings).resolve()

        #expect(resolved.shellPath == "/bin/bash",
                "the configured shell must be honoured, not overridden by $SHELL")
        #expect(resolved.workingDirectory.standardizedFileURL == directory.standardizedFileURL,
                "the configured working directory must be honoured, not replaced with home")
    }

    @Test("An invalid configured shell falls back and SAYS so")
    func invalidShellIsReported() {
        // Silently substituting a shell is how a basic-mode command runs under
        // something the user did not pick with nothing on screen to explain it.
        var settings = TerminalSettings()
        settings.defaultShell = "/not/a/shell"
        let resolved = TerminalSessionFactory(settings: settings).resolve()

        #expect(resolved.shellPath != "/not/a/shell")
        #expect(resolved.notices.isEmpty == false,
                "a rejected shell must produce a notice, not a silent substitution")
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
    /// Every instance is retained for the life of the test process, for the
    /// reason `FakeHostServices` already documents: `TerminalRuntime` keys its
    /// per-host registries by `ObjectIdentifier(host)` and never evicts them.
    /// A short-lived host that deallocates can have its ADDRESS REUSED by a
    /// later test, which then collides with the stale entry and defeats
    /// register-once — so `registerActions` silently does nothing and the
    /// assertion fails in whichever test happened to allocate second.
    ///
    /// Found the hard way: this double omitted the retention, and adding two
    /// unrelated tests was enough to change the allocation pattern and break a
    /// test that had been passing.
    nonisolated(unsafe) static var liveInstances: [BasicModeHost] = []

    let documents: PluginDocumentStore = MemoryDocs()
    let secrets: PluginSecretStore = MemorySecrets()
    let launcher = RecordingLauncher()
    let actionRegistry = RecordingActions()

    init() { BasicModeHost.liveInstances.append(self) }

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
    /// Generation 11, alongside the overlay-size control.
    var overlaySize: PluginOverlaySizeControl { StubOverlaySize() }
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

@MainActor
private struct StubOverlaySize: PluginOverlaySizeControl {
    var current: PluginOverlaySize { .medium }
    func set(_ size: PluginOverlaySize) {}
    func reset() {}
}
