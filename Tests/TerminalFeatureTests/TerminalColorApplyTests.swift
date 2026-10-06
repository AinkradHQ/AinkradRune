import AppKit
import AinkradAppKit
import SwiftTerm
import SwiftUI
import Testing

@testable import TerminalFeature

/// Hex parsing, `Color+Hex`, the native-colour install in
/// `TerminalContainerView.apply`, and `RuneApp.chromeFill` (RUNE-2).
@MainActor
@Suite("Terminal colour apply")
struct TerminalColorApplyTests {
    private func srgb(_ c: NSColor) throws -> [Int] {
        let s = try #require(c.usingColorSpace(.sRGB))
        return [s.redComponent, s.greenComponent, s.blueComponent].map { Int(($0 * 255).rounded()) }
    }

    private func appearance(scheme: String = "match-theme", theme: String = "neonBlue", opacity: Double = 1) -> TerminalRenderAppearance {
        var s = TerminalSettings()
        s.colorSchemeID = scheme
        s.backgroundOpacity = opacity
        return TerminalAppearanceResolver.resolve(settings: s, tokens: tokens(themeID: theme))
    }

    private func container(_ a: TerminalRenderAppearance) -> TerminalContainerView {
        TerminalContainerView(
            session: TerminalSession(workingDirectory: URL(fileURLWithPath: "/tmp"), shellPath: "/bin/zsh"),
            appearance: a, contextBridge: TerminalContextBridge(),
            reporter: RuneSignalReporter(signals: FakeHostServices(context: RecordingContextRegistry()).signals))
    }

    @Test("rgb(hex:) parses RRGGBB with or without a leading #")
    func rgbParsing() throws {
        let a = try #require(TerminalContainerView.rgb(hex: "0A0E17"))
        let b = try #require(TerminalContainerView.rgb(hex: "#0A0E17"))
        #expect(a == (10, 14, 23) && b == (10, 14, 23))
        #expect(try #require(TerminalContainerView.rgb(hex: "ffffff")) == (255, 255, 255))
    }

    @Test("rgb(hex:) rejects malformed input")
    func rgbRejects() {
        for bad in ["", "FFF", "FFFFFFF", "GGGGGG", "##FFFFF", " 0A0E17"] {
            #expect(TerminalContainerView.rgb(hex: bad) == nil, "\(bad)")
        }
    }

    @Test("nsColor(hex:) maps to sRGB and falls back to black on bad input")
    func nsColorConversion() throws {
        #expect(try srgb(TerminalContainerView.nsColor(hex: "282A36")) == [0x28, 0x2A, 0x36])
        #expect(try srgb(TerminalContainerView.nsColor(hex: "bad")) == [0, 0, 0])
    }

    @Test("terminalColor(hex:) scales 8-bit channels to 16-bit by 257, nil on bad input")
    func terminalColorConversion() throws {
        let c = try #require(TerminalContainerView.terminalColor(hex: "FF8000"))
        #expect(c.red == 255 * 257 && c.green == 128 * 257 && c.blue == 0)
        #expect(TerminalContainerView.terminalColor(hex: "nope") == nil)
    }

    @Test("every scheme's 16 ANSI colours convert to terminal colours")
    func allANSIConvert() {
        for s in TerminalColorScheme.all {
            #expect(s.ansi.compactMap(TerminalContainerView.terminalColor(hex:)).count == 16, "\(s.id)")
        }
    }

    @Test("Color(hex:) and hexString round-trip, uppercase and without #")
    func colorHexRoundTrip() {
        for hex in ["0A0E17", "FE8019", "000000", "FFFFFF"] {
            #expect(Color(hex: hex).hexString == hex)
        }
        #expect(Color(hex: "").hexString == "000000")
    }

    @Test("apply installs bg (with opacity), fg, caret and selection on the view")
    func applyInstallsColours() throws {
        let a = appearance(scheme: "dracula", opacity: 0.5)
        let view = AinkradTerminalView(frame: .zero)
        let c = container(a)
        c.apply(a, to: view, coordinator: c.makeCoordinator())

        #expect(try srgb(view.nativeBackgroundColor) == [0x28, 0x2A, 0x36])
        #expect(abs(view.nativeBackgroundColor.alphaComponent - 0.5) < 0.001)
        #expect(try srgb(view.nativeForegroundColor) == [0xF8, 0xF8, 0xF2])
        #expect(try srgb(view.caretColor) == [0xBD, 0x93, 0xF9])
        #expect(try srgb(view.selectedTextBackgroundColor) == [0x3B, 0x42, 0x52])
        #expect(view.layer?.isOpaque == false)
    }

    @Test("apply is skipped when the appearance is unchanged")
    func applySkipsUnchanged() throws {
        let a = appearance()
        let view = AinkradTerminalView(frame: .zero)
        let c = container(a)
        let coordinator = c.makeCoordinator()
        c.apply(a, to: view, coordinator: coordinator)
        view.caretColor = .red
        c.apply(a, to: view, coordinator: coordinator)
        #expect(try srgb(view.caretColor) == [255, 0, 0])
    }

    @Test("apply of Match Theme paints each host palette's bg, fg and cursor")
    func applyMatchThemePerHost() throws {
        for row in PaletteOracle.hostPalettes {
            let a = appearance(theme: row.id)
            let view = AinkradTerminalView(frame: .zero)
            let c = container(a)
            c.apply(a, to: view, coordinator: c.makeCoordinator())
            #expect(try srgb(view.nativeBackgroundColor) == hexComponents(row.bg), "\(row.id) bg")
            #expect(try srgb(view.nativeForegroundColor) == hexComponents(row.fg), "\(row.id) fg")
            #expect(try srgb(view.caretColor) == hexComponents(row.cursor), "\(row.id) cursor")
        }
    }

    @Test("chromeFill is the resolved background at the configured opacity")
    func chromeFillMatchesBackground() throws {
        let host = FakeHostServices(context: RecordingContextRegistry())
        let fill = try #require(RuneApp.chromeFill(host: host))
        let ns = try #require(NSColor(fill).usingColorSpace(.sRGB))
        // FakeHostServices theme id is "test" -> unknown id -> neonBlue fallback row.
        #expect(try srgb(ns) == [0x0A, 0x0E, 0x17])
        #expect(abs(ns.alphaComponent - 1) < 0.001)
    }

    private func hexComponents(_ hex: String) -> [Int] {
        let v = Int(hex, radix: 16) ?? 0
        return [(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF]
    }
}
