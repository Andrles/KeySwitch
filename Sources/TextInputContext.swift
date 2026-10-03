import AppKit
import ApplicationServices
import Carbon

/// A short-lived identity, never a document history. Unsupported or secure
/// fields fail closed: do not synthesize destructive input into them.
struct TextInputContext {
    let processID: pid_t
    let element: AXUIElement
    let selection: NSRange
    let inputSourceID: String

    static func current() -> TextInputContext? {
        guard !IsSecureEventInputEnabled(),
              let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.02)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString,
                                           &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.02)
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        guard (subrole as? String) != "AXSecureTextField" else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString,
                                           &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range),
              range.location >= 0, range.length == 0 else { return nil }
        return TextInputContext(processID: app.processIdentifier, element: element,
                                selection: NSRange(location: range.location, length: range.length),
                                inputSourceID: InputSourceController.currentIdentifier())
    }

    func isSameField(as other: TextInputContext) -> Bool {
        processID == other.processID && CFEqual(element, other.element)
            && inputSourceID == other.inputSourceID
    }

    func verifies(_ suffix: VerifiedTextSuffix) -> Bool {
        guard let range = suffix.range else { return false }
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else { return false }
        var value: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element, kAXStringForRangeParameterizedAttribute as CFString, rangeValue, &value)
        if result == .success {
            return suffix.matches(selection: selection, actual: value as? String)
        }
        // Text fields may expose AXValue but no AXStringForRange. Never retain
        // the returned document; inspect only a bounded value during preflight.
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
              let string = value as? String else { return false }
        let text = string as NSString
        guard text.length <= 100_000, NSMaxRange(range) <= text.length else { return false }
        return suffix.matches(selection: selection, actual: text.substring(with: range))
    }
}
