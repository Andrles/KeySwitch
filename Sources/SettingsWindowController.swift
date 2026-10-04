import AppKit
import ServiceManagement
import UniformTypeIdentifiers

private enum UIStyle {
    static let accent = NSColor.controlAccentColor
    static let secondaryText = NSColor.secondaryLabelColor
}

final class TraySettingsWindow: NSWindow {
    override func miniaturize(_ sender: Any?) {
        hideToTray(sender)
    }

    override func close() {
        hideToTray(nil)
    }

    private func hideToTray(_ sender: Any?) {
        NotificationCenter.default.post(name: .keySwitchHideRequested, object: nil)
    }
}

private enum SettingsSection: Int, CaseIterable {
    case general
    case spelling
    case exclusions
    case permissions
    case appearance
    case about

    var title: String {
        switch self {
        case .general: return "Раскладка"
        case .spelling: return "Опечатки"
        case .exclusions: return "Где не исправлять"
        case .permissions: return "Доступ macOS"
        case .appearance: return "Вид и запуск"
        case .about: return "О приложении"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .spelling: return "text.badge.checkmark"
        case .exclusions: return "nosign"
        case .permissions: return "hand.raised"
        case .appearance: return "circle.lefthalf.filled"
        case .about: return "info.circle"
        }
    }
}

private final class CardView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        updateAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.controlBackgroundColor
                .withAlphaComponent(1).cgColor
            layer?.borderColor = NSColor.separatorColor
                .withAlphaComponent(0.55).cgColor
        }
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0
        layer?.shadowRadius = 12
        layer?.shadowOffset = CGSize(width: 0, height: -3)
    }
}

private final class SectionStackView: NSStackView {}

private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

private final class SidebarButton: NSButton {
    var selected = false {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        if selected {
            UIStyle.accent.withAlphaComponent(0.16).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2),
                         xRadius: 10,
                         yRadius: 10).fill()
        }
        super.draw(dirtyRect)
    }
}

private final class GlassSidebarView: NSVisualEffectView {
    let content = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .sidebar
        blendingMode = .withinWindow
        state = .active
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class SettingsWindowController: NSWindowController,
                                      NSTableViewDataSource,
                                      NSTableViewDelegate, NSTextFieldDelegate {
    private let preferences = Preferences.shared
    private let monitor = KeyboardMonitor.shared
    private let updateChecker = UpdateChecker.shared
    private let sidebar = GlassSidebarView()
    private let contentHost = NSView()
    private let appTable = NSTableView()
    private var selectedSection: SettingsSection = .general
    private var sidebarButtons: [SettingsSection: SidebarButton] = [:]

    private weak var accessStatusLabel: NSTextField?
    private weak var spellingModeControl: NSSegmentedControl?
    private weak var ignoredWordsField: NSTextField?
    private var ignoredWordsBaseline: Set<String> = []
    private weak var learnedWordsField: NSTextField?
    private weak var replacementsField: NSTextField?
    private var learnedWordsBaseline: Set<String> = []
    private var replacementsBaseline: [String: String] = [:]
    private weak var spellingDescriptionLabel: NSTextField?
    private weak var themeControl: NSSegmentedControl?
    private weak var automaticUpdatesSwitch: NSButton?
    private weak var updateStatusLabel: NSTextField?
    private weak var updateDetailLabel: NSTextField?
    private weak var updateActionButton: NSButton?
    private weak var statusIcon: NSImageView?
    private weak var statusTitleLabel: NSTextField?
    private weak var statusDetailLabel: NSTextField?
    private weak var enabledControl: NSButton?
    private weak var removeApplicationButton: NSButton?
    private weak var emptyExclusionsLabel: NSTextField?
    private var renderedMonitorState: MonitorState?
    private weak var testField: NSTextField?
    private weak var testResultLabel: NSTextField?
    private var pendingUpdateURL: URL?

    convenience init(initialSection: Int) {
        let window = TraySettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "KeySwitch"
        window.minSize = NSSize(width: 760, height: 560)
        window.titlebarAppearsTransparent = true
        window.center()
        self.init(window: window)
        configureAppTable()
        buildUI()
        if let section = SettingsSection(rawValue: initialSection) { showSection(section) }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStateChanged),
            name: .keySwitchUpdateStateChanged,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let background = NSVisualEffectView()
        background.translatesAutoresizingMaskIntoConstraints = false
        background.material = .underWindowBackground
        background.blendingMode = .withinWindow
        background.state = .active
        content.addSubview(background)

        sidebar.translatesAutoresizingMaskIntoConstraints = false
        contentHost.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(sidebar)
        background.addSubview(contentHost)
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            background.topAnchor.constraint(equalTo: content.topAnchor),
            background.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            sidebar.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: background.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 220),
            contentHost.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 0),
            contentHost.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            contentHost.topAnchor.constraint(equalTo: background.topAnchor),
            contentHost.bottomAnchor.constraint(equalTo: background.bottomAnchor)
        ])
        buildSidebar()
        showSection(.general)
    }

    private func buildSidebar() {
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 6
        root.translatesAutoresizingMaskIntoConstraints = false
        sidebar.content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: sidebar.content.leadingAnchor, constant: 14),
            root.trailingAnchor.constraint(equalTo: sidebar.content.trailingAnchor, constant: -14),
            root.topAnchor.constraint(equalTo: sidebar.content.topAnchor, constant: 18),
            root.bottomAnchor.constraint(equalTo: sidebar.content.bottomAnchor, constant: -14)
        ])

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 10
        header.addArrangedSubview(appMark(size: 32))
        let labels = NSStackView()
        labels.orientation = .vertical
        labels.spacing = 1
        let name = label("KeySwitch", size: 16, weight: .semibold)
        let languages = label("Русский и английский", size: 10, color: UIStyle.secondaryText)
        labels.addArrangedSubview(name)
        labels.addArrangedSubview(languages)
        header.addArrangedSubview(labels)
        root.addArrangedSubview(header)
        root.setCustomSpacing(18, after: header)

        for section in SettingsSection.allCases where section != .about {
            root.addArrangedSubview(sidebarButton(for: section))
        }

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        root.addArrangedSubview(spacer)
        root.addArrangedSubview(sidebarButton(for: .about))

        let version = label(AppVersion.display, size: 10, color: UIStyle.secondaryText)
        version.toolTip = "Сборка \(AppVersion.build)"
        root.addArrangedSubview(version)
    }

    private func sidebarButton(for section: SettingsSection) -> NSButton {
        let button = SidebarButton(title: section.title,
                                   target: self,
                                   action: #selector(selectSection(_:)))
        button.tag = section.rawValue
        button.isBordered = false
        button.image = symbol(section.symbol, pointSize: 15)
        button.imagePosition = .imageLeading
        button.alignment = .left
        button.font = .systemFont(ofSize: 13,
                                  weight: section == selectedSection ? .semibold : .regular)
        button.contentTintColor = .labelColor
        button.selected = section == selectedSection
        button.setButtonType(.toggle)
        button.state = section == selectedSection ? .on : .off
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        button.widthAnchor.constraint(equalToConstant: 172).isActive = true
        sidebarButtons[section] = button
        return button
    }

    @objc private func selectSection(_ sender: NSButton) {
        guard let section = SettingsSection(rawValue: sender.tag) else { return }
        showSection(section)
    }

    private func showSection(_ section: SettingsSection) {
        saveIgnoredWords()
        guard persistUserDictionary() else {
            for (value, button) in sidebarButtons { button.state = value == selectedSection ? .on : .off }
            return
        }
        selectedSection = section
        renderedMonitorState = monitor.state
        for (value, button) in sidebarButtons {
            button.selected = value == section
            button.state = value == section ? .on : .off
            button.font = .systemFont(ofSize: 13,
                                      weight: value == section ? .semibold : .regular)
            button.contentTintColor = .labelColor
        }
        contentHost.subviews.forEach { $0.removeFromSuperview() }
        resetWeakControls()

        let sectionView: NSView
        switch section {
        case .general: sectionView = buildGeneralSection()
        case .spelling: sectionView = buildSpellingSection()
        case .exclusions: sectionView = buildExclusionsSection()
        case .permissions: sectionView = buildPermissionsSection()
        case .appearance: sectionView = buildAppearanceSection()
        case .about: sectionView = buildAboutSection()
        }
        fillSectionWidth(in: sectionView)
        sectionView.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(sectionView)
        NSLayoutConstraint.activate([
            sectionView.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            sectionView.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            sectionView.topAnchor.constraint(equalTo: contentHost.topAnchor),
            sectionView.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor)
        ])
        refresh()
    }

    private func fillSectionWidth(in view: NSView) {
        if let stack = view as? SectionStackView {
            for child in stack.arrangedSubviews {
                child.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            }
        }
        for child in view.subviews { fillSectionWidth(in: child) }
    }

    private func resetWeakControls() {
        statusIcon = nil
        statusTitleLabel = nil
        statusDetailLabel = nil
        enabledControl = nil
        removeApplicationButton = nil
        emptyExclusionsLabel = nil
        testField = nil
        testResultLabel = nil
        accessStatusLabel = nil
        spellingModeControl = nil
        ignoredWordsField = nil
        learnedWordsField = nil
        replacementsField = nil
        spellingDescriptionLabel = nil
        themeControl = nil
        automaticUpdatesSwitch = nil
        updateStatusLabel = nil
        updateDetailLabel = nil
        updateActionButton = nil
    }

    private func buildGeneralSection() -> NSView {
        let (view, stack) = sectionCanvas(title: "Печатайте спокойно", subtitle: "KeySwitch исправит слово, набранное не на том языке.")
        let status = card(height: 140)
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        let icon = NSImageView(image: symbol("keyboard", pointSize: 20, color: UIStyle.accent) ?? NSImage())
        statusIcon = icon
        row.addArrangedSubview(icon)
        let labels = NSStackView()
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 4
        let title = label(monitor.state.title, size: 15, weight: .semibold)
        let detail = label(monitor.state.detail, size: 12, color: UIStyle.secondaryText, wrapping: true)
        statusTitleLabel = title
        statusDetailLabel = detail
        labels.addArrangedSubview(title)
        labels.addArrangedSubview(detail)
        row.addArrangedSubview(labels)
        status.stack.addArrangedSubview(row)
        status.stack.addArrangedSubview(separator())
        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.addArrangedSubview(label("Исправлять раскладку", size: 13, weight: .medium))
        controls.addArrangedSubview(spacer())
        let enabled = switchButton(accessibilityLabel: "Исправлять раскладку", state: preferences.enabled, action: #selector(toggleEnabled(_:)))
        enabledControl = enabled
        controls.addArrangedSubview(enabled)
        status.stack.addArrangedSubview(controls)
        if !monitor.isTrusted {
            status.stack.addArrangedSubview(NSButton(title: "Разрешить исправление…", target: self, action: #selector(openPermissionsSection)))
        }
        stack.addArrangedSubview(status.view)

        let practice = card(height: 142)
        practice.stack.addArrangedSubview(label("Попробуйте здесь", size: 15, weight: .semibold))
        practice.stack.addArrangedSubview(label("ghbdtn превратится в привет. Это безопасный пример внутри KeySwitch.", size: 12, color: UIStyle.secondaryText, wrapping: true))
        let practiceRow = NSStackView()
        practiceRow.orientation = .horizontal
        practiceRow.alignment = .centerY
        practiceRow.spacing = 8
        let field = NSTextField(string: "ghbdtn")
        field.setAccessibilityLabel("Слово для примера")
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        testField = field
        practiceRow.addArrangedSubview(field)
        practiceRow.addArrangedSubview(NSButton(title: "Исправить", target: self, action: #selector(testCorrection)))
        practice.stack.addArrangedSubview(practiceRow)
        let result = label("Пример не меняет текст в других приложениях.", size: 12, color: UIStyle.secondaryText, wrapping: true)
        testResultLabel = result
        practice.stack.addArrangedSubview(result)
        stack.addArrangedSubview(practice.view)
        stack.addArrangedSubview(verticalLabels(title: "Дважды нажмите Shift", subtitle: preferences.shiftLayoutOnly ? "Сменить язык текущего слова." : "Сменить язык текущего слова. Если есть подсказка — применить её. Сразу после автоисправления — отменить замену."))
        stack.addArrangedSubview(settingRow(title: "Звук при исправлении", subtitle: "Короткий сигнал после замены слова", state: preferences.playSound, action: #selector(toggleSound(_:))))
        return view
    }

    @objc private func openPermissionsSection() { showSection(.permissions) }

    private func buildSpellingSection() -> NSView {
        let (view, stack) = sectionCanvas(
            title: "Опечатки",
            subtitle: "Выберите, что делать с ошибками в словах."
        )
        let modeCard = card(height: 150)
        modeCard.stack.addArrangedSubview(sectionCardHeader(
            symbolName: "text.badge.checkmark",
            title: "Режим проверки",
            subtitle: "Выберите, как обрабатывать найденные опечатки",
            tint: .systemBlue
        ))
        let mode = NSSegmentedControl(
            labels: SpellingMode.allCases.map(\.displayTitle),
            trackingMode: .selectOne,
            target: self,
            action: #selector(changeSpellingMode(_:))
        )
        mode.setAccessibilityLabel("Режим проверки орфографии")
        mode.selectedSegment = SpellingMode.allCases.firstIndex(
            of: preferences.spellingMode
        ) ?? 0
        mode.segmentDistribution = .fillEqually
        mode.heightAnchor.constraint(equalToConstant: 32).isActive = true
        spellingModeControl = mode
        modeCard.stack.addArrangedSubview(mode)
        stack.addArrangedSubview(modeCard.view)

        let description = label(spellingDescription, size: 13, color: UIStyle.secondaryText, wrapping: true)
        spellingDescriptionLabel = description
        modeCard.stack.addArrangedSubview(description)

        let ignored = card(height: 125)
        ignored.stack.addArrangedSubview(sectionCardHeader(
            symbolName: "textformat.abc",
            title: "Не исправлять эти слова",
            subtitle: "Напишите слова через запятую и нажмите Enter.",
            tint: .systemOrange
        ))
        let field = NSTextField()
        ignoredWordsBaseline = preferences.ignoredWords
        field.stringValue = ignoredWordsBaseline.sorted().joined(separator: ", ")
        field.placeholderAttributedString = NSAttributedString(string: "Например: KeySwitch, API", attributes: [.foregroundColor: UIStyle.secondaryText])
        field.setAccessibilityLabel("Слова, которые не нужно исправлять; через запятую")
        field.delegate = self
        field.target = self
        field.action = #selector(saveIgnoredWords)
        ignoredWordsField = field
        ignored.stack.addArrangedSubview(field)
        stack.addArrangedSubview(ignored.view)
        let dictionary = card(height: 160)
        dictionary.stack.addArrangedSubview(label("Мой словарь", size: 15, weight: .semibold))
        dictionary.stack.addArrangedSubview(label("Правильные слова через запятую: не считаются опечатками и помогают распознать раскладку.", size: 13, color: UIStyle.secondaryText, wrapping: true))
        learnedWordsBaseline = preferences.learnedWords
        let learned = NSTextField(string: learnedWordsBaseline.sorted().joined(separator: ", "))
        learned.placeholderString = "Например: KeySwitch, аэрогель"
        learned.setAccessibilityLabel("Правильные слова моего словаря")
        learned.target = self; learned.action = #selector(saveUserDictionary); learned.delegate = self
        learnedWordsField = learned
        dictionary.stack.addArrangedSubview(learned)
        dictionary.stack.addArrangedSubview(label("Мои исправления: опечатка=правильное слово, через запятую. Применяются автоматически на границе слова.", size: 13, color: UIStyle.secondaryText, wrapping: true))
        replacementsBaseline = preferences.wordReplacements
        let pairs = NSTextField(string: replacementsBaseline.keys.sorted().map { "\($0)=\(replacementsBaseline[$0]!)" }.joined(separator: ", "))
        pairs.placeholderString = "Например: кейсвич=KeySwitch"
        pairs.setAccessibilityLabel("Пары пользовательских исправлений")
        pairs.target = self; pairs.action = #selector(saveUserDictionary); pairs.delegate = self
        replacementsField = pairs
        dictionary.stack.addArrangedSubview(pairs)
        let files = NSStackView()
        files.addArrangedSubview(NSButton(title: "Экспорт словаря…", target: self, action: #selector(exportDictionary)))
        files.addArrangedSubview(NSButton(title: "Импорт словаря…", target: self, action: #selector(importDictionary)))
        dictionary.stack.addArrangedSubview(files)
        stack.addArrangedSubview(dictionary.view)
        stack.addArrangedSubview(footerView())
        return view
    }

    private var spellingDescription: String {
        switch preferences.spellingMode {
        case .off:
            return "KeySwitch меняет только раскладку. Опечатки остаются как есть."
        case .suggestions:
            return "Появится подсказка с кнопками «Применить» и «Закрыть». Замена доступна до следующего ввода в том же поле."
        case .autoCorrect:
            return "Проверенные опечатки исправляются сразу. Для остальных появится подсказка. Подсказку можно применить кнопкой. Отмена доступна в меню ручных действий."
        }
    }

    private func buildExclusionsSection() -> NSView {
        let (view, stack) = sectionCanvas(
            title: "Где не исправлять",
            subtitle: "В этих приложениях KeySwitch не изменяет ввод"
        )
        let tableCard = card(height: 360)
        let scroll = NSScrollView()
        scroll.documentView = appTable
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        let empty = label("Исключений нет. Добавьте приложение, в котором KeySwitch не должен менять текст.",
                          size: 12, color: UIStyle.secondaryText, wrapping: true)
        empty.isHidden = !preferences.excludedApps.isEmpty
        emptyExclusionsLabel = empty
        tableCard.stack.addArrangedSubview(empty)
        tableCard.stack.addArrangedSubview(scroll)
        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.spacing = 8
        let add = NSButton(title: "Добавить приложение…",
                           target: self,
                           action: #selector(addApplication))
        add.bezelStyle = .rounded
        add.imagePosition = .imageLeading
        add.image = symbol("plus", pointSize: 12)
        let remove = NSButton(title: "Убрать из списка",
                              target: self,
                              action: #selector(removeSelectedApp))
        remove.bezelStyle = .rounded
        remove.isEnabled = appTable.selectedRow >= 0
        removeApplicationButton = remove
        controls.addArrangedSubview(add)
        controls.addArrangedSubview(remove)
        controls.addArrangedSubview(spacer())
        tableCard.stack.addArrangedSubview(controls)
        stack.addArrangedSubview(tableCard.view)

        let info = card(height: 86)
        info.stack.addArrangedSubview(sectionCardHeader(
            symbolName: "lightbulb",
            title: "Изменения применяются сразу",
            subtitle: "Активное приложение можно добавить и через меню KeySwitch.",
            tint: .systemOrange
        ))
        stack.addArrangedSubview(info.view)
        stack.addArrangedSubview(footerView())
        return view
    }

    private func buildPermissionsSection() -> NSView {
        let (view, stack) = sectionCanvas(
            title: "Доступ macOS",
            subtitle: "Доступ необходим только для исправления введённого текста"
        )
        let granted = monitor.isTrusted
        let access = card(height: 130)
        access.stack.addArrangedSubview(sectionCardHeader(
            symbolName: granted ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
            title: monitor.state.title,
            subtitle: monitor.state.detail,
            tint: granted ? .systemGreen : .systemOrange
        ))
        let statusRow = NSStackView()
        statusRow.orientation = .horizontal
        statusRow.addArrangedSubview(spacer())
        let status = label(granted ? "Доступ разрешён" : "Доступ не разрешён",
                           size: 12,
                           weight: .semibold,
                           color: UIStyle.secondaryText)
        status.stringValue = granted ? "Доступ разрешён" : "Доступ не разрешён"
        statusRow.addArrangedSubview(status)
        if granted && !monitor.isRunning {
            statusRow.addArrangedSubview(NSButton(title: "Повторить запуск", target: self,
                                                  action: #selector(retryMonitor)))
        }
        if !granted {
            statusRow.addArrangedSubview(NSButton(
                title: "Открыть настройки macOS",
                target: self,
                action: #selector(requestAccess)
            ))
        }
        access.stack.addArrangedSubview(statusRow)
        if !granted {
            access.stack.addArrangedSubview(label(
                "Уже разрешили доступ? После обновления может понадобиться удалить старую запись KeySwitch и добавить новую копию. Затем перезапустите приложение.",
                size: 12, color: UIStyle.secondaryText, wrapping: true))
            access.stack.addArrangedSubview(NSButton(title: "Показать приложение в Finder",
                target: self, action: #selector(revealApplication)))
        }
        stack.addArrangedSubview(access.view)

        let privacy = card(height: 135)
        privacy.stack.addArrangedSubview(sectionCardHeader(
            symbolName: "lock.shield",
            title: "Конфиденциальность",
            subtitle: "История печати не сохраняется. Настройки и добавленные вами исключения хранятся локально.",
            tint: .systemBlue
        ))
        let details = label(
            "Сетевой запрос выполняется только для проверки версии KeySwitch через GitHub. Текст ввода в этот запрос не включается.",
            size: 12,
            color: UIStyle.secondaryText,
            wrapping: true
        )
        privacy.stack.addArrangedSubview(details)
        stack.addArrangedSubview(privacy.view)
        stack.addArrangedSubview(footerView())
        return view
    }

    private func buildAppearanceSection() -> NSView {
        let (view, stack) = sectionCanvas(
            title: "Вид и запуск",
            subtitle: "Настройте тему, запуск и значок приложения."
        )
        let themeCard = card(height: 155)
        themeCard.stack.addArrangedSubview(sectionCardHeader(
            symbolName: "circle.lefthalf.filled",
            title: "Тема приложения",
            subtitle: "Выберите светлую, тёмную или тему macOS.",
            tint: UIStyle.accent
        ))
        let theme = NSSegmentedControl(
            labels: AppTheme.allCases.map(\.displayTitle),
            trackingMode: .selectOne,
            target: self,
            action: #selector(changeTheme(_:))
        )
        theme.setAccessibilityLabel("Тема приложения")
        theme.selectedSegment = AppTheme.allCases.firstIndex(
            of: preferences.appTheme
        ) ?? 0
        theme.segmentDistribution = .fillEqually
        theme.heightAnchor.constraint(equalToConstant: 32).isActive = true
        themeControl = theme
        themeCard.stack.addArrangedSubview(theme)
        stack.addArrangedSubview(themeCard.view)

        let launch = card(height: 166)
        launch.stack.addArrangedSubview(label("Запуск и значок", size: 15, weight: .semibold))
        launch.stack.addArrangedSubview(settingRow(title: "Только в строке меню", subtitle: "Без значка в Dock. Окно открывается из меню KeySwitch.", state: preferences.menuBarOnly, action: #selector(toggleMenuBarOnly(_:))))
        launch.stack.addArrangedSubview(settingRow(title: "Открывать при входе в Mac", subtitle: "KeySwitch запустится вместе с системой", state: SMAppService.mainApp.status == .enabled, action: #selector(toggleLogin(_:))))
        stack.addArrangedSubview(launch.view)
        let shortcuts = card(height: 200)
        shortcuts.stack.addArrangedSubview(label("Горячие клавиши", size: 15, weight: .semibold))
        shortcuts.stack.addArrangedSubview(label("Сочетания Control + Option действуют в доступных текстовых полях. Не назначайте занятые другими приложениями сочетания.", size: 13, color: UIStyle.secondaryText, wrapping: true))
        shortcuts.stack.addArrangedSubview(settingRow(title: "Двойной Shift — только раскладка", subtitle: "Подсказку можно применить кнопкой. Отмена — через ручные действия или отдельное сочетание.", state: preferences.shiftLayoutOnly, action: #selector(toggleShiftMode(_:))))
        for command in ManualCommand.allCases {
            let row = NSStackView()
            row.addArrangedSubview(label(command.title, size: 13, wrapping: true))
            row.addArrangedSubview(spacer())
            let popup = NSPopUpButton()
            popup.addItems(withTitles: ShortcutPreset.allCases.map(\.title))
            popup.selectItem(at: preferences.shortcut(for: command).rawValue)
            popup.tag = command.rawValue; popup.target = self; popup.action = #selector(changeShortcut(_:))
            popup.setAccessibilityLabel(command.title)
            row.addArrangedSubview(popup)
            shortcuts.stack.addArrangedSubview(row)
        }
        stack.addArrangedSubview(shortcuts.view)
        stack.addArrangedSubview(footerView())
        return view
    }

    private func buildAboutSection() -> NSView {
        let (view, stack) = sectionCanvas(
            title: "О приложении",
            subtitle: "Версия, обновления и полезные ссылки"
        )
        let app = card(height: 112)
        let appRow = NSStackView()
        appRow.orientation = .horizontal
        appRow.alignment = .centerY
        appRow.spacing = 14
        appRow.addArrangedSubview(appMark(size: 52))
        appRow.addArrangedSubview(verticalLabels(
            title: "KeySwitch",
            subtitle: "\(AppVersion.display) · Сборка \(AppVersion.build)"
        ))
        appRow.addArrangedSubview(spacer())
        let github = NSButton(title: "GitHub",
                              target: self,
                              action: #selector(openGitHub))
        github.imagePosition = .imageLeading
        github.image = symbol("link", pointSize: 12)
        appRow.addArrangedSubview(github)
        app.stack.addArrangedSubview(appRow)
        stack.addArrangedSubview(app.view)

        let update = card(height: 190)
        let status = label("Проверка обновлений", size: 16, weight: .semibold)
        let detail = label("Проверьте, есть ли новая версия KeySwitch.",
                           size: 12,
                           color: UIStyle.secondaryText,
                           wrapping: true)
        updateStatusLabel = status
        updateDetailLabel = detail
        update.stack.addArrangedSubview(status)
        update.stack.addArrangedSubview(detail)
        let actionRow = NSStackView()
        actionRow.orientation = .horizontal
        actionRow.alignment = .centerY
        actionRow.spacing = 8
        let auto = switchButton(
            title: "Проверять автоматически",
            state: preferences.automaticallyChecksForUpdates,
            action: #selector(toggleAutomaticUpdates(_:))
        )
        automaticUpdatesSwitch = auto
        actionRow.addArrangedSubview(auto)
        actionRow.addArrangedSubview(spacer())
        let check = NSButton(title: "Проверить обновления",
                             target: self,
                             action: #selector(checkUpdates(_:)))
        check.bezelStyle = .rounded
        updateActionButton = check
        actionRow.addArrangedSubview(check)
        update.stack.addArrangedSubview(actionRow)
        stack.addArrangedSubview(update.view)

        let links = card(height: 90)
        let linksRow = NSStackView()
        linksRow.orientation = .horizontal
        linksRow.alignment = .centerY
        linksRow.addArrangedSubview(sectionCardHeader(
            symbolName: "doc.text",
            title: "Что нового",
            subtitle: "История изменений и возможности KeySwitch",
            tint: .systemBlue
        ))
        linksRow.addArrangedSubview(spacer())
        linksRow.addArrangedSubview(linkButton("Открыть",
                                               action: #selector(openChangelog)))
        links.stack.addArrangedSubview(linksRow)
        stack.addArrangedSubview(links.view)
        stack.addArrangedSubview(footerView())
        renderUpdateState()
        return view
    }

    private func sectionCanvas(title: String,
                               subtitle: String) -> (NSView, NSStackView) {
        let view = NSView()
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let document = FlippedDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        let stack = SectionStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24)
        ])
        let titleLabel = label(title, size: 23, weight: .semibold)
        let subtitleLabel = label(subtitle,
                                  size: 13,
                                  color: UIStyle.secondaryText)
        stack.addArrangedSubview(titleLabel)
        stack.setCustomSpacing(2, after: titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.setCustomSpacing(20, after: subtitleLabel)
        return (view, stack)
    }

    private func card(height: CGFloat) -> (view: CardView, stack: NSStackView) {
        let view = CardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])

        return (view, stack)
    }

    private func sectionCardHeader(symbolName: String,
                                   title: String,
                                   subtitle: String,
                                   tint: NSColor) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 14
        let icon = NSImageView(image: symbol(symbolName,
                                             pointSize: 18,
                                             color: UIStyle.secondaryText) ?? NSImage())
        icon.widthAnchor.constraint(equalToConstant: 28).isActive = true
        row.addArrangedSubview(icon)
        row.addArrangedSubview(verticalLabels(title: title, subtitle: subtitle))
        return row
    }

    private func settingRow(title: String,
                            subtitle: String,
                            state: Bool,
                            action: Selector) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.addArrangedSubview(verticalLabels(title: title,
                                              subtitle: subtitle,
                                              compact: true))
        row.addArrangedSubview(spacer())
        row.addArrangedSubview(switchButton(accessibilityLabel: title, state: state, action: action))
        return row
    }

    private func verticalLabels(title: String,
                                subtitle: String,
                                light: Bool = false,
                                compact: Bool = false) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = compact ? 1 : 3
        stack.addArrangedSubview(label(
            title,
            size: compact ? 13 : 15,
            weight: .semibold,
            color: light ? .white : .labelColor
        ))
        stack.addArrangedSubview(label(
            subtitle,
            size: compact ? 11 : 12,
            color: light ? NSColor.white.withAlphaComponent(1) : UIStyle.secondaryText,
            wrapping: true
        ))
        return stack
    }

    private func footerView() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        let access = label(monitor.isTrusted ? "Доступ разрешён" : "Нужен доступ macOS",
                           size: 11,
                           color: UIStyle.secondaryText)
        accessStatusLabel = access
        row.addArrangedSubview(access)
        row.addArrangedSubview(spacer())
        row.addArrangedSubview(label(
            "Текст остаётся на этом Mac",
            size: 11,
            color: UIStyle.secondaryText
        ))
        return row
    }

    private func label(_ value: String,
                       size: CGFloat,
                       weight: NSFont.Weight = .regular,
                       color: NSColor = .labelColor,
                       wrapping: Bool = false) -> NSTextField {
        let field = wrapping
            ? NSTextField(wrappingLabelWithString: value)
            : NSTextField(labelWithString: value)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.setContentCompressionResistancePriority(.required, for: .vertical)
        field.textColor = color
        return field
    }

    private func spacer() -> NSView {
        let value = NSView()
        value.setContentHuggingPriority(.defaultLow, for: .horizontal)
        value.setContentHuggingPriority(.defaultLow, for: .vertical)
        return value
    }

    private func separator() -> NSBox {
        let value = NSBox()
        value.boxType = .separator
        return value
    }

    private func switchButton(title: String = "",
                              accessibilityLabel: String? = nil,
                              state: Bool,
                              action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.setButtonType(.switch)
        button.setAccessibilityLabel(accessibilityLabel ?? title)
        button.state = state ? .on : .off
        return button
    }

    private func linkButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.contentTintColor = UIStyle.accent
        button.font = .systemFont(ofSize: 12, weight: .medium)
        return button
    }

    private func symbol(_ name: String,
                        pointSize: CGFloat,
                        color: NSColor? = nil) -> NSImage? {
        let image = NSImage(systemSymbolName: name,
                            accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: pointSize,
                                           weight: .medium))
        image?.isTemplate = true
        // Section icons are decorative; adjacent text supplies their meaning.
        return image
    }

    private func appMark(size: CGFloat) -> NSView {
        let image = NSImageView(image: NSApplication.shared.applicationIconImage)
        image.imageScaling = .scaleProportionallyUpOrDown
        image.translatesAutoresizingMaskIntoConstraints = false
        image.widthAnchor.constraint(equalToConstant: size).isActive = true
        image.heightAnchor.constraint(equalToConstant: size).isActive = true
        return image
    }

    private func configureAppTable() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("application"))
        column.resizingMask = .autoresizingMask
        appTable.addTableColumn(column)
        appTable.headerView = nil
        appTable.dataSource = self
        appTable.delegate = self
        appTable.rowHeight = 52
        appTable.backgroundColor = .clear
        appTable.selectionHighlightStyle = .regular
        appTable.setAccessibilityLabel("Приложения, исключённые из исправления")
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        preferences.excludedApps.count
    }

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        let bundleID = preferences.excludedApps[row]
        let application = applicationPresentation(for: bundleID)
        let cell = NSTableCellView()
        let icon = NSImageView(image: application.icon)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        let labels = verticalLabels(title: application.name,
                                    subtitle: "В этом приложении исправление выключено",
                                    compact: true)
        labels.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(icon)
        cell.addSubview(labels)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 30),
            icon.heightAnchor.constraint(equalToConstant: 30),
            labels.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            labels.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            labels.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    @objc private func toggleEnabled(_ sender: NSButton) {
        preferences.enabled = sender.state == .on
        monitor.invalidateContext()
        NotificationCenter.default.post(name: .keySwitchStateChanged, object: nil)
        refresh()
    }

    @objc private func toggleSound(_ sender: NSButton) {
        preferences.playSound = sender.state == .on
    }

    @objc private func toggleMenuBarOnly(_ sender: NSButton) {
        preferences.menuBarOnly = sender.state == .on
        NotificationCenter.default.post(name: .keySwitchStateChanged, object: nil)
    }

    @objc private func toggleLogin(_ sender: NSButton) {
        do {
            if sender.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            sender.state = sender.state == .on ? .off : .on
            showError("Не удалось изменить запуск при входе: \(error.localizedDescription)")
        }
    }

    @objc private func changeSpellingMode(_ sender: NSSegmentedControl) {
        let modes = SpellingMode.allCases
        guard sender.selectedSegment >= 0,
              sender.selectedSegment < modes.count else { return }
        preferences.spellingMode = modes[sender.selectedSegment]
        spellingDescriptionLabel?.stringValue = spellingDescription
        // Keep the segmented control and keyboard/VoiceOver focus in place.
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        if let field = notification.object as? NSTextField {
            if field === ignoredWordsField { saveIgnoredWords() }
            if field === learnedWordsField || field === replacementsField { saveUserDictionary() }
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        removeApplicationButton?.isEnabled = appTable.selectedRow >= 0
    }

    @objc private func retryMonitor() {
        monitor.resetRetry()
        monitor.start()
        refresh()
        NotificationCenter.default.post(name: .keySwitchStateChanged, object: nil)
    }

    @objc private func testCorrection() {
        guard let field = testField else { return }
        let text = field.stringValue
        guard text.count <= 64 else {
            testResultLabel?.stringValue = "Введите одно короткое слово (до 64 символов)."
            return
        }
        if let correction = LanguageEngine().correction(for: text, ignored: preferences.ignoredWords, learned: preferences.learnedWords, replacements: preferences.wordReplacements) {
            testResultLabel?.stringValue = "\(text) → \(correction.replacement). Это локальный пример, а не проверка внешнего редактора."
        } else {
            testResultLabel?.stringValue = "Замена не требуется. Попробуйте ghbdtn или руддщ."
        }
    }

    @objc private func saveUserDictionary() { _ = persistUserDictionary() }

    private func persistUserDictionary() -> Bool {
        if let field = replacementsField, UserDictionaryFormat.replacements(field.stringValue) == nil {
            field.textColor = .systemRed
            showError("Запись словаря не сохранена. Используйте формат опечатка=исправление, без пробелов и повторных ключей.")
            return false
        }
        if let field = learnedWordsField {
            let draft = UserDictionaryFormat.words(field.stringValue)
            if draft != learnedWordsBaseline {
                preferences.learnedWords = preferences.learnedWords.subtracting(learnedWordsBaseline.subtracting(draft)).union(draft.subtracting(learnedWordsBaseline))
                learnedWordsBaseline = preferences.learnedWords
            }
        }
        if let field = replacementsField {
            guard let draft = UserDictionaryFormat.replacements(field.stringValue) else {
                field.toolTip = "Проверьте формат: опечатка=исправление. Не используйте пробелы или повторные ключи."
                field.textColor = .systemRed
                return false
            }
            field.textColor = .labelColor
            field.toolTip = nil
            if draft != replacementsBaseline {
                var current = preferences.wordReplacements
                for key in replacementsBaseline.keys where draft[key] == nil { current.removeValue(forKey: key) }
                for (key, value) in draft where replacementsBaseline[key] != value { current[key] = value }
                preferences.wordReplacements = current
                replacementsBaseline = current
            }
        }
        return true
    }

    @objc private func exportDictionary() {
        guard persistUserDictionary() else { return }
        saveIgnoredWords()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "KeySwitch-dictionary.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: ["words": preferences.learnedWords.sorted(), "replacements": preferences.wordReplacements, "ignored": preferences.ignoredWords.sorted()], options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
        } catch { showError("Не удалось экспортировать словарь: \(error.localizedDescription)") }
    }

    @objc private func importDictionary() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard ((attributes[.size] as? NSNumber)?.intValue ?? Int.max) <= 1_000_000 else { throw CocoaError(.fileReadTooLarge) }
            let data = try Data(contentsOf: url)
            guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let words = dictionary["words"] as? [String], let replacements = dictionary["replacements"] as? [String: String], let ignored = dictionary["ignored"] as? [String],
                  words.count + replacements.count + ignored.count <= 5000,
                  words.allSatisfy({ UserDictionaryFormat.words($0).count == 1 && !$0.contains(",") }),
                  ignored.allSatisfy({ UserDictionaryFormat.words($0).count == 1 && !$0.contains(",") }),
                  replacements.allSatisfy({ !$0.key.contains(",") && !$0.value.contains(",") && !$0.key.contains("=") && !$0.value.contains("=") }),
                  let pairs = UserDictionaryFormat.replacements(replacements.keys.sorted().map { "\($0)=\(replacements[$0]!)" }.joined(separator: ", ")) else { throw CocoaError(.fileReadCorruptFile) }
            guard persistUserDictionary() else { return }
            saveIgnoredWords()
            preferences.learnedWords.formUnion(words.flatMap { UserDictionaryFormat.words($0) })
            preferences.ignoredWords.formUnion(ignored.flatMap { UserDictionaryFormat.words($0) })
            preferences.wordReplacements.merge(pairs) { _, incoming in incoming }
            // Clear old fields before rebuilding; imported data is already committed.
            learnedWordsField = nil; replacementsField = nil; ignoredWordsField = nil
            showSection(.spelling)
        } catch { showError("Не удалось импортировать словарь: \(error.localizedDescription)") }
    }

    @objc private func saveIgnoredWords() {
        guard let ignoredWordsField else { return }
        let words = ignoredWordsField.stringValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        preferences.saveIgnoredWords(Set(words), baseline: ignoredWordsBaseline)
        ignoredWordsBaseline = preferences.ignoredWords
        ignoredWordsField.stringValue = ignoredWordsBaseline.sorted().joined(separator: ", ")
    }

    @objc private func toggleShiftMode(_ sender: NSButton) {
        preferences.shiftLayoutOnly = sender.state == .on
    }

    @objc private func changeShortcut(_ sender: NSPopUpButton) {
        guard let command = ManualCommand(rawValue: sender.tag), let shortcut = ShortcutPreset(rawValue: sender.indexOfSelectedItem) else { return }
        if !preferences.setShortcut(shortcut, for: command) {
            sender.selectItem(at: preferences.shortcut(for: command).rawValue)
            showError("Это сочетание уже назначено другому действию KeySwitch.")
        }
    }

    @objc private func changeTheme(_ sender: NSSegmentedControl) {
        let themes = AppTheme.allCases
        guard sender.selectedSegment >= 0,
              sender.selectedSegment < themes.count else { return }
        preferences.appTheme = themes[sender.selectedSegment]
        AppearanceController.apply(preferences.appTheme)
    }

    @objc private func toggleAutomaticUpdates(_ sender: NSButton) {
        preferences.automaticallyChecksForUpdates = sender.state == .on
    }

    @objc private func checkUpdates(_ sender: NSButton) {
        if let pendingUpdateURL {
            NSWorkspace.shared.open(pendingUpdateURL)
            return
        }
        sender.isEnabled = false
        updateStatusLabel?.stringValue = "Проверяю обновления…"
        updateDetailLabel?.stringValue = "Подключение к GitHub Releases"
        updateChecker.check { [weak self] _ in
            self?.renderUpdateState()
        }
    }

    @objc private func updateStateChanged() {
        renderUpdateState()
    }

    private func renderUpdateState() {
        guard let updateStatusLabel,
              let updateDetailLabel,
              let updateActionButton else { return }
        pendingUpdateURL = nil
        updateActionButton.isEnabled = !updateChecker.isChecking
        if updateChecker.isChecking {
            updateStatusLabel.stringValue = "Проверяю обновления…"
            updateDetailLabel.stringValue = "Подключение к GitHub Releases"
            return
        }
        if let error = updateChecker.lastError {
            updateStatusLabel.stringValue = "Не удалось проверить обновления"
            updateDetailLabel.stringValue = (error as? URLError)?.code == .notConnectedToInternet
                ? "Нет соединения. Подключитесь к интернету и нажмите «Повторить»."
                : "GitHub недоступен или ответ не удалось прочитать. Повторите проверку позже."
            updateActionButton.title = "Повторить"
            return
        }
        switch updateChecker.lastResult {
        case .upToDate:
            updateStatusLabel.stringValue = "Установлена последняя версия"
            updateDetailLabel.stringValue = "\(AppVersion.display) актуальна"
            updateActionButton.title = "Проверить снова"
        case let .available(update):
            updateStatusLabel.stringValue = "Доступна версия \(update.version)"
            updateDetailLabel.stringValue = "Новая версия готова к загрузке"
            updateActionButton.title = "Скачать обновление"
            pendingUpdateURL = update.downloadURL
        case nil:
            updateStatusLabel.stringValue = "Проверка обновлений"
            updateDetailLabel.stringValue = "Проверьте, есть ли новая версия KeySwitch."
            updateActionButton.title = "Проверить обновления"
        }
    }

    @objc private func requestAccess() {
        monitor.requestPermission()
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        showSection(.permissions)
    }

    @objc private func revealApplication() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
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
                self.monitor.invalidateContext()
                self.refresh()
            }
        }
    }

    @objc private func removeSelectedApp() {
        let row = appTable.selectedRow
        guard row >= 0, row < preferences.excludedApps.count else { return }
        preferences.excludedApps.remove(at: row)
        appTable.deselectAll(nil)
        refresh()
    }

    @objc private func openSpellingSection() {
        showSection(.spelling)
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/Andrles/KeySwitch")!)
    }

    @objc private func openChangelog() {
        NSWorkspace.shared.open(
            URL(string: "https://github.com/Andrles/KeySwitch/blob/main/CHANGELOG.md")!
        )
    }

    func showPermissions() { showSection(.permissions) }

    func showAboutAndCheckForUpdates() {
        showSection(.about)
        if !updateChecker.isChecking {
            checkUpdates(updateActionButton ?? NSButton())
        }
    }

    @discardableResult
    func commitPendingEdits() -> Bool {
        guard persistUserDictionary() else { return false }
        saveIgnoredWords()
        return true
    }

    func refresh() {
        let state = monitor.state
        if renderedMonitorState != state && selectedSection == .permissions {
            showSection(.permissions)
            return
        }
        renderedMonitorState = state
        let statusSymbol = state == .ready ? "checkmark.circle.fill"
            : state == .paused ? "pause.circle.fill" : "exclamationmark.triangle.fill"
        statusIcon?.image = symbol(statusSymbol, pointSize: 25, color: UIStyle.accent)
        statusTitleLabel?.stringValue = state.title
        statusDetailLabel?.stringValue = state == .ready ? monitor.availabilityDetail : state.detail
        enabledControl?.state = preferences.enabled ? .on : .off
        if selectedSection == .exclusions {
            let selection = appTable.selectedRow
            appTable.reloadData()
            if selection >= 0 && selection < preferences.excludedApps.count {
                appTable.selectRowIndexes(IndexSet(integer: selection), byExtendingSelection: false)
            }
            removeApplicationButton?.isEnabled = appTable.selectedRow >= 0
            emptyExclusionsLabel?.isHidden = !preferences.excludedApps.isEmpty
        }
        accessStatusLabel?.stringValue = monitor.isTrusted
            ? "Доступ разрешён"
            : "Нужен доступ macOS"
        accessStatusLabel?.textColor = UIStyle.secondaryText
        if let field = ignoredWordsField {
            let draft = Set(field.stringValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty })
            if draft == ignoredWordsBaseline && preferences.ignoredWords != ignoredWordsBaseline {
                ignoredWordsBaseline = preferences.ignoredWords
                field.stringValue = ignoredWordsBaseline.sorted().joined(separator: ", ")
            }
        }
        spellingModeControl?.selectedSegment = SpellingMode.allCases.firstIndex(
            of: preferences.spellingMode
        ) ?? 0
        themeControl?.selectedSegment = AppTheme.allCases.firstIndex(
            of: preferences.appTheme
        ) ?? 0
        automaticUpdatesSwitch?.state = preferences.automaticallyChecksForUpdates
            ? .on
            : .off
        renderUpdateState()
    }

    private func applicationPresentation(for bundleID: String) -> (name: String, icon: NSImage) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let bundle = Bundle(url: url)
            let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            let fileName = url.deletingPathExtension().lastPathComponent
            return (
                displayName ?? bundleName ?? fileName,
                NSWorkspace.shared.icon(forFile: url.path)
            )
        }
        let knownNames = ["com.apple.dt.Xcode": "Xcode", "com.microsoft.VSCode": "Visual Studio Code",
                          "com.jetbrains.intellij": "IntelliJ IDEA", "com.jetbrains.AppCode": "AppCode",
                          "com.unity3d.UnityEditor5.x": "Unity"]
        let fallback = knownNames[bundleID] ?? bundleID.split(separator: ".").last.map(String.init) ?? bundleID
        let icon = NSImage(systemSymbolName: "app.dashed",
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
