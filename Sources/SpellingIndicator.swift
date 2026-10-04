import AppKit

final class SpellingIndicator {
    private let panel: NSPanel
    private let label = NSTextField(wrappingLabelWithString: "")
    private let stack = NSStackView()
    private let hint = NSTextField(wrappingLabelWithString: "")
    private var word = ""
    var onApply: (() -> Void)?
    var onIgnore: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 144),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        panel.contentView = background
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: background.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -14)
        ])
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .labelColor
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        stack.addArrangedSubview(label)
        label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .secondaryLabelColor
        hint.setContentCompressionResistancePriority(.required, for: .vertical)
        stack.addArrangedSubview(hint)
        hint.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let actions = NSStackView()
        actions.orientation = .horizontal
        actions.spacing = 10
        actions.addArrangedSubview(NSButton(title: "Применить", target: self, action: #selector(apply)))
        actions.addArrangedSubview(NSButton(title: "Не исправлять это слово", target: self,
                                            action: #selector(ignoreWord)))
        actions.addArrangedSubview(NSButton(title: "Закрыть", target: self, action: #selector(dismiss)))
        stack.addArrangedSubview(actions)
    }

    func show(word: String, suggestion: String) {
        self.word = word
        let instruction = Preferences.shared.shiftLayoutOnly ? "Кнопка «Применить» — до следующего ввода." : "Двойной Shift — применить до следующего ввода."
        hint.stringValue = instruction + " Esc — закрыть. При смене поля замена отменяется."
        label.stringValue = "Возможная опечатка: \(word) → \(suggestion)"
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.setContentSize(NSSize(width: 420, height: max(144, stack.fittingSize.height + 28)))
        let screen = NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.maxX - panel.frame.width - 18,
                                         y: frame.maxY - panel.frame.height - 18))
        }
        panel.orderFrontRegardless()
        NSAccessibility.post(element: panel, notification: .announcementRequested,
                             userInfo: [.announcement: label.stringValue + ". " +
                                        hint.stringValue,
                                        .priority: NSAccessibilityPriorityLevel.medium.rawValue])
    }

    func contains(eventPoint: CGPoint) -> Bool {
        guard panel.isVisible else { return false }
        let point = NSPoint(x: eventPoint.x,
                            y: (NSScreen.screens.first?.frame.maxY ?? 0) - eventPoint.y)
        return panel.frame.contains(point)
    }

    func hide() {
        panel.orderOut(nil)
        word = ""
        label.stringValue = ""
    }

    @objc private func apply() { onApply?(); hide() }

    @objc private func ignoreWord() {
        onIgnore?(word)
        hide()
    }

    @objc private func dismiss() {
        onDismiss?()
        hide()
    }
}
