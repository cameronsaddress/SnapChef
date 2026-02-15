import Foundation
import OSLog

/// Central logging entrypoint.
///
/// - Use `AppLog.debug(...)` for verbose diagnostics (compiled out of Release).
/// - Use `AppLog.error(...)` only for actionable errors (kept in Release).
enum AppLog {
    static let subsystem: String = Bundle.main.bundleIdentifier ?? "com.snapchef.app"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let cloudKit = Logger(subsystem: subsystem, category: "cloudkit")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let share = Logger(subsystem: subsystem, category: "share")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")

    @inline(__always)
    static func debug(_ logger: Logger, _ message: @autoclosure () -> String) {
        #if DEBUG
        let resolved = message()
        logger.debug("\(resolved, privacy: .private)")
        #endif
    }

    @inline(__always)
    static func info(_ logger: Logger, _ message: @autoclosure () -> String) {
        let resolved = message()
        logger.info("\(resolved, privacy: .private)")
    }

    @inline(__always)
    static func warning(_ logger: Logger, _ message: @autoclosure () -> String) {
        let resolved = message()
        logger.warning("\(resolved, privacy: .private)")
    }

    @inline(__always)
    static func error(_ logger: Logger, _ message: @autoclosure () -> String) {
        let resolved = message()
        logger.error("\(resolved, privacy: .private)")
    }
}
