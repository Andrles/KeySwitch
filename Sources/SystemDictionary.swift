import AppKit

final class SystemDictionary {
    static let shared = SystemDictionary()

    private let checker = NSSpellChecker.shared
    private var cache: [String: Bool] = [:]
    private var suggestionCache: [String: String] = [:]
    private var noSuggestionCache: Set<String> = []
    private var availability: [Language: Bool] = [:]
    private let lock = NSLock()

    private init() {}

    func contains(_ word: String, language: Language) -> Bool {
        let normalized = word.lowercased()
        let key = "\(language.rawValue):\(normalized)"

        lock.lock()
        defer { lock.unlock() }

        if let cached = cache[key] {
            return cached
        }
        guard dictionaryIsAvailable(for: language) else {
            cache[key] = false
            return false
        }

        let result = spellingIsCorrect(normalized, language: language)
        if cache.count >= 20_000 {
            cache.removeAll(keepingCapacity: true)
        }
        cache[key] = result
        return result
    }

    func suggestion(for word: String, language: Language) -> String? {
        let normalized = word.lowercased()
        let key = "\(language.rawValue):\(normalized)"

        lock.lock()
        defer { lock.unlock() }

        if let cached = suggestionCache[key] {
            return cached
        }
        if noSuggestionCache.contains(key) {
            return nil
        }
        guard dictionaryIsAvailable(for: language),
              !spellingIsCorrect(normalized, language: language) else {
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

        let result = preserveCapitalization(from: word, in: guess)
        if suggestionCache.count >= 10_000 {
            suggestionCache.removeAll(keepingCapacity: true)
            noSuggestionCache.removeAll(keepingCapacity: true)
        }
        suggestionCache[key] = result
        return result
    }

    private func dictionaryIsAvailable(for language: Language) -> Bool {
        if let cached = availability[language] {
            return cached
        }

        let identifier = languageIdentifier(for: language)
        guard checker.availableLanguages.contains(identifier) else {
            availability[language] = false
            return false
        }

        // A failed spell-check service can report every word as valid. A known
        // impossible word keeps that failure from causing false conversions.
        let probe = language == .russian ? "ыъыъщщъы" : "zzqxjkvbwq"
        let available = !spellingIsCorrect(probe, language: language)
        availability[language] = available
        return available
    }

    private func spellingIsCorrect(_ word: String, language: Language) -> Bool {
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

    private func preserveCapitalization(from original: String, in replacement: String) -> String {
        guard original.first?.isUppercase == true else { return replacement.lowercased() }
        return replacement.prefix(1).uppercased() + replacement.dropFirst().lowercased()
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
