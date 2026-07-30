import AppKit
import ServiceManagement
import UniformTypeIdentifiers

final class TraySettingsWindow: NSWindow {
    override func miniaturize(_ sender: Any?) {
        hideToTray(sender)
    }

    override func close() {
        hideToTray(nil)
    }

    private func hideToTray(_ sender: Any?) {
        orderOut(sender)
        NotificationCenter.default.post(name: .keySwitchHideRequested, object: nil)
    }
}

final class SettingsWindowController: NSWindowController,
                                      NSTableViewDataSource,
                                      NSTableViewDelegate {
    private let preferences = Preferences.shared
    private let monitor = KeyboardMonitor.shared
    private let appTable = NSTableView()
    private let ignoredWordsField = NSTextField()
    private let accessLabel = NSTextField(labelWithString: "")
    private let versionLabel = NSTextField(labelWithString: AppVersion.display)
    private var accessButton: NSButton!
    private let countLabel = NSTextField(labelWithString: "")
    private var spellCheckButton: NSButton!
    private var spellAutoCorrectButton: NSButton!

    convenience init() {
        let window = TraySettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 640),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Настройки KeySwitch"
        window.center()
        self.init(window: window)
        buildUI()
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            root.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -22)
        ])

        let title = NSTextField(labelWithString: "Языки автопереключения")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        root.addArrangedSubview(title)

        let languagePair = NSTextField(labelWithString:
            "\(Language.russian.displayTitle)  ⇄  \(Language.english.displayTitle)  ·  определяется автоматически")
        languagePair.font = .systemFont(ofSize: 15, weight: .medium)
        languagePair.textColor = .secondaryLabelColor
        root.addArrangedSubview(languagePair)

        let subtitle = NSTextField(wrappingLabelWithString:
            "Исправляет слова после пробела. Двойной Shift конвертирует текущее слово вручную. Введённый текст не покидает этот Mac.")
        subtitle.textColor = .secondaryLabelColor
        root.addArrangedSubview(subtitle)

        root.addArrangedSubview(makeSwitch("Автоматическое исправление",
                                           state: preferences.enabled,
                                           action: #selector(toggleEnabled(_:))))
        spellCheckButton = makeSwitch("Проверять орфографию",
                                      state: preferences.spellChecking,
                                      action: #selector(toggleSpellChecking(_:)))
        root.addArrangedSubview(spellCheckButton)
        spellAutoCorrectButton = makeSwitch("Автоисправление опечатков",
                                            state: preferences.spellAutoCorrect,
                                            action: #selector(toggleSpellAutoCorrect(_:)))
        spellAutoCorrectButton.isEnabled = preferences.spellChecking
        root.addArrangedSubview(spellAutoCorrectButton)
        root.addArrangedSubview(makeSwitch("Звуковой сигнал после исправления",
                                           state: preferences.playSound,
                                           action: #selector(toggleSound(_:))))
        root.addArrangedSubview(makeSwitch("Запускать при входе в систему",
                                           state: SMAppService.mainApp.status == .enabled,
                                           action: #selector(toggleLogin(_:))))

        countLabel.stringValue = "Исправлений: \(preferences.correctionCount)"
        root.addArrangedSubview(countLabel)

        let ignoredTitle = NSTextField(labelWithString: "Не исправлять эти слова (через запятую)")
        ignoredTitle.font = .systemFont(ofSize: 13, weight: .medium)
        root.addArrangedSubview(ignoredTitle)
        ignoredWordsField.stringValue = preferences.ignoredWords.sorted().joined(separator: ", ")
        ignoredWordsField.placeholderString = "например: API, productname"
        ignoredWordsField.target = self
        ignoredWordsField.action = #selector(saveIgnoredWords)
        root.addArrangedSubview(ignoredWordsField)
        ignoredWordsField.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let appsTitle = NSTextField(labelWithString: "Автоматика выключена в приложениях")
        appsTitle.font = .systemFont(ofSize: 13, weight: .medium)
        root.addArrangedSubview(appsTitle)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("bundle"))
        column.title = "Bundle ID"
        appTable.addTableColumn(column)
        appTable.headerView = nil
        appTable.dataSource = self
        appTable.delegate = self
        appTable.rowHeight = 34
        appTable.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        column.resizingMask = .autoresizingMask
        column.width = 500
        let scroll = NSScrollView()
        scroll.documentView = appTable
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        root.addArrangedSubview(scroll)
        scroll.heightAnchor.constraint(equalToConstant: 105).isActive = true
        scroll.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.spacing = 8
        controls.addArrangedSubview(NSButton(title: "Добавить приложение…",
                                             target: self,
                                             action: #selector(addApplication)))
        controls.addArrangedSubview(NSButton(title: "Удалить выбранное",
                                             target: self,
                                             action: #selector(removeSelectedApp)))
        root.addArrangedSubview(controls)

        let accessRow = NSStackView()
        accessRow.orientation = .horizontal
        accessRow.alignment = .centerY
        accessRow.spacing = 8
        versionLabel.textColor = .tertiaryLabelColor
        versionLabel.font = .systemFont(ofSize: 11)
        versionLabel.toolTip = "Сборка \(AppVersion.build)"
        accessRow.addArrangedSubview(versionLabel)
        let accessSpacer = NSView()
        accessSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        accessRow.addArrangedSubview(accessSpacer)
        accessRow.addArrangedSubview(accessLabel)
        accessButton = NSButton(title: "Открыть доступ…",
                                target: self,
                                action: #selector(requestAccess))
        accessRow.addArrangedSubview(accessButton)
        root.addArrangedSubview(accessRow)
        accessRow.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        refreshAccessStatus()
    }

    private func makeSwitch(_ title: String, state: Bool, action: Selector) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: self, action: action)
        button.state = state ? .on : .off
        return button
    }

    func numberOfRows(in tableView: NSTableView) -> Int { preferences.excludedApps.count }

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        let bundleID = preferences.excludedApps[row]
        let application = applicationPresentation(for: bundleID)
        let cell = NSTableCellView()
        let iconView = NSImageView()
        iconView.image = application.icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let nameField = NSTextField(labelWithString: application.name)
        nameField.font = .systemFont(ofSize: 13, weight: .medium)
        nameField.lineBreakMode = .byTruncatingTail
        nameField.toolTip = bundleID
        nameField.translatesAutoresizingMaskIntoConstraints = false
        cell.imageView = iconView
        cell.textField = nameField
        cell.addSubview(iconView)
        cell.addSubview(nameField)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 5),
            iconView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            nameField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            nameField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            nameField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    @objc private func toggleEnabled(_ sender: NSButton) {
        preferences.enabled = sender.state == .on
        NotificationCenter.default.post(name: .keySwitchStateChanged, object: nil)
    }

    @objc private func toggleSound(_ sender: NSButton) {
        preferences.playSound = sender.state == .on
    }

    @objc private func toggleSpellChecking(_ sender: NSButton) {
        preferences.spellChecking = sender.state == .on
        spellAutoCorrectButton.isEnabled = preferences.spellChecking
    }

    @objc private func toggleSpellAutoCorrect(_ sender: NSButton) {
        preferences.spellAutoCorrect = sender.state == .on
    }

    @objc private func toggleLogin(_ sender: NSButton) {
        do {
            if sender.state == .on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            sender.state = sender.state == .on ? .off : .on
            showError("Не удалось изменить запуск при входе: \(error.localizedDescription)")
        }
    }

    @objc private func requestAccess() {
        monitor.requestPermission()
        refreshAccessStatus()
    }

    @objc private func saveIgnoredWords() {
        let words = ignoredWordsField.stringValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        preferences.ignoredWords = Set(words)
    }

    @objc private func addApplication() {
        let panel = NSOpenPanel()
        panel.title = "Выберите приложение-исключение"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard let window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK,
                  let self,
                  let url = panel.url,
                  let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
            if !self.preferences.excludedApps.contains(bundleID) {
                self.preferences.excludedApps.append(bundleID)
                self.appTable.reloadData()
            }
        }
    }

    @objc private func removeSelectedApp() {
        let row = appTable.selectedRow
        guard row >= 0, row < preferences.excludedApps.count else { return }
        preferences.excludedApps.remove(at: row)
        appTable.reloadData()
    }

    func refresh() {
        refreshAccessStatus()
        countLabel.stringValue = "Исправлений: \(preferences.correctionCount)"
        appTable.reloadData()
        spellCheckButton?.state = preferences.spellChecking ? .on : .off
        spellAutoCorrectButton?.state = preferences.spellAutoCorrect ? .on : .off
        spellAutoCorrectButton?.isEnabled = preferences.spellChecking
    }

    private func refreshAccessStatus() {
        if monitor.isTrusted && monitor.isRunning {
            accessLabel.stringValue = "● Доступ разрешён"
            accessLabel.textColor = .systemGreen
            accessButton?.isHidden = true
        } else if monitor.isTrusted {
            accessLabel.stringValue = "● Доступ разрешён"
            accessLabel.textColor = .systemOrange
            accessButton?.isHidden = true
        } else {
            accessLabel.stringValue = "● Требуется доступ к Универсальному доступу"
            accessLabel.textColor = .systemOrange
            accessButton?.isHidden = false
        }
    }

    private func applicationPresentation(for bundleID: String) -> (name: String, icon: NSImage) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let bundle = Bundle(url: url)
            let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            let fileName = url.deletingPathExtension().lastPathComponent
            let name = displayName ?? bundleName ?? fileName
            return (name, NSWorkspace.shared.icon(forFile: url.path))
        }
        let fallback = bundleID.split(separator: ".").last.map(String.init) ?? bundleID
        let icon = NSImage(systemSymbolName: "app",
                           accessibilityDescription: "Приложение") ?? NSImage()
        return (fallback.prefix(1).uppercased() + fallback.dropFirst(), icon)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "KeySwitch"
        alert.informativeText = message
        alert.runModal()
    }
}

extension Notification.Name {
    static let keySwitchStateChanged = Notification.Name("keySwitchStateChanged")
    static let keySwitchHideRequested = Notification.Name("keySwitchHideRequested")
}
