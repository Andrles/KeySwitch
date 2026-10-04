import Foundation

enum ManualCommand: Int, CaseIterable {
    case layout, accept, undo, uppercase, lowercase

    var title: String {
        switch self {
        case .layout: return "Сменить раскладку слова или выделения"
        case .accept: return "Применить подсказку"
        case .undo: return "Отменить последнее автоисправление"
        case .uppercase: return "Выделение → ПРОПИСНЫЕ"
        case .lowercase: return "Выделение → строчные"
        }
    }
}

enum ShortcutPreset: Int, CaseIterable {
    case none, space, l, enter, z, u, j

    var keyCode: Int64? {
        switch self {
        case .none: return nil
        case .space: return 49
        case .l: return 37
        case .enter: return 36
        case .z: return 6
        case .u: return 32
        case .j: return 38
        }
    }

    var title: String {
        switch self {
        case .none: return "Без сочетания"
        case .space: return "⌃⌥Пробел"
        case .l: return "⌃⌥L"
        case .enter: return "⌃⌥Return"
        case .z: return "⌃⌥Z"
        case .u: return "⌃⌥U"
        case .j: return "⌃⌥J"
        }
    }
}

enum SelectedTextTransform {
    /// One target layout for the whole selection, including its punctuation.
    static func apply(_ command: ManualCommand, to text: String) -> String? {
        guard !text.isEmpty, text.utf16.count <= 4096 else { return nil }
        switch command {
        case .layout:
            let engine = LanguageEngine()
            let target: Language = text.unicodeScalars.contains { (0x0400...0x04FF).contains(Int($0.value)) } ? .english : .russian
            var result = "", token = ""
            func appendToken() {
                let parts = TextToken(token)
                result += parts.wrapping(engine.convert(parts.word, to: target))
                token = ""
            }
            for character in text {
                if character.isWhitespace { appendToken(); result.append(character) }
                else { token.append(character) }
            }
            appendToken()
            return result == text ? nil : result
        case .uppercase: return text.uppercased()
        case .lowercase: return text.lowercased()
        default: return nil
        }
    }
}

enum UserDictionaryFormat {
    static func words(_ text: String) -> Set<String> {
        Set(text.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }.filter { !$0.isEmpty && $0.count <= 64 && !$0.contains(where: \.isWhitespace) })
    }

    static func replacements(_ text: String) -> [String: String]? {
        var result: [String: String] = [:]
        for item in text.split(separator: ",") {
            let pair = item.split(separator: "=", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard pair.count == 2, pair.allSatisfy({ !$0.isEmpty && $0.count <= 64 && !$0.contains(where: \.isWhitespace) }),
                  result[pair[0].lowercased()] == nil else { return nil }
            result[pair[0].lowercased()] = pair[1]
        }
        return result
    }
}
