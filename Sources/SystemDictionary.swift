import AppKit

final class SystemDictionary {
    static let shared = SystemDictionary()

    private lazy var checker = NSSpellChecker.shared
    private var cache: [String: Bool] = [:]
    private var suggestionCache: [String: String] = [:]
    private var noSuggestionCache: Set<String> = []
    private var availability: [Language: (available: Bool, checkedAt: TimeInterval)] = [:]
    private let now: () -> TimeInterval
    private let availableLanguages: () -> [String]
    private let check: ((String, Language) -> Bool)?
    private let isDisabled: () -> Bool
    private let lock = NSLock()

    init(now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         availableLanguages: @escaping () -> [String] = { NSSpellChecker.shared.availableLanguages },
         check: ((String, Language) -> Bool)? = nil,
         isDisabled: @escaping () -> Bool = {
             ProcessInfo.processInfo.environment["KEYSWITCH_DISABLE_SYSTEM_DICTIONARY"] == "1"
         }) {
        self.now = now
        self.availableLanguages = availableLanguages
        self.check = check
        self.isDisabled = isDisabled
    }

    func contains(_ word: String, language: Language) -> Bool {
        guard !word.isEmpty, word.count <= 64 else { return false }
        // macOS accepts arbitrary ALL-CAPS and mixed-case abbreviations. Preserve title case
        // for proper names, but verify capitals as a normal lexical word.
        let letters = word.filter(\.isLetter)
        let query = letters.dropFirst().contains(where: \.isUppercase) ? word.lowercased() : word
        let key = "\(language.rawValue):\(query)"

        lock.lock()
        defer { lock.unlock() }

        guard dictionaryIsAvailable(for: language) else { return false }
        if let cached = cache[key] { return cached }
        let result = spellingIsCorrect(query, language: language)
        if cache.count >= 20_000 {
            cache.removeAll(keepingCapacity: true)
        }
        cache[key] = result
        return result
    }

    func suggestion(for word: String, language: Language) -> String? {
        guard !word.isEmpty, word.count <= 64 else { return nil }
        let normalized = word.lowercased()
        let key = "\(language.rawValue):\(word)"

        lock.lock()
        defer { lock.unlock() }

        guard dictionaryIsAvailable(for: language) else { return nil }
        if let cached = suggestionCache[key] {
            return TextToken.applyingCase(of: word, to: cached)
        }
        if noSuggestionCache.count >= 2_000 {
            noSuggestionCache.removeAll(keepingCapacity: true)
        }
        if noSuggestionCache.contains(key) {
            return nil
        }
        guard !spellingIsCorrect(word, language: language) else {
            noSuggestionCache.insert(key)
            return nil
        }

        let range = NSRange(location: 0, length: normalized.utf16.count)
        let guesses = checker.guesses(
            forWordRange: range,
            in: normalized,
            language: languageIdentifier(for: language),
            inSpellDocumentWithTag: 0
        ) ?? []
        let maximumDistance = normalized.count <= 4 ? 1 : 2
        guard let guess = guesses.first(where: {
            editDistance(normalized, $0.lowercased()) <= maximumDistance
        }) else {
            noSuggestionCache.insert(key)
            return nil
        }

        let result = guess.lowercased()
        if suggestionCache.count >= 10_000 {
            suggestionCache.removeAll(keepingCapacity: true)
            noSuggestionCache.removeAll(keepingCapacity: true)
        }
        suggestionCache[key] = result
        return TextToken.applyingCase(of: word, to: result)
    }

    private func dictionaryIsAvailable(for language: Language) -> Bool {
        guard !isDisabled() else { return false }
        let timestamp = now()
        if let cached = availability[language],
           timestamp - cached.checkedAt < (cached.available ? 60 : 2) {
            return cached.available
        }
        let probe = language == .russian ? "ыъыъщщъы" : "zzqxjkvbwq"
        let available = availableLanguages().contains(languageIdentifier(for: language)) &&
            !spellingIsCorrect(probe, language: language)
        // A service outage must not poison word caches after recovery. Refresh
        // healthy results too: the spelling service can restart during a session.
        let prefix = "\(language.rawValue):"
        cache = cache.filter { !$0.key.hasPrefix(prefix) }
        suggestionCache = suggestionCache.filter { !$0.key.hasPrefix(prefix) }
        noSuggestionCache = Set(noSuggestionCache.filter { !$0.hasPrefix(prefix) })
        availability[language] = (available, timestamp)
        return available
    }

    private func spellingIsCorrect(_ word: String, language: Language) -> Bool {
        if let check { return check(word, language) }
        let misspelledRange = checker.checkSpelling(
            of: word,
            startingAt: 0,
            language: languageIdentifier(for: language),
            wrap: false,
            inSpellDocumentWithTag: 0,
            wordCount: nil
        )
        return misspelledRange.location == NSNotFound
    }

    private func languageIdentifier(for language: Language) -> String {
        language == .russian ? "ru" : "en"
    }

    private func editDistance(_ left: String, _ right: String) -> Int {
        let lhs = Array(left)
        let rhs = Array(right)
        var previous = Array(0...rhs.count)
        for (leftIndex, leftCharacter) in lhs.enumerated() {
            var current = [leftIndex + 1]
            for (rightIndex, rightCharacter) in rhs.enumerated() {
                current.append(min(
                    current[rightIndex] + 1,
                    previous[rightIndex + 1] + 1,
                    previous[rightIndex] + (leftCharacter == rightCharacter ? 0 : 1)
                ))
            }
            previous = current
        }
        return previous[rhs.count]
    }
}
