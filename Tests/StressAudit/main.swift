import AppKit
import Foundation
struct AuditCase: Codable { let kind: String; let input: String; let expected: String; let language: String; let group: String }
struct Result: Codable { let kind: String; let input: String; let expected: String; let actual: String; let group: String; let passed: Bool; let microseconds: Double }
let engine = LanguageEngine()
// Model only token accumulation/decision ordering. No AX permissions or OS keystroke delivery.
func stream(_ input: String, spelling: Bool) -> String {
    var output = "", token = "", suppressed = false
    for c in input {
        let text = String(c)
        if KeyboardTokenClassifier.isTechnicalBoundary(text) { token = ""; suppressed = false; output += text; continue }
        if KeyboardTokenClassifier.continuesWord(text) {
            output += text
            if !suppressed {
                if token.count + 1 > 64 { token = ""; suppressed = true }
                else { token += text }
            }
        } else {
            if !suppressed, !token.isEmpty {
                var replacement = engine.correction(for: token)?.replacement
                if replacement == nil && spelling {
                    replacement = engine.spellingCorrection(for: token, automatic: true)?.replacement
                }
                if let replacement { output.removeLast(token.count); output += replacement }
            }
            output += text; token = ""; suppressed = false
        }
    }
    return output
}
let mode = CommandLine.arguments[1]
let dictionaryEN = SystemDictionary.shared.contains("hello", language: .english)
let dictionaryRU = SystemDictionary.shared.contains("мир", language: .russian)
print("system en hello=\(dictionaryEN) ru мир=\(dictionaryRU)")
if mode == "system" && (!dictionaryEN || !dictionaryRU) {
    fputs("System dictionaries unavailable. This is not a valid system audit; previous results were preserved.\n", stderr)
    exit(2)
}
let file = URL(fileURLWithPath: CommandLine.arguments[2])
let cases = try JSONDecoder().decode([AuditCase].self, from: Data(contentsOf: file))
var results: [Result] = []
let start = Date()
for c in cases {
    let t = DispatchTime.now().uptimeNanoseconds
    let lang: Language = c.language == "russian" ? .russian : .english
    let actual: String
    switch c.kind {
    case "keep", "keep-exploratory", "layout": actual = engine.correction(for: c.input)?.replacement ?? c.input
    case "spell", "probe-spell": actual = engine.spellingSuggestion(for: c.input, language: lang) ?? c.input
    case "roundtrip": actual = engine.convert(engine.convert(c.input, to: lang.opposite), to: lang)
    case "stream": actual = stream(c.input, spelling: false)
    case "stream-auto-keep": actual = stream(c.input, spelling: true)
    default: _ = engine.correction(for: c.input); _ = engine.spellingSuggestion(for: c.input, language: lang); actual = c.input
    }
    let elapsed = Double(DispatchTime.now().uptimeNanoseconds-t)/1000
    results.append(Result(kind: c.kind, input: c.input, expected: c.expected, actual: actual, group: c.group, passed: actual == c.expected, microseconds: elapsed))
}
for s in ["helo Helo HELO ", "recieve Recieve RECIEVE ", "превет Превет ПРЕВЕТ ", "малако Малако МАЛАКО ", "helo, Helo. HELO! ", "[recieve] \"recieve\" 'recieve' ", "GitHub Docker Kubernetes TypeScript PostgreSQL "] {
    results.append(Result(kind:"stream-auto-probe",input:s,expected:"",actual:stream(s,spelling:true),group:"auto-correct",passed:false,microseconds:0))
}
let data = try JSONEncoder().encode(results)
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
print("mode=\(mode) cases=\(results.count) elapsed=\(Date().timeIntervalSince(start))s")
for k in Set(results.map(\.kind)).sorted() { let rows=results.filter{$0.kind==k}; if k.contains("probe") { print("\(k): \(rows.count) observations (no expected answer)") } else { print("\(k): \(rows.filter(\.passed).count)/\(rows.count)") } }
