import AppKit
import CoreText

/// The list of monospaced font families offered in Terminal settings: every
/// installed fixed-pitch family, unioned with the fonts Ainkrad bundles
/// (JetBrains Mono, MesloLGS NF) so they are always present even if the
/// availability probe misses them.
enum MonospacedFonts {
    /// Families Ainkrad bundles or always wants offered when present.
    private static let preferred = ["MesloLGS NF", "JetBrains Mono", "Menlo", "Monaco"]

    /// Probed once per launch, in the background as soon as Rune loads
    /// (`warm()`), so the first Settings open does not pay for it. Settings
    /// asks on every catalog build, and probing creates a font for every
    /// installed family. A font installed while Ainkrad runs appears after a
    /// relaunch.
    @MainActor private static var cached: [String]?
    @MainActor private static var isWarming = false

    /// Starts the probe off the main thread. Safe to call more than once.
    @MainActor
    static func warm() {
        guard cached == nil, !isWarming else { return }
        isWarming = true
        Task.detached(priority: .utility) {
            let found = probe()
            await MainActor.run {
                if cached == nil { cached = found }
                isWarming = false
            }
        }
    }

    /// The families, from the warm-up if it has finished, otherwise probed
    /// now on the caller's thread (the same probe, so the same answer).
    @MainActor
    static func available() -> [String] {
        if let cached { return cached }
        let found = probe()
        cached = found
        return found
    }

    /// CoreText rather than `NSFontManager`/`NSFont`: it is thread-safe,
    /// which is what lets `warm()` run off the main thread.
    nonisolated private static func probe() -> [String] {
        var families = Set<String>()
        let isFont = { (name: String) in
            CTFontCopyFamilyName(CTFontCreateWithName(name as CFString, 12, nil)) as String == name
        }
        for family in preferred where isFont(family) {
            families.insert(family)
        }
        let installed = CTFontManagerCopyAvailableFontFamilyNames() as? [String] ?? []
        for family in installed {
            let font = CTFontCreateWithName(family as CFString, 12, nil)
            if CTFontGetSymbolicTraits(font).contains(.traitMonoSpace) {
                families.insert(family)
            }
        }
        return families.sorted()
    }
}
