import AppKit

/// Explicitly opened from the status item. Automatic spelling feedback never
/// activates this controller or the app: it uses the nonactivating indicator.
final class QuickSettingsController: NSViewController {
    enum Action: Int, CaseIterable {
        case settings, shortcuts, permission, updates, hide, quit, exclusion
    }
    var onToggle: (() -> Void)?
    var onRetry: (() -> Void)?
    var onAction: ((Action) -> Void)?
    private let status = NSTextField(wrappingLabelWithString: "")
    private let detail = NSTextField(wrappingLabelWithString: "")
    private let toggle = NSSwitch()
    private let retry = NSButton(title: "Повторить запуск", target: nil, action: nil)
    private var exclusion: NSButton!

    override func loadView() {
        let surface = MaterialSurface(role: .popover)
        view = surface
        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: surface.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -16)
        ])
        let title = NSTextField(labelWithString: "KeySwitch")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        stack.addArrangedSubview(title)
        status.font = .systemFont(ofSize: 14, weight: .semibold)
        detail.font = .systemFont(ofSize: 12); detail.textColor = .secondaryLabelColor
        for label in [status, detail] {
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            stack.addArrangedSubview(label)
            label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        let row = NSStackView()
        row.orientation = .horizontal; row.alignment = .centerY
        let label = NSTextField(labelWithString: "Автоисправления")
        label.font = .systemFont(ofSize: 14, weight: .medium)
        row.addArrangedSubview(label)
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        toggle.target = self; toggle.action = #selector(toggleCorrection)
        toggle.setAccessibilityLabel("Автоисправления")
        row.addArrangedSubview(toggle)
        stack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        retry.target = self; retry.action = #selector(retryMonitoring)
        retry.bezelStyle = .rounded
        stack.addArrangedSubview(retry)
        addSeparator(to: stack)
        exclusion = addAction(.exclusion, title: "Активное приложение не определено", symbol: "app.badge.checkmark", to: stack)
        addSeparator(to: stack)
        addAction(.settings, title: "Настройки…", symbol: "gearshape", to: stack)
        addAction(.shortcuts, title: "Горячие клавиши…", symbol: "keyboard", to: stack)
        addAction(.permission, title: "Доступ macOS…", symbol: "hand.raised", to: stack)
        addAction(.updates, title: "Проверить обновления…", symbol: "arrow.triangle.2.circlepath", to: stack)
        addAction(.hide, title: "Скрыть окно настроек", symbol: "menubar.rectangle", to: stack)
        addSeparator(to: stack)
        addAction(.quit, title: "Завершить KeySwitch", symbol: "power", to: stack)
        let privacy = NSTextField(labelWithString: "Русский ↔ English · Текст остаётся на Mac")
        privacy.font = .systemFont(ofSize: 11); privacy.textColor = .secondaryLabelColor
        stack.addArrangedSubview(privacy)
    }

    @discardableResult
    private func addAction(_ action: Action, title: String, symbol: String, to stack: NSStackView) -> NSButton {
        let button = NSButton(title: title, target: self, action: #selector(selectAction(_:)))
        button.tag = action.rawValue
        button.isBordered = false; button.alignment = .left
        button.font = .systemFont(ofSize: 13)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .regular))
        button.imagePosition = .imageLeading
        button.lineBreakMode = .byTruncatingMiddle
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 26).isActive = true
        stack.addArrangedSubview(button)
        button.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return button
    }

    private func addSeparator(to stack: NSStackView) {
        let separator = NSBox(); separator.boxType = .separator
        stack.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    func refresh(state: MonitorState, enabled: Bool) {
        _ = view
        status.stringValue = state.title
        status.textColor = state == .ready ? .systemGreen : .labelColor
        detail.stringValue = state.detail
        toggle.state = enabled ? .on : .off
        retry.isHidden = state != .failed
        view.layoutSubtreeIfNeeded()
        preferredContentSize = NSSize(width: 350, height: view.fittingSize.height)
    }

    func refreshApplication(name: String?, excluded: Bool) {
        _ = view
        exclusion.title = name.map { excluded ? "Включить для «\($0)»" : "Не исправлять в «\($0)»" }
            ?? "Активное приложение не определено"
        exclusion.toolTip = exclusion.title
        exclusion.isEnabled = name != nil
    }

    func focusControls() {
        view.window?.makeKeyAndOrderFront(nil)
        view.window?.makeFirstResponder(toggle)
    }

    @objc private func toggleCorrection() { onToggle?() }
    @objc private func retryMonitoring() { onRetry?() }
    @objc private func selectAction(_ sender: NSButton) {
        guard let action = Action(rawValue: sender.tag) else { return }
        onAction?(action)
    }
}
