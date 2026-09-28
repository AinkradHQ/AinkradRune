import SwiftUI
import Foundation
import AinkradAppKit

/// Rune's **basic** mode: type a command, run it, read the output.
///
/// Ahmed's case for it, verbatim: *"sometimes I need to run a quick command on
/// the run, not to open a new session."*
///
/// The difference from advanced is not the chrome, it is the **shell**.
/// Advanced spawns an interactive login shell through `TerminalSessionFactory`,
/// which is a PTY plus the user's whole startup: `.zshrc`, plugin managers,
/// version managers, prompt setup. That is what `TerminalSession.startupNotices`
/// exists to report on, and it is the reason opening Rune to run one command
/// costs far more than the command.
///
/// Basic runs the command under the same shell a session would use — resolved
/// by `TerminalSessionFactory.resolve()`, so the configured shell and working
/// directory are honoured and the shell is validated against `/etc/shells` —
/// but with `-c`, so no PTY and no interactive startup.
///
/// Which also means: **no aliases, no shell functions, no rc-file `PATH`
/// edits.** That is a real behavioural difference, not a simplification to
/// paper over, so it is stated in the placeholder rather than discovered when
/// something works in advanced and not here.
struct RuneBasicView: View {
    let settingsStore: TerminalSettingsStore
    let theme: HostTheme

    @State private var command = ""
    @State private var buffer = AinkradLogBuffer()
    @State private var isRunning = false
    @State private var lastExitCode: Int32?
    @State private var running: Process?

    @Environment(\.ainkradStatusColors) private var statusColors

    private var tokens: HostThemeTokens { theme.tokens }

    var body: some View {
        AinkradBasicShell(icon: "terminal", title: "Rune", subtitle: subtitle) {
            if isRunning {
                AinkradButton(title: "Stop", style: .secondary, icon: "stop.fill") { stop() }
            }
        } content: {
            VStack(spacing: AinkradSpacing.sm) {
                AinkradTextField(text: $command,
                                 placeholder: "Command — your shell, without its startup files")
                    .onSubmit { run() }
                    .disabled(isRunning)
                AinkradLogView(lines: buffer.all,
                               palette: AinkradANSIPalette(theme: tokens,
                                                           statusColors: statusColors),
                               foreground: tokens.foreground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var subtitle: String {
        if isRunning { return "running…" }
        guard let lastExitCode else { return "no shell startup" }
        return lastExitCode == 0 ? "exit 0" : "exit \(lastExitCode)"
    }

    private func run() {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isRunning else { return }

        buffer.append("$ \(trimmed)\n", stream: .stdout)
        isRunning = true
        lastExitCode = nil

        // The SAME resolution a session uses: the configured shell validated
        // against /etc/shells, then $SHELL, then the account shell, then
        // /bin/zsh — and the configured working directory.
        //
        // This was hand-rolled as `environment["SHELL"] ?? "/bin/zsh"` in the
        // first version, which ignored BOTH settings and skipped the
        // /etc/shells check. Rune already had `ShellResolver` and
        // `WorkingDirectoryResolver`; reaching past them meant basic mode ran
        // somewhere other than where the user said, under a shell they had not
        // chosen.
        let resolved = TerminalSessionFactory(settings: settingsStore.settings).resolve()
        for notice in resolved.notices {
            buffer.append(notice + "\n", stream: .stderr)
        }

        let process = Process()
        // `-c` runs it non-interactively, so the shell still reads none of the
        // interactive rc files.
        process.executableURL = URL(fileURLWithPath: resolved.shellPath)
        process.arguments = ["-c", trimmed]
        process.currentDirectoryURL = resolved.workingDirectory

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        // Streamed rather than read at exit, so a long-running command shows
        // its output as it happens instead of all at once at the end.
        out.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor in buffer.append(data, stream: .stdout) }
        }
        err.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor in buffer.append(data, stream: .stderr) }
        }

        process.terminationHandler = { finished in
            // Handlers are cleared before hopping to the main actor: leaving
            // them attached keeps the file handles (and this closure's capture)
            // alive for the life of the pane, one leak per command run.
            out.fileHandleForReading.readabilityHandler = nil
            err.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor in
                lastExitCode = finished.terminationStatus
                isRunning = false
                running = nil
            }
        }

        do {
            try process.run()
            running = process
            command = ""
        } catch {
            buffer.append("could not run: \(error.localizedDescription)\n", stream: .stderr)
            isRunning = false
        }
    }

    private func stop() {
        running?.terminate()
    }
}
