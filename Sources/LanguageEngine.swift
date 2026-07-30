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
    moscow
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
    """.split(whereSeparator: \.isWhitespace).map(String.init))

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

    func correction(for word: String, ignored: Set<String> = []) -> Correction? {
        let normalized = word.lowercased()
        guard !word.isEmpty, !ignored.contains(normalized) else { return nil }

        let hasLatin = word.unicodeScalars.contains { (0x0041...0x007A).contains(Int($0.value)) }
        let hasCyrillic = word.unicodeScalars.contains { (0x0400...0x04FF).contains(Int($0.value)) }
        guard hasLatin != hasCyrillic else { return nil }

        if hasLatin {
            let converted = convert(word, to: .russian)
            let replacement = normalizedName(converted, language: .russian)
            let sourceScore = englishScore(normalized)
            let targetScore = russianScore(replacement.lowercased())
            let minimumTargetScore = word.count <= 2 ? 12 : 4
            if targetScore >= minimumTargetScore && targetScore - sourceScore >= 3 {
                return Correction(original: word, replacement: replacement, language: .russian)
            }
        } else {
            let converted = convert(word, to: .english)
            let replacement = normalizedName(converted, language: .english)
            let sourceScore = russianScore(normalized)
            let targetScore = englishScore(replacement.lowercased())
            let minimumTargetScore = word.count <= 2 ? 12 : 4
            if targetScore >= minimumTargetScore && targetScore - sourceScore >= 3 {
                return Correction(original: word, replacement: replacement, language: .english)
            }
        }
        return nil
    }

    func detectedLanguage(for word: String) -> Language? {
        let normalized = word.lowercased()
        let hasLatin = word.unicodeScalars.contains { (0x0041...0x007A).contains(Int($0.value)) }
        let hasCyrillic = word.unicodeScalars.contains { (0x0400...0x04FF).contains(Int($0.value)) }
        guard hasLatin != hasCyrillic else { return nil }

        if hasLatin {
            return englishScore(normalized) >= 0 ? .english : nil
        }
        return russianScore(normalized) >= 0 ? .russian : nil
    }

    func spellingSuggestion(for word: String, language: Language) -> String? {
        let name = normalizedName(word, language: language)
        if name != word {
            return name
        }
        return systemDictionary.suggestion(for: word, language: language)
    }

    private func englishScore(_ word: String) -> Int {
        if Self.englishWords.contains(word) { return 12 }
        if Self.englishNames.contains(word) { return 14 }
        if systemDictionary.contains(word, language: .english) { return 16 }
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

    private func russianScore(_ word: String) -> Int {
        if Self.russianWords.contains(word) { return 12 }
        if Self.russianNames.contains(word) { return 14 }
        if systemDictionary.contains(word, language: .russian) { return 16 }
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
        let names = language == .russian ? Self.russianNames : Self.englishNames
        guard !names.contains(normalized) else { return word }
        guard let nearest = names
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
