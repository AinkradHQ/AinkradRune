import AinkradAppKit
import Foundation
import Testing

@testable import RuneFeature

@MainActor
@Suite("TerminalActions")
struct TerminalActionTests {
    @Test("registerActions registers exactly one terminal.echo handler per host")
    func registersOnce() {
        let actions = RecordingActionRegistry()
        let host = FakeHostServices(context: RecordingContextRegistry(), actions: actions)
        RuneRuntime.registerActions(for: host)
        RuneRuntime.registerActions(for: host)
        #expect(actions.ids.values.filter { $0 == "terminal.echo" }.count == 1)
    }

    @Test("the echo handler decodes {command, output} and writes to the active terminal")
    func handlerEchoesToTerminal() async throws {
        let actions = RecordingActionRegistry()
        let host = FakeHostServices(context: RecordingContextRegistry(), actions: actions)
        let source = FakeBufferSource(buffer: "x")
        RuneRuntime.contextBridge(for: host).setActiveSource(source)
        RuneRuntime.registerActions(for: host)
        let json = "{\"command\":\"ls\",\"output\":\"a\\nb\"}"
        let result = await actions.invoke(actionID: "terminal.echo", input: json)
        #expect(result?.isError == false)
        #expect(source.echoedCommands.first?.command == "ls")
        #expect(source.echoedCommands.first?.output == "a\nb")
    }
}
