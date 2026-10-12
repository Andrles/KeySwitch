import AppKit
import ApplicationServices
import Carbon

struct AXSuffixEditor: SuffixEditingBackend {
    let context: TextInputContext
    var canReplace: Bool {
        [kAXSelectedTextAttribute, kAXSelectedTextRangeAttribute].allSatisfy { attribute in
            var settable = DarwinBoolean(false)
            return AXUIElementIsAttributeSettable(context.element, attribute as CFString, &settable) == .success && settable.boolValue
        }
    }
    var contextIsCurrent: Bool {
        guard AXIsProcessTrusted(), !IsSecureEventInputEnabled(),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == context.processID,
              InputSourceController.currentIdentifier() == context.inputSourceID else { return false }
        let application = AXUIElementCreateApplication(context.processID)
        AXUIElementSetMessagingTimeout(application, 0.02)
        var focused: CFTypeRef?
        return AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focused) == .success
            && focused.map { CFEqual($0, context.element) } == true
    }
    func selection() -> NSRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(context.element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range), range.location >= 0, range.length >= 0 else { return nil }
        return NSRange(location: range.location, length: range.length)
    }
    func text(in range: NSRange) -> String? { context.text(in: range) }
    func select(_ range: NSRange) -> Bool {
        var range = CFRange(location: range.location, length: range.length)
        guard let value = AXValueCreate(.cfRange, &range) else { return false }
        return AXUIElementSetAttributeValue(context.element, kAXSelectedTextRangeAttribute as CFString, value) == .success
    }
    func replaceSelection(with text: String) -> Bool {
        AXUIElementSetAttributeValue(context.element, kAXSelectedTextAttribute as CFString, text as CFString) == .success
    }
}
