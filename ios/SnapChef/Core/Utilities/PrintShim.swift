import Foundation

// Avoid shipping stdout spam in Release builds.
// Prefer `AppLog` for structured logging that can be filtered in Console.

public func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    Swift.print(items.map { String(describing: $0) }.joined(separator: separator), terminator: terminator)
    #else
    // Intentionally no-op in Release.
    #endif
}

public func print<Target: TextOutputStream>(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n",
    to output: inout Target
) {
    #if DEBUG
    Swift.print(items.map { String(describing: $0) }.joined(separator: separator), terminator: terminator, to: &output)
    #else
    // Intentionally no-op in Release.
    #endif
}

