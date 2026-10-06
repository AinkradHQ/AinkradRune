import Testing

@testable import TerminalFeature

@Suite("SSHLaunch")
struct SSHLaunchTests {
    @Test("decodes a valid ssh payload")
    func decodes() {
        let l = SSHLaunch(json: #"{"kind":"ssh","host":"h","port":2222,"username":"u","identityFile":"/k"}"#)
        #expect(l?.host == "h")
        #expect(l?.port == 2222)
        #expect(l?.username == "u")
        #expect(l?.identityFile == "/k")
    }
    @Test("rejects nil, malformed, or wrong-kind payloads")
    func rejects() {
        #expect(SSHLaunch(json: nil) == nil)
        #expect(SSHLaunch(json: "not json") == nil)
        #expect(SSHLaunch(json: #"{"kind":"other","host":"h","port":22,"username":"u"}"#) == nil)
    }
    @Test("argv: identity + non-default port + user@host")
    func argvFull() throws {
        let l = try #require(SSHLaunch(json: #"{"kind":"ssh","host":"h","port":2222,"username":"u","identityFile":"/k"}"#))
        #expect(SSHInvocation.argv(l) == ["-i", "/k", "-p", "2222", "u@h"])
    }
    @Test("argv: default port omitted, empty user drops prefix")
    func argvMinimal() throws {
        let l = try #require(SSHLaunch(json: #"{"kind":"ssh","host":"h","port":22,"username":"","identityFile":null}"#))
        #expect(SSHInvocation.argv(l) == ["h"])
    }
}
