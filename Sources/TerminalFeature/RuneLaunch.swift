import Foundation
import AinkradAppKit

/// Everything Rune can be launched WITH, decided by looking at the payload
/// before decoding it as anything in particular.
///
/// ## Why this type exists
///
/// `RuneApp` used to pass `takeLaunch: () -> SSHLaunchPayload?`, so the seam
/// could only express one payload kind — and `takePendingLaunch()` CONSUMES.
/// Any other kind was therefore not "ignored", it was **eaten**: taken off the
/// mailbox, failed to decode, and dropped, with the sender seeing a successful
/// launch. That was a recorded landmine, and E5 is what would have tripped it:
/// a `.md` handed to Rune would have vanished.
///
/// Branch on the kind FIRST. Anything unrecognised is `.none`, which is the
/// honest answer for a payload meant for a future Rune or for nobody.
enum RuneLaunch: Equatable {
    /// Connect to a host, from Leyline.
    case ssh(SSHLaunchPayload)
    /// A document for Rune to show the path of. Rune does not render markdown —
    /// Lore does — so this is NOT "open it here"; it is here so the payload is
    /// recognised rather than silently consumed, and so a future Rune can act
    /// on it without another seam change.
    case document(AinkradLaunchIntent)

    /// Classifies a raw payload. Returns nil when it is not a launch Rune
    /// understands — which is a normal outcome, not a failure.
    static func decode(_ json: String?) -> RuneLaunch? {
        guard let json else { return nil }
        // Document intents carry an explicit `kind`, so they are identified
        // without guessing. Checked first for that reason: the SSH payload has
        // no kind field, so it can only be recognised by shape, and
        // shape-matching is the weaker test of the two.
        if let intent = AinkradLaunchIntent.decode(json), intent.isOpenDocument {
            return .document(intent)
        }
        if let ssh = SSHLaunch.pending(from: json) {
            return .ssh(ssh)
        }
        return nil
    }

    /// The SSH payload, when that is what this is. Lets the session factory
    /// keep taking exactly what it took before.
    var sshPayload: SSHLaunchPayload? {
        if case .ssh(let payload) = self { return payload }
        return nil
    }
}
