import CoreText
import Foundation

/// Registers the terminal's bundled render font (MesloLGS NF) for this process,
/// resolved from whichever bundle contains this type (the loaded plugin bundle).
public enum TerminalFonts {
    private nonisolated(unsafe) static var done = false
    public static func registerBundledFonts() {
        guard !done else { return }
        done = true
        let bundle = Bundle(for: BundleToken.self)
        for url in bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        // After registering, so the bundled fonts are in the list. Settings'
        // first open then finds it ready instead of probing every font.
        Task { @MainActor in MonospacedFonts.warm() }
    }
    private final class BundleToken {}
}
