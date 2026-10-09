import AinkradAppKit
import Testing

@testable import RuneFeature

/// RUNE-5: Match App Theme renders `host.theme.terminalPalette`, with Neon Blue
/// standing in for anything the host did not send.
@Suite("Match Theme palette")
struct TerminalPaletteTests {
    private let neonBlue = PaletteOracle.hostPalettes[0]

    @Test("a host that publishes no palette gets Neon Blue")
    func nilFallsBack() {
        let p = TerminalAppearanceResolver.matchPalette(nil)
        #expect(p.background == neonBlue.bg && p.foreground == neonBlue.fg && p.cursor == neonBlue.cursor)
        #expect(p.ansi == neonBlue.ansi)
    }

    @Test("the host's colours are used as sent")
    func hostColoursPassThrough() throws {
        let host = try #require(palette(themeID: "dracula"))
        let p = TerminalAppearanceResolver.matchPalette(host)
        #expect(p.background == host.background && p.foreground == host.foreground && p.cursor == host.cursor)
        #expect(p.ansi == host.ansi)
    }

    @Test("empty fields and a short ANSI list fall back entry by entry")
    func emptyFieldsFallBack() {
        var ansi = Array(repeating: "", count: 3)
        ansi[1] = "FF0000"
        let host = HostTerminalPalette(background: "", foreground: "FFFFFF", cursor: "", selection: "", ansi: ansi)
        let p = TerminalAppearanceResolver.matchPalette(host)
        #expect(p.background == neonBlue.bg && p.cursor == neonBlue.cursor && p.foreground == "FFFFFF")
        #expect(p.ansi.count == 16)
        #expect(p.ansi[0] == neonBlue.ansi[0] && p.ansi[1] == "FF0000" && p.ansi[15] == neonBlue.ansi[15])
    }
}
