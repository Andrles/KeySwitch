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

    static func validatedWords(_ text: String) -> Set<String>? {
        let entries = text.split(separator: ",", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
        guard entries.allSatisfy({ validWord($0) }) else { return nil }
        return Set(entries.map { $0.lowercased() })
    }

    static func validWord(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 64 && TextToken(value).word == value && KeyboardTokenClassifier.continuesWord(value) && !value.contains(where: { $0.isWhitespace || $0 == "," || $0 == "=" || $0.isNewline || $0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) })
    }

    static func validReplacement(_ value: String) -> Bool {
        guard validWord(value) else { return false }
        let latin = value.unicodeScalars.contains { (65...90).contains(Int($0.value)) || (97...122).contains(Int($0.value)) }
        let russian = value.unicodeScalars.contains { (0x0410...0x044F).contains(Int($0.value)) || $0.value == 0x0401 || $0.value == 0x0451 }
        return latin != russian
    }

    static func replacements(_ text: String) -> [String: String]? {
        var result: [String: String] = [:]
        for item in text.split(separator: ",") {
            let pair = item.split(separator: "=", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard pair.count == 2, validWord(pair[0]), validReplacement(pair[1]),
                  result[pair[0].lowercased()] == nil else { return nil }
            result[pair[0].lowercased()] = pair[1]
        }
        return result
    }
}

enum CorrectionFeature: Int, CaseIterable { case layout, spelling, snippets }

struct ApplicationProfile: Codable, Equatable {
    var layout: Bool
    var spelling: Bool
    var snippets: Bool
    static let all = Self(layout: true, spelling: true, snippets: true)
    static let none = Self(layout: false, spelling: false, snippets: false)
    func allows(_ feature: CorrectionFeature) -> Bool {
        switch feature { case .layout: return layout; case .spelling: return spelling; case .snippets: return snippets }
    }
}

enum SnippetFormat {
    static func validPhrase(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= 256 && text.utf16.count <= 512 && !text.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) || CharacterSet.newlines.contains($0) } && chunks(text) != nil
    }
    /// Keep graphemes intact and bound every injected event's Unicode payload.
    static func chunks(_ text: String) -> [String]? {
        var result: [String] = [], current = ""
        for character in text {
            let piece = String(character)
            guard piece.utf16.count <= 20 else { return nil }
            if current.utf16.count + piece.utf16.count > 20 { result.append(current); current = "" }
            current += piece
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}

struct DictionarySnapshot: Codable, Equatable {
    var words: [String]
    var replacements: [String: String]
    var ignored: [String]
    var snippets: [String: String]
    init(words: [String], replacements: [String: String], ignored: [String], snippets: [String: String] = [:]) {
        self.words = words; self.replacements = replacements; self.ignored = ignored; self.snippets = snippets
    }
    enum CodingKeys: String, CodingKey { case words, replacements, ignored, snippets }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        words = try values.decode([String].self, forKey: .words)
        replacements = try values.decode([String: String].self, forKey: .replacements)
        ignored = try values.decode([String].self, forKey: .ignored)
        snippets = try values.decodeIfPresent([String: String].self, forKey: .snippets) ?? [:]
    }

    func validate() throws {
        guard words.count + replacements.count + ignored.count + snippets.count <= 5000 else {
            throw DictionaryError("В словаре больше 5000 записей. Удалите лишние записи перед переносом.")
        }
        guard words.allSatisfy(UserDictionaryFormat.validWord),
              replacements.allSatisfy({ UserDictionaryFormat.validWord($0.key) && UserDictionaryFormat.validReplacement($0.value) }) else {
            throw DictionaryError("Проверьте слова и пары: до 64 символов, без пробелов. Исправление должно содержать буквы одного языка — русского или английского.")
        }
        // Preserve ignored entries from older releases; new entries use strict validation.
        guard ignored.allSatisfy({ !$0.isEmpty && $0.count <= 4096 && !$0.contains(",") && !$0.contains(where: { $0.isNewline || $0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) }) }) else {
            throw DictionaryError("В исключениях есть неподдерживаемая запись. Исправьте её перед переносом.")
        }
        guard snippets.allSatisfy({ UserDictionaryFormat.validWord($0.key) && SnippetFormat.validPhrase($0.value) }), Set(snippets.keys.map { $0.lowercased() }).count == snippets.count else { throw DictionaryError("Сокращения: одно слово; фраза — одна строка до 256 символов. Повторяющиеся сокращения не поддерживаются.") }
        let normalized = replacements.keys.map { $0.lowercased() }
        guard Set(normalized).count == normalized.count else { throw DictionaryError("Одному слову назначены разные исправления. Оставьте одну пару.") }
    }

    func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= 1_000_000 else { throw DictionaryError("Словарь больше 1 МБ. Удалите лишние записи перед переносом.") }
        return data
    }

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 1_000_000 else { throw DictionaryError("Файл больше 1 МБ. Выберите меньший словарь.") }
        let result = try JSONDecoder().decode(Self.self, from: data)
        try result.validate()
        return result
    }

    func merging(_ incoming: Self) throws -> Self {
        try validate(); try incoming.validate()
        var phrases = Dictionary(uniqueKeysWithValues: snippets.map { ($0.key.lowercased(), $0.value) })
        phrases.merge(Dictionary(uniqueKeysWithValues: incoming.snippets.map { ($0.key.lowercased(), $0.value) })) { _, new in new }
        var pairs = Dictionary(uniqueKeysWithValues: replacements.map { ($0.key.lowercased(), $0.value) })
        pairs.merge(Dictionary(uniqueKeysWithValues: incoming.replacements.map { ($0.key.lowercased(), $0.value) })) { _, new in new }
        let merged = Self(words: Array(Set(words).union(incoming.words.map { $0.lowercased() })).sorted(), replacements: pairs,
                          ignored: Array(Set(ignored).union(incoming.ignored.map { $0.lowercased() })).sorted(), snippets: phrases)
        _ = try merged.encoded()
        return merged
    }
}

struct DictionaryError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct ShortcutBinding: Codable, Equatable {
    let keyCode: Int64
    let modifiers: UInt64
    let title: String
    static let command: UInt64 = 1 << 20
    static let control: UInt64 = 1 << 18
    static let option: UInt64 = 1 << 19
    static let shift: UInt64 = 1 << 17
    static let mask = command | control | option | shift
    var allowed: Bool {
        guard modifiers & (Self.command | Self.control) != 0 else { return false }
        if modifiers & (Self.control | Self.option) == Self.control | Self.option && keyCode == 32 { return false }
        if modifiers == Self.command && [0, 1, 6, 7, 8, 9, 12, 13, 17, 31, 35, 45, 46, 48, 49].contains(keyCode) { return false }
        return ![53, 51, 55, 56, 58, 59, 60, 61, 62, 63].contains(keyCode)
    }
    func matches(keyCode: Int64, modifiers: UInt64) -> Bool {
        self.keyCode == keyCode && self.modifiers == modifiers & Self.mask
    }
}

enum ManualEditResult: Equatable {
    case success, permission, secure, excluded, unsupported, noSelection, tooLong, unchanged, contextChanged, noWord, noSuggestion, noUndo
    var message: String {
        switch self {
        case .success: return "Готово."
        case .permission: return "Разрешите KeySwitch доступ в настройках macOS, затем повторите действие."
        case .secure: return "Защищённое поле не изменяется. Перейдите в обычное текстовое поле."
        case .excluded: return "Для этого приложения исправления отключены. Проверьте раздел «Где не исправлять»."
        case .unsupported: return "Это поле не позволяет изменить выделение. Попробуйте обычное текстовое поле."
        case .noSelection: return "Сначала выделите текст, который нужно изменить."
        case .tooLong: return "Выделение больше 4096 символов. Выберите меньший фрагмент."
        case .unchanged: return "Текст уже в нужном виде. Замена не требуется."
        case .contextChanged: return "Поле или выделение изменилось. Выделите текст заново и повторите действие."
        case .noWord: return "Нет доступного слова для замены. Выделите нужный текст и повторите действие."
        case .noSuggestion: return "Нет доступной подсказки. Она может исчезнуть после нового ввода или смены поля."
        case .noUndo: return "Последняя замена больше недоступна для отмены: прошло время или изменилось поле. Используйте отмену редактора, если она доступна."
        }
    }
}
