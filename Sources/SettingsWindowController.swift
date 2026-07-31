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

private enum SettingsSection: Int, CaseIterable {
    case general
    case spelling
    case exclusions
    case permissions
    case appearance
    case about

    var title: String {
        switch self {
        case .general: return "Основные"
        case .spelling: return "Орфография"
        case .exclusions: return "Исключения"
        case .permissions: return "Разрешения"
        case .appearance: return "Оформление"
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
                .withAlphaComponent(0.82).cgColor
            layer?.borderColor = NSColor.separatorColor
                .withAlphaComponent(0.55).cgColor
        }
        layer?.cornerRadius = 16
        layer?.borderWidth = 1
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.09
        layer?.shadowRadius = 12
        layer?.shadowOffset = CGSize(width: 0, height: -3)
    }
}

private final class HeroView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        let gradient = CAGradientLayer()
        gradient.colors = [
            NSColor(calibratedRed: 0.30, green: 0.44, blue: 1.0, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.62, green: 0.34, blue: 0.97, alpha: 1).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.cornerRadius = 20
        layer = gradient
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.14
        layer?.shadowRadius = 14
        layer?.shadowOffset = CGSize(width: 0, height: -4)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layer?.frame = bounds
    }
}

private final class SidebarButton: NSButton {
    var selected = false {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        if selected {
            NSColor.controlAccentColor.withAlphaComponent(0.16).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2),
                         xRadius: 10,
                         yRadius: 10).fill()
        }
        super.draw(dirtyRect)
    }
}

private final class GlassSidebarView: NSView {
    let content = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.translatesAutoresizingMaskIntoConstraints = false
            glass.cornerRadius = 18
            glass.tintColor = NSColor.controlAccentColor.withAlphaComponent(0.04)
            glass.contentView = content
            addSubview(glass)
            NSLayoutConstraint.activate([
                glass.leadingAnchor.constraint(equalTo: leadingAnchor),
                glass.trailingAnchor.constraint(equalTo: trailingAnchor),
                glass.topAnchor.constraint(equalTo: topAnchor),
                glass.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        } else {
            installFallbackMaterial()
        }
        #else
        installFallbackMaterial()
        #endif
    }

    private func installFallbackMaterial() {
            let material = NSVisualEffectView()
            material.translatesAutoresizingMaskIntoConstraints = false
            material.material = .sidebar
            material.blendingMode = .withinWindow
            material.state = .active
            addSubview(material)
            material.addSubview(content)
            content.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                material.leadingAnchor.constraint(equalTo: leadingAnchor),
                material.trailingAnchor.constraint(equalTo: trailingAnchor),
                material.topAnchor.constraint(equalTo: topAnchor),
                material.bottomAnchor.constraint(equalTo: bottomAnchor),
                content.leadingAnchor.constraint(equalTo: material.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: material.trailingAnchor),
                content.topAnchor.constraint(equalTo: material.topAnchor),
                content.bottomAnchor.constraint(equalTo: material.bottomAnchor)
            ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class SettingsWindowController: NSWindowController,
                                      NSTableViewDataSource,
                                      NSTableViewDelegate {
    private let preferences = Preferences.shared
    private let monitor = KeyboardMonitor.shared
    private let updateChecker = UpdateChecker.shared
    private let sidebar = GlassSidebarView()
    private let contentHost = NSView()
    private let appTable = NSTableView()
    private var selectedSection: SettingsSection = .general
    private var sidebarButtons: [SettingsSection: SidebarButton] = [:]

    private weak var correctionCountLabel: NSTextField?
    private weak var accessStatusLabel: NSTextField?
    private weak var spellingModeControl: NSSegmentedControl?
    private weak var ignoredWordsField: NSTextField?
    private weak var themeControl: NSSegmentedControl?
    private weak var automaticUpdatesSwitch: NSButton?
    private weak var updateStatusLabel: NSTextField?
    private weak var updateDetailLabel: NSTextField?
    private weak var updateActionButton: NSButton?
    private var pendingUpdateURL: URL?

    convenience init() {
        let window = TraySettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 670),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "KeySwitch"
        window.minSize = NSSize(width: 900, height: 620)
        window.titlebarAppearsTransparent = true
        window.center()
        self.init(window: window)
        configureAppTable()
        buildUI()
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
            sidebar.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 14),
            sidebar.topAnchor.constraint(equalTo: background.topAnchor, constant: 14),
            sidebar.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -14),
            sidebar.widthAnchor.constraint(equalToConstant: 220),
            contentHost.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 18),
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
        header.addArrangedSubview(appMark(size: 40))
        let labels = NSStackView()
        labels.orientation = .vertical
        labels.spacing = 1
        let name = label("KeySwitch", size: 16, weight: .semibold)
        let languages = label("Русский  ⇄  English", size: 10, color: .secondaryLabelColor)
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

        let version = label(AppVersion.display, size: 10, color: .tertiaryLabelColor)
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
        button.contentTintColor = section == selectedSection ? .controlAccentColor : .labelColor
        button.selected = section == selectedSection
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        button.widthAnchor.constraint(equalToConstant: 192).isActive = true
        sidebarButtons[section] = button
        return button
    }

    @objc private func selectSection(_ sender: NSButton) {
        guard let section = SettingsSection(rawValue: sender.tag) else { return }
        showSection(section)
    }

    private func showSection(_ section: SettingsSection) {
        selectedSection = section
        for (value, button) in sidebarButtons {
            button.selected = value == section
            button.font = .systemFont(ofSize: 13,
                                      weight: value == section ? .semibold : .regular)
            button.contentTintColor = value == section ? .controlAccentColor : .labelColor
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

    private func resetWeakControls() {
        correctionCountLabel = nil
        accessStatusLabel = nil
        spellingModeControl = nil
        ignoredWordsField = nil
        themeControl = nil
        automaticUpdatesSwitch = nil
        updateStatusLabel = nil
        updateDetailLabel = nil
        updateActionButton = nil
    }

    private func buildGeneralSection() -> NSView {
        let (view, stack) = sectionCanvas(
            title: "Основные",
            subtitle: "Управление автоматикой и поведением KeySwitch"
        )
        let hero = HeroView()
        hero.translatesAutoresizingMaskIntoConstraints = false
        hero.heightAnchor.constraint(equalToConstant: 120).isActive = true
        let heroStack = NSStackView()
        heroStack.orientation = .horizontal
        heroStack.alignment = .centerY
        heroStack.spacing = 16
        heroStack.translatesAutoresizingMaskIntoConstraints = false
        hero.addSubview(heroStack)
        NSLayoutConstraint.activate([
            heroStack.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 22),
            heroStack.trailingAnchor.constraint(equalTo: hero.trailingAnchor, constant: -22),
            heroStack.centerYAnchor.constraint(equalTo: hero.centerYAnchor)
        ])
        let check = NSImageView(image: symbol("checkmark.circle.fill",
                                             pointSize: 25,
                                             color: .white) ?? NSImage())
        heroStack.addArrangedSubview(check)
        let heroLabels = verticalLabels(
            title: preferences.enabled ? "Автоматика активна" : "Автоматика приостановлена",
            subtitle: "Русский  ⇄  English  ·  язык определяется автоматически",
            light: true
        )
        heroStack.addArrangedSubview(heroLabels)
        heroStack.addArrangedSubview(spacer())
        let count = label("\(preferences.correctionCount) исправлений",
                          size: 11,
                          color: NSColor.white.withAlphaComponent(0.78))
        correctionCountLabel = count
        heroStack.addArrangedSubview(count)
        let enabledSwitch = switchButton(state: preferences.enabled,
                                         action: #selector(toggleEnabled(_:)))
        heroStack.addArrangedSubview(enabledSwitch)
        stack.addArrangedSubview(hero)

        let behavior = card(height: 150)
        behavior.stack.addArrangedSubview(sectionCardHeader(
            symbolName: "switch.2",
            title: "Поведение",
            subtitle: "Звуки и запуск приложения",
            tint: .controlAccentColor
        ))
        behavior.stack.addArrangedSubview(separator())
        behavior.stack.addArrangedSubview(settingRow(
            title: "Звуковой сигнал",
            subtitle: "После автоматического исправления",
            state: preferences.playSound,
            action: #selector(toggleSound(_:))
        ))
        behavior.stack.addArrangedSubview(settingRow(
            title: "Запуск при входе",
            subtitle: "KeySwitch готов к работе сразу после входа",
            state: SMAppService.mainApp.status == .enabled,
            action: #selector(toggleLogin(_:))
        ))
        stack.addArrangedSubview(behavior.view)

        let summary = card(height: 92)
        let summaryRow = NSStackView()
        summaryRow.orientation = .horizontal
        summaryRow.alignment = .centerY
        summaryRow.spacing = 14
        summaryRow.addArrangedSubview(NSImageView(image: symbol(
            "text.badge.checkmark",
            pointSize: 23,
            color: .systemBlue
        ) ?? NSImage()))
        summaryRow.addArrangedSubview(verticalLabels(
            title: "Орфография: \(preferences.spellingMode.displayTitle)",
            subtitle: preferences.spellingMode == .suggestions
                ? "Подсказки появляются после найденной опечатки"
                : "Всплывающее окно не используется"
        ))
        summaryRow.addArrangedSubview(spacer())
        summaryRow.addArrangedSubview(linkButton("Настроить",
                                                 action: #selector(openSpellingSection)))
        summary.stack.addArrangedSubview(summaryRow)
        stack.addArrangedSubview(summary.view)

        stack.addArrangedSubview(footerView())
        return view
    }

    private func buildSpellingSection() -> NSView {
        let (view, stack) = sectionCanvas(
            title: "Орфография",
            subtitle: "Проверка запускается только в выбранном режиме"
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
        mode.selectedSegment = SpellingMode.allCases.firstIndex(
            of: preferences.spellingMode
        ) ?? 0
        mode.segmentDistribution = .fillEqually
        mode.heightAnchor.constraint(equalToConstant: 32).isActive = true
        spellingModeControl = mode
        modeCard.stack.addArrangedSubview(mode)
        stack.addArrangedSubview(modeCard.view)

        let info = card(height: 112)
        info.stack.addArrangedSubview(sectionCardHeader(
            symbolName: "bolt.fill",
            title: "Лёгкий режим",
            subtitle: spellingDescription,
            tint: .controlAccentColor
        ))
        stack.addArrangedSubview(info.view)

        let ignored = card(height: 125)
        ignored.stack.addArrangedSubview(sectionCardHeader(
            symbolName: "textformat.abc",
            title: "Не исправлять эти слова",
            subtitle: "Перечислите слова через запятую",
            tint: .systemOrange
        ))
        let field = NSTextField()
        field.stringValue = preferences.ignoredWords.sorted().joined(separator: ", ")
        field.placeholderString = "API, KeySwitch, productname"
        field.target = self
        field.action = #selector(saveIgnoredWords)
        ignoredWordsField = field
        ignored.stack.addArrangedSubview(field)
        stack.addArrangedSubview(ignored.view)
        stack.addArrangedSubview(footerView())
        return view
    }

    private var spellingDescription: String {
        switch preferences.spellingMode {
        case .off:
            return "Слова не проверяются, системный словарь не вызывается."
        case .suggestions:
            return "После ошибки показывается компактная подсказка на 2,4 секунды."
        case .autoCorrect:
            return "Очевидные ошибки исправляются без создания всплывающего окна."
        }
    }

    private func buildExclusionsSection() -> NSView {
        let (view, stack) = sectionCanvas(
            title: "Исключения",
            subtitle: "В этих приложениях KeySwitch не изменяет ввод"
        )
        let tableCard = card(height: 360)
        let scroll = NSScrollView()
        scroll.documentView = appTable
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        tableCard.stack.addArrangedSubview(scroll)
        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.spacing = 8
        let add = NSButton(title: "Добавить приложение…",
                           target: self,
                           action: #selector(addApplication))
        add.bezelStyle = .rounded
        add.image = symbol("plus", pointSize: 12)
        let remove = NSButton(title: "Удалить выбранное",
                              target: self,
                              action: #selector(removeSelectedApp))
        remove.bezelStyle = .rounded
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
            title: "Разрешения",
            subtitle: "Доступ необходим только для исправления введённого текста"
        )
        let granted = monitor.isTrusted
        let access = card(height: 130)
        access.stack.addArrangedSubview(sectionCardHeader(
            symbolName: granted ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
            title: granted ? "Доступ разрешён" : "Требуется Универсальный доступ",
            subtitle: granted
                ? "KeySwitch готов исправлять раскладку во всех приложениях."
                : "Разрешите KeySwitch управлять вводом в настройках macOS.",
            tint: granted ? .systemGreen : .systemOrange
        ))
        let statusRow = NSStackView()
        statusRow.orientation = .horizontal
        statusRow.addArrangedSubview(spacer())
        let status = label(granted ? "● Активно" : "● Не разрешено",
                           size: 12,
                           weight: .semibold,
                           color: granted ? .systemGreen : .systemOrange)
        accessStatusLabel = status
        statusRow.addArrangedSubview(status)
        if !granted {
            statusRow.addArrangedSubview(NSButton(
                title: "Открыть настройки macOS",
                target: self,
                action: #selector(requestAccess)
            ))
        }
        access.stack.addArrangedSubview(statusRow)
        stack.addArrangedSubview(access.view)

        let privacy = card(height: 135)
        privacy.stack.addArrangedSubview(sectionCardHeader(
            symbolName: "lock.shield",
            title: "Конфиденциальность",
            subtitle: "Введённые слова обрабатываются локально и не сохраняются.",
            tint: .systemBlue
        ))
        let details = label(
            "Сетевой запрос выполняется только для проверки версии KeySwitch через GitHub. Текст ввода в этот запрос не включается.",
            size: 12,
            color: .secondaryLabelColor,
            wrapping: true
        )
        privacy.stack.addArrangedSubview(details)
        stack.addArrangedSubview(privacy.view)
        stack.addArrangedSubview(footerView())
        return view
    }

    private func buildAppearanceSection() -> NSView {
        let (view, stack) = sectionCanvas(
            title: "Оформление",
            subtitle: "KeySwitch может следовать системной теме macOS"
        )
        let themeCard = card(height: 155)
        themeCard.stack.addArrangedSubview(sectionCardHeader(
            symbolName: "circle.lefthalf.filled",
            title: "Тема приложения",
            subtitle: "Системная тема выбрана по умолчанию",
            tint: .controlAccentColor
        ))
        let theme = NSSegmentedControl(
            labels: AppTheme.allCases.map(\.displayTitle),
            trackingMode: .selectOne,
            target: self,
            action: #selector(changeTheme(_:))
        )
        theme.selectedSegment = AppTheme.allCases.firstIndex(
            of: preferences.appTheme
        ) ?? 0
        theme.segmentDistribution = .fillEqually
        theme.heightAnchor.constraint(equalToConstant: 32).isActive = true
        themeControl = theme
        themeCard.stack.addArrangedSubview(theme)
        stack.addArrangedSubview(themeCard.view)

        let glass = card(height: 125)
        glass.stack.addArrangedSubview(sectionCardHeader(
            symbolName: "sparkles",
            title: "Liquid Glass",
            subtitle: "На новых версиях macOS используется системный стеклянный материал.",
            tint: .controlAccentColor
        ))
        glass.stack.addArrangedSubview(label(
            "На macOS 13–15 KeySwitch автоматически применяет совместимый системный материал.",
            size: 12,
            color: .secondaryLabelColor,
            wrapping: true
        ))
        stack.addArrangedSubview(glass.view)
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
        github.image = symbol("link", pointSize: 12)
        appRow.addArrangedSubview(github)
        app.stack.addArrangedSubview(appRow)
        stack.addArrangedSubview(app.view)

        let update = card(height: 190)
        let status = label("Проверка обновлений", size: 16, weight: .semibold)
        let detail = label("Нажмите кнопку, чтобы проверить GitHub Releases.",
                           size: 12,
                           color: .secondaryLabelColor,
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
        let document = NSView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -34),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24)
        ])
        let titleLabel = label(title, size: 27, weight: .bold)
        let subtitleLabel = label(subtitle,
                                  size: 13,
                                  color: .secondaryLabelColor)
        stack.addArrangedSubview(titleLabel)
        stack.setCustomSpacing(2, after: titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.setCustomSpacing(20, after: subtitleLabel)
        return (view, stack)
    }

    private func card(height: CGFloat) -> (view: CardView, stack: NSStackView) {
        let view = CardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
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
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16)
        ])
        view.widthAnchor.constraint(greaterThanOrEqualToConstant: 580).isActive = true
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
                                             pointSize: 23,
                                             color: tint) ?? NSImage())
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
        row.addArrangedSubview(switchButton(state: state, action: action))
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
            color: light ? NSColor.white.withAlphaComponent(0.82) : .secondaryLabelColor,
            wrapping: true
        ))
        return stack
    }

    private func footerView() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        let access = label(monitor.isTrusted ? "● Доступ разрешён" : "● Требуется доступ",
                           size: 11,
                           color: monitor.isTrusted ? .systemGreen : .systemOrange)
        accessStatusLabel = access
        row.addArrangedSubview(access)
        row.addArrangedSubview(spacer())
        row.addArrangedSubview(label(
            "Все данные обрабатываются на этом Mac",
            size: 11,
            color: .tertiaryLabelColor
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
        field.font = .systemFont(ofSize: size, weight: weight)
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
                              state: Bool,
                              action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.setButtonType(.switch)
        button.state = state ? .on : .off
        return button
    }

    private func linkButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.contentTintColor = .controlAccentColor
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
        if color != nil {
            image?.accessibilityDescription = name
        }
        return image
    }

    private func appMark(size: CGFloat) -> NSView {
        let background = NSView()
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        background.layer?.cornerRadius = size * 0.23
        background.widthAnchor.constraint(equalToConstant: size).isActive = true
        background.heightAnchor.constraint(equalToConstant: size).isActive = true
        let image = NSImageView(image: symbol("arrow.triangle.2.circlepath",
                                              pointSize: size * 0.48,
                                              color: .white) ?? NSImage())
        image.contentTintColor = .white
        image.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(image)
        NSLayoutConstraint.activate([
            image.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            image.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            image.widthAnchor.constraint(equalToConstant: size * 0.55),
            image.heightAnchor.constraint(equalToConstant: size * 0.55)
        ])
        return background
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
                                    subtitle: bundleID,
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
        NotificationCenter.default.post(name: .keySwitchStateChanged, object: nil)
        showSection(.general)
    }

    @objc private func toggleSound(_ sender: NSButton) {
        preferences.playSound = sender.state == .on
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
        showSection(.spelling)
    }

    @objc private func saveIgnoredWords() {
        guard let ignoredWordsField else { return }
        let words = ignoredWordsField.stringValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        preferences.ignoredWords = Set(words)
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
            updateDetailLabel.stringValue = error.localizedDescription
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
            updateDetailLabel.stringValue = "Нажмите кнопку, чтобы проверить GitHub Releases."
            updateActionButton.title = "Проверить обновления"
        }
    }

    @objc private func requestAccess() {
        monitor.requestPermission()
        showSection(.permissions)
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

    func showAboutAndCheckForUpdates() {
        showSection(.about)
        if !updateChecker.isChecking {
            checkUpdates(updateActionButton ?? NSButton())
        }
    }

    func refresh() {
        appTable.reloadData()
        correctionCountLabel?.stringValue = "\(preferences.correctionCount) исправлений"
        accessStatusLabel?.stringValue = monitor.isTrusted
            ? "● Доступ разрешён"
            : "● Требуется доступ"
        accessStatusLabel?.textColor = monitor.isTrusted ? .systemGreen : .systemOrange
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
