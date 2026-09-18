import Testing
import Foundation
import AinkradAppKit
@testable import TerminalFeature

/// Rune's launch seam, widened in E5.
///
/// The landmine this closes: `takePendingLaunch()` CONSUMES, and the seam used
/// to be typed `SSHLaunchPayload?`. A payload of any other kind was not
/// ignored — it was taken off the mailbox, failed to decode, and dropped, while
/// the sender saw a successful launch.
@Suite("Rune — launch seam")
struct RuneLaunchTests {

    @Test("An SSH payload still classifies as SSH")
    func sshStillWorks() {
        let ssh = SSHLaunchPayload(host: "example.com", port: 22,
                                   username: "ahmed", identityFile: nil)
        let decoded = RuneLaunch.decode(ssh.json)
        #expect(decoded?.sshPayload?.host == "example.com")
    }

    @Test("A document intent is RECOGNISED, not eaten")
    func documentIsRecognised() {
        // The whole point. Before this, a `.md` handed to Rune vanished.
        let intent = AinkradLaunchIntent(path: "/vault/roadmap.md", mode: .basic)
        guard case .document(let decoded)? = RuneLaunch.decode(intent.json) else {
            Issue.record("a document intent must classify as .document")
            return
        }
        #expect(decoded.path == "/vault/roadmap.md")
    }

    @Test("A document intent does NOT become an SSH launch")
    func documentIsNotMistakenForSSH() {
        // Shape-matching in the wrong order would turn a path into a hostname.
        let intent = AinkradLaunchIntent(path: "/vault/roadmap.md", mode: .basic)
        #expect(RuneLaunch.decode(intent.json)?.sshPayload == nil)
    }

    @Test("Nothing pending is nil, not a launch")
    func nothingPendingIsNil() {
        #expect(RuneLaunch.decode(nil) == nil)
    }

    @Test("An unrecognised payload is nil rather than a guess")
    func unknownKindIsNil() {
        // A payload meant for a future Rune, or for nobody. `.none` is the
        // honest answer; guessing is how a launch does the wrong thing.
        #expect(RuneLaunch.decode(#"{"kind":"openProject","path":"/p"}"#) == nil)
        #expect(RuneLaunch.decode("not json") == nil)
        #expect(RuneLaunch.decode("{}") == nil)
    }

    @Test("An SSH payload that fails validation is refused, not passed through")
    func invalidSSHIsRefused() {
        // Every field lands in an ssh argv, and ssh's option surface runs shell
        // commands — so a hostile host must not survive classification.
        let hostile = SSHLaunchPayload(host: "-oProxyCommand=touch /tmp/pwned",
                                       port: 22, username: "a", identityFile: nil)
        #expect(RuneLaunch.decode(hostile.json) == nil)
    }
}
