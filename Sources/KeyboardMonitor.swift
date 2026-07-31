import AppKit
import ApplicationServices
import Carbon

final class KeyboardMonitor {
    static let shared = KeyboardMonitor()

    private let engine = LanguageEngine()
    private let preferences = Preferences.shared
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var currentWord = ""
    private var lastShiftRelease: TimeInterval = 0
    private let injectedMarker: Int64 = 0x5241534B

    var onCorrection: ((Language) -> Void)?
    var onSpellingIssue: ((String, String) -> Void)?
    var onPermissionChanged: ((Bool) -> Void)?

    private init() {}

    var isTrusted: Bool { AXIsProcessTrusted() }
    var isRunning: Bool { eventTap != nil }

    func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        onPermissionChanged?(isTrusted)
    }

    func start() {
        guard eventTap == nil else { return }
        let mask = (1 << CGEventType.keyDown.rawValue) |
                   (1 << CGEventType.flagsChanged.rawValue)
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            },
            userInfo: pointer
        )
        guard let eventTap else {
            onPermissionChanged?(false)
            return
        }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        onPermissionChanged?(true)
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap { CFMachPortInvalidate(eventTap) }
        runLoopSource = nil
        eventTap = nil
        currentWord = ""
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == injectedMarker {
            return Unmanaged.passUnretained(event)
        }
        guard preferences.enabled, !frontmostAppIsExcluded() else {
            currentWord = ""
            return Unmanaged.passUnretained(event)
        }

        if type == .flagsChanged {
            handleShift(event)
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            currentWord = ""
            return Unmanaged.passUnretained(event)
        }
        if keyCode == 51 {
            if !currentWord.isEmpty { currentWord.removeLast() }
            return Unmanaged.passUnretained(event)
        }
        if [123, 124, 125, 126, 115, 119, 116, 121].contains(keyCode) {
            currentWord = ""
            return Unmanaged.passUnretained(event)
        }

        let text = unicodeString(from: event)
        guard !text.isEmpty else { return Unmanaged.passUnretained(event) }
        if KeyboardTokenClassifier.continuesWord(text) {
            currentWord += text
            return Unmanaged.passUnretained(event)
        }

        if let correction = layoutCorrection(for: currentWord) {
            replaceTypedText(correction, boundaryEvent: event)
            currentWord = ""
            return nil
        }

        let spellingParts = splitTrailingPunctuation(from: currentWord)
        if preferences.spellChecking,
           !preferences.ignoredWords.contains(spellingParts.word.lowercased()),
           let language = engine.detectedLanguage(for: spellingParts.word),
           let suggestion = engine.spellingSuggestion(for: spellingParts.word,
                                                       language: language) {
            if preferences.spellAutoCorrect {
                let correction = Correction(
                    original: currentWord,
                    replacement: suggestion + spellingParts.trailing,
                    language: language
                )
                replaceTypedText(correction, boundaryEvent: event)
                currentWord = ""
                return nil
            }
            DispatchQueue.main.async { [weak self] in
                self?.onSpellingIssue?(spellingParts.word, suggestion)
            }
        }

        if let language = engine.detectedLanguage(for: spellingParts.word) {
            InputSourceController.select(language: language)
        }
        currentWord = ""
        return Unmanaged.passUnretained(event)
    }

    private func handleShift(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == 56 || keyCode == 60, !event.flags.contains(.maskShift) else { return }
        let now = ProcessInfo.processInfo.systemUptime
        defer { lastShiftRelease = now }
        guard now - lastShiftRelease < 0.36,
              let correction = engine.forcedConversion(currentWord) else { return }
        replaceTypedText(correction)
        currentWord = correction.replacement
        lastShiftRelease = 0
    }

    private func replaceTypedText(_ correction: Correction, boundaryEvent: CGEvent? = nil) {
        let plan = KeyboardReplacementPlan(
            correction: correction,
            replayBoundary: boundaryEvent != nil
        )
        for step in plan.steps {
            switch step {
            case .backspace:
                postKey(code: 51)
            case let .insert(text):
                postText(text)
            case .replayBoundary:
                if let boundaryEvent { postEvent(boundaryEvent) }
            }
        }
        InputSourceController.select(language: correction.language)
        preferences.correctionCount += 1
        if preferences.playSound { NSSound.beep() }
        DispatchQueue.main.async { [weak self] in
            self?.onCorrection?(correction.language)
        }
    }

    private func postKey(code: CGKeyCode) {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) else { return }
        down.setIntegerValueField(.eventSourceUserData, value: injectedMarker)
        up.setIntegerValueField(.eventSourceUserData, value: injectedMarker)
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }

    private func postText(_ text: String) {
        let units = Array(text.utf16)
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else { return }
        down.setIntegerValueField(.eventSourceUserData, value: injectedMarker)
        up.setIntegerValueField(.eventSourceUserData, value: injectedMarker)
        down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }

    private func postEvent(_ event: CGEvent) {
        guard let replay = event.copy() else { return }
        replay.setIntegerValueField(.eventSourceUserData, value: injectedMarker)
        replay.post(tap: .cgSessionEventTap)
    }

    private func unicodeString(from event: CGEvent) -> String {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: buffer.count,
                                       actualStringLength: &length,
                                       unicodeString: &buffer)
        return String(utf16CodeUnits: buffer, count: length)
    }

    private func frontmostAppIsExcluded() -> Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        return preferences.excludedApps.contains { bundleID == $0 || bundleID.hasPrefix($0) }
    }

    private func layoutCorrection(for token: String) -> Correction? {
        engine.correction(for: token, ignored: preferences.ignoredWords)
    }

    private func splitTrailingPunctuation(from token: String) -> (word: String, trailing: String) {
        let punctuation = "`[];,.~{}:\"<>"
        var word = token
        var trailing = ""
        while let last = word.last, punctuation.contains(last) {
            trailing.insert(last, at: trailing.startIndex)
            word.removeLast()
        }
        return (word, trailing)
    }
}
