import Testing

@testable import RuneFeature

/// Pins how `TerminalAppearanceResolver` combines scheme, host theme and
/// overrides today. RUNE-5 must keep every expectation here unchanged.
@Suite("Terminal appearance parity")
struct TerminalAppearanceParityTests {
    private func resolve(scheme: String = TerminalColorScheme.matchThemeID, theme: String, cursor: String? = nil, selection: String? = nil)
        -> TerminalRenderAppearance
    {
        var s = TerminalSettings()
        s.colorSchemeID = scheme
        s.cursorColor = cursor
        s.selectionColor = selection
        return TerminalAppearanceResolver.resolve(settings: s, palette: palette(themeID: theme))
    }

    @Test("Match Theme resolves every host palette to today's full row, with the default selection")
    func matchThemePerHostPalette() {
        for row in PaletteOracle.hostPalettes {
            let a = resolve(theme: row.id)
            #expect(a.background == row.bg, "\(row.id) bg")
            #expect(a.foreground == row.fg, "\(row.id) fg")
            #expect(a.cursor == row.cursor, "\(row.id) cursor")
            #expect(a.selection == PaletteOracle.defaultSelection, "\(row.id) selection")
            #expect(a.ansi == row.ansi, "\(row.id) ansi")
        }
    }

    @Test("an unknown host theme id under Match Theme resolves to the neonBlue row")
    func unknownThemeFallsBack() {
        let a = resolve(theme: "not-a-theme")
        let blue = PaletteOracle.hostPalettes[0]
        #expect(a.background == blue.bg && a.foreground == blue.fg && a.cursor == blue.cursor)
        #expect(a.ansi == blue.ansi)
        #expect(a.selection == PaletteOracle.defaultSelection)
    }

    @Test("an explicit scheme ignores the host theme for every colour, on all 7 themes")
    func explicitSchemeIgnoresTheme() {
        for scheme in PaletteOracle.schemes where scheme.background != nil {
            for row in PaletteOracle.hostPalettes {
                let a = resolve(scheme: scheme.id, theme: row.id)
                #expect(a.background == scheme.background, "\(scheme.id)/\(row.id) bg")
                #expect(a.foreground == scheme.foreground, "\(scheme.id)/\(row.id) fg")
                #expect(a.cursor == scheme.cursor, "\(scheme.id)/\(row.id) cursor")
                #expect(a.ansi == scheme.ansi, "\(scheme.id)/\(row.id) ansi")
                #expect(a.selection == PaletteOracle.defaultSelection)
            }
        }
    }

    @Test("an unknown colorSchemeID resolves exactly like Match Theme")
    func unknownSchemeIDResolvesAsMatchTheme() {
        for row in PaletteOracle.hostPalettes {
            #expect(resolve(scheme: "bogus", theme: row.id) == resolve(theme: row.id), "\(row.id)")
        }
    }

    @Test("cursor and selection overrides are applied last, over Match Theme and over a named scheme")
    func overridesApplyLast() {
        for scheme in [TerminalColorScheme.matchThemeID, "dracula", "monokai"] {
            let a = resolve(scheme: scheme, theme: "nord", cursor: "112233", selection: "445566")
            let base = resolve(scheme: scheme, theme: "nord")
            #expect(a.cursor == "112233", "\(scheme)")
            #expect(a.selection == "445566", "\(scheme)")
            #expect(a.background == base.background && a.foreground == base.foreground && a.ansi == base.ansi, "\(scheme)")
        }
    }

    @Test("a cursor override does not touch selection, and vice versa")
    func overridesAreIndependent() {
        let c = resolve(theme: "dracula", cursor: "ABCDEF")
        #expect(c.cursor == "ABCDEF" && c.selection == PaletteOracle.defaultSelection)
        let s = resolve(theme: "dracula", selection: "ABCDEF")
        #expect(s.selection == "ABCDEF" && s.cursor == "BD93F9")
    }

    @Test("an override is passed through verbatim, not validated or normalised")
    func overrideIsVerbatim() {
        #expect(resolve(theme: "nord", cursor: "zzzzzz").cursor == "zzzzzz")
        #expect(resolve(theme: "nord", cursor: "#abcdef").cursor == "#abcdef")
    }

    @Test("Basic and Advanced differ today: Match Theme ANSI is the neutral table for neonBlue and cyberPurple only")
    func matchThemeANSIOnlyNeutralForTwoThemes() {
        for row in PaletteOracle.hostPalettes {
            let neutral = row.ansi == PaletteOracle.matchThemeANSI
            #expect(neutral == ["neonBlue", "cyberPurple"].contains(row.id), "\(row.id)")
        }
    }
}
