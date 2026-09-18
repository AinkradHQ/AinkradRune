import SwiftUI
import AinkradAppKit

/// Rune as an `AinkradApp` — the SDK contract. Compiled into the host for
/// now (slice 4a); slice 4b extracts it into its own catalog bundle. Depends
/// only on `HostServices`, never on `AppEnvironment`.
public struct RuneApp: AinkradApp {
    public static let id = "rune"
    public static let displayName = "Rune"
    public static let icon = "terminal"

    public static func makeRootView(host: HostServices) -> AnyView {
        makeRootView(host: host, mode: .advanced)
    }

    private static func advancedRootView(host: HostServices) -> AnyView {
        TerminalRuntime.registerActions(for: host)
        return AnyView(TerminalBlockRootView(
            settingsStore: TerminalRuntime.settingsStore(for: host),
            contextBridge: TerminalRuntime.contextBridge(for: host),
            reporter: RuneSignalReporter(signals: host.signals),
            theme: host.theme,
            takeLaunch: { RuneLaunch.decode(host.apps.takePendingLaunch()) }
        ))
    }

    public static func makeSettingsView(host: HostServices) -> AnyView {
        AnyView(TerminalSettingsView(
            settingsStore: TerminalRuntime.settingsStore(for: host),
            theme: host.theme,
            presentation: host.presentation,
            modeControl: host.mode
        ))
    }

    /// The header matches the terminal window: the resolved scheme background at
    /// the configured transparency, so the title bar reads as one continuous
    /// surface with the terminal below.
    public static func chromeFill(host: HostServices) -> Color? {
        let appearance = TerminalAppearanceResolver.resolve(
            settings: TerminalRuntime.settingsStore(for: host).settings,
            tokens: host.theme.tokens
        )
        return Color(hex: appearance.background).opacity(appearance.backgroundOpacity)
    }
}

/// Publishes Terminal's read side to the assistant. Resources only, no tools —
/// see `TerminalMCPServer` for why. Cached per host by `mcpServer(for:)` so the
/// resources read the same bridge the visible terminal registers with.
extension RuneApp: AinkradAppMCP {
    public static func makeMCPServer(host: HostServices) -> MCPAppServer {
        TerminalRuntime.mcpServer(for: host)
    }
}

/// Generation 8: release this instance when the host closes it.
///
/// `TerminalRuntime` held four static, never-evicted registries — settings
/// store, context bridge, its registration token, and the `terminal.echo`
/// action token. Closing Terminal left all of them live for the rest of the
/// process, including a context source the agent kept consulting.
extension RuneApp: AinkradAppTeardown {
    public static func teardown(instance: PluginInstanceID) {
        TerminalRuntime.teardown(instance: instance, host: nil)
    }
}

/// Generation 11: Rune's basic mode runs ONE command without an interactive
/// shell — the "quick command on the run" case, where opening a session costs
/// more than the command does.
extension RuneApp: AinkradAppModes {
    public static func makeRootView(host: HostServices, mode: PluginMode) -> AnyView {
        switch mode {
        case .basic:
            // Actions are NOT registered here. They drive the live terminal
            // session, and basic mode has none — registering them would publish
            // an agent action whose target does not exist.
            return AnyView(RuneBasicView(
                settingsStore: TerminalRuntime.settingsStore(for: host),
                theme: host.theme))
        case .advanced:
            return advancedRootView(host: host)
        // Resilient enum: fall back to advanced, never to a stripped view for a
        // mode this build does not understand.
        @unknown default:
            return advancedRootView(host: host)
        }
    }
}
