import Carbon
import Foundation

enum InputSourceController {
    private static var cachedSources: [Language: TISInputSource] = [:]

    static func select(language: Language) {
        guard currentLanguage() != language else { return }
        if let cached = cachedSources[language] {
            TISSelectInputSource(cached)
            return
        }
        guard let source = findSource(for: language) else { return }
        cachedSources[language] = source
        TISSelectInputSource(source)
    }

    static func currentLanguage() -> Language? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return language(of: source)
    }

    private static func findSource(for language: Language) -> TISInputSource? {
        let filters: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource!,
            kTISPropertyInputSourceIsSelectCapable: true
        ]
        guard let sources = TISCreateInputSourceList(filters as CFDictionary, false)?
            .takeRetainedValue() as? [TISInputSource] else { return nil }

        for source in sources {
            if self.language(of: source) == language { return source }
        }
        return nil
    }

    private static func language(of source: TISInputSource) -> Language? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else {
            return nil
        }
        let values = Unmanaged<CFArray>.fromOpaque(pointer).takeUnretainedValue() as NSArray
        let languages = values.compactMap { $0 as? String }.map { $0.lowercased() }
        if languages.contains(where: { $0.hasPrefix("ru") }) { return .russian }
        if languages.contains(where: { $0.hasPrefix("en") }) { return .english }
        return nil
    }
}
