import Foundation

let engine = LanguageEngine()

func expect(_ actual: String?, _ expected: String, _ label: String) {
    guard actual == expected else {
        fputs("FAIL \(label): expected \(expected), got \(actual ?? "nil")\n", stderr)
        exit(1)
    }
}

func expectNil(_ actual: Correction?, _ label: String) {
    guard actual == nil else {
        fputs("FAIL \(label): unexpected \(actual!.replacement)\n", stderr)
        exit(1)
    }
}

expect(engine.correction(for: "ghbdtn")?.replacement, "привет", "English keys to Russian")
expect(engine.correction(for: "руддщ")?.replacement, "hello", "Russian keys to English")
expect(engine.correction(for: "ghjgecrftim")?.replacement, "пропускаешь", "Russian verb")
expect(engine.correction(for: "bkb")?.replacement, "или", "Short Russian word")
expect(engine.correction(for: "Lfdfq")?.replacement, "Давай", "Capitalized Russian word")
expect(engine.correction(for: "Cnfybckfd")?.replacement, "Станислав", "Russian name Stanislav")
expect(engine.correction(for: "Fktrcfylh")?.replacement, "Александр", "Russian name Alexander")
expect(engine.correction(for: "Fktrcfyllh")?.replacement, "Александр", "Russian name with one typo")
expect(engine.correction(for: "Cltkfq")?.replacement, "Сделай", "User test: Сделай")
expect(engine.correction(for: "Gjxtve")?.replacement, "Почему", "User test: Почему")
expect(engine.correction(for: "gthdjt")?.replacement, "первое", "User test: первое")
expect(engine.correction(for: "yt")?.replacement, "не", "User test: short word не")
expect(engine.correction(for: "цщкл")?.replacement, "work", "User test: work")
expect(engine.correction(for: "ldjhtw")?.replacement, "дворец", "User test: дворец")
expect(engine.correction(for: "vj;tn")?.replacement, "может", "User test: punctuation key ж")
expect(engine.correction(for: "VJ:TN")?.replacement, "МОЖЕТ", "Shift punctuation key Ж")
expect(engine.correction(for: "Z")?.replacement, "Я", "User test: one-letter Я")
expect(engine.correction(for: "Ьщысщц")?.replacement, "Moscow", "User test: Moscow")
expect(engine.spellingSuggestion(for: "Alexandr", language: .english),
       "Alexander",
       "User test: English name spelling")
expect(engine.forcedConversion("руддщ")?.replacement, "hello", "Forced conversion")
expectNil(engine.correction(for: "hello"), "Valid English stays")
expectNil(engine.correction(for: "привет"), "Valid Russian stays")
expectNil(engine.correction(for: "API"), "Short abbreviation stays")
expectNil(engine.correction(for: "Yes"), "Valid English yes stays")
expectNil(engine.correction(for: "hi"), "Valid short English stays")
expectNil(engine.correction(for: "no"), "Valid short English no stays")
expectNil(engine.correction(for: "palace"), "Valid English palace stays")
expectNil(engine.correction(for: "ghbdtn", ignored: ["ghbdtn"]), "Ignored word stays")
guard engine.detectedLanguage(for: "hello") == .english else {
    fputs("FAIL Detect valid English\n", stderr)
    exit(1)
}
guard engine.detectedLanguage(for: "привет") == .russian else {
    fputs("FAIL Detect valid Russian\n", stderr)
    exit(1)
}

print("LanguageEngineTests: OK")
