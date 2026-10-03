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
    private var wordContext: TextInputContext?
    private var expectedCaret: Int?
    private var suppressToken = false
    private var retryPolicy = MonitorRetryPolicy()
    private struct PendingEdit {
        let context: TextInputContext
        let suffix: VerifiedTextSuffix
        let replacement: String
        let language: Language?
        let expires: TimeInterval
    }
    private var feedbackGeneration = 0
    private var undoGeneration = 0
    private var lastCorrection: PendingEdit?
    private var pendingSuggestion: PendingEdit?
    private let injectedMarker: Int64 = 0x5241534B

    var onCorrection: ((Language) -> Void)?
    var onSpellingIssue: ((String, String) -> Void)?
    var preservesFeedbackAtPoint: ((CGPoint) -> Bool)?
    var onFeedbackInvalidated: (() -> Void)?
    var onPermissionChanged: ((Bool) -> Void)?

    private init() {}

    var isTrusted: Bool { AXIsProcessTrusted() }
    var isRunning: Bool {
        eventTap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false
    }
    var state: MonitorState {
        MonitorState.resolve(enabled: preferences.enabled, trusted: isTrusted, running: isRunning)
    }

    func invalidateContext() {
        feedbackGeneration += 1
        currentWord = ""
        wordContext = nil
        expectedCaret = nil
        lastShiftRelease = 0
        suppressToken = false
        lastCorrection = nil
        pendingSuggestion = nil
        onFeedbackInvalidated?()
    }

    func resetRetry() { retryPolicy.reset() }

    func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        onPermissionChanged?(isTrusted)
    }

    func start() {
        guard isTrusted,
              retryPolicy.allowsAttempt(at: ProcessInfo.processInfo.systemUptime) else { return }
        if let eventTap {
            guard !isRunning else { return }
            CGEvent.tapEnable(tap: eventTap, enable: true)
            if isRunning { retryPolicy.reset() }
            else { retryPolicy.recordFailure(at: ProcessInfo.processInfo.systemUptime) }
            return
        }
        let mask = (1 << CGEventType.keyDown.rawValue) |
                   (1 << CGEventType.flagsChanged.rawValue) |
                   (1 << CGEventType.leftMouseDown.rawValue) |
                   (1 << CGEventType.rightMouseDown.rawValue) |
                   (1 << CGEventType.otherMouseDown.rawValue) |
                   (1 << CGEventType.scrollWheel.rawValue)
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
            retryPolicy.recordFailure(at: ProcessInfo.processInfo.systemUptime)
            // The timer owns retries. Calling pollPermission here would recurse.
            return
        }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        retryPolicy.reset()
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap { CFMachPortInvalidate(eventTap) }
        runLoopSource = nil
        eventTap = nil
        invalidateContext()
        retryPolicy.reset()
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            invalidateContext()
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == injectedMarker {
            return Unmanaged.passUnretained(event)
        }
        if [.leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel].contains(type) {
            if preservesFeedbackAtPoint?(event.location) != true { invalidateContext() }
            return Unmanaged.passUnretained(event)
        }
        guard preferences.enabled, !frontmostAppIsExcluded(),
              let context = TextInputContext.current() else {
            invalidateContext()
            return Unmanaged.passUnretained(event)
        }

        if let wordContext, !wordContext.isSameField(as: context) {
            invalidateContext()
        }
        if type == .flagsChanged {
            handleShift(event)
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        feedbackGeneration += 1
        lastShiftRelease = 0
        lastCorrection = nil
        pendingSuggestion = nil
        onFeedbackInvalidated?()
        if let expectedCaret, context.selection.location != expectedCaret {
            invalidateContext()
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            invalidateContext()
            return Unmanaged.passUnretained(event)
        }
        if keyCode == 51 {
            if let last = currentWord.last {
                currentWord.removeLast()
                expectedCaret = max(0, context.selection.location - String(last).utf16.count)
            }
            return Unmanaged.passUnretained(event)
        }
        if KeyboardTokenClassifier.isNavigationKey(keyCode) {
            invalidateContext()
            return Unmanaged.passUnretained(event)
        }

        let text = keyCode == 48 ? "\t" : unicodeString(from: event)
        guard !text.isEmpty else { return Unmanaged.passUnretained(event) }
        if KeyboardTokenClassifier.continuesWord(text) {
            guard !suppressToken else { return Unmanaged.passUnretained(event) }
            guard currentWord.count + text.count <= 64 else {
                invalidateContext()
                suppressToken = true
                return Unmanaged.passUnretained(event)
            }
            wordContext = context
            currentWord += text
            expectedCaret = context.selection.location + text.utf16.count
            return Unmanaged.passUnretained(event)
        }

        guard !suppressToken else {
            invalidateContext()
            return Unmanaged.passUnretained(event)
        }
        if KeyboardTokenClassifier.isTechnicalBoundary(text) {
            invalidateContext()
            return Unmanaged.passUnretained(event)
        }
        if let correction = layoutCorrection(for: currentWord),
           replaceTypedText(correction, boundaryEvent: event) {
            currentWord = ""
            wordContext = nil
            expectedCaret = nil
            return nil
        }

        let spellingParts = TextToken(currentWord)
        let spellingMode = preferences.spellingMode
        if spellingMode != .off,
           !preferences.ignoredWords.contains(spellingParts.word.lowercased()) {
            let automatic = spellingMode == .autoCorrect
                ? engine.spellingCorrection(for: currentWord, automatic: true) : nil
            if let automatic, replaceTypedText(automatic, boundaryEvent: event) {
                currentWord = ""
                wordContext = nil
                expectedCaret = nil
                return nil
            }
            // Uncertain guesses remain hints even in automatic mode.
            if let hint = engine.spellingCorrection(for: currentWord, automatic: false) {
                let suffix = currentWord + text
                if context.verifies(VerifiedTextSuffix(text: currentWord, caret: context.selection.location)) {
                    pendingSuggestion = PendingEdit(context: context,
                        suffix: VerifiedTextSuffix(text: suffix, caret: context.selection.location + text.utf16.count),
                        replacement: hint.replacement + text, language: hint.language,
                        expires: .infinity)
                    let generation = feedbackGeneration
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.feedbackGeneration == generation,
                              self.pendingSuggestion != nil else { return }
                        self.onSpellingIssue?(spellingParts.word, TextToken(hint.replacement).word)
                    }
                }
            }
        }

        currentWord = ""
        expectedCaret = nil
        return Unmanaged.passUnretained(event)
    }

    private func handleShift(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == 56 || keyCode == 60,
              !event.flags.contains(.maskShift),
              event.flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if lastShiftRelease > 0, now - lastShiftRelease < 0.36 {
            lastShiftRelease = 0
            if pendingSuggestion != nil { _ = acceptSuggestion(); return }
            if lastCorrection != nil { _ = restoreLastCorrection(); return }
            if let correction = engine.forcedConversion(currentWord), replaceTypedText(correction) {
                currentWord = ""
                wordContext = nil
                expectedCaret = nil
                suppressToken = true
            }
        } else {
            lastShiftRelease = now
        }
    }

    @discardableResult
    func acceptSuggestion() -> Bool {
        guard let edit = pendingSuggestion else { return false }
        pendingSuggestion = nil
        onFeedbackInvalidated?()
        return performPendingEdit(edit, keepUndo: true)
    }

    @discardableResult
    func restoreLastCorrection() -> Bool {
        guard let edit = lastCorrection else { return false }
        lastCorrection = nil
        return performPendingEdit(edit, keepUndo: false)
    }

    func ignoreSuggestion(word: String) {
        preferences.ignoredWords.insert(word.lowercased())
        pendingSuggestion = nil
    }

    func dismissSuggestion() { pendingSuggestion = nil }

    private func performPendingEdit(_ edit: PendingEdit, keepUndo: Bool) -> Bool {
        guard preferences.enabled, !frontmostAppIsExcluded(),
              ProcessInfo.processInfo.systemUptime <= edit.expires,
              let context = TextInputContext.current(), context.isSameField(as: edit.context),
              context.verifies(edit.suffix) else { return false }
        let language = edit.language ?? InputSourceController.currentLanguage() ?? .english
        let correction = Correction(original: edit.suffix.text, replacement: edit.replacement, language: language)
        guard replaceTypedText(correction, verifiedContext: context, keepUndo: keepUndo) else { return false }
        currentWord = ""
        wordContext = nil
        expectedCaret = nil
        return true
    }

    @discardableResult
    private func replaceTypedText(_ correction: Correction, boundaryEvent: CGEvent? = nil,
                                  verifiedContext: TextInputContext? = nil, keepUndo: Bool = true) -> Bool {
        guard let context = verifiedContext ?? TextInputContext.current(),
              verifiedContext != nil || wordContext.map({ context.isSameField(as: $0) }) == true,
              context.verifies(VerifiedTextSuffix(text: correction.original, caret: context.selection.location)) else {
            return false
        }
        let oldLanguage = InputSourceController.currentLanguage()
        let boundary = boundaryEvent.map(unicodeString(from:)) ?? ""
        // Enter/Tab changes editor context, so only plain separators support undo.
        let canUndo = !boundary.contains("\n") && !boundary.contains("\r") && !boundary.contains("\t")
        let plan = KeyboardReplacementPlan(correction: correction, replayBoundary: boundaryEvent != nil)
        // Allocate the whole burst before deleting anything. Allocation failure
        // must preserve the user's boundary event and original text.
        var events: [CGEvent] = []
        for step in plan.steps {
            switch step {
            case .backspace:
                guard let pair = keyEvents(code: 51) else { return false }
                events.append(contentsOf: pair)
            case let .insert(text):
                guard let pair = textEvents(text) else { return false }
                events.append(contentsOf: pair)
            case .replayBoundary:
                guard let replay = boundaryEvent?.copy() else { return false }
                events.append(replay)
            }
        }
        // Recheck after linguistic work and allocation, just before posting.
        guard let fresh = TextInputContext.current(), fresh.isSameField(as: context),
              fresh.verifies(VerifiedTextSuffix(text: correction.original, caret: context.selection.location)) else {
            return false
        }
        for event in events {
            event.setIntegerValueField(.eventSourceUserData, value: injectedMarker)
            event.postToPid(context.processID)
        }
        InputSourceController.select(language: correction.language)
        if keepUndo { preferences.correctionCount += 1 }
        if keepUndo && canUndo {
            // Source changes are intentional here; save the expected new source.
            let undoContext = TextInputContext(processID: context.processID, element: context.element,
                selection: context.selection, inputSourceID: InputSourceController.currentIdentifier())
            undoGeneration += 1
            let generation = undoGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                guard let self, self.undoGeneration == generation else { return }
                self.lastCorrection = nil
            }
            lastCorrection = PendingEdit(context: undoContext,
                suffix: VerifiedTextSuffix(text: correction.replacement + boundary,
                    caret: context.selection.location - correction.original.utf16.count
                        + correction.replacement.utf16.count + boundary.utf16.count),
                replacement: correction.original + boundary, language: oldLanguage,
                expires: ProcessInfo.processInfo.systemUptime + 15)
        }
        if preferences.playSound && keepUndo { NSSound.beep() }
        DispatchQueue.main.async { [weak self] in self?.onCorrection?(correction.language) }
        return true
    }

    private func keyEvents(code: CGKeyCode) -> [CGEvent]? {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) else { return nil }
        return [down, up]
    }

    private func textEvents(_ text: String) -> [CGEvent]? {
        let units = Array(text.utf16)
        guard let pair = keyEvents(code: 0) else { return nil }
        for event in pair { event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units) }
        return pair
    }

    private func unicodeString(from event: CGEvent) -> String {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: buffer.count,
                                       actualStringLength: &length,
                                       unicodeString: &buffer)
        guard length >= 0, length <= buffer.count else { return "" }
        return String(utf16CodeUnits: buffer, count: length)
    }

    private func frontmostAppIsExcluded() -> Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        return preferences.excludedApps.contains { bundleID == $0 || bundleID.hasPrefix($0) }
    }

    private func layoutCorrection(for token: String) -> Correction? {
        engine.correction(for: token, ignored: preferences.ignoredWords)
    }

}
