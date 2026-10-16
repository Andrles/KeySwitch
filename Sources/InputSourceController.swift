import Carbon
import Foundation

enum InputSourceController {

    static func currentIdentifier() -> String {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return "" }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    @discardableResult
    static func select(language: Language) -> InputSourceSelectionResult {
        InputSourceSelection.select(language: language,
            currentLanguage: currentLanguage,
            findSource: findSource,
            apply: { TISSelectInputSource($0) })
    }

    static func currentLanguage() -> Language? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return language(of: source)
    }

    private static func findSource(for language: Language) -> TISInputSource? {
        let filters: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource!,
            kTISPropertyInputSourceIsSelectCapable: true,
            kTISPropertyInputSourceIsEnabled: true
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

/// Text replacement and system input-source selection are separate operations.
/// Never repeat an already-applied text edit just because macOS refused a switch.
enum InputSourceSelectionResult: Equatable {
    case selected, alreadySelected, unavailable, rejected(Int32), unconfirmed
    var succeeded: Bool { self == .selected || self == .alreadySelected }
}

enum InputSourceSelection {
    static func select<Source>(language: Language,
                               currentLanguage: () -> Language?,
                               findSource: (Language) -> Source?,
                               apply: (Source) -> Int32) -> InputSourceSelectionResult {
        guard currentLanguage() != language else { return .alreadySelected }
        // Enumerate enabled sources afresh: users can remove a layout while the
        // application is running. A stale cached TISInputSource is not reusable.
        guard let source = findSource(language) else { return .unavailable }
        let status = apply(source)
        guard status == 0 else { return .rejected(status) }
        return currentLanguage() == language ? .selected : .unconfirmed
    }
}
