import Foundation
import Testing

@testable import RuneFeature

@Suite("TerminalSession")
@MainActor
struct TerminalSessionTests {

    @Test("a new session keeps the given shell and working directory")
    func keepsShellAndDirectory() {
        let workingDirectory = URL(fileURLWithPath: "/tmp")
        let session = TerminalSession(workingDirectory: workingDirectory, shellPath: "/bin/zsh")

        #expect(session.workingDirectory == workingDirectory)
        #expect(session.shellPath == "/bin/zsh")
    }
}
