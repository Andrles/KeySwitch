import AppKit
import ApplicationServices
import Carbon

/// No clipboard, deletion events or document history. Unsupported fields are skipped.
enum SelectionEditor {
    static func perform(_ command: ManualCommand) -> Bool {
        guard AXIsProcessTrusted(), !IsSecureEventInputEnabled(),
              let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let id = app.bundleIdentifier, !Preferences.shared.excludesApplication(id) else { return false }
        let sourceID = InputSourceController.currentIdentifier()
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.02)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return false }
        let field = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(field, 0.02)
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(field, kAXSubroleAttribute as CFString, &subrole)
        guard subrole as? String != "AXSecureTextField" else { return false }
        var selected: CFTypeRef?
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(field, kAXSelectedTextAttribute as CFString, &selected) == .success,
              let text = selected as? String,
              AXUIElementCopyAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return false }
        var range = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range), range.location >= 0,
              range.length == text.utf16.count, range.length > 0,
              let result = SelectedTextTransform.apply(command, to: text), result != text else { return false }
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(field, kAXSelectedTextAttribute as CFString, &settable) == .success,
              settable.boolValue, !IsSecureEventInputEnabled(),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
              InputSourceController.currentIdentifier() == sourceID else { return false }
        var freshFocus: CFTypeRef?
        var freshText: CFTypeRef?
        var freshRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &freshFocus) == .success,
              let freshFocus, CFEqual(freshFocus, field),
              AXUIElementCopyAttributeValue(field, kAXSelectedTextAttribute as CFString, &freshText) == .success,
              freshText as? String == text,
              AXUIElementCopyAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, &freshRange) == .success,
              let freshRange, CFEqual(freshRange, rangeValue) else { return false }
        let applied = AXUIElementSetAttributeValue(field, kAXSelectedTextAttribute as CFString, result as CFString) == .success
        if applied, command == .layout, let language = LanguageEngine().forcedConversion(text)?.language {
            InputSourceController.select(language: language)
        }
        return applied
    }
}
