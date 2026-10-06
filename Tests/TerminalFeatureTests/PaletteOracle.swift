// design-lint: allow-file hex-color characterisation oracle: today's terminal palette values, frozen as literals
/// Today's terminal palette values, frozen as literals (NOT read from the source
/// tables) so a later change to where the palette lives cannot move a colour
/// without a test failing. RUNE-5 moves Match Theme onto the skin's `terminal`
/// group; these rows are the parity oracle it must still satisfy.
struct SchemeRow {
    let id: String
    let name: String
    let background: String?
    let foreground: String?
    let cursor: String?
    let ansi: [String]
}

enum PaletteOracle {
    private static func ansi(_ s: String) -> [String] { s.split(separator: " ").map(String.init) }

    static let matchThemeANSI = ansi("1A1D24 E06C75 98C379 E5C07B 61AFEF C678DD 56B6C2 ABB2BF 5C6370 E06C75 98C379 E5C07B 61AFEF C678DD 56B6C2 FFFFFF")
    static let draculaANSI = ansi("21222C FF5555 50FA7B F1FA8C BD93F9 FF79C6 8BE9FD F8F8F2 6272A4 FF6E6E 69FF94 FFFFA5 D6ACFF FF92DF A4FFFF FFFFFF")
    static let nordANSI = ansi("3B4252 BF616A A3BE8C EBCB8B 81A1C1 B48EAD 88C0D0 E5E9F0 4C566A BF616A A3BE8C EBCB8B 81A1C1 B48EAD 8FBCBB ECEFF4")
    static let tokyoNightANSI = ansi("15161E F7768E 9ECE6A E0AF68 7AA2F7 BB9AF7 7DCFFF A9B1D6 414868 F7768E 9ECE6A E0AF68 7AA2F7 BB9AF7 7DCFFF C0CAF5")
    static let gruvboxANSI = ansi("282828 CC241D 98971A D79921 458588 B16286 689D6A A89984 928374 FB4934 B8BB26 FABD2F 83A598 D3869B 8EC07C EBDBB2")
    static let solarizedDarkANSI = ansi("073642 DC322F 859900 B58900 268BD2 D33682 2AA198 EEE8D5 002B36 CB4B16 586E75 657B83 839496 6C71C4 93A1A1 FDF6E3")
    static let monokaiANSI = ansi("272822 F92672 A6E22E F4BF75 66D9EF AE81FF A1EFE4 F8F8F2 75715E F92672 A6E22E F4BF75 66D9EF AE81FF A1EFE4 F9F8F5")
    static let oneDarkANSI = ansi("282C34 E06C75 98C379 E5C07B 61AFEF C678DD 56B6C2 ABB2BF 5C6370 E06C75 98C379 E5C07B 61AFEF C678DD 56B6C2 FFFFFF")
    static let catppuccinANSI = ansi("45475A F38BA8 A6E3A1 F9E2AF 89B4FA F5C2E7 94E2D5 BAC2DE 585B70 F38BA8 A6E3A1 F9E2AF 89B4FA F5C2E7 94E2D5 A6ADC8")

    /// Match Theme rows: host theme id -> (bg, fg, cursor, ansi).
    static let hostPalettes: [(id: String, bg: String, fg: String, cursor: String, ansi: [String])] = [
        ("neonBlue", "0A0E17", "E2E8F0", "22D3EE", matchThemeANSI),
        ("cyberPurple", "080814", "EDE9FE", "C084FC", matchThemeANSI),
        ("dracula", "282A36", "F8F8F2", "BD93F9", draculaANSI),
        ("nord", "2E3440", "D8DEE9", "88C0D0", nordANSI),
        ("tokyoNight", "1A1B26", "C0CAF5", "7AA2F7", tokyoNightANSI),
        ("gruvbox", "282828", "EBDBB2", "FE8019", gruvboxANSI),
        ("solarizedDark", "002B36", "839496", "93A1A1", solarizedDarkANSI),
    ]

    /// The nine user-selectable schemes, in picker order.
    static let schemes: [SchemeRow] = [
        SchemeRow(id: "match-theme", name: "Match App Theme", background: nil, foreground: nil, cursor: nil, ansi: matchThemeANSI),
        SchemeRow(id: "dracula", name: "Dracula", background: "282A36", foreground: "F8F8F2", cursor: "BD93F9", ansi: draculaANSI),
        SchemeRow(id: "nord", name: "Nord", background: "2E3440", foreground: "D8DEE9", cursor: "88C0D0", ansi: nordANSI),
        SchemeRow(id: "tokyo-night", name: "Tokyo Night", background: "1A1B26", foreground: "C0CAF5", cursor: "7AA2F7", ansi: tokyoNightANSI),
        SchemeRow(id: "gruvbox", name: "Gruvbox", background: "282828", foreground: "EBDBB2", cursor: "FE8019", ansi: gruvboxANSI),
        SchemeRow(id: "solarized-dark", name: "Solarized Dark", background: "002B36", foreground: "839496", cursor: "93A1A1", ansi: solarizedDarkANSI),
        SchemeRow(id: "monokai", name: "Monokai", background: "272822", foreground: "F8F8F2", cursor: "F8F8F0", ansi: monokaiANSI),
        SchemeRow(id: "one-dark", name: "One Dark", background: "282C34", foreground: "ABB2BF", cursor: "528BFF", ansi: oneDarkANSI),
        SchemeRow(id: "catppuccin-mocha", name: "Catppuccin Mocha", background: "1E1E2E", foreground: "CDD6F4", cursor: "F5E0DC", ansi: catppuccinANSI),
    ]

    static let defaultSelection = "3B4252"
}
