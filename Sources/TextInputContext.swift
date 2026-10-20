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

    enum Unavailability: String {
        case secureInput, noExternalApplication, focusedElement, secureField, selection, nonCaretSelection
    }

    static func current(onFailure: ((Unavailability) -> Void)? = nil) -> TextInputContext? {
        guard !IsSecureEventInputEnabled() else { onFailure?(.secureInput); return nil }
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            onFailure?(.noExternalApplication); return nil
        }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.02)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString,
                                           &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            onFailure?(.focusedElement); return nil
        }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.02)
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        guard (subrole as? String) != "AXSecureTextField" else { onFailure?(.secureField); return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString,
                                           &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { onFailure?(.selection); return nil }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range), range.location >= 0 else {
            onFailure?(.selection); return nil
        }
        guard range.length == 0 else { onFailure?(.nonCaretSelection); return nil }
        return TextInputContext(processID: app.processIdentifier, element: element,
                                selection: NSRange(location: range.location, length: range.length),
                                inputSourceID: InputSourceController.currentIdentifier())
    }

    func isSameField(as other: TextInputContext) -> Bool {
        processID == other.processID && CFEqual(element, other.element)
            && inputSourceID == other.inputSourceID
    }

    var requiresCompleteAddressWord: Bool {
        let bundle = NSRunningApplication(processIdentifier: processID)?.bundleIdentifier
        guard bundle == "com.apple.Safari" else { return false }
        var identifier: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifier) == .success else { return false }
        return BrowserAddressFieldPolicy.requiresCompleteWord(bundleIdentifier: bundle,
            fieldIdentifier: identifier as? String)
    }

    var screen: NSScreen? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var position = CGPoint.zero
        guard AXValueGetValue(value as! AXValue, .cgPoint, &position) else { return nil }
        var sizeValue: CFTypeRef?
        var size = CGSize.zero
        if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
           let sizeValue, CFGetTypeID(sizeValue) == AXValueGetTypeID() {
            _ = AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        }
        // AX uses a top-left origin on the primary display; AppKit uses bottom-left.
        let point = NSPoint(x: position.x + size.width / 2,
                            y: (NSScreen.screens.first?.frame.maxY ?? 0) - position.y - size.height / 2)
        return NSScreen.screens.first { $0.frame.contains(point) }
    }

    func verifies(_ suffix: VerifiedTextSuffix) -> Bool {
        guard let range = suffix.range else { return false }
        return suffix.matches(selection: selection, actual: text(in: range))
    }

    func text(in range: NSRange) -> String? {
        guard range.location >= 0, range.length >= 0, range.length <= 4096,
              range.location <= Int.max - range.length else { return nil }
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else { return nil }
        var value: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element, kAXStringForRangeParameterizedAttribute as CFString, rangeValue, &value)
        if result == .success {
            return value as? String
        }
        // Text fields may expose AXValue but no AXStringForRange. Never retain
        // the returned document; inspect only a bounded value during preflight.
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
              let string = value as? String else { return nil }
        let text = string as NSString
        guard text.length <= 100_000, NSMaxRange(range) <= text.length else { return nil }
        return text.substring(with: range)
    }
}
