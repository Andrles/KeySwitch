import AppKit

final class SpellingIndicator: NSObject, NSMenuDelegate {
    private let panel: NSPanel
    private let title = NSTextField(wrappingLabelWithString: "Возможно, опечатка")
    private let label = NSTextField(wrappingLabelWithString: "")
    private let stack = NSStackView()
    private let hint = NSTextField(wrappingLabelWithString: "")
    private var word = ""
    private var dismissal: DispatchWorkItem?
    private let actions = NSStackView()
    private let more = NSPopUpButton(frame: .zero, pullsDown: true)
    private let undoButton = NSButton(title: "Отменить исключение", target: nil, action: nil)
    private var targetScreen: NSScreen?
    private(set) var isMenuOpen = false
    var onUndoIgnore: ((String) -> Void)?
    var isVisible: Bool { panel.isVisible }
    var onApply: (() -> Void)?
    var onIgnore: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    override init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 330, height: 170),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = true; panel.hidesOnDeactivate = false
        panel.isOpaque = false; panel.backgroundColor = .clear
        panel.setAccessibilityLabel("Подсказка KeySwitch")
        let background = MaterialSurface(role: .popover)
        panel.contentView = background
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -16)
        ])
        let header = NSStackView()
        header.orientation = .horizontal; header.alignment = .centerY; header.spacing = 8
        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.setContentCompressionResistancePriority(.required, for: .vertical)
        header.addArrangedSubview(title)
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(spacer)
        more.isBordered = false; more.bezelStyle = .inline
        (more.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
        more.setAccessibilityLabel("Другие действия со словом")
        more.toolTip = "Другие действия со словом"
        let menu = NSMenu(); menu.delegate = self
        menu.addItem(NSMenuItem(title: "•••", action: nil, keyEquivalent: ""))
        let ignore = NSMenuItem(title: "Не предлагать это слово", action: #selector(ignoreWord), keyEquivalent: "")
        ignore.target = self; menu.addItem(ignore); more.menu = menu
        header.addArrangedSubview(more)
        stack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        label.font = .systemFont(ofSize: 21, weight: .medium); label.textColor = .labelColor
        hint.font = .systemFont(ofSize: 11); hint.textColor = .secondaryLabelColor
        for text in [label, hint] {
            text.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        stack.addArrangedSubview(label)
        label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        actions.orientation = .horizontal; actions.spacing = 10
        let replace = NSButton(title: "Заменить", target: self, action: #selector(apply))
        replace.bezelStyle = .rounded; replace.keyEquivalent = ""
        let skip = NSButton(title: "Пропустить", target: self, action: #selector(dismiss))
        skip.bezelStyle = .rounded; skip.isBordered = false
        actions.addArrangedSubview(replace); actions.addArrangedSubview(skip)
        stack.addArrangedSubview(actions)
        stack.addArrangedSubview(hint)
        hint.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        undoButton.target = self; undoButton.action = #selector(undoIgnore)
        undoButton.bezelStyle = .rounded; undoButton.isHidden = true
        stack.addArrangedSubview(undoButton)
    }

    func menuWillOpen(_ menu: NSMenu) { isMenuOpen = true }
    func menuDidClose(_ menu: NSMenu) { isMenuOpen = false }

    func show(word: String, suggestion: String, screen: NSScreen? = nil) {
        dismissal?.cancel(); dismissal = nil
        self.word = word; self.targetScreen = screen
        title.stringValue = "Возможно, опечатка"
        title.isHidden = false; more.isHidden = false
        actions.isHidden = false; undoButton.isHidden = true
        hint.stringValue = Preferences.shared.shiftLayoutOnly
            ? "Esc — пропустить. Заменить можно до следующего ввода."
            : "⇧ ⇧ — заменить · Esc — пропустить"
        label.stringValue = "\(word) → \(suggestion)"
        layout()
        announce(label.stringValue + ". " + hint.stringValue)
    }

    private func layout() {
        resizeToContent()
        panel.orderFrontRegardless()
    }

    private func resizeToContent() {
        let screen = targetScreen ?? NSScreen.main
        guard let screen else { return }
        let width = min(330, screen.visibleFrame.width - 24)
        panel.setContentSize(NSSize(width: width, height: panel.frame.height))
        panel.contentView?.layoutSubtreeIfNeeded()
        let size = NSSize(width: width, height: max(132, stack.fittingSize.height + 32))
        panel.setFrame(SuggestionPlacement.frame(size: size, visibleFrame: screen.visibleFrame), display: false)
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
        more.menu?.cancelTracking()
        isMenuOpen = false
        panel.orderOut(nil); word = ""; label.stringValue = ""
        targetScreen = nil
    }

    @objc private func apply() { onApply?() }

    func showResult(applied: Bool) {
        label.stringValue = applied ? "Слово заменено" : "Не удалось подтвердить замену"
        hint.stringValue = applied ? "Продолжайте печатать." : "Проверьте текст. Если слово не исправлено, повторите ввод или используйте ручную замену."
        title.isHidden = true; more.isHidden = true
        actions.isHidden = true; undoButton.isHidden = true
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
        title.isHidden = true; more.isHidden = true
        actions.isHidden = true; undoButton.isHidden = false
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

    @objc private func dismiss() { onDismiss?(); hide() }
}
