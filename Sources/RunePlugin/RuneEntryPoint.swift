import AinkradAppKit
import Foundation
import RuneFeature

/// The bundle's `NSPrincipalClass`. `@objc` + explicit name so the Info.plist
/// resolves it after `Bundle.load()`. Hands the host the Rune app type; the
/// bundled fonts register from `RuneRuntime` the first time a pane needs them.
@objc(RuneEntryPoint)
final class RuneEntryPoint: NSObject, AinkradPluginEntryPoint {
    static func app() -> any AinkradApp.Type { RuneApp.self }
}
