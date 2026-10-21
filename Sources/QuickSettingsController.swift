import AppKit

/// Explicitly opened from the status item. Automatic spelling feedback never
/// activates this controller or the app: it uses the nonactivating indicator.
final class QuickSettingsController: NSViewController {
    var onToggle: (() -> Void)?
    var onSettings: (() -> Void)?
    var onPermission: (() -> Void)?
    var onRetry: (() -> Void)?
    private var currentState = MonitorState.ready
    var onMore: (() -> Void)?
    private let status = NSTextField(wrappingLabelWithString: "")
    private let detail = NSTextField(wrappingLabelWithString: "")
    private let toggle = NSSwitch()
    private let permission = NSButton(title: "Открыть доступ macOS…", target: nil, action: nil)

    override func loadView() {
        let surface = MaterialSurface(role: .popover)
        view = surface
        preferredContentSize = NSSize(width: 320, height: 320)
        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: surface.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -20)
        ])
        let title = NSTextField(labelWithString: "KeySwitch")
        title.font = .systemFont(ofSize: 19, weight: .semibold)
        stack.addArrangedSubview(title)
        let languages = NSTextField(labelWithString: "Русский ↔ English")
        languages.font = .systemFont(ofSize: 12); languages.textColor = .secondaryLabelColor
        stack.addArrangedSubview(languages)
        status.font = .systemFont(ofSize: 13, weight: .semibold)
        detail.font = .systemFont(ofSize: 12); detail.textColor = .secondaryLabelColor
        for label in [status, detail] {
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            stack.addArrangedSubview(label)
            label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        let row = NSStackView()
        row.orientation = .horizontal; row.alignment = .centerY
        row.addArrangedSubview(NSTextField(labelWithString: "Автоисправления"))
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        toggle.target = self; toggle.action = #selector(toggleCorrection)
        toggle.setAccessibilityLabel("Автоисправления")
        row.addArrangedSubview(toggle)
        stack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        permission.target = self; permission.action = #selector(openPermission)
        permission.bezelStyle = .rounded
        stack.addArrangedSubview(permission)
        let separator = NSBox(); separator.boxType = .separator
        stack.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let settings = NSButton(title: "Открыть настройки…", target: self, action: #selector(openSettings))
        settings.bezelStyle = .rounded
        stack.addArrangedSubview(settings)
        let more = NSButton(title: "Ещё действия…", target: self, action: #selector(openMore))
        more.isBordered = false
        more.toolTip = "Горячие клавиши, исключения, обновления и выход. Также доступны правой кнопкой по иконке."
        stack.addArrangedSubview(more)
        let privacy = NSTextField(labelWithString: "Текст остаётся на Mac")
        privacy.font = .systemFont(ofSize: 10); privacy.textColor = .secondaryLabelColor
        stack.addArrangedSubview(privacy)
    }

    func refresh(state: MonitorState, enabled: Bool) {
        _ = view
        status.stringValue = state.title
        detail.stringValue = state.detail
        toggle.state = enabled ? .on : .off
        currentState = state
        permission.title = state == .failed ? "Повторить запуск" : "Открыть доступ macOS…"
        permission.isHidden = state != .needsPermission && state != .failed
        view.layoutSubtreeIfNeeded()
        preferredContentSize = NSSize(width: 320, height: view.fittingSize.height)
    }
    @objc private func toggleCorrection() { onToggle?() }
    @objc private func openSettings() { onSettings?() }
    @objc private func openPermission() { if currentState == .failed { onRetry?() } else { onPermission?() } }
    @objc private func openMore() { onMore?() }
}
