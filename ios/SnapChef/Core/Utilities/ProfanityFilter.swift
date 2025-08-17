import Foundation

@MainActor
class ProfanityFilter {
    static let shared = ProfanityFilter()

    private let profanityList: Set<String>

    private init() {
        // Basic profanity list - expand as needed
        // Using a basic list for demonstration - in production, use a comprehensive filter service
        profanityList = Set([
            // Common English profanity (abbreviated list for demonstration)
            "fuck", "shit", "ass", "damn", "hell", "bitch", "bastard", "dick", "cock", "pussy",
            "fck", "sht", "azz", "btch", "d1ck", "c0ck", "puss", "fuk", "sh1t", "a55",
            "nigger", "nigga", "faggot", "fag", "retard", "cunt", "whore", "slut",
            // Common variations with numbers/symbols
            "f*ck", "sh*t", "b*tch", "d*ck", "c*ck", "p*ssy", "n*gger", "f@ck", "sh!t",
            // Hate speech terms
            "nazi", "hitler", "kkk", "isis", "terrorist",
            // Sexual terms
            "porn", "sex", "nude", "naked", "penis", "vagina", "boob", "tits", "anal",
            // Drug references
            "cocaine", "heroin", "meth", "crack", "weed", "marijuana",
            // Violence
            "kill", "murder", "rape", "suicide", "death"
        ])
    }

    func containsProfanity(_ text: String) -> Bool {
        let lowercased = text.lowercased()

        // Check exact matches
        if profanityList.contains(lowercased) {
            return true
        }

        // Check if any profanity is contained within the text
        for word in profanityList {
            if lowercased.contains(word) {
                return true
            }
        }

        // Check for leetspeak variations
        let leetVariations = text
            .lowercased()
            .replacingOccurrences(of: "0", with: "o")
            .replacingOccurrences(of: "1", with: "i")
            .replacingOccurrences(of: "3", with: "e")
            .replacingOccurrences(of: "4", with: "a")
            .replacingOccurrences(of: "5", with: "s")
            .replacingOccurrences(of: "7", with: "t")
            .replacingOccurrences(of: "@", with: "a")
            .replacingOccurrences(of: "$", with: "s")
            .replacingOccurrences(of: "!", with: "i")

        for word in profanityList {
            if leetVariations.contains(word) {
                return true
            }
        }

        return false
    }

    func cleanText(_ text: String) -> String {
        var cleaned = text

        for word in profanityList {
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
}
