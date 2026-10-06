import Testing

@testable import TerminalFeature

/// The Match-Theme palette assertions, moved out of the host `DesignTokensTests`.
/// The host `Theme` enum doesn't exist in this repo, so the seven theme ids are
/// listed directly (they are the host `Theme` raw values / SDK `themeID`s).
@Suite("TerminalMatchThemePalette")
struct TerminalPaletteTests {
    private let themeIDs = ["neonBlue", "cyberPurple", "dracula", "nord", "tokyoNight", "gruvbox", "solarizedDark"]

    @Test("every theme id resolves to a 16-color palette with a distinct background")
    func everyThemeResolves() {
        var backgrounds = Set<String>()
        for id in themeIDs {
            let palette = TerminalMatchThemePalette.forThemeID(id)
            #expect(palette.ansi.count == 16)
            backgrounds.insert(palette.background)
        }
        #expect(backgrounds.count == themeIDs.count)
    }

    @Test("an unknown theme id falls back to the default (neonBlue) palette")
    func unknownFallsBack() {
        let fallback = TerminalMatchThemePalette.forThemeID("does-not-exist")
        let dflt = TerminalMatchThemePalette.forThemeID("neonBlue")
        #expect(fallback.background == dflt.background)
    }
}
