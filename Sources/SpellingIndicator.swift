import AppKit

final class SpellingIndicator {
    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")
    private var hideWorkItem: DispatchWorkItem?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear

        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.borderWidth = 1
        background.layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.8).cgColor
        background.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = background

        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: background.centerYAnchor)
        ])
    }

    func show(word: String, suggestion: String) {
        hideWorkItem?.cancel()
        label.stringValue = "Опечатка: \(word)  →  \(suggestion)"

        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main
        if let visibleFrame = screen?.visibleFrame {
            let origin = NSPoint(
                x: visibleFrame.maxX - panel.frame.width - 18,
                y: visibleFrame.maxY - panel.frame.height - 18
            )
            panel.setFrameOrigin(origin)
        }
        panel.orderFrontRegardless()

        let workItem = DispatchWorkItem { [weak self] in
            self?.panel.orderOut(nil)
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: workItem)
    }
}
