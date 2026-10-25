import Foundation

enum Language: String {
    case english
    case russian

    var displayTitle: String {
        switch self {
        case .english: return "🇺🇸 English"
        case .russian: return "🇷🇺 Русский"
        }
    }

    var opposite: Language {
        self == .russian ? .english : .russian
    }
}

struct Correction: Equatable {
    let original: String
    let replacement: String
    let language: Language
}

struct LanguageEngine {
    private let enToRu: [Character: Character]
    private let ruToEn: [Character: Character]
    private let systemDictionary = SystemDictionary.shared

    private static let englishWords: Set<String> = Set("""
    a about after again all also am an and any app are as at back be because been
    before best but by can change come could day did do does done down each email
    even every file find first for from get give go good great had has have he
    hello help her here him his home how i if in into is it its just know last
    like little look mac make many may me menu more most my need new no not now
    of off on one only open or other our out over people please program right run
    same see send set she should so some start still such system take test text
    than that the their them then there these they thing think this time to try
    two up use user very want was way we well were what when where which who why
    will with word work would write yes you your name english russian palace hi
    moscow above across against along among around behind below beside between beyond despite
    during except inside into near onto opposite outside past round since through
    throughout towards under underneath unlike until upon via within without
    ahead apart account top owing prior regardless
    """.split(whereSeparator: \.isWhitespace).map(String.init))

    private static let russianWords: Set<String> = Set("""
    а без был была были было быть в вам вас весь вот все всегда всего вы где да
    даже два для до его ее если есть ещё же за здесь и из или им их к как когда
    кто ли мне мой можно мы на надо наш не него нет но ну о об один она они оно
    от очень по под после потому привет при про программа раз раскладка русский
    пропускаешь с сам себе сейчас система слово со спасибо так такой там текст то
    тоже только ты у уже хорошо хотя чем что чтобы это этот я язык давай немного
    пишем писать английский русского русском английском подобное сделай почему
    первое первый первая первые второе второй вторая вторые может дворец
    название названии иконка иконку приложение приложении приложением приложения
    репозиторий репозитория пишу включен включена включено включены включенный
    включенным включён включена включено включены включённый включённым
    близ возле вокруг впереди вдоль вместо вне внутри навстречу напротив около
    во ко кроме между над обо перед передо подо ради сквозь среди через
    благодаря вопреки ввиду вследствие
    насчёт несмотря согласно спустя включая исключая начиная помимо посредством
    путём касательно относительно из-за из-под течение продолжение исключением
    время связи зависимости направлению
    брызговик брызговики
    """.split(whereSeparator: \.isWhitespace).map(String.init))

    private static let latinBrands: [String: String] = [
        "acura": "Acura",
        "alfa": "Alfa",
        "audi": "Audi",
        "bentley": "Bentley",
        "bmw": "BMW",
        "byd": "BYD",
        "cadillac": "Cadillac",
        "chery": "Chery",
        "chevrolet": "Chevrolet",
        "chrysler": "Chrysler",
        "citroen": "Citroen",
        "cupra": "Cupra",
        "dodge": "Dodge",
        "exeed": "Exeed",
        "ferrari": "Ferrari",
        "fiat": "Fiat",
        "ford": "Ford",
        "gac": "GAC",
        "gaz": "GAZ",
        "geely": "Geely",
        "genesis": "Genesis",
        "greatwall": "Great Wall",
        "haval": "Haval",
        "honda": "Honda",
        "hongqi": "Hongqi",
        "hyundai": "Hyundai",
        "infiniti": "Infiniti",
        "jaecoo": "Jaecoo",
        "jeep": "Jeep",
        "jetour": "Jetour",
        "kia": "Kia",
        "lada": "Lada",
        "lamborghini": "Lamborghini",
        "land": "Land",
        "lexus": "Lexus",
        "li": "Li Auto",
        "mazda": "Mazda",
        "mercedes": "Mercedes",
        "mini": "MINI",
        "mitsubishi": "Mitsubishi",
        "moskvich": "Moskvich",
        "nissan": "Nissan",
        "omoda": "Omoda",
        "opel": "Opel",
        "peugeot": "Peugeot",
        "porsche": "Porsche",
        "renault": "Renault",
        "rover": "Rover",
        "seat": "SEAT",
        "skoda": "Skoda",
        "subaru": "Subaru",
        "suzuki": "Suzuki",
        "tank": "TANK",
        "tesla": "Tesla",
        "toyota": "Toyota",
        "uaz": "UAZ",
        "volkswagen": "Volkswagen",
        "volvo": "Volvo",
        "voyah": "VOYAH",
        "zeekr": "Zeekr"
    ]

    private static let englishNames: Set<String> = Set("""
    alexander alexey alice andrew anna anton boris daniel david dmitry elena
    george ivan james john julia maria mark mary michael natalia nicholas olga
    paul peter sergey stanislav tatiana victor
    """.split(whereSeparator: \.isWhitespace).map(String.init))

    private static let russianNames: Set<String> = Set("""
    александр алексей алиса андрей анна антон борис виктор владимир георгий
    давид даниил дмитрий елена екатерина иван мария марк михаил наталья николай
    ольга павел пётр сергей станислав татьяна юлия
    """.split(whereSeparator: \.isWhitespace).map(String.init))

    init() {
        let english = "`qwertyuiop[]asdfghjkl;'zxcvbnm,."
        let russian = "ёйцукенгшщзхъфывапролджэячсмитьбю"
        var forward: [Character: Character] = [:]
        var backward: [Character: Character] = [:]
        for (en, ru) in zip(english, russian) {
            forward[en] = ru
            backward[ru] = en
            if en.isLetter {
                forward[Character(String(en).uppercased())] = Character(String(ru).uppercased())
                backward[Character(String(ru).uppercased())] = Character(String(en).uppercased())
            }
        }
        let shiftedEnglish = "~{}:\"<>"
        let shiftedRussian = "ЁХЪЖЭБЮ"
        for (en, ru) in zip(shiftedEnglish, shiftedRussian) {
            forward[en] = ru
            backward[ru] = en
        }
        enToRu = forward
        ruToEn = backward
    }

    func convert(_ word: String, to language: Language) -> String {
        let mapping = language == .russian ? enToRu : ruToEn
        return String(word.map { mapping[$0] ?? $0 })
    }

    func forcedConversion(_ word: String) -> Correction? {
        guard !word.isEmpty else { return nil }
        let hasCyrillic = word.unicodeScalars.contains { (0x0400...0x04FF).contains(Int($0.value)) }
        let target: Language = hasCyrillic ? .english : .russian
        let replacement = convert(word, to: target)
        guard replacement != word else { return nil }
        return Correction(original: word, replacement: replacement, language: target)
    }

    func correction(for word: String, ignored: Set<String> = [], learned: Set<String> = [], replacements: [String: String] = [:]) -> Correction? {
        guard word.count <= 64 else { return nil }
        let protectedCore = TextToken(word).word
        let tokenParts = TextToken(word)
        let key = protectedCore.lowercased()
        if ignored.contains(key) { return nil }
        if let replacement = replacements[key], replacement != protectedCore,
           let language = scriptLanguage(replacement) {
            return Correction(original: word, replacement: tokenParts.wrapping(replacement), language: language)
        }
        if learned.contains(key) { return nil }
        if let punctuation = wrappedPunctuationLayoutCorrection(for: word) { return punctuation }
        if isKnownWord(protectedCore) { return nil }
        if let mixed = mixedLayoutCorrection(for: word) { return mixed }
        if let converted = forcedConversion(word), learned.contains(TextToken(converted.replacement).word.lowercased()) {
            return converted
        }
        if TextToken.isIdentifier(protectedCore) || (word.count <= 2 && word.hasSuffix(":")), canonicalModel(convert(word, to: .english)) == nil { return nil }
        let characters = Array(word)
        let punctuation = "`[];',.~{}:\"<>«»„“”‘’()!?…"
        let leftCount = characters.prefix { punctuation.contains($0) }.count
        let rightCount = characters.reversed().prefix { punctuation.contains($0) }.count
        let trailingDots = characters.reversed().prefix { $0 == "." }.count
        var best: (correction: Correction, score: Int)?
        for left in 0...leftCount {
            for right in 0...rightCount where left + right < characters.count {
                if trailingDots >= 2 && right > 0 && right < trailingDots { continue }
                let core = String(characters[left..<(characters.count - right)])
                guard let candidate = punctuationLayoutCorrection(for: core) ?? correctionForBareWord(core, ignored: ignored) else { continue }
                let target = candidate.replacement.lowercased()
                let local = LocalLexicon.contains(target) || Self.englishWords.contains(target) ||
                    Self.russianWords.contains(target) || Self.englishNames.contains(target) ||
                    Self.russianNames.contains(target)
                // Exact offline vocabulary outranks a rare system-only fragment.
                // Ties retain mapped edge letters, matching bare-word conversion.
                let score = (local ? 100 : 0) - left - right
                if best == nil || score > best!.score {
                    best = (Correction(original: word,
                        replacement: String(characters.prefix(left)) + candidate.replacement +
                            String(characters.suffix(right)), language: candidate.language), score)
                }
            }
        }
        return best?.correction
    }

    private func wrappedPunctuationLayoutCorrection(for word: String) -> Correction? {
        let characters = Array(word)
        let punctuation = "`[];',.~{}:\"<>«»„“”‘’()!?…"
        let leading = characters.prefix { punctuation.contains($0) }.count
        let trailing = characters.reversed().prefix { punctuation.contains($0) }.count
        for removed in 0...(leading + trailing) {
            for left in 0...min(leading, removed) {
                let right = removed - left
                guard right <= trailing, left + right < characters.count else { continue }
                let core = String(characters[left..<(characters.count - right)])
                if let candidate = punctuationLayoutCorrection(for: core) {
                    let replacement = String(characters.prefix(left)) + candidate.replacement + String(characters.suffix(right))
                    return Correction(original: word, replacement: replacement, language: .russian)
                }
            }
        }
        return nil
    }

    /// A punctuation key can be a missing Russian letter, but only when the
    /// entire mapped token is an exact local word. Ordinary punctuation stays.
    private func punctuationLayoutCorrection(for word: String) -> Correction? {
        let keys = "[];',.{}:\"<>`~"
        guard (3...64).contains(word.count),
              word.contains(where: { keys.contains($0) }),
              word.unicodeScalars.contains(where: { (0x0410...0x044F).contains($0.value) || $0.value == 0x0401 || $0.value == 0x0451 }),
              word.allSatisfy({ $0.isLetter || keys.contains($0) }),
              !TextToken.hasProtectedCase(word) || word.filter(\.isLetter).allSatisfy(\.isUppercase) else { return nil }
        let mapped = convert(word, to: .russian)
        guard mapped != word, mapped.unicodeScalars.allSatisfy({
            (0x0410...0x044F).contains($0.value) || $0.value == 0x0401 || $0.value == 0x0451
        }), Self.russianWords.contains(mapped.lowercased()) || LocalLexicon.contains(mapped) else { return nil }
        return Correction(original: word, replacement: mapped, language: .russian)
    }

    /// Repair only an exact, unambiguous word after input switched mid-token.
    /// Never combine this with fuzzy spelling or synchronous system guesses.
    private func mixedLayoutCorrection(for token: String) -> Correction? {
        let parts = TextToken(token)
        let word = parts.word
        guard word.count >= 3, word.count <= 64,
              word.unicodeScalars.allSatisfy({
                  (65...90).contains($0.value) || (97...122).contains($0.value) ||
                  (0x0410...0x044F).contains($0.value) || $0.value == 0x0401 || $0.value == 0x0451
              }),
              word.unicodeScalars.contains(where: { (65...90).contains($0.value) || (97...122).contains($0.value) }),
              word.unicodeScalars.contains(where: { (0x0410...0x044F).contains($0.value) || $0.value == 0x0401 || $0.value == 0x0451 }),
              !TextToken.hasProtectedCase(word) || word.allSatisfy(\.isUppercase) else { return nil }
        let candidates = [Language.russian, .english].compactMap { language -> Correction? in
            let mapped = convert(word, to: language)
            let key = mapped.lowercased()
            let vocabulary = language == .russian ? Self.russianWords : Self.englishWords
            let names = language == .russian ? Self.russianNames : Self.englishNames
            guard vocabulary.contains(key) || LocalLexicon.contains(key) ||
                    (word.first?.isUppercase == true && names.contains(key)) else { return nil }
            return Correction(original: token, replacement: parts.wrapping(mapped), language: language)
        }
        return candidates.count == 1 ? candidates[0] : nil
    }

    private func correctionForBareWord(_ word: String,
                                       ignored: Set<String>) -> Correction? {
        let normalized = word.lowercased()
        guard !word.isEmpty, !ignored.contains(normalized) else { return nil }

        let hasLatin = word.unicodeScalars.contains { (0x0041...0x005A).contains(Int($0.value)) || (0x0061...0x007A).contains(Int($0.value)) }
        let hasCyrillic = word.unicodeScalars.contains { (0x0400...0x04FF).contains(Int($0.value)) }
        guard hasLatin != hasCyrillic else { return nil }

        if hasLatin {
            let converted = convert(word, to: .russian)
            let replacement = converted
            let sourceScore = englishScore(word)
            let targetScore = russianScore(replacement)
            let minimumTargetScore = word.count <= 2 ? 12 : 4
            if isKnownWord(replacement),
               word.count > 2 || (Self.englishWords.contains(replacement.lowercased()) || Self.russianWords.contains(replacement.lowercased())), targetScore >= minimumTargetScore && targetScore - sourceScore >= 3 {
                return Correction(original: word, replacement: replacement, language: .russian)
            }
        } else {
            let converted = convert(word, to: .english)
            if let identifier = canonicalLatinIdentifier(converted) {
                return Correction(original: word,
                                  replacement: identifier,
                                  language: .english)
            }
            let replacement = converted
            let sourceScore = russianScore(word)
            let targetScore = englishScore(replacement)
            let minimumTargetScore = word.count <= 2 ? 12 : 4
            if isKnownWord(replacement),
               word.count > 2 || (Self.englishWords.contains(replacement.lowercased()) || Self.russianWords.contains(replacement.lowercased())), targetScore >= minimumTargetScore && targetScore - sourceScore >= 3 {
                return Correction(original: word, replacement: replacement, language: .english)
            }
        }
        return nil
    }

    private func canonicalLatinIdentifier(_ candidate: String) -> String? {
        let normalized = candidate.lowercased()
        if candidate.count > 2, Self.latinBrands[normalized] != nil {
            return candidate
        }

        return canonicalModel(candidate)
    }

    private func canonicalModel(_ candidate: String) -> String? {
        // Only known model families; arbitrary Cyrillic abbreviations are never models.
        let family = candidate.prefix(while: { $0.isLetter }).uppercased()
        guard ["X", "Q", "CX", "GLE"].contains(family) else { return nil }
        let characters = Array(candidate)
        guard (2...10).contains(characters.count),
              characters.contains(where: \.isNumber),
              characters.contains(where: \.isLetter),
              characters.filter(\.isLetter).allSatisfy(\.isUppercase),
              characters.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }),
              characters.first?.isLetter == true,
              characters.last != "-",
              characters.filter({ $0 == "-" }).count <= 1 else {
            return nil
        }

        let parts = candidate.split(separator: "-", omittingEmptySubsequences: false)
        let compact = characters.filter { $0 != "-" }
        guard parts.allSatisfy({ !$0.isEmpty }),
              let firstDigit = compact.firstIndex(where: \.isNumber) else {
            return nil
        }
        let prefix = compact[..<firstDigit]
        let remainder = compact[firstDigit...]
        var reachedSuffix = false
        var hasDigitAfterSuffix = false
        for character in remainder {
            if character.isLetter {
                reachedSuffix = true
            } else if character.isNumber && reachedSuffix {
                hasDigitAfterSuffix = true
            }
        }
        guard (1...4).contains(prefix.filter(\.isLetter).count),
              prefix.allSatisfy(\.isLetter),
              remainder.filter(\.isNumber).count <= 4,
              remainder.filter(\.isLetter).count <= 2,
              !hasDigitAfterSuffix else {
            return nil
        }
        return candidate.uppercased()
    }

    func detectedLanguage(for word: String) -> Language? {
        let hasLatin = word.unicodeScalars.contains { (0x0041...0x005A).contains(Int($0.value)) || (0x0061...0x007A).contains(Int($0.value)) }
        let hasCyrillic = word.unicodeScalars.contains { (0x0400...0x04FF).contains(Int($0.value)) }
        guard hasLatin != hasCyrillic else { return nil }

        if hasLatin {
            return englishScore(word) >= 0 ? .english : nil
        }
        return russianScore(word) >= 0 ? .russian : nil
    }

    func spellingSuggestion(for word: String, language: Language) -> String? {
        guard word.count > 2, word.count <= 64 else { return nil }
        let normalized = word.lowercased()
        let vocabulary = language == .english ? Self.englishWords : Self.russianWords
        let names = language == .english ? Self.englishNames : Self.russianNames
        guard !LocalLexicon.contains(word), !TextToken.isIdentifier(word),
              !TextToken.hasProtectedCase(word),
              !vocabulary.contains(normalized), !names.contains(normalized),
              !systemDictionary.contains(word, language: language) else { return nil }
        if let preferred = preferredSpellingSuggestion(for: word, language: language) { return preferred }
        // A name-like typo may be suggested, but ordinary lowercase words must
        // never be silently promoted to names.
        let name = word.first?.isUppercase == true ? normalizedName(word, language: language) : word
        if name != word {
            return name
        }
        return systemDictionary.suggestion(for: word, language: language)
    }

    // Hints only; shared by ordinary spelling and confirmed cross-layout hints.
    // Never use arbitrary system guesses to combine layout and spelling changes.
    private func preferredSpellingSuggestion(for word: String, language: Language) -> String? {
        let preferred = language == .english
            ? ["helo": "hello", "adress": "address", "teh": "the"]
            : ["превет": "привет", "малако": "молоко"]
        guard let replacement = preferred[word.lowercased()] else { return nil }
        return TextToken.applyingCase(of: word, to: replacement)
    }

    private func isKnownWord(_ word: String) -> Bool {
        let normalized = word.lowercased()
        if Self.englishWords.contains(normalized) || Self.russianWords.contains(normalized) ||
           Self.englishNames.contains(normalized) || Self.russianNames.contains(normalized) ||
           LocalLexicon.contains(word) { return true }
        // A spell service may accept fragments separated by punctuation. Require a word.
        guard word.count > 2, word.first?.isLetter == true, word.last?.isLetter == true, word.allSatisfy({ $0.isLetter || $0 == "-" || $0 == "'" || $0 == "’" }),
              (!word.contains("-") || word.split(separator: "-").allSatisfy({ $0.count >= 3 })),
              let language = scriptLanguage(word) else { return false }
        return systemDictionary.contains(word, language: language)
    }

    private func scriptLanguage(_ word: String) -> Language? {
        let latin = word.unicodeScalars.contains { (65...90).contains(Int($0.value)) || (97...122).contains(Int($0.value)) }
        let russian = word.unicodeScalars.contains { (0x0410...0x044F).contains(Int($0.value)) || $0.value == 0x0401 || $0.value == 0x0451 }
        guard latin != russian else { return nil }
        if russian, word.unicodeScalars.contains(where: {
            CharacterSet.letters.contains($0) && !(0x0400...0x04FF).contains(Int($0.value))
        }) { return nil }
        return russian ? .russian : .english
    }

    func spellingCorrection(for token: String, automatic: Bool) -> Correction? {
        let parts = TextToken(token)
        guard !TextToken.isIdentifier(parts.word), let language = scriptLanguage(parts.word) else { return nil }
        if !automatic, (3...64).contains(parts.word.count),
           parts.word.allSatisfy(\.isLetter), !TextToken.hasProtectedCase(parts.word),
           !isKnownWord(parts.word) {
            let target = language.opposite
            let converted = convert(parts.word, to: target)
            if scriptLanguage(converted) == target,
               let suggestion = preferredSpellingSuggestion(for: converted, language: target) {
                return Correction(original: token, replacement: parts.wrapping(suggestion), language: target)
            }
        }
        let replacement = automatic
            ? automaticSpellingCorrection(for: parts.word, language: language)
            : spellingSuggestion(for: parts.word, language: language)
        guard let replacement else { return nil }
        return Correction(original: token, replacement: parts.wrapping(replacement), language: language)
    }

    /// Only unambiguous curated typos can be replaced automatically. Other guesses are hints.
    func automaticSpellingCorrection(for word: String, language: Language) -> String? {
        guard !isKnownWord(word), !TextToken.isIdentifier(word),
              !TextToken.hasProtectedCase(word) || word.filter(\.isLetter).allSatisfy(\.isUppercase) else { return nil }
        let fixes = language == .english ? [
            "recieve": "receive", "langauge": "language", "definately": "definitely",
            "occured": "occurred", "seperate": "separate", "accomodate": "accommodate",
            "wierd": "weird", "quikc": "quick", "programmng": "programming"
        ] : [
            "пожалуйсто": "пожалуйста", "здраствуйте": "здравствуйте",
            "програмирование": "программирование", "симпотичный": "симпатичный",
            "агенство": "агентство", "будующий": "будущий", "сдесь": "здесь",
            "жыраф": "жираф", "щюка": "щука"
        ]
        guard let replacement = fixes[word.lowercased()] else { return nil }
        return TextToken.applyingCase(of: word, to: replacement)
    }

    private func englishScore(_ original: String) -> Int {
        let word = original.lowercased()
        if LocalLexicon.contains(word), !word.unicodeScalars.contains(where: { (0x0400...0x04FF).contains(Int($0.value)) }) { return 16 }
        if Self.englishWords.contains(word) { return 12 }
        if Self.englishNames.contains(word) { return 14 }
        if scriptLanguage(original) == .english, isKnownWord(original) { return 16 }
        var score = 0
        let common = ["th", "he", "in", "er", "an", "re", "on", "at", "en", "nd",
                      "tion", "ing", "ed", "ou", "ea", "st", "to", "it", "is"]
        for unit in common where word.contains(unit) { score += unit.count > 2 ? 3 : 1 }
        if word.contains(where: { "aeiou".contains($0) }) { score += 2 }
        else if word.contains("y") { score += 1 }
        if word.contains(where: { !$0.isLetter && $0 != "'" && $0 != "-" }) { score -= 4 }
        for bad in ["jj", "qq", "zx", "xq", "jv", "qf", "wq"] where word.contains(bad) { score -= 2 }
        if longestConsonantRun(in: word, vowels: "aeiouy") >= 5 { score -= 3 }
        return score
    }

    private func russianScore(_ original: String) -> Int {
        let word = original.lowercased()
        if LocalLexicon.contains(word), word.unicodeScalars.contains(where: { (0x0400...0x04FF).contains(Int($0.value)) }) { return 16 }
        if Self.russianWords.contains(word) { return 12 }
        if Self.russianNames.contains(word) { return 14 }
        if scriptLanguage(original) == .russian, isKnownWord(original) { return 16 }
        var score = 0
        let common = ["ст", "но", "то", "на", "ен", "ов", "ни", "ра", "во", "ко",
                      "пр", "по", "ро", "ал", "ль", "ого", "ени", "ать", "ить"]
        for unit in common where word.contains(unit) { score += unit.count > 2 ? 3 : 1 }
        if word.contains(where: { "аеёиоуыэюя".contains($0) }) { score += 2 }
        if word.contains(where: { !$0.isLetter && $0 != "'" && $0 != "-" }) { score -= 4 }
        for bad in ["ъъ", "ыы", "ьь", "йй", "щщ", "йф", "щз"] where word.contains(bad) { score -= 2 }
        if longestConsonantRun(in: word, vowels: "аеёиоуыэюя") >= 5 { score -= 3 }
        return score
    }

    private func longestConsonantRun(in word: String, vowels: String) -> Int {
        var current = 0
        var longest = 0
        for character in word {
            if character.isLetter && !vowels.contains(character) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return longest
    }

    private func normalizedName(_ word: String, language: Language) -> String {
        let normalized = word.lowercased()
        let vocabulary = language == .english ? Self.englishWords : Self.russianWords
        if vocabulary.contains(normalized) { return word }
        let names = language == .russian ? Self.russianNames : Self.englishNames
        guard word.count <= 64, !names.contains(normalized) else { return word }
        guard let nearest = names
            .filter({ abs($0.count - normalized.count) <= 1 })
            .map({ ($0, editDistance(normalized, $0)) })
            .filter({ $0.1 == 1 })
            .sorted(by: { $0.0 < $1.0 })
            .first?.0 else { return word }
        guard word.first?.isUppercase == true else { return nearest }
        return nearest.prefix(1).uppercased() + nearest.dropFirst()
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
