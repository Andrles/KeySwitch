import Foundation

let word = CommandLine.arguments.dropFirst().first ?? "ghbdtn"
let start = DispatchTime.now().uptimeNanoseconds
let engine = LanguageEngine()
let constructed = DispatchTime.now().uptimeNanoseconds
let correction = engine.correction(for: word)
let corrected = DispatchTime.now().uptimeNanoseconds
let suggestion = correction == nil ? engine.spellingCorrection(for: word, automatic: false) : nil
let finished = DispatchTime.now().uptimeNanoseconds
let row: [String: Any] = [
    "input": word,
    "construction_ms": Double(constructed - start) / 1_000_000,
    "layout_ms": Double(corrected - constructed) / 1_000_000,
    "spelling_ms": Double(finished - corrected) / 1_000_000,
    "total_ms": Double(finished - start) / 1_000_000,
    "replacement": correction?.replacement ?? suggestion?.replacement ?? word,
    // Probe only after measuring: prewarming the spell service hides cold cost.
    "dictionary_en": SystemDictionary.shared.contains("hello", language: .english),
    "dictionary_ru": SystemDictionary.shared.contains("мир", language: .russian)
]
let data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
print(String(decoding: data, as: UTF8.self))
