import AppKit

/// A non-activating notice preserves the editor's focus and selection.
final class ManualFeedback {
    static let shared = ManualFeedback()
    private var panel: NSPanel?
    private var dismissal: DispatchWorkItem?
    func show(_ message: String) {
        dismissal?.cancel(); panel?.orderOut(nil)
        let notice = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 104), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        notice.level = .floating; notice.isReleasedWhenClosed = false; notice.hidesOnDeactivate = false
        notice.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let text = NSTextField(wrappingLabelWithString: message); text.font = .systemFont(ofSize: 14); text.textColor = .labelColor
        text.translatesAutoresizingMaskIntoConstraints = false
        notice.contentView?.addSubview(text)
        if let view = notice.contentView {
            NSLayoutConstraint.activate([text.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18), text.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18), text.topAnchor.constraint(equalTo: view.topAnchor, constant: 18), text.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -18)])
        }
        let frame = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        notice.setFrameOrigin(NSPoint(x: frame.midX - 220, y: frame.maxY - 124))
        panel = notice; notice.orderFrontRegardless()
        NSAccessibility.post(element: text, notification: .announcementRequested, userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue])
        let work = DispatchWorkItem { [weak self, weak notice] in notice?.orderOut(nil); self?.panel = nil }
        dismissal = work; DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
    }
}
