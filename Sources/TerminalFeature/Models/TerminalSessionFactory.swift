import Foundation

/// Resolves a new Terminal session's shell and working directory from
/// `TerminalSettings`, per the precedence orders in
/// Terminal App Architecture.md. An invalid configured shell is rejected by
/// `ShellResolving` and retried with no override rather than failing
/// session start.
@MainActor
struct TerminalSessionFactory {
    private let shellResolver: ShellResolving
    private let workingDirectoryResolver: WorkingDirectoryResolving
    private let settings: TerminalSettings

    init(
        shellResolver: ShellResolving = ShellResolver(),
        workingDirectoryResolver: WorkingDirectoryResolving = WorkingDirectoryResolver(),
        settings: TerminalSettings
    ) {
        self.shellResolver = shellResolver
        self.workingDirectoryResolver = workingDirectoryResolver
        self.settings = settings
    }

    /// Where a command runs: which shell, which directory, and anything the
    /// user should be told about how those were arrived at.
    ///
    /// Extracted so BASIC MODE can reach the same answer. Basic runs one
    /// command instead of opening a session, but "which shell" and "which
    /// directory" are the same questions with the same settings behind them.
    /// The first version of basic mode hand-rolled
    /// `ProcessInfo.environment["SHELL"] ?? "/bin/zsh"`, which ignored the
    /// user's configured shell AND working directory and skipped the
    /// `/etc/shells` validation `ShellResolver` does.
    struct Resolution {
        let shellPath: String
        let workingDirectory: URL
        let notices: [String]
    }

    func resolve() -> Resolution {
        let settings = self.settings
        var notices: [String] = []

        let shellPath: String
        do {
            shellPath = try shellResolver.resolveDefaultShell(override: settings.defaultShell)
        } catch {
            shellPath = (try? shellResolver.resolveDefaultShell(override: nil)) ?? ShellResolver.fallback
            if let configuredShell = settings.defaultShell {
                notices.append("The configured shell “\(configuredShell)” isn’t valid, so \(shellPath) was used instead.")
            }
        }

        let resolution = workingDirectoryResolver.resolveWorkingDirectory(
            sessionOverride: nil,
            settingsDefault: settings.defaultWorkingDirectory
        )
        if resolution.rejectedSettingsDefault, let configuredDirectory = settings.defaultWorkingDirectory {
            notices.append("The configured working directory “\(configuredDirectory.path)” isn’t usable, so \(resolution.url.path) was used instead.")
        }

        return Resolution(shellPath: shellPath, workingDirectory: resolution.url, notices: notices)
    }

    func makeSession(launch: SSHLaunch? = nil) -> TerminalSession {
        let resolved = resolve()
        TerminalLog.terminal.info("Terminal session resolved: shell \(resolved.shellPath, privacy: .public), cwd \(resolved.workingDirectory.path, privacy: .public), \(resolved.notices.count) notice(s)")
        return TerminalSession(
            workingDirectory: resolved.workingDirectory,
            shellPath: resolved.shellPath,
            startupNotices: resolved.notices,
            launchExecutable: launch.map { _ in SSHInvocation.executable },
            launchArgs: launch.map { SSHInvocation.argv($0) }
        )
    }
}
