import SwiftUI
import Testing

@testable import RuneFeature

/// `Color(hex:)` shares `TerminalContainerView.rgb(hex:)`, so the header fill
/// and the terminal read a hex string the same way.
@Suite("Color(hex:) shares the terminal's hex parser")
struct ColorHexTests {
    @Test("a leading # is accepted, as the terminal accepts it")
    func acceptsHashPrefix() {
        #expect(Color(hex: "#0A0E17").hexString == "0A0E17")
    }

    @Test("malformed input is black, as the terminal's background fallback is")
    func malformedIsBlack() {
        for bad in ["", "12345", "1234567", "GGGGGG"] {
            #expect(Color(hex: bad).hexString == "000000", "\(bad)")
        }
    }
}
