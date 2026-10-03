import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let monitor = KeyboardMonitor.shared
    private let preferences = Preferences.shared
    private let updateChecker = UpdateChecker.shared
    private lazy var spellingIndicator = SpellingIndicator()
    private var settingsController: SettingsWindowController?
    private var toggleItem: NSMenuItem?
    private var applicationExclusionItem: NSMenuItem?
    private var lastExternalApplication: NSRunningApplication?
    private var permissionTimer: Timer?
    private var displayedLanguage: Language = .english
    private var lastPermissionState = false
    private var lastMonitorRunning = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppearanceController.apply(preferences.appTheme)
        // Show the primary UI before input monitoring or update checks start.
        openSettings()
        configureStatusItem()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refreshMenu),
                                               name: .keySwitchStateChanged,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleHideRequest(_:)),
                                               name: .keySwitchHideRequested,
                                               object: nil)
        refreshMenu()
        if CommandLine.arguments.contains("--ui-preview") { return }
        if CommandLine.arguments.contains("--launch-check") {
            var presentationCheckPassed = NSApp.activationPolicy() == .accessory
            print("Initial: controller=\(settingsController != nil) window=\(settingsController?.window != nil) visible=\(settingsController?.window?.isVisible == true)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self else { return }
                self.preferences.menuBarOnly = false
                self.refreshMenu()
                presentationCheckPassed = presentationCheckPassed && NSApp.activationPolicy() == .regular
                self.preferences.menuBarOnly = true
                self.refreshMenu()
                presentationCheckPassed = presentationCheckPassed && NSApp.activationPolicy() == .accessory
                self.hideSettings()
                guard let menu = self.statusItem.menu,
                      let index = menu.items.firstIndex(where: { $0.action == #selector(AppDelegate.openSettings) }) else { return }
                menu.performActionForItem(at: index)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                let visible = self?.settingsController?.window?.isVisible == true
                let menuBarOnly = NSApp.activationPolicy() == .accessory
                print("KeySwitch launch check: delegate=\(self != nil) window=\(self?.settingsController?.window != nil) windowVisible=\(visible) menuBarOnly=\(menuBarOnly) dockToggle=\(presentationCheckPassed)")
                fflush(stdout)
                exit(visible && menuBarOnly && presentationCheckPassed ? 0 : 1)
            }
            return
        }
        captureExternalApplication(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeApplicationDidChange(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        monitor.onCorrection = { [weak self] language in
            self?.settingsController?.refresh()
            self?.animateStatusIcon(to: language)
        }
        spellingIndicator.onIgnore = { [weak self] word in self?.monitor.ignoreSuggestion(word: word) }
        spellingIndicator.onDismiss = { [weak self] in self?.monitor.dismissSuggestion() }
        monitor.preservesFeedbackAtPoint = { [weak self] in self?.spellingIndicator.contains(eventPoint: $0) ?? false }
        monitor.onFeedbackInvalidated = { [weak self] in self?.spellingIndicator.hide() }
        monitor.onSpellingIssue = { [weak self] word, suggestion in
            self?.spellingIndicator.show(word: word, suggestion: suggestion)
        }
        preferences.defaults.set(Date(), forKey: "lastLaunchDate")
        lastPermissionState = monitor.isTrusted
        if monitor.isTrusted {
            monitor.start()
        }
        lastMonitorRunning = monitor.isRunning
        monitor.onPermissionChanged = { [weak self] _ in
            self?.settingsController?.refresh()
            self?.refreshMenu()
        }
        permissionTimer = Timer.scheduledTimer(timeInterval: 1,
                                               target: self,
                                               selector: #selector(pollPermission),
                                               userInfo: nil,
                                               repeats: true)
        if let permissionTimer {
            RunLoop.main.add(permissionTimer, forMode: .common)
        }
        refreshMenu()
        if updateChecker.shouldCheckAutomatically {
            updateChecker.check { _ in }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    private func configureStatusItem() {
        statusItem.button?.title = ""
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "KeySwitch"
        let menu = NSMenu()
        menu.delegate = self
        let header = NSMenuItem(title: "KeySwitch", action: nil, keyEquivalent: "")
        header.isEnabled = false
        header.image = menuSymbol("keyboard")
        menu.addItem(header)
        menu.addItem(.separator())
        let toggle = NSMenuItem(title: "", action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        toggleItem = toggle
        menu.addItem(toggle)
        let exclusion = NSMenuItem(title: "Определяю активное приложение…",
                                   action: #selector(toggleActiveApplicationExclusion),
                                   keyEquivalent: "")
        exclusion.target = self
        applicationExclusionItem = exclusion
        menu.addItem(exclusion)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Открыть KeySwitch…",
                                  action: #selector(openSettings),
                                  keyEquivalent: ",")
        settings.target = self
        settings.image = menuSymbol("gearshape")
        menu.addItem(settings)
        let hide = NSMenuItem(title: "Скрыть окно",
                              action: #selector(hideSettings),
                              keyEquivalent: "m")
        hide.target = self
        hide.image = menuSymbol("menubar.rectangle")
        menu.addItem(hide)
        let permission = NSMenuItem(title: "Проверить доступ macOS",
                                    action: #selector(checkPermission),
                                    keyEquivalent: "")
        permission.target = self
        permission.image = menuSymbol("hand.raised")
        menu.addItem(permission)
        let updates = NSMenuItem(title: "Проверить обновления…",
                                 action: #selector(checkForUpdates),
                                 keyEquivalent: "")
        updates.target = self
        updates.image = menuSymbol("arrow.triangle.2.circlepath")
        menu.addItem(updates)
        let version = NSMenuItem(title: AppVersion.display,
                                 action: nil,
                                 keyEquivalent: "")
        version.isEnabled = false
        version.toolTip = "Сборка \(AppVersion.build)"
        menu.addItem(version)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Завершить KeySwitch",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        quit.target = NSApp
        quit.image = menuSymbol("xmark.square")
        menu.addItem(quit)
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateApplicationExclusionItem()
    }

    @objc private func toggleEnabled() {
        preferences.enabled.toggle()
        monitor.invalidateContext()
        NotificationCenter.default.post(name: .keySwitchStateChanged, object: nil)
    }

    private func applyPresentation() {
        let policy: NSApplication.ActivationPolicy = preferences.menuBarOnly ? .accessory : .regular
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
    }

    @objc private func refreshMenu() {
        applyPresentation()
        settingsController?.refresh()
        let state = monitor.state
        statusItem.button?.toolTip = "KeySwitch: \(state.title)"
        statusItem.button?.setAccessibilityLabel("KeySwitch: \(state.title)")
        toggleItem?.title = preferences.enabled ? "Поставить на паузу" : "Включить исправление"
        toggleItem?.image = menuSymbol(preferences.enabled ? "pause.circle" : "play.circle")
        statusItem.button?.image = makeStatusImage(
            enabled: state == .ready,
            glyph: statusGlyph(for: displayedLanguage)
        )
    }

    @objc private func activeApplicationDidChange(_ notification: Notification) {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication
        monitor.invalidateContext()
        spellingIndicator.hide()
        captureExternalApplication(application)
    }

    private func captureExternalApplication(_ application: NSRunningApplication?) {
        guard let application,
              application.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        lastExternalApplication = application
    }

    private func updateApplicationExclusionItem() {
        guard let item = applicationExclusionItem,
              let application = lastExternalApplication,
              let bundleID = application.bundleIdentifier else {
            applicationExclusionItem?.title = "Активное приложение не определено"
            applicationExclusionItem?.isEnabled = false
            return
        }
        let name = application.localizedName ?? "Приложение"
        let isExcluded = preferences.excludedApps.contains(bundleID)
        item.title = isExcluded
            ? "Исправлять в «\(name)»"
            : "Не исправлять в «\(name)»"
        item.representedObject = bundleID
        item.image = applicationMenuIcon(application)
        item.isEnabled = true
    }

    @objc private func toggleActiveApplicationExclusion(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        if preferences.excludedApps.contains(bundleID) {
            preferences.excludedApps.removeAll { $0 == bundleID }
        } else {
            preferences.excludedApps.append(bundleID)
        }
        monitor.invalidateContext()
        settingsController?.refresh()
        updateApplicationExclusionItem()
    }

    @objc private func pollPermission() {
        let trusted = monitor.isTrusted
        if trusted != lastPermissionState { monitor.resetRetry() }
        if trusted && !monitor.isRunning {
            monitor.start()
        } else if !trusted {
            monitor.stop()
        }
        if !updateChecker.isChecking && updateChecker.shouldCheckAutomatically {
            updateChecker.check { _ in }
        }
        if trusted != lastPermissionState || monitor.isRunning != lastMonitorRunning {
            lastPermissionState = trusted
            lastMonitorRunning = monitor.isRunning
            refreshMenu()
        }
    }

    @objc private func openSettings() {
        applyPresentation()
        if settingsController == nil { settingsController = SettingsWindowController(initialSection: 0) }
        settingsController?.refresh()
        settingsController?.showWindow(nil)
        guard let window = settingsController?.window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    @objc private func hideSettings() {
        settingsController?.commitPendingEdits()
        settingsController?.window?.orderOut(nil)
        applyPresentation()
    }

    @objc private func handleHideRequest(_ notification: Notification) {
        hideSettings()
    }

    @objc private func checkPermission() {
        if monitor.isTrusted {
            monitor.resetRetry()
            monitor.start()
            let alert = NSAlert()
            alert.messageText = monitor.state.title
            alert.informativeText = monitor.state.detail
            alert.runModal()
        } else {
            showOnboarding()
        }
    }

    @objc private func checkForUpdates() {
        openSettings()
        settingsController?.showAboutAndCheckForUpdates()
    }

    private func showOnboarding() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Разрешите KeySwitch исправлять ввод"
        alert.informativeText = """
        macOS требует доступ «Универсальный доступ» для глобального исправления раскладки.
        История печати не сохраняется. Настройки и добавленные вами исключения хранятся на этом Mac.
        """
        alert.addButton(withTitle: "Открыть системный запрос")
        alert.addButton(withTitle: "Позже")
        if alert.runModal() == .alertFirstButtonReturn {
            monitor.requestPermission()
        }
    }

    private func animateStatusIcon(to language: Language) {
        displayedLanguage = language
        refreshMenu()
    }

    private func statusGlyph(for language: Language) -> String {
        language == .russian ? "RU" : "EN"
    }

    private func makeStatusImage(enabled: Bool, glyph: String) -> NSImage {
        let name = enabled ? "keyboard" : "keyboard.badge.ellipsis"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "KeySwitch")?
            .withSymbolConfiguration(.init(pointSize: 17, weight: .regular)) ?? NSImage()
        image.isTemplate = true
        return image
    }

    private func menuSymbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .regular))
    }

    private func applicationMenuIcon(_ application: NSRunningApplication) -> NSImage? {
        guard let source = application.icon?.copy() as? NSImage else { return menuSymbol("app") }
        source.size = NSSize(width: 18, height: 18)
        return source
    }
}
