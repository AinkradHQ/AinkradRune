import AinkradAppKit

/// The caret shape, independent of blink (which is a separate toggle). Maps
/// to SwiftTerm's combined `CursorStyle` in the view layer.
enum TerminalCursorShape: String, Codable, CaseIterable {
    case block
    case underline
    case bar
}

/// The fully-resolved appearance a terminal renders with — the product of a
/// `TerminalColorScheme`, the active app theme (for Match Theme), and the
/// per-terminal overrides. Colors are hex strings; the view layer converts
/// them. `Equatable` so SwiftUI only re-applies when something changed.
struct TerminalRenderAppearance: Equatable {
    let background: String
    let foreground: String
    let cursor: String
    let selection: String
    let ansi: [String]
    let fontFamily: String
    let fontSize: Double
    let cursorShape: TerminalCursorShape
    let cursorBlink: Bool
    let optionAsMeta: Bool
    let scrollback: Int
    /// Terminal background alpha (0.2…1.0); < 1 lets the ambient backdrop show
    /// through the pane.
    let backgroundOpacity: Double
    /// When false, the terminal keeps mouse events for native selection/scroll
    /// and forwards nothing to the child process.
    let sendMouseEventsToApps: Bool
}

/// Pure resolution of `TerminalSettings` (+ the palette the host publishes for
/// the active theme) into a concrete `TerminalRenderAppearance`. No AppKit here —
/// kept unit-testable.
enum TerminalAppearanceResolver {
    static let defaultFontFamily = "MesloLGS NF"
    static let defaultFontSize: Double = 15
    static let defaultSelection = "3B4252"

    /// `palette` is `host.theme.terminalPalette`: what Match App Theme renders with.
    static func resolve(settings: TerminalSettings, palette: HostTerminalPalette?) -> TerminalRenderAppearance {
        let scheme = TerminalColorScheme.scheme(id: settings.colorSchemeID)
        let matchesTheme = scheme.id == TerminalColorScheme.matchThemeID
        let themed = matchPalette(palette)
        return TerminalRenderAppearance(
            background: scheme.background ?? themed.background,
            foreground: scheme.foreground ?? themed.foreground,
            cursor: settings.cursorColor ?? scheme.cursor ?? themed.cursor,
            selection: settings.selectionColor ?? defaultSelection,
            ansi: matchesTheme ? themed.ansi : scheme.ansi,
            fontFamily: settings.fontFamily ?? defaultFontFamily,
            fontSize: settings.fontSize ?? defaultFontSize,
            cursorShape: settings.cursorShape,
            cursorBlink: settings.cursorBlink,
            optionAsMeta: settings.optionAsMeta,
            scrollback: settings.scrollbackLines,
            backgroundOpacity: min(1, max(0.2, settings.backgroundOpacity)),
            sendMouseEventsToApps: settings.sendMouseEventsToApps
        )
    }

    /// The host's palette, field by field, with Neon Blue wherever it sent nothing
    /// (its `selection` is not used: the default selection stays, as before RUNE-5):
    /// `nil` from a host that publishes none, `""` for a token with no fixed colour.
    static func matchPalette(_ host: HostTerminalPalette?) -> HostTerminalPalette {
        func pick(_ value: String?, _ fallback: String) -> String {
            guard let value, !value.isEmpty else { return fallback }
            return value
        }
        let fallbackANSI = TerminalColorScheme.matchTheme.ansi
        let hostANSI = host?.ansi ?? []
        return HostTerminalPalette(
            background: pick(host?.background, "0A0E17"), foreground: pick(host?.foreground, "E2E8F0"),
            cursor: pick(host?.cursor, "22D3EE"), selection: defaultSelection,
            ansi: fallbackANSI.indices.map { pick(hostANSI.indices.contains($0) ? hostANSI[$0] : nil, fallbackANSI[$0]) })
    }
}
