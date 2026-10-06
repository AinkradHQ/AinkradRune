import Foundation

/// The outcome of resolving a Terminal session's working directory,
/// including which configured tiers (if any) were rejected — a later UI
/// layer surfaces that as a calm inline message. See Terminal App
/// Architecture.md.
struct WorkingDirectoryResolution: Equatable {
    let url: URL
    let rejectedSettingsDefault: Bool
}

protocol WorkingDirectoryResolving {
    func resolveWorkingDirectory(settingsDefault: URL?) -> WorkingDirectoryResolution
}

/// Resolves a Terminal session's working directory: Terminal settings
/// default → home directory. Each candidate is validated
/// (exists, is a directory, is readable) before use; an invalid one falls
/// through to the next tier rather than failing session start.
struct WorkingDirectoryResolver: WorkingDirectoryResolving {
    private let isValidDirectory: (URL) -> Bool
    private let homeDirectory: () -> URL

    init(
        isValidDirectory: @escaping (URL) -> Bool = WorkingDirectoryResolver.defaultIsValidDirectory,
        homeDirectory: @escaping () -> URL = { FileManager.default.homeDirectoryForCurrentUser }
    ) {
        self.isValidDirectory = isValidDirectory
        self.homeDirectory = homeDirectory
    }

    func resolveWorkingDirectory(settingsDefault: URL?) -> WorkingDirectoryResolution {
        var rejectedSettingsDefault = false

        if let settingsDefault {
            if isValidDirectory(settingsDefault) {
                return WorkingDirectoryResolution(url: settingsDefault, rejectedSettingsDefault: false)
            }
            rejectedSettingsDefault = true
        }

        return WorkingDirectoryResolution(url: homeDirectory(), rejectedSettingsDefault: rejectedSettingsDefault)
    }

    private static func defaultIsValidDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }
        return FileManager.default.isReadableFile(atPath: url.path)
    }
}
