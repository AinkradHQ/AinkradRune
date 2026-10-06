import AinkradAppKit
import os

/// The module's loggers, one per area, all under the shared Ainkrad subsystem
/// (`AinkradLog`) so a single Console filter covers the host and Rune.
enum Log {
    static let persistence = AinkradLog.logger(app: "rune", area: "persistence")
    static let session = AinkradLog.logger(app: "rune", area: "session")
}
