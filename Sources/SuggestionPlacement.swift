import AppKit

/// Stable top-right placement within the editor display's usable area.
enum SuggestionPlacement {
    static func frame(size: NSSize, visibleFrame: NSRect) -> NSRect {
        let area = visibleFrame.insetBy(dx: 12, dy: 12)
        let width = min(size.width, area.width)
        let height = min(size.height, area.height)
        return NSRect(x: area.maxX - width, y: area.maxY - height, width: width, height: height)
    }
}
