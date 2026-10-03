import SwiftUI
import AppKit
import AinkradAppKit

/// Rune's settings as DECLARED fields, so the host draws them in the shared
/// settings style. The "Appearance" group is merged by the host into its one
/// Appearance tab (after Open as / Open in, before Blur). `TerminalSettingsView`
/// stays as the page for hosts that predate this.
@MainActor
enum TerminalSettingsCatalog {
    static func page(store: TerminalSettingsStore, state: TerminalSettingsPageState,
                     theme: HostTheme) -> SettingsPage {
        let root = SettingsPath([RuneApp.id])
        return SettingsPage(
            path: root, title: RuneApp.displayName, icon: RuneApp.icon, group: .installedApps, order: 0,
            groups: [appearance(store, theme, root), behavior(store, state, root)],
            appID: RuneApp.id)
    }

    private static let defaults = TerminalSettings()

    private static func appearance(_ store: TerminalSettingsStore, _ theme: HostTheme,
                                   _ root: SettingsPath) -> SettingsGroup {
        let group = root.appending("appearance")
        let s = store.settings
        let resolved = TerminalAppearanceResolver.resolve(settings: s, tokens: theme.tokens)
        let size = s.fontSize ?? TerminalAppearanceResolver.defaultFontSize
        return SettingsGroup(path: group, title: "Appearance", fields: [
            SettingsField(
                path: group.appending("scheme"), label: "Color scheme",
                help: "The terminal's palette. Match Theme follows the workspace colours.",
                keywords: ["colour", "color", "scheme", "palette", "theme"],
                kind: .select(options: TerminalColorScheme.all.map { SettingsOption(id: $0.id, title: $0.name) },
                              selection: Binding(get: { store.settings.colorSchemeID },
                                                 set: { v in store.update { $0.colorSchemeID = v } })),
                defaultDescription: TerminalColorScheme.all.first { $0.id == defaults.colorSchemeID }?.name,
                isModified: { store.settings.colorSchemeID != defaults.colorSchemeID },
                reset: { store.update { $0.colorSchemeID = defaults.colorSchemeID } }),
            SettingsField(
                path: group.appending("transparency"), label: "Background transparency",
                help: "\(Int((1 - s.backgroundOpacity) * 100))%. Lets the ambient backdrop show through the terminal.",
                keywords: ["transparency", "opacity", "translucent", "background"],
                kind: .slider(range: 0.2...1.0, step: 0.05, value: Binding(
                    get: { 1.2 - store.settings.backgroundOpacity },   // right = more transparent
                    set: { v in store.update { $0.backgroundOpacity = 1.2 - v } })),
                defaultDescription: "0%",
                isModified: { store.settings.backgroundOpacity != defaults.backgroundOpacity },
                reset: { store.update { $0.backgroundOpacity = defaults.backgroundOpacity } }),
            SettingsField(
                path: group.appending("font"), label: "Font",
                keywords: ["font", "typeface", "monospace"],
                kind: .select(options: MonospacedFonts.available().map { SettingsOption(id: $0, title: $0) },
                              selection: Binding(
                                get: { store.settings.fontFamily ?? TerminalAppearanceResolver.defaultFontFamily },
                                set: { v in store.update { $0.fontFamily = v } })),
                defaultDescription: TerminalAppearanceResolver.defaultFontFamily,
                isModified: { store.settings.fontFamily != nil },
                reset: { store.update { $0.fontFamily = nil } }),
            SettingsField(
                path: group.appending("font-size"), label: "Font size",
                help: "\(Int(size)) pt",
                keywords: ["font", "size", "text"],
                kind: .slider(range: 9...28, step: 1, value: Binding(
                    get: { store.settings.fontSize ?? TerminalAppearanceResolver.defaultFontSize },
                    set: { v in store.update { $0.fontSize = v.rounded() } })),
                defaultDescription: "\(Int(TerminalAppearanceResolver.defaultFontSize)) pt",
                isModified: { store.settings.fontSize != nil },
                reset: { store.update { $0.fontSize = nil } }),
            SettingsField(
                path: group.appending("cursor"), label: "Cursor",
                keywords: ["cursor", "caret", "block", "bar", "underline"],
                kind: .select(options: TerminalCursorShape.allCases.map { SettingsOption(id: $0.rawValue, title: $0.rawValue.capitalized) },
                              selection: Binding(get: { store.settings.cursorShape.rawValue },
                                                 set: { v in store.update { $0.cursorShape = TerminalCursorShape(rawValue: v) ?? .block } })),
                defaultDescription: defaults.cursorShape.rawValue.capitalized,
                isModified: { store.settings.cursorShape != defaults.cursorShape },
                reset: { store.update { $0.cursorShape = defaults.cursorShape } }),
            SettingsField(
                path: group.appending("blink"), label: "Cursor blink",
                keywords: ["cursor", "blink"],
                kind: .toggle(Binding(get: { store.settings.cursorBlink },
                                      set: { v in store.update { $0.cursorBlink = v } })),
                defaultDescription: "On",
                isModified: { store.settings.cursorBlink != defaults.cursorBlink },
                reset: { store.update { $0.cursorBlink = defaults.cursorBlink } }),
            color(store, group.appending("cursor-color"), "Cursor color", s.cursorColor, resolved.cursor,
                  \.cursorColor),
            color(store, group.appending("selection-color"), "Selection color", s.selectionColor,
                  resolved.selection, \.selectionColor),
        ])
    }

    /// A colour row: the button shows the colour's hex and opens the system
    /// colour panel; reset returns it to the scheme's own colour.
    private static func color(_ store: TerminalSettingsStore, _ path: SettingsPath, _ label: String,
                              _ override: String?, _ resolvedHex: String,
                              _ key: WritableKeyPath<TerminalSettings, String?>) -> SettingsField {
        SettingsField(
            path: path, label: label,
            help: override == nil ? "From the color scheme." : "Custom.",
            keywords: ["colour", "color", label.lowercased()],
            kind: .action(title: "#" + (override ?? resolvedHex).uppercased().trimmingCharacters(in: ["#"])) {
                ColorPanelBridge.shared.edit(Color(hex: override ?? resolvedHex)) { picked in // design-lint: allow hex-color user-chosen terminal colour (settings data)
                    store.update { $0[keyPath: key] = picked.hexString }
                }
            },
            defaultDescription: "the scheme's color",
            isModified: { store.settings[keyPath: key] != nil },
            reset: { store.update { $0[keyPath: key] = nil } })
    }

    private static func behavior(_ store: TerminalSettingsStore, _ state: TerminalSettingsPageState,
                                 _ root: SettingsPath) -> SettingsGroup {
        let group = root.appending("behavior")
        let s = store.settings
        if state.shellDraft == nil { state.shellDraft = s.defaultShell ?? "" }
        func toggle(_ id: String, _ label: String, _ help: String,
                    _ key: WritableKeyPath<TerminalSettings, Bool>) -> SettingsField {
            SettingsField(
                path: group.appending(id), label: label, help: help, keywords: [label.lowercased()],
                kind: .toggle(Binding(get: { store.settings[keyPath: key] },
                                      set: { v in store.update { $0[keyPath: key] = v } })),
                defaultDescription: defaults[keyPath: key] ? "On" : "Off",
                isModified: { store.settings[keyPath: key] != defaults[keyPath: key] },
                reset: { store.update { $0[keyPath: key] = defaults[keyPath: key] } })
        }
        return SettingsGroup(path: group, title: "Behavior", fields: [
            SettingsField(
                path: group.appending("shell"), label: "Default shell",
                help: state.shellInvalid ? "Not a shell listed in /etc/shells — not saved."
                    : "Must be listed in /etc/shells. Leave empty to use the login shell.",
                keywords: ["shell", "zsh", "bash", "fish"],
                kind: .text(Binding(get: { state.shellDraft ?? "" },
                                    set: { state.setShell($0, in: store) })),
                defaultDescription: "the login shell",
                isModified: { store.settings.defaultShell != nil },
                reset: { state.setShell("", in: store) }),
            SettingsField(
                path: group.appending("directory"), label: "Default working directory",
                help: s.defaultWorkingDirectory?.path ?? "Home directory",
                keywords: ["directory", "folder", "cwd", "working"],
                kind: .action(title: "Choose…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.showsHiddenFiles = true
                    panel.message = "Choose the default working directory"
                    panel.prompt = "Choose"
                    panel.directoryURL = store.settings.defaultWorkingDirectory
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    store.update { $0.defaultWorkingDirectory = url }
                },
                defaultDescription: "Home directory",
                isModified: { store.settings.defaultWorkingDirectory != nil },
                reset: { store.update { $0.defaultWorkingDirectory = nil } }),
            toggle("meta", "Use Option as Meta key",
                   "Send ⌥ as Meta/Esc+ (for tmux, emacs, and shell editing).", \.optionAsMeta),
            toggle("mouse", "Send mouse events to apps",
                   "Forward clicks, motion, and the wheel to terminal apps (Claude Code, vim, tmux). "
                   + "Off: mouse stays for native selection and scrollback.", \.sendMouseEventsToApps),
            SettingsField(
                path: group.appending("scrollback"), label: "Scrollback lines",
                help: "\(s.scrollbackLines) lines kept above the screen.",
                keywords: ["scrollback", "history", "lines", "buffer"],
                kind: .slider(range: 0...100_000, step: 500, value: Binding(
                    get: { Double(store.settings.scrollbackLines) },
                    set: { v in store.update { $0.scrollbackLines = Int(v) } })),
                defaultDescription: "\(defaults.scrollbackLines)",
                isModified: { store.settings.scrollbackLines != defaults.scrollbackLines },
                reset: { store.update { $0.scrollbackLines = defaults.scrollbackLines } }),
        ])
    }
}

/// The shell field's draft between the host's rebuilds of the page: saved
/// only when it names a real shell (or is empty), as the old view did on submit.
@MainActor @Observable
final class TerminalSettingsPageState {
    var shellDraft: String?
    private(set) var shellInvalid = false

    func setShell(_ text: String, in store: TerminalSettingsStore) {
        shellDraft = text
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            store.update { $0.defaultShell = nil }
            shellInvalid = false
        } else if (try? ShellResolver().resolveDefaultShell(override: trimmed)) != nil {
            store.update { $0.defaultShell = trimmed }
            shellInvalid = false
        } else {
            shellInvalid = true
        }
    }
}

/// Drives the shared `NSColorPanel` for one colour row at a time.
@MainActor
final class ColorPanelBridge: NSObject {
    static let shared = ColorPanelBridge()
    private var onChange: ((Color) -> Void)?

    func edit(_ color: Color, onChange: @escaping (Color) -> Void) {
        self.onChange = onChange
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.color = NSColor(color)
        panel.setTarget(self)
        panel.setAction(#selector(changed(_:)))
        panel.orderFront(nil)
    }

    @objc private func changed(_ sender: NSColorPanel) {
        onChange?(Color(nsColor: sender.color))
    }
}
