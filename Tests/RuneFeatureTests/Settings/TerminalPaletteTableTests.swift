import Testing

@testable import RuneFeature

/// Pins every row of today's terminal scheme data (RUNE-2 characterisation). Match
/// Theme's colours are the host's since RUNE-5 (`TerminalPaletteTests`).
@Suite("Terminal palette table")
struct TerminalPaletteTableTests {
    @Test("there are exactly nine schemes, in picker order, with unique ids")
    func schemeList() {
        #expect(TerminalColorScheme.all.map(\.id) == PaletteOracle.schemes.map(\.id))
        #expect(Set(TerminalColorScheme.all.map(\.id)).count == 9)
        #expect(TerminalColorScheme.matchThemeID == "match-theme")
    }

    @Test("each scheme matches today's name, bg, fg, cursor and 16 ANSI colours")
    func schemeRows() {
        for row in PaletteOracle.schemes {
            let s = TerminalColorScheme.scheme(id: row.id)
            #expect(s.id == row.id)
            #expect(s.name == row.name, "\(row.id) name")
            #expect(s.background == row.background, "\(row.id) background")
            #expect(s.foreground == row.foreground, "\(row.id) foreground")
            #expect(s.cursor == row.cursor, "\(row.id) cursor")
            #expect(s.ansi == row.ansi, "\(row.id) ansi")
        }
    }

    @Test("every scheme has 16 well-formed uppercase RRGGBB ANSI colours")
    func schemesAreWellFormed() {
        for s in TerminalColorScheme.all {
            #expect(s.ansi.count == 16, "\(s.id)")
            let all = s.ansi + [s.background, s.foreground, s.cursor].compactMap { $0 }
            for hex in all {
                #expect(
                    hex.count == 6 && hex == hex.uppercased() && UInt32(hex, radix: 16) != nil,
                    "\(s.id) \(hex)")
            }
        }
    }

    @Test("only Match Theme leaves bg, fg and cursor nil")
    func onlyMatchThemeIsDerived() {
        for s in TerminalColorScheme.all {
            let derived = s.background == nil && s.foreground == nil && s.cursor == nil
            #expect(derived == (s.id == TerminalColorScheme.matchThemeID), "\(s.id)")
        }
    }

    @Test("an unknown scheme id falls back to Match Theme")
    func unknownSchemeID() {
        #expect(TerminalColorScheme.scheme(id: "nope") == TerminalColorScheme.matchTheme)
        #expect(TerminalColorScheme.scheme(id: "") == TerminalColorScheme.matchTheme)
    }
}
