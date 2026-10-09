import AppKit
// design-lint: allow-file hex-color terminal colours are RRGGBB data (schemes, overrides, host.theme.terminalPalette)
import SwiftUI

extension Color {
    /// Creates a `Color` from a 6-digit RRGGBB hex string, `#` optional.
    /// Parsed by `TerminalContainerView.rgb(hex:)`, the one hex parser, so the
    /// header and the terminal never disagree; malformed input is black.
    init(hex: String) {
        let c = TerminalContainerView.rgb(hex: hex) ?? (0, 0, 0)
        self = Color(red: Double(c.r) / 255, green: Double(c.g) / 255, blue: Double(c.b) / 255)  // design-lint: allow raw-color decodes terminal scheme/override hex (settings data); Match Theme rows come from host.theme.terminalPalette
    }

    /// The color as an uppercase 6-digit RRGGBB hex string (no `#`), or nil if
    /// it can't be resolved to sRGB components.
    var hexString: String? {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return String(
            format: "%02X%02X%02X",
            Int((c.redComponent * 255).rounded()),
            Int((c.greenComponent * 255).rounded()),
            Int((c.blueComponent * 255).rounded())
        )
    }
}
