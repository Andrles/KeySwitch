import Foundation

enum KeyboardTokenClassifier {
    private static let layoutCharacters = "`[];',.~{}:\"<>"

    static func continuesWord(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy {
            $0.isLetter ||
            $0.isNumber ||
            $0 == "-" ||
            layoutCharacters.contains($0)
        }
    }
}
