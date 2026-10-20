import Foundation

assert(RuntimeCheckTarget.bundleIdentifier(arguments: ["KeySwitch"]) == nil)
assert(RuntimeCheckTarget.bundleIdentifier(arguments: ["KeySwitch", "--input-diagnostics"]) == nil)
assert(RuntimeCheckTarget.bundleIdentifier(arguments: ["KeySwitch", "--runtime-check"]) == "com.apple.TextEdit")
assert(RuntimeCheckTarget.bundleIdentifier(arguments: ["KeySwitch", "--runtime-browser-check"]) == "local.keyswitch.browserlab")
assert(RuntimeCheckTarget.bundleIdentifier(arguments: ["KeySwitch", "--runtime-check", "--runtime-browser-check"]) == "local.keyswitch.browserlab")

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
for word in ["ktв", "kев", "леd"] {
    expect(engine.correction(for: word)?.replacement, "лев", "Mid-word source change: \(word)")
}
expect(engine.correction(for: "(ktв!)")?.replacement, "(лев!)", "Mixed word punctuation")
expect(engine.correction(for: "Ktв")?.replacement, "Лев", "Mixed word title case")
expect(engine.correction(for: "KTВ")?.replacement, "ЛЕВ", "Mixed word uppercase")
expect(engine.correction(for: "рудlo")?.replacement, "hello", "Mixed word to English")
expect(engine.correction(for: "heддщ")?.replacement, "hello", "Mixed English prefix")
expect(engine.correction(for: "Fлександр")?.replacement, "Александр", "Mixed proper name")
for word in ["ktв3", "api/ktв", "user@ktв", "foo_ktв", "https://ktв", "myKtв", "ktвxyz"] {
    expectNil(engine.correction(for: word), "Mixed identifier or unknown word stays: \(word)")
}
expectNil(engine.correction(for: "ktв", ignored: ["ktв"]), "Ignored mixed word")
expectNil(engine.correction(for: "ktв", learned: ["ktв"]), "Learned mixed word")
var mixedCases = 0
for (word, language) in [("лев", Language.russian), ("привет", .russian),
                          ("раскладки", .russian), ("Анастасия", .russian),
                          ("hello", .english), ("world", .english),
                          ("keyboard", .english), ("morning", .english)] {
    let correct = Array(word)
    let wrong = Array(engine.convert(word, to: language.opposite))
    for split in 1..<correct.count {
        for mixed in [String(wrong.prefix(split)) + String(correct.dropFirst(split)),
                      String(correct.prefix(split)) + String(wrong.dropFirst(split))] {
            expect(engine.correction(for: mixed)?.replacement, word, "Mixed source boundary: \(mixed)")
            mixedCases += 1
        }
    }
}
print("Mixed-layout boundary cases: \(mixedCases) OK")

func recoveredToken(_ document: String, suffix: String) -> String? {
    let text = document as NSString
    return KeyboardTokenRecovery.token(caret: text.length, typedSuffix: suffix) { range in
        precondition(range.length <= 65, "Recovery must inspect at most 65 UTF-16 units")
        return text.substring(with: range)
    }
}
expect(recoveredToken("lbhtrnjh", suffix: "htrnjh"), "lbhtrnjh", "Ordinary field: recover full homogeneous token, never its recognised suffix")
expect(recoveredToken("ktв", suffix: "в"), "ktв", "Recover prefix discarded on source change")
expect(recoveredToken("Предыдущее слово ktв", suffix: "в"), "ktв", "Only recover current token")
expect(recoveredToken("🙂\nheддщ", suffix: "дщ"), "heддщ", "UTF-16 and multiline recovery")
assert(recoveredToken("ktв", suffix: "д") == nil, "Changed text must not be recovered")
assert(recoveredToken("ktв", suffix: "") == nil, "No newly typed text means no recovery")
assert(recoveredToken(String(repeating: "k", count: 70) + "в", suffix: "в") == nil,
       "Do not recover truncated long words")
assert(KeyboardTokenRecovery.token(caret: 3, typedSuffix: "в", read: { _ in nil }) == nil,
       "Unavailable editor text must fail closed")
assert(recoveredToken("https://ktв", suffix: "в") == nil, "Recovery must refuse a URL instead of stripping its prefix")
for (document, expected) in [("вчера lbhtrnjh", "lbhtrnjh"), ("🙂\nlbhtrnjh", "lbhtrnjh"), ("«ghbdtn,»", "«ghbdtn,»")] {
    let suffix = document.hasSuffix("»") ? "ghbdtn,»" : "trnjh"
    expect(recoveredToken(document, suffix: suffix), expected, "Complete word including punctuation")
}
for token in ["www.lbhtrnjh", "me@lbhtrnjh", "key=lbhtrnjh", "path/lbhtrnjh", "my_lbhtrnjh", "host:lbhtrnjh"] {
    assert(recoveredToken(token, suffix: "trnjh") == nil, "Keep technical prefix in every field")
}
print("Mixed-layout recovery regressions: OK")

func recoveredAddressWord(_ document: String, suffix: String) -> String? {
    let text = document as NSString
    return KeyboardTokenRecovery.token(caret: text.length, typedSuffix: suffix, scope: .completeAddressWord) { range in
        assert(range.length <= 65)
        return text.substring(with: range)
    }
}
for suffix in ["trnjh", "htrnjh", "h", "lbhtrnjh"] {
    let recovered = recoveredAddressWord("lbhtrnjh", suffix: suffix)
    expect(recovered, "lbhtrnjh", "Safari: recover all letters after unavailable early events")
    expect(recovered.flatMap { engine.correction(for: $0)?.replacement }, "директор", "Safari: correct whole word rather than suffix")
}
expect(recoveredAddressWord("предыдущий запрос lbhtrnjh", suffix: "trnjh"), "lbhtrnjh", "Safari: respect word boundary")
for input in ["https://lbhtrnjh", "www.lbhtrnjh", "me@lbhtrnjh", "key=lbhtrnjh", "path/lbhtrnjh", "my_lbhtrnjh", "host:lbhtrnjh", String(repeating: "l", count: 70) + "trnjh"] {
    assert(recoveredAddressWord(input, suffix: "trnjh") == nil, "Safari: preserve technical or truncated token")
}
assert(recoveredAddressWord("lbhtrnjh", suffix: "wrong") == nil, "Safari: changed suffix refuses recovery")
assert(recoveredAddressWord("lbhtrnjh", suffix: "") == nil, "Safari: no recent typing refuses recovery")
assert(KeyboardTokenRecovery.token(caret: 8, typedSuffix: "trnjh", scope: .completeAddressWord, read: { _ in nil }) == nil,
       "Safari: unavailable read refuses correction, never falls back to partial suffix")
assert(BrowserAddressFieldPolicy.requiresCompleteWord(bundleIdentifier: "com.apple.Safari", fieldIdentifier: "WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD"))
assert(!BrowserAddressFieldPolicy.requiresCompleteWord(bundleIdentifier: "com.apple.Safari", fieldIdentifier: "page-search"))
assert(!BrowserAddressFieldPolicy.requiresCompleteWord(bundleIdentifier: "other.app", fieldIdentifier: "WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD"))
assert(!BrowserAddressFieldPolicy.requiresCompleteWord(bundleIdentifier: "com.apple.Safari", fieldIdentifier: nil))
print("Safari address-word recovery regressions: OK")

expect(engine.forcedConversion("ghtdtn")?.replacement, "превет",
       "Wrong-layout typo preserves spelling during explicit conversion")
expectNil(engine.correction(for: "ghtdtn"),
          "Wrong-layout typo must not silently perform two uncertain corrections")
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
assert(engine.spellingSuggestion(for: "Alexandr", language: .english) == nil,
       "Valid transliteration Alexandr must not be rewritten as Alexander")
expect(engine.spellingSuggestion(for: "Alexanddr", language: .english),
       "Alexander",
       "English name typo suggestion")
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
// A platform dictionary can rank "пресет" first. The greeting preference is
// suggestion-only, preserves wrappers/case, and still protects acronyms.
for (input, expected) in [("превет", "привет"), ("Превет", "Привет"),
                          ("(превет)", "(привет)"), ("[Превет]", "[Привет]"),
                          ("превет...", "привет...")] {
    expect(engine.spellingCorrection(for: input, automatic: false)?.replacement, expected, "Preferred greeting hint \(input)")
    guard engine.spellingCorrection(for: input, automatic: true) == nil else {
        fputs("FAIL Greeting hint auto-applied: \(input)\n", stderr); exit(1)
    }
}
for word in ["ПРЕВЕТ", "преВет", "пресет"] {
    guard engine.spellingCorrection(for: word, automatic: true) == nil else {
        fputs("FAIL Protected spelling changed: \(word)\n", stderr); exit(1)
    }
}
guard engine.spellingSuggestion(for: "ПРЕВЕТ", language: .russian) == nil,
      engine.spellingSuggestion(for: "преВет", language: .russian) == nil else {
    fputs("FAIL Protected hint case changed\n", stderr); exit(1)
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

// Concurrent dictionary edits must preserve panel additions and explicit removals.
let auditDefaults = UserDefaults(suiteName: "local.keyswitch.tests.dictionary")!
auditDefaults.removePersistentDomain(forName: "local.keyswitch.tests.dictionary")
let auditPreferences = Preferences(defaults: auditDefaults)
auditPreferences.ignoredWords = ["api", "newhud"]
auditPreferences.saveIgnoredWords(["api"], baseline: ["api"])
assert(auditPreferences.ignoredWords == ["api", "newhud"])
auditPreferences.saveIgnoredWords(["manual"], baseline: ["api"])
assert(auditPreferences.ignoredWords == ["manual", "newhud"])
auditPreferences.excludedApps = ["com.editor.app"]
assert(auditPreferences.excludesApplication("com.editor.app"))
assert(!auditPreferences.excludesApplication("com.editor.application"))
assert(!auditPreferences.excludesApplication("com.editor.app.helper"))
assert(auditPreferences.setShortcut(.l, for: .layout))
assert(!auditPreferences.setShortcut(.l, for: .accept))
assert(auditPreferences.shortcut(for: .accept) == .none)
assert(auditPreferences.setShortcut(.enter, for: .accept))
assert(UserDictionaryFormat.replacements("wrong=Right, typo=слово") == ["wrong": "Right", "typo": "слово"])
assert(UserDictionaryFormat.replacements("bad=") == nil)
assert(UserDictionaryFormat.replacements("a=one,A=two") == nil)
expect(engine.correction(for: "кейсвич", replacements: ["кейсвич":"KeySwitch"])?.replacement, "KeySwitch", "Explicit user spelling")
expect(engine.correction(for: "(кейсвич)", replacements: ["кейсвич":"KeySwitch"])?.replacement, "(KeySwitch)", "User spelling preserves brackets")
expectNil(engine.correction(for: "кейсвич", ignored: ["кейсвич"], replacements: ["кейсвич":"KeySwitch"]), "Ignore takes priority over custom replacement")
expectNil(engine.correction(for: "flarnyx", learned: ["flarnyx"]), "Learned unfamiliar word remains")
expect(engine.correction(for: "адфктнч", learned: ["flarnyx"])?.replacement, "flarnyx", "Layout uses learned vocabulary")
expect(SelectedTextTransform.apply(.layout, to: "Ghbdtn, vbh!"), "Привет, мир!", "Selected sentence layout with punctuation")
expect(SelectedTextTransform.apply(.uppercase, to: "Привет, Straße!"), "ПРИВЕТ, STRASSE!", "Selected unicode case expands safely")
expect(SelectedTextTransform.apply(.lowercase, to: "API, ЁЖ!"), "api, ёж!", "Selected lowercase")
assert(SelectedTextTransform.apply(.layout, to: String(repeating: "a", count: 4097)) == nil)
auditDefaults.removePersistentDomain(forName: "local.keyswitch.tests.dictionary")
print("Dictionary/manual command regressions: OK")

// Audit 2026-10-05: invalid drafts, inert pairs and non-restorable exports.
assert(UserDictionaryFormat.validatedWords("kept, aero gel") == nil)
assert(UserDictionaryFormat.validatedWords("kept, aerogel") == ["kept", "aerogel"])
assert(UserDictionaryFormat.validatedWords(String(repeating: "a", count: 65)) == nil)
assert(UserDictionaryFormat.replacements("abc=123") == nil)
assert(UserDictionaryFormat.replacements("abc=тестtest") == nil)
let oldIgnored = DictionarySnapshot(words: ["aerogel"], replacements: ["кейсвич": "KeySwitch"], ignored: ["two words", String(repeating: "x", count: 65)])
assert(try! DictionarySnapshot.decode(oldIgnored.encoded()) == oldIgnored)
let imported = DictionarySnapshot(words: ["other"], replacements: ["кейсвич": "KeySwitch"], ignored: ["api"])
let mergedDictionary = try! oldIgnored.merging(imported)
assert(Set(mergedDictionary.words) == ["aerogel", "other"])
assert(Set(mergedDictionary.ignored).contains("two words"))
let fullDictionary = DictionarySnapshot(words: (0..<5000).map { "word\($0)" }, replacements: [:], ignored: [])
do { _ = try fullDictionary.merging(DictionarySnapshot(words: ["extra"], replacements: [:], ignored: [])); assertionFailure("Merged limit must be enforced") } catch { }
assert(!ShortcutBinding(keyCode: 32, modifiers: ShortcutBinding.control | ShortcutBinding.option, title: "VO U").allowed)
assert(!ShortcutBinding(keyCode: 49, modifiers: ShortcutBinding.command, title: "Spotlight").allowed)
let custom = ShortcutBinding(keyCode: 37, modifiers: ShortcutBinding.command | ShortcutBinding.control, title: "⌃⌘L")
assert(auditPreferences.setShortcutBinding(custom, for: .layout))
assert(!auditPreferences.setShortcutBinding(custom, for: .uppercase))
assert(auditPreferences.shortcutBinding(for: .layout)?.matches(keyCode: 37, modifiers: custom.modifiers | (1 << 16)) == true)
assert(auditPreferences.setShortcutBinding(nil, for: .layout))
assert(auditPreferences.shortcutBinding(for: .layout) == nil)
auditDefaults.removePersistentDomain(forName: "local.keyswitch.tests.dictionary")
print("Audit dictionary/shortcut regressions: OK")

assert(!UserDictionaryFormat.validWord("word."))
assert(!UserDictionaryFormat.validWord("foo/bar"))
assert(!UserDictionaryFormat.validWord("🙂"))

let featureSuite = "local.keyswitch.tests.features"
let featureDefaults = UserDefaults(suiteName: featureSuite)!
featureDefaults.removePersistentDomain(forName: featureSuite)
let features = Preferences(defaults: featureDefaults)
assert(!features.snippetsEnabled)
features.snippets = ["спс": "Спасибо, хорошего дня!", "sig": "Best regards, Алексей 🙂"]
features.snippetsEnabled = true
assert(features.snippet(for: "спс", boundary: " ", bundleID: "editor") == "Спасибо, хорошего дня!")
for separator in ["\n", "\t", ".", "!", "", "  "] { assert(features.snippet(for: "sig", boundary: separator, bundleID: "editor") == nil) }
features.ignoredWords = ["sig"]
assert(features.snippet(for: "SIG", boundary: " ", bundleID: "editor") == nil)
features.ignoredWords = []
features.excludedApps = ["editor"]
assert(features.snippet(for: "sig", boundary: " ", bundleID: "editor") == nil)
features.setProfile(ApplicationProfile(layout: false, spelling: true, snippets: true), for: "editor")
assert(!features.excludesApplication("editor"))
assert(!features.profile(for: "editor").layout && features.profile(for: "editor").spelling)
assert(features.snippet(for: "SIG", boundary: " ", bundleID: "editor") == "Best regards, Алексей 🙂")
assert(Preferences(defaults: featureDefaults).profile(for: "editor") == features.profile(for: "editor"))
features.setProfile(.none, for: "editor")
assert(!features.excludesApplication("editor") && features.snippet(for: "sig", boundary: " ", bundleID: "editor") == nil)
features.removeApplicationRule("editor")
assert(features.profile(for: "editor") == .all && features.applicationRuleIDs.isEmpty)
features.enabled = false
assert(features.snippet(for: "sig", boundary: " ", bundleID: "editor") == nil)
assert(!SnippetFormat.validPhrase("\nHello") && !SnippetFormat.validPhrase("a\tb") && !SnippetFormat.validPhrase(" "))
assert(SnippetFormat.validPhrase(String(repeating: "я", count: 256)))
assert(!SnippetFormat.validPhrase(String(repeating: "я", count: 257)))
let unicodePhrase = String(repeating: "Привет 👨‍👩‍👧‍👦 e\u{301}! ", count: 8)
let chunks = SnippetFormat.chunks(unicodePhrase)!
assert(chunks.joined() == unicodePhrase && chunks.allSatisfy { $0.utf16.count <= 20 })
let oldJSON = Data(#"{"words":["hello"],"replacements":{},"ignored":[]}"#.utf8)
assert(try! DictionarySnapshot.decode(oldJSON).snippets.isEmpty)
let phrases = DictionarySnapshot(words: [], replacements: [:], ignored: [], snippets: ["sig": "Best regards, Алексей 🙂"])
assert(try! DictionarySnapshot.decode(phrases.encoded()) == phrases)
let importedPhrases = try phrases.merging(DictionarySnapshot(words: [], replacements: [:], ignored: [], snippets: ["SIG": "С уважением, Алексей"]))
assert(importedPhrases.snippets == ["sig": "С уважением, Алексей"])
do { _ = try phrases.merging(DictionarySnapshot(words: [], replacements: [:], ignored: [], snippets: ["SIG": "One", "sig": "Two"])); assertionFailure("Case collision must throw") } catch { }
featureDefaults.removePersistentDomain(forName: featureSuite)
print("Application profiles / snippet policy / transfer regressions: OK")

// Exercise the editing transaction with editor responses, including partial failures.
final class SuffixEditorFixture: SuffixEditingBackend {
    var value: String
    var range: NSRange
    var canReplace = true
    var contextIsCurrent = true
    var rejectWrite = false
    var acknowledgeWithoutWriting = false
    var transformWrite: ((String) -> String)?
    var afterSelect: (() -> Void)?
    var afterWrite: (() -> Void)?
    var selections = 0
    var writes = 0
    init(_ value: String) { self.value = value; range = NSRange(location: value.utf16.count, length: 0) }
    func selection() -> NSRange? { range }
    func text(in range: NSRange) -> String? {
        let string = value as NSString
        guard range.location >= 0, range.length >= 0, NSMaxRange(range) <= string.length else { return nil }
        return string.substring(with: range)
    }
    func select(_ range: NSRange) -> Bool {
        selections += 1
        self.range = range; afterSelect?(); return true
    }
    func replaceSelection(with text: String) -> Bool {
        guard !rejectWrite else { return false }
        defer { afterWrite?() }
        writes += 1
        if acknowledgeWithoutWriting { return true }
        let inserted = transformWrite?(text) ?? text
        value = (value as NSString).replacingCharacters(in: range, with: inserted)
        range.length = inserted.utf16.count
        return true
    }
}
func suffixRequire(_ condition: @autoclosure () -> Bool, _ label: String) {
    if !condition() { fputs("SuffixReplacement FAIL: \(label)\n", stderr); exit(1) }
}
for (original, replacement) in [("превет ", "привет "), ("recieve ", "receive "),
                                ("Превет ", "Привет "), ("😀 превет ", "😀 привет "),
                                ("ошибк ", "ошибка ")] {
    let editor = SuffixEditorFixture("Начало: " + original)
    let suffix = VerifiedTextSuffix(text: original, caret: editor.range.location)
    suffixRequire(SuffixReplacement.apply(suffix, replacement: replacement, using: editor) == .applied, "successful exact replacement")
    suffixRequire(editor.value == "Начало: " + replacement && editor.range == NSRange(location: editor.value.utf16.count, length: 0), "prefix, UTF16 and caret preserved")
}
let unsupportedEditor = SuffixEditorFixture("превет "); unsupportedEditor.canReplace = false
suffixRequire(SuffixReplacement.apply(VerifiedTextSuffix(text: "превет ", caret: 7), replacement: "привет ", using: unsupportedEditor) == .unsupported && unsupportedEditor.writes == 0 && unsupportedEditor.range.length == 0, "unsupported field untouched")
let staleEditor = SuffixEditorFixture("другой ")
suffixRequire(SuffixReplacement.apply(VerifiedTextSuffix(text: "превет ", caret: 7), replacement: "привет ", using: staleEditor) == .contextChanged && staleEditor.writes == 0, "changed text untouched")
let changedFocusEditor = SuffixEditorFixture("превет ")
changedFocusEditor.afterSelect = { changedFocusEditor.contextIsCurrent = false }
suffixRequire(SuffixReplacement.apply(VerifiedTextSuffix(text: "превет ", caret: 7), replacement: "привет ", using: changedFocusEditor) == .contextChanged && changedFocusEditor.writes == 0, "focus change prevents write")
let rejectedEditor = SuffixEditorFixture("превет "); rejectedEditor.rejectWrite = true
suffixRequire(SuffixReplacement.apply(VerifiedTextSuffix(text: "превет ", caret: 7), replacement: "привет ", using: rejectedEditor) == .failed && rejectedEditor.value == "превет " && rejectedEditor.range == NSRange(location: 7, length: 0), "failed write preserves text and restores caret")
let corruptedEditor = SuffixEditorFixture("превет "); corruptedEditor.transformWrite = { _ in "пресет " }
suffixRequire(SuffixReplacement.apply(VerifiedTextSuffix(text: "превет ", caret: 7), replacement: "привет ", using: corruptedEditor) == .unverified, "unexpected result never reports success")
// Reproduced in WebKit: AX write succeeds but the DOM remains unchanged and
// selected. A subsequent physical separator must not replace the whole word.
let acknowledgedEditor = SuffixEditorFixture("lbhtrnjh")
acknowledgedEditor.acknowledgeWithoutWriting = true
suffixRequire(SuffixReplacement.apply(VerifiedTextSuffix(text: "lbhtrnjh", caret: 8), replacement: "директор", using: acknowledgedEditor) == .unverified, "acknowledged no-op is not success")
suffixRequire(acknowledgedEditor.value == "lbhtrnjh" && acknowledgedEditor.range == NSRange(location: 8, length: 0), "unchanged original caret restored after acknowledged no-op")
acknowledgedEditor.acknowledgeWithoutWriting = false
_ = acknowledgedEditor.replaceSelection(with: " ")
suffixRequire(acknowledgedEditor.value == "lbhtrnjh ", "next separator preserves original after acknowledged no-op")
let focusLostAfterAcknowledgement = SuffixEditorFixture("lbhtrnjh")
focusLostAfterAcknowledgement.acknowledgeWithoutWriting = true
focusLostAfterAcknowledgement.afterWrite = { focusLostAfterAcknowledgement.contextIsCurrent = false }
suffixRequire(SuffixReplacement.apply(VerifiedTextSuffix(text: "lbhtrnjh", caret: 8), replacement: "директор", using: focusLostAfterAcknowledgement) == .unverified, "focus loss after acknowledgement is not success")
suffixRequire(focusLostAfterAcknowledgement.selections == 1, "caret recovery never touches a field after focus loss")
let textChangedAfterAcknowledgement = SuffixEditorFixture("lbhtrnjh")
textChangedAfterAcknowledgement.acknowledgeWithoutWriting = true
textChangedAfterAcknowledgement.afterWrite = { textChangedAfterAcknowledgement.value = "new text" }
suffixRequire(SuffixReplacement.apply(VerifiedTextSuffix(text: "lbhtrnjh", caret: 8), replacement: "директор", using: textChangedAfterAcknowledgement) == .unverified, "external text change after acknowledgement is not success")
suffixRequire(textChangedAfterAcknowledgement.value == "new text" && textChangedAfterAcknowledgement.selections == 1, "caret recovery preserves externally changed text and selection")
print("Verified suffix replacement regressions: OK")

// Reproduced Caramba comparison cases, including mapped punctuation at edges.
for (input, expected) in [
    ("[jhjij,", "хорошо,"), ("([jhjij)", "(хорошо)"),
    ("ВЩТэЕ", "DON'T"), ("Ящë", "Zoë"), ("enhj,", "утро,"), ("hf,jnf...", "работа..."), ("GHBDTN", "ПРИВЕТ"), ("Fyfcnfcbz", "Анастасия"),
    ("hfcrkflrb", "раскладки"), ("hfcgjpyfdfybt", "распознавание"),
    (",fpf,", "база,"), ("'nj!", "это!")
] {
    expect(engine.correction(for: input)?.replacement, expected, "Boundary/name regression \(input)")
}

// Simulate an unavailable and an all-words-valid spelling service, then recovery.
var dictionaryTime = 0.0
var serviceUp = false
var failOpen = false
var checks = 0
let recoveringDictionary = SystemDictionary(now: { dictionaryTime },
    availableLanguages: { serviceUp ? ["ru", "en"] : [] },
    check: { word, _ in checks += 1; return failOpen || ["Ирина", "Igor"].contains(word) },
    isDisabled: { false })
assert(!recoveringDictionary.contains("Ирина", language: .russian))
serviceUp = true
dictionaryTime = 3
assert(recoveringDictionary.contains("Ирина", language: .russian))
assert(!recoveringDictionary.contains("ирина", language: .russian))
assert(recoveringDictionary.contains("Igor", language: .english))
assert(!recoveringDictionary.contains("igor", language: .english))
let cachedChecks = checks
assert(recoveringDictionary.contains("Ирина", language: .russian))
assert(checks == cachedChecks)
failOpen = true
dictionaryTime = 64
assert(!recoveringDictionary.contains("Ирина", language: .russian))
failOpen = false
dictionaryTime = 67
assert(recoveringDictionary.contains("Ирина", language: .russian))

var selectedLanguage: Language? = .english
var sourcePresent = false
var sourceStatus: Int32 = 0
var confirmsSwitch = true
var selections = 0
func selectTestSource() -> InputSourceSelectionResult {
    InputSourceSelection.select(language: .russian,
        currentLanguage: { selectedLanguage },
        findSource: { _ in sourcePresent ? "ru-test" : nil },
        apply: { _ in
            selections += 1
            if sourceStatus == 0 && confirmsSwitch { selectedLanguage = .russian }
            return sourceStatus
        })
}
assert(selectTestSource() == .unavailable && selections == 0)
sourcePresent = true
sourceStatus = -50
assert(selectTestSource() == .rejected(-50) && selectedLanguage == .english)
sourceStatus = 0
confirmsSwitch = false
assert(selectTestSource() == .unconfirmed)
confirmsSwitch = true
assert(selectTestSource() == .selected)
let completedSelections = selections
assert(selectTestSource() == .alreadySelected && selections == completedSelections)
// Removing/re-enabling a source is picked up without restarting the application.
selectedLanguage = .english
sourcePresent = false
assert(selectTestSource() == .unavailable)
sourcePresent = true
assert(selectTestSource() == .selected)
print("Names, punctuation, dictionary recovery and input-source failures: OK")
