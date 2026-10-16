import AppKit

final class SpellingIndicator {
    private let panel: NSPanel
    private let label = NSTextField(wrappingLabelWithString: "")
    private let stack = NSStackView()
    private let hint = NSTextField(wrappingLabelWithString: "")
    private var word = ""
    private var dismissal: DispatchWorkItem?
    private let actions = NSStackView()
    private let ignoreButton = NSButton(title: "Не предлагать", target: nil, action: nil)
    private let undoButton = NSButton(title: "Отменить исключение", target: nil, action: nil)
    var onUndoIgnore: ((String) -> Void)?
    var isVisible: Bool { panel.isVisible }
    var onApply: (() -> Void)?
    var onIgnore: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 132),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        let background = MaterialSurface(role: .popover)
        panel.contentView = background
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: background.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -14)
        ])
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .labelColor
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        stack.addArrangedSubview(label)
        label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .labelColor
        hint.setContentCompressionResistancePriority(.required, for: .vertical)
        stack.addArrangedSubview(hint)
        hint.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        actions.orientation = .horizontal
        actions.spacing = 10
        let replace = NSButton(title: "Заменить", target: self, action: #selector(apply))
        replace.bezelStyle = .rounded
        replace.keyEquivalent = ""
        actions.addArrangedSubview(replace)
        actions.addArrangedSubview(NSButton(title: "Пропустить", target: self, action: #selector(dismiss)))
        stack.addArrangedSubview(actions)
        ignoreButton.target = self; ignoreButton.action = #selector(ignoreWord)
        ignoreButton.bezelStyle = .rounded
        ignoreButton.font = .systemFont(ofSize: 12)
        ignoreButton.toolTip = "Больше не предлагать исправление этого слова"
        ignoreButton.setAccessibilityLabel("Больше не предлагать это слово")
        ignoreButton.isBordered = false
        actions.addArrangedSubview(ignoreButton)
        undoButton.target = self; undoButton.action = #selector(undoIgnore)
        undoButton.isHidden = true
        stack.addArrangedSubview(undoButton)
    }

    func show(word: String, suggestion: String, screen: NSScreen? = nil) {
        dismissal?.cancel()
        self.word = word
        actions.isHidden = false; ignoreButton.isHidden = false; undoButton.isHidden = true
        hint.stringValue = Preferences.shared.shiftLayoutOnly
            ? "Заменить можно до следующего ввода. Esc — пропустить."
            : "Двойной Shift — заменить. Esc — пропустить."
        label.stringValue = "\(word) → \(suggestion)"
        layout(screen: screen)
        announce(label.stringValue + ". " + hint.stringValue)
    }

    private func layout(screen: NSScreen? = nil) {
        resizeToContent()
        if let frame = (screen ?? NSScreen.main)?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.maxX - panel.frame.width - 18,
                                         y: frame.maxY - panel.frame.height - 18))
        }
        panel.orderFrontRegardless()
    }

    private func resizeToContent() {
        let top = panel.frame.maxY
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.setContentSize(NSSize(width: 380, height: max(132, stack.fittingSize.height + 28)))
        panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: top - panel.frame.height))
        panel.contentView?.layoutSubtreeIfNeeded()
    }

    private func announce(_ message: String) {
        NSAccessibility.post(element: panel, notification: .announcementRequested,
                             userInfo: [.announcement: message,
                                        .priority: NSAccessibilityPriorityLevel.medium.rawValue])
    }

    func contains(eventPoint: CGPoint) -> Bool {
        guard panel.isVisible else { return false }
        let point = NSPoint(x: eventPoint.x,
                            y: (NSScreen.screens.first?.frame.maxY ?? 0) - eventPoint.y)
        return panel.frame.contains(point)
    }

    func hide() {
        dismissal?.cancel(); dismissal = nil
        panel.orderOut(nil)
        word = ""
        label.stringValue = ""
    }

    @objc private func apply() { onApply?() }

    func showResult(applied: Bool) {
        label.stringValue = applied ? "Слово заменено" : "Не удалось подтвердить замену"
        hint.stringValue = applied ? "Продолжайте печатать." : "Проверьте текст. Если слово не исправлено, повторите ввод или используйте ручную замену."
        actions.isHidden = true; ignoreButton.isHidden = true; undoButton.isHidden = true
        resizeToContent()
        announce(label.stringValue + ". " + hint.stringValue)
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        dismissal?.cancel(); dismissal = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (applied ? 2 : 6), execute: work)
    }

    @objc private func ignoreWord() {
        onIgnore?(word)
        label.stringValue = "«\(word)» добавлено в исключения"
        hint.stringValue = "KeySwitch больше не предлагает исправлять это слово."
        actions.isHidden = true; ignoreButton.isHidden = true; undoButton.isHidden = false
        resizeToContent()
        announce(label.stringValue + ". Можно отменить исключение.")
    }

    @objc private func undoIgnore() {
        onUndoIgnore?(word)
        label.stringValue = "Исключение отменено"
        hint.stringValue = "Слово снова проверяется при следующем вводе."
        undoButton.isHidden = true
        resizeToContent()
        announce(label.stringValue + ". " + hint.stringValue)
    }

    @objc private func dismiss() {
        onDismiss?()
        hide()
    }
}
