import Foundation

/// A bounded editing transaction. Unsupported editors never receive deletion events.
protocol SuffixEditingBackend {
    var canReplace: Bool { get }
    var contextIsCurrent: Bool { get }
    func selection() -> NSRange?
    func text(in range: NSRange) -> String?
    func select(_ range: NSRange) -> Bool
    func replaceSelection(with text: String) -> Bool
}

enum SuffixReplacementResult: Equatable {
    case applied, unsupported, contextChanged, failed, unverified
}

enum SuffixReplacement {
    static func apply(_ suffix: VerifiedTextSuffix, replacement: String,
                      using backend: SuffixEditingBackend) -> SuffixReplacementResult {
        guard let range = suffix.range, !replacement.isEmpty,
              replacement.utf16.count <= 4096 else { return .unsupported }
        guard backend.canReplace else { return .unsupported }
        let caret = NSRange(location: suffix.caret, length: 0)
        guard backend.contextIsCurrent, backend.selection() == caret,
              backend.text(in: range) == suffix.text else { return .contextChanged }
        guard backend.select(range) else { return .failed }
        // Selection itself is reversible; do not write if focus or text changed.
        guard backend.contextIsCurrent, backend.selection() == range,
              backend.text(in: range) == suffix.text else {
            restoreCaret(caret, selectedRange: range, original: suffix.text, using: backend)
            return .contextChanged
        }
        guard backend.replaceSelection(with: replacement) else {
            restoreCaret(caret, selectedRange: range, original: suffix.text, using: backend)
            return .failed
        }
        let updated = NSRange(location: range.location, length: replacement.utf16.count)
        let end = NSRange(location: NSMaxRange(updated), length: 0)
        guard backend.contextIsCurrent, backend.text(in: updated) == replacement,
              let selection = backend.selection(), selection == updated || selection == end else {
            // Some WebKit fields acknowledge AXSelectedText but leave the
            // original word selected. The next physical key would erase it.
            // Restore only an exact, unchanged original in the same field.
            restoreCaret(caret, selectedRange: range, original: suffix.text, using: backend)
            return .unverified
        }
        if selection != end, !backend.select(end) { return .unverified }
        guard backend.contextIsCurrent, backend.selection() == end,
              backend.text(in: updated) == replacement else { return .unverified }
        return .applied
    }

    private static func restoreCaret(_ caret: NSRange, selectedRange: NSRange,
                                     original: String, using backend: SuffixEditingBackend) {
        guard backend.contextIsCurrent, backend.selection() == selectedRange,
              backend.text(in: selectedRange) == original else { return }
        _ = backend.select(caret)
    }
}
