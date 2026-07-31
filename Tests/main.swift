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
expect(engine.correction(for: "d")?.replacement, "в", "User test: one-letter в")
expect(engine.correction(for: "'d")?.replacement, "'в", "User test: quoted one-letter в")
expect(engine.correction(for: "Ьщысщц")?.replacement, "Moscow", "User test: Moscow")
expect(engine.correction(for: "yfpdfybb")?.replacement, "названии", "User test: названии")
expect(engine.correction(for: "brjyre")?.replacement, "иконку", "User test: иконку")
expect(engine.correction(for: "gbie")?.replacement, "пишу", "User test: пишу")
expect(engine.correction(for: "drk.xtyysv")?.replacement, "включенным", "User test: включенным")
expect(engine.correction(for: "ghbkj;tybtv")?.replacement, "приложением", "User test: приложением")
expect(engine.correction(for: ",hspujdbrb")?.replacement,
       "брызговики",
       "User test: брызговики")
expect(engine.correction(for: "<hspujdbrb")?.replacement,
       "Брызговики",
       "User test: capitalized Брызговики")
expect(engine.correction(for: "иьц")?.replacement, "BMW", "Automotive brand BMW")
expect(engine.correction(for: "фгвш")?.replacement, "Audi", "Automotive brand Audi")
expect(engine.correction(for: "Ч3")?.replacement, "X3", "Automotive model X3")
expect(engine.correction(for: "Й7")?.replacement, "Q7", "Automotive model Q7")
expect(engine.correction(for: "СЧ-5")?.replacement, "CX-5", "Automotive model CX-5")
expect(engine.correction(for: "ПДУ450")?.replacement, "GLE450", "Automotive model GLE450")
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
expectNil(engine.correction(for: "версия3"), "Ordinary word with a number stays")
expectNil(engine.correction(for: "дом15"), "Ordinary Russian text with a number stays")
expectNil(engine.correction(for: "ghbdtn", ignored: ["ghbdtn"]), "Ignored word stays")

guard KeyboardTokenClassifier.continuesWord("3"),
      KeyboardTokenClassifier.continuesWord("-"),
      KeyboardTokenClassifier.continuesWord("Ч"),
      !KeyboardTokenClassifier.continuesWord(" ") else {
    fputs("FAIL Model letters, digits, and hyphens must stay in one token\n", stderr)
    exit(1)
}

let boundaryCorrection = Correction(
    original: "ghbdtn",
    replacement: "привет",
    language: .russian
)
let boundaryPlan = KeyboardReplacementPlan(
    correction: boundaryCorrection,
    replayBoundary: true
)
let expectedBoundaryPlan =
    Array(repeating: KeyboardReplacementStep.backspace, count: 6) +
    [.insert("привет"), .replayBoundary]
guard boundaryPlan.steps == expectedBoundaryPlan else {
    fputs("FAIL Boundary replacement must replay the swallowed separator last\n", stderr)
    exit(1)
}

let russianPrepositions = """
без близ в во возле вокруг впереди вдоль вместо вне внутри для до за из из-за
из-под к ко кроме между на над навстречу напротив о об обо около от перед передо
по под подо при про ради с со сквозь среди у через благодаря вопреки ввиду
вследствие насчёт несмотря согласно спустя включая исключая начиная помимо
посредством путём касательно относительно
""".split(whereSeparator: \.isWhitespace).map(String.init)

for preposition in russianPrepositions {
    let mistyped = engine.convert(preposition, to: .english)
    expect(engine.correction(for: mistyped)?.replacement,
           preposition,
           "Russian preposition \(preposition) from \(mistyped)")
}

let englishPrepositions = """
about above across after against along among around as at before behind below
beside between beyond by despite down during except for from in inside into near
of off on onto opposite out outside over past round since than through throughout
to towards under underneath unlike until up upon via with within without
""".split(whereSeparator: \.isWhitespace).map(String.init)

for preposition in englishPrepositions {
    let mistyped = engine.convert(preposition, to: .russian)
    expect(engine.correction(for: mistyped)?.replacement,
           preposition,
           "English preposition \(preposition) from \(mistyped)")
}

guard engine.detectedLanguage(for: "hello") == .english else {
    fputs("FAIL Detect valid English\n", stderr)
    exit(1)
}
guard engine.detectedLanguage(for: "привет") == .russian else {
    fputs("FAIL Detect valid Russian\n", stderr)
    exit(1)
}

print("LanguageEngineTests: OK")
