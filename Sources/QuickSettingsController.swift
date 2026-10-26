import AppKit

/// Opened explicitly from the status item. Automatic spelling feedback uses
/// a separate nonactivating panel and never takes keyboard focus.
final class QuickSettingsController: NSViewController {
    enum Action { case settings, permission, exclusion }
    var onToggle: (() -> Void)?
    var onRetry: (() -> Void)?
    var onAction: ((Action) -> Void)?

    private let stack = NSStackView()
    private let status = NSTextField(wrappingLabelWithString: "")
    private let detail = NSTextField(wrappingLabelWithString: "")
    private let applicationName = NSTextField(wrappingLabelWithString: "")
    private let applicationNote = NSTextField(wrappingLabelWithString: "")
    private let toggle = NSSwitch()
    private let applicationToggle = NSSwitch()
    private let recovery = NSButton(title: "", target: nil, action: nil)
    private var state: MonitorState = .ready
    private var enabled = true
    private var hasApplication = false
    private let width: CGFloat = 350

    override func loadView() {
        let surface = MaterialSurface(role: .popover)
        view = surface
        // Intrinsic widths of long labels must never expand the popover.
        surface.widthAnchor.constraint(equalToConstant: width).isActive = true
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: surface.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -16)
        ])
        let header = NSStackView(); header.orientation = .horizontal; header.spacing = 8
        let icon = NSImageView()
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png") {
            icon.image = NSImage(contentsOf: url)
        } else { icon.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil) }
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let title = NSTextField(labelWithString: "KeySwitch")
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        header.addArrangedSubview(icon); header.addArrangedSubview(title)
        stack.addArrangedSubview(header)
        status.font = .systemFont(ofSize: 13, weight: .medium)
        for label in [status, detail, applicationName, applicationNote] {
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            label.preferredMaxLayoutWidth = width - 36
        }
        for label in [detail, applicationName, applicationNote] {
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
        }
        applicationName.maximumNumberOfLines = 2
        applicationName.lineBreakMode = .byTruncatingTail
        func add(_ child: NSView) {
            stack.addArrangedSubview(child)
            child.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        add(status)
        add(detail)
        recovery.bezelStyle = .rounded
        recovery.target = self; recovery.action = #selector(recover)
        add(recovery)
        add(switchRow("Автоисправления", control: toggle, action: #selector(toggleCorrection)))
        let separator = NSBox(); separator.boxType = .separator
        add(separator)
        add(applicationName)
        add(switchRow("Исправлять в этом приложении", control: applicationToggle, action: #selector(toggleApplication)))
        add(applicationNote)
        let open = NSButton(title: "Открыть приложение", target: self, action: #selector(openApplication))
        open.bezelStyle = .rounded
        open.font = .systemFont(ofSize: 13)
        add(open)
    }

    private func switchRow(_ title: String, control: NSSwitch, action: Selector) -> NSView {
        let row = NSStackView(); row.orientation = .horizontal; row.alignment = .centerY
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(label); row.addArrangedSubview(spacer)
        control.target = self; control.action = action; control.setAccessibilityLabel(title)
        row.addArrangedSubview(control)
        return row
    }

    func refresh(state: MonitorState, enabled: Bool) {
        _ = view
        self.state = state; self.enabled = enabled
        switch state {
        case .ready: status.stringValue = "Работает"
        case .paused: status.stringValue = "На паузе"
        case .needsPermission: status.stringValue = "Не работает: нужен доступ"
        case .failed: status.stringValue = "Не удалось запустить"
        }
        status.textColor = state == .paused ? .secondaryLabelColor : .labelColor
        toggle.state = enabled ? .on : .off
        detail.stringValue = state.detail
        detail.isHidden = state == .ready || state == .paused
        recovery.title = state == .needsPermission ? "Разрешить доступ…" : "Повторить запуск"
        recovery.isHidden = state != .failed && state != .needsPermission
        refreshApplicationNote()
        resizeToContent()
    }

    func refreshApplication(name: String?, excluded: Bool) {
        _ = view
        hasApplication = name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        applicationName.stringValue = hasApplication ? name! : "Приложение не определено"
        applicationName.toolTip = hasApplication ? name : nil
        applicationToggle.isEnabled = hasApplication
        applicationToggle.state = excluded ? .off : .on
        refreshApplicationNote()
        resizeToContent()
    }

    private func refreshApplicationNote() {
        applicationNote.stringValue = !hasApplication ? "Откройте панель из нужного приложения." : !enabled ? "Правило сохранено. Сейчас действует общая пауза." : ""
        applicationNote.isHidden = applicationNote.stringValue.isEmpty
    }

    private func resizeToContent() {
        view.layoutSubtreeIfNeeded()
        preferredContentSize = NSSize(width: width, height: stack.fittingSize.height + 34)
    }

    func focusControls() {
        view.window?.makeKeyAndOrderFront(nil)
        view.window?.makeFirstResponder(toggle)
    }

    @objc private func toggleCorrection() { onToggle?() }
    @objc private func toggleApplication() { onAction?(.exclusion) }
    @objc private func openApplication() { onAction?(.settings) }
    @objc private func recover() {
        if state == .needsPermission { onAction?(.permission) }
        else if state == .failed { onRetry?() }
    }
}
