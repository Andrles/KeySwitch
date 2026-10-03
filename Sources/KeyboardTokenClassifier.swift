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
