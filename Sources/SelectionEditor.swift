import AppKit
import ApplicationServices
import Carbon

/// No clipboard, deletion events or document history. Unsupported fields are skipped.
enum SelectionEditor {
    static func perform(_ command: ManualCommand) -> Bool { performResult(command) == .success }

    static func performResult(_ command: ManualCommand) -> ManualEditResult {
        guard AXIsProcessTrusted() else { return .permission }
        guard !IsSecureEventInputEnabled() else { return .secure }
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let id = app.bundleIdentifier else { return .unsupported }
        guard !Preferences.shared.excludesApplication(id) else { return .excluded }
        let sourceID = InputSourceController.currentIdentifier()
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.02)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return .unsupported }
        let field = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(field, 0.02)
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(field, kAXSubroleAttribute as CFString, &subrole)
        guard subrole as? String != "AXSecureTextField" else { return .secure }
        var selected: CFTypeRef?
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(field, kAXSelectedTextAttribute as CFString, &selected) == .success,
              let text = selected as? String,
              AXUIElementCopyAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return .unsupported }
        var range = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range), range.location >= 0,
              range.length == text.utf16.count else { return .unsupported }
        guard range.length > 0 else { return .noSelection }
        guard text.utf16.count <= 4096 else { return .tooLong }
        guard let result = SelectedTextTransform.apply(command, to: text), result != text else { return .unchanged }
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(field, kAXSelectedTextAttribute as CFString, &settable) == .success,
              settable.boolValue, !IsSecureEventInputEnabled(),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
              InputSourceController.currentIdentifier() == sourceID else { return .unsupported }
        var freshFocus: CFTypeRef?
        var freshText: CFTypeRef?
        var freshRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &freshFocus) == .success,
              let freshFocus, CFEqual(freshFocus, field),
              AXUIElementCopyAttributeValue(field, kAXSelectedTextAttribute as CFString, &freshText) == .success,
              freshText as? String == text,
              AXUIElementCopyAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, &freshRange) == .success,
              let freshRange, CFEqual(freshRange, rangeValue) else { return .contextChanged }
        guard !IsSecureEventInputEnabled(), NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier, InputSourceController.currentIdentifier() == sourceID else { return .contextChanged }
        let applied = AXUIElementSetAttributeValue(field, kAXSelectedTextAttribute as CFString, result as CFString) == .success
        if applied, command == .layout, let language = LanguageEngine().forcedConversion(text)?.language {
            InputSourceController.select(language: language)
        }
        return applied ? .success : .unsupported
    }
}
