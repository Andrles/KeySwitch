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
expectNil(engine.correction(for: "Fktrcfyllh"), "Layout must not silently rewrite a misspelled name")
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
expect(engine.correction(for: "иьц")?.replacement, "bmw", "Brand layout preserves input case")
expect(engine.correction(for: "фгвш")?.replacement, "audi", "Brand layout preserves input case")
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

guard SemanticVersion("v3.0.0") == SemanticVersion("3.0"),
      SemanticVersion("3.0.1")! > SemanticVersion("3.0.0")!,
      SemanticVersion("2.10.0")! > SemanticVersion("2.9.9")!,
      SemanticVersion("3.0.0-beta") == SemanticVersion("3.0.0"),
      SemanticVersion("not-a-version") == nil else {
    fputs("FAIL Semantic version comparison\n", stderr)
    exit(1)
}

// Regression: valid words must never be rewritten as nearby names.
for word in ["many", "Many", "may", "mark", "hello", "привет"] {
    let language: Language = word.unicodeScalars.contains { $0.value >= 0x0400 } ? .russian : .english
    guard engine.spellingSuggestion(for: word, language: language) == nil else {
        fputs("FAIL Valid word rewritten as name: \(word)\n", stderr)
        exit(1)
    }
}

// macOS text positions are UTF-16, not Swift grapheme counts.
let suffix = VerifiedTextSuffix(text: "привет ", caret: 12)
guard suffix.matches(selection: NSRange(location: 12, length: 0), actual: "привет "),
      !suffix.matches(selection: NSRange(location: 13, length: 0), actual: "привет "),
      !suffix.matches(selection: NSRange(location: 12, length: 1), actual: "привет "),
      !suffix.matches(selection: NSRange(location: 12, length: 0), actual: "другой "),
      !suffix.matches(selection: NSRange(location: 12, length: 0), actual: nil),
      VerifiedTextSuffix(text: "😀a", caret: 3).range == NSRange(location: 0, length: 3),
      VerifiedTextSuffix(text: "hello", caret: 2).range == nil else {
    fputs("FAIL Unsafe text replacement preflight\n", stderr)
    exit(1)
}

var retry = MonitorRetryPolicy()
for attempt in 0..<5 {
    let time = Double(attempt) * 100
    guard retry.allowsAttempt(at: time) else {
        fputs("FAIL Retry rejected too early\n", stderr); exit(1)
    }
    retry.recordFailure(at: time)
    guard !retry.allowsAttempt(at: time + 1) else {
        fputs("FAIL Retry must back off\n", stderr); exit(1)
    }
}
guard !retry.allowsAttempt(at: 10_000) else {
    fputs("FAIL Retries must stop after five failures\n", stderr); exit(1)
}
retry.reset()
guard retry.allowsAttempt(at: 10_000),
      MonitorState.resolve(enabled: true, trusted: false, running: false) == .needsPermission,
      MonitorState.resolve(enabled: false, trusted: true, running: true) == .paused,
      MonitorState.resolve(enabled: true, trusted: true, running: false) == .failed,
      MonitorState.resolve(enabled: true, trusted: true, running: true) == .ready else {
    fputs("FAIL Monitor readiness state\n", stderr); exit(1)
}

guard engine.spellingSuggestion(for: String(repeating: "a", count: 10_000), language: .english) == nil else {
    fputs("FAIL Long token must bypass spelling\n", stderr); exit(1)
}

print("LanguageEngineTests: OK")

// Presentation preference must default to menu-bar-only and persist opt-out.
let presentationSuite = "local.keyswitch.tests.presentation.\(UUID().uuidString)"
let presentationDefaults = UserDefaults(suiteName: presentationSuite)!
let presentationPreferences = Preferences(defaults: presentationDefaults)
precondition(presentationPreferences.menuBarOnly)
presentationPreferences.menuBarOnly = false
precondition(!Preferences(defaults: presentationDefaults).menuBarOnly)
presentationPreferences.menuBarOnly = true
precondition(Preferences(defaults: presentationDefaults).menuBarOnly)
presentationDefaults.removePersistentDomain(forName: presentationSuite)
print("Presentation preference tests: OK")

// Stress-audit regressions: protect correct input before considering candidates.
for word in ["Chen", "Petr", "ещё", "из-за", "ЖКХ", "РФ,", "МИ8", "ТУ154", "АН2", "ГОСТ123", "МИ-8", "ТУ-154", "АН-2", "ГОСТ-123", "Александра", "Инна", "Наталия", "Anne", "Julie", "Sergei", "Семён", "асинхронность", "коммит", "OpenAI", "macOS", "AMD", "BMW", "РФ", "ЕГЭ", "C:", "https://example.com", "v3.1.0"] {
    expectNil(engine.correction(for: word), "Protect correct/technical input \(word)")
    guard engine.spellingCorrection(for: word, automatic: true) == nil else {
        fputs("FAIL Unsafe automatic spelling: \(word)\n", stderr); exit(1)
    }
}
for (input, expected) in [("зфкл", "park"), ("вфкл", "dark"), ("фкшф", "aria"), ("ЗФКЛ", "PARK"), ("ghbdtn...", "привет..."), ("[зфкл]", "[park]"), ("'ghbdtn'", "'привет'")] {
    expect(engine.correction(for: input)?.replacement, expected, "Exact layout \(input)")
}
for word in ["helo", "adress", "teh", "превет", "малако", "Alexandr", "unknownBrand", "ABC123"] {
    guard engine.spellingCorrection(for: word, automatic: true) == nil else {
        fputs("FAIL Ambiguous spelling auto-applied: \(word)\n", stderr); exit(1)
    }
}
for (input, expected) in [("recieve", "receive"), ("Recieve", "Receive"), ("RECIEVE", "RECEIVE"), ("пожалуйсто", "пожалуйста"), ("Пожалуйсто", "Пожалуйста"), ("ПОЖАЛУЙСТО", "ПОЖАЛУЙСТА"), ("[recieve]", "[receive]"), ("\"recieve\"", "\"receive\""), ("'recieve'", "'receive'"), ("recieve...", "receive...")] {
    expect(engine.spellingCorrection(for: input, automatic: true)?.replacement, expected, "Safe spelling and punctuation \(input)")
}
if ProcessInfo.processInfo.environment["KEYSWITCH_DISABLE_SYSTEM_DICTIONARY"] == "0" {
    guard SystemDictionary.shared.contains("hello", language: .english), SystemDictionary.shared.contains("мир", language: .russian) else {
        fputs("FAIL System dictionary service unavailable\n", stderr); exit(1)
    }
    let lower = SystemDictionary.shared.suggestion(for: "recieve", language: .english)!
    expect(SystemDictionary.shared.suggestion(for: "Recieve", language: .english), TextToken.applyingCase(of: "Recieve", to: lower), "Cache title case")
    expect(SystemDictionary.shared.suggestion(for: "RECIEVE", language: .english), lower.uppercased(), "Cache upper case")
    let upper = SystemDictionary.shared.suggestion(for: "ПОЖАЛУЙСТО", language: .russian)!
    expect(SystemDictionary.shared.suggestion(for: "пожалуйсто", language: .russian), upper.lowercased(), "Cache lowercase after uppercase")
}
print("Stress regression tests: OK")

guard !KeyboardTokenClassifier.isNavigationKey(48), KeyboardTokenClassifier.isNavigationKey(123),
      KeyboardTokenClassifier.isTechnicalBoundary("/"), KeyboardTokenClassifier.isTechnicalBoundary("@"),
      !KeyboardTokenClassifier.isTechnicalBoundary("\t"), !KeyboardTokenClassifier.isTechnicalBoundary(" ") else {
    fputs("FAIL Word completion/navigation policy\n", stderr); exit(1)
}
print("Keyboard boundary policy tests: OK")
