import Foundation

enum KeyboardTokenClassifier {
    private static let layoutCharacters = "`[];',.~{}:\"<>"

    static func isNavigationKey(_ code: Int64) -> Bool {
        [123, 124, 125, 126, 115, 119, 116, 121, 117, 53].contains(code)
    }

    static func isTechnicalBoundary(_ text: String) -> Bool {
        ["/", "\\", "@", "="].contains(text)
    }

    static func continuesWord(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy {
            $0.isLetter ||
            $0.isNumber ||
            $0 == "-" ||
            layoutCharacters.contains($0)
        }
    }
}

/// Recover a complete token only next to newly typed text in the current field.
/// Source changes may discard the event buffer; the editor remains authoritative.
enum KeyboardTokenRecovery {
    enum Scope { case mixedScripts, completeWord, completeAddressWord }

    static func token(caret: Int, typedSuffix: String, scope: Scope = .completeWord,
                      read: (NSRange) -> String?) -> String? {
        guard caret > 0, !typedSuffix.isEmpty, typedSuffix.utf16.count <= 64 else { return nil }
        let count = min(65, caret)
        let range = NSRange(location: caret - count, length: count)
        guard let prefix = read(range), prefix.utf16.count == count else { return nil }
        let token = String(prefix.reversed().prefix(while: { !$0.isWhitespace }).reversed())
        guard !token.isEmpty, token.utf16.count <= 64, token.hasSuffix(typedSuffix),
              range.location == 0 || token.utf16.count < prefix.utf16.count else { return nil }
        switch scope {
        case .mixedScripts:
            guard token.unicodeScalars.contains(where: { (65...90).contains($0.value) || (97...122).contains($0.value) }),
                  token.unicodeScalars.contains(where: { (0x0410...0x044F).contains($0.value) || $0.value == 0x0401 || $0.value == 0x0451 }) else { return nil }
        case .completeWord:
            let core = TextToken(token).word
            guard !token.contains(where: { "/\\@=_".contains($0) }),
                  !core.contains("."), !core.contains(":") else { return nil }
        case .completeAddressWord:
            // Never discard a URL, domain, email or code prefix to reach a word.
            guard KeyboardTokenClassifier.continuesWord(token),
                  !token.contains(where: { "/\\@=.:_".contains($0) }) else { return nil }
        }
        return token
    }
}

/// Only Safari's native smart-search field needs this recovery policy.
enum BrowserAddressFieldPolicy {
    static func requiresCompleteWord(bundleIdentifier: String?, fieldIdentifier: String?) -> Bool {
        bundleIdentifier == "com.apple.Safari" && fieldIdentifier == "WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD"
    }
}
