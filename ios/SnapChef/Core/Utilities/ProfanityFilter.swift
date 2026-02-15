import Foundation

@MainActor
class ProfanityFilter {
    static let shared = ProfanityFilter()

    // Usernames are constrained to `[a-zA-Z0-9_]` elsewhere, so we keep this list:
    // - small (avoid embedding slurs/hate terms in the app binary)
    // - focused on unambiguous fragments (avoid false positives like "analysis" -> "anal", "passion" -> "ass")
    private let bannedFragments: [String]

    private init() {
        bannedFragments = [
            // Unambiguous profanity fragments + common leetspeak variants.
            // Keep this intentionally small to avoid blocking common words/names.
            "fuck", "fck", "fuk",
            "shit", "sht", "sh1t",
            "bitch", "btch",
            "cunt",
            "whore",
            "slut"
        ]
    }

    func containsProfanity(_ text: String) -> Bool {
        let normalized = normalize(text)
        for fragment in bannedFragments {
            if normalized.contains(fragment) {
                return true
            }
        }
        return false
    }

    func cleanText(_ text: String) -> String {
        var cleaned = text

        for word in bannedFragments {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let replacement = String(repeating: "*", count: word.count)
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    options: [],
                    range: NSRange(location: 0, length: cleaned.utf16.count),
                    withTemplate: replacement
                )
            }
        }

        return cleaned
    }

    private func normalize(_ text: String) -> String {
        let transformed = text
            .lowercased()
            // Usernames allow underscores; strip them so `f_u_c_k` is still detected.
            .replacingOccurrences(of: "_", with: "")
            // Common leetspeak normalization.
            .replacingOccurrences(of: "0", with: "o")
            .replacingOccurrences(of: "1", with: "i")
            .replacingOccurrences(of: "3", with: "e")
            .replacingOccurrences(of: "4", with: "a")
            .replacingOccurrences(of: "5", with: "s")
            .replacingOccurrences(of: "7", with: "t")

        // Keep only alphanumerics for consistent matching.
        return transformed.filter { $0.isLetter || $0.isNumber }
    }
}
