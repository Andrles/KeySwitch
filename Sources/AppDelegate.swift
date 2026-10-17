import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSPopoverDelegate {
    private lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let monitor = KeyboardMonitor.shared
    private let preferences = Preferences.shared
    private let updateChecker = UpdateChecker.shared
    private lazy var spellingIndicator = SpellingIndicator()
    private var settingsController: SettingsWindowController?
    private let quickPopover = NSPopover()
    private let quickSettings = QuickSettingsController()
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var contextMenu: NSMenu?
    private var toggleItem: NSMenuItem?
    private var statusMenuOpen = false
    private var menuStatusItem: NSMenuItem?
    private var applicationExclusionItem: NSMenuItem?
    private var lastExternalApplication: NSRunningApplication?
    private var permissionTimer: Timer?
    private var suggestionTimer: Timer?
    private var undoIgnoredWord: String?
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
        if CommandLine.arguments.contains("--ui-preview") {
            if CommandLine.arguments.contains("--glass-preview") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    guard let self, self.settingsController?.window != nil else { return }
                    self.spellingIndicator.onApply = { [weak self] in self?.spellingIndicator.showResult(applied: true) }
                    self.spellingIndicator.show(word: "превет", suggestion: "привет",
                        screen: self.settingsController?.window?.screen)
                }
            }
            return
        }
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
                self.toggleQuickSettings()
                presentationCheckPassed = presentationCheckPassed && self.quickPopover.isShown
                presentationCheckPassed = presentationCheckPassed && self.outsideClickMonitor != nil && self.localClickMonitor != nil
                print("Popover click check: shown=\(self.quickPopover.isShown) global=\(self.outsideClickMonitor != nil) local=\(self.localClickMonitor != nil)")
                if let button = self.statusItem.button, let window = button.window {
                    let icon = window.convertToScreen(button.convert(button.bounds, to: nil))
                    self.dismissQuickSettingsIfOutside(NSPoint(x: icon.midX, y: icon.midY))
                    print("Popover icon check: shown=\(self.quickPopover.isShown)")
                    presentationCheckPassed = presentationCheckPassed && self.quickPopover.isShown
                }
                if let window = self.quickSettings.view.window {
                    let inside = NSPoint(x: window.frame.midX, y: window.frame.midY)
                    self.dismissQuickSettingsIfOutside(inside)
                    print("Popover inside check: shown=\(self.quickPopover.isShown)")
                    presentationCheckPassed = presentationCheckPassed && self.quickPopover.isShown
                    self.dismissQuickSettingsIfOutside(NSPoint(x: window.frame.minX - 20, y: window.frame.minY - 20))
                    print("Popover outside check: shown=\(self.quickPopover.isShown) global=\(self.outsideClickMonitor != nil) local=\(self.localClickMonitor != nil)")
                } else { presentationCheckPassed = false }
                guard let menu = self.contextMenu,
                      let index = menu.items.firstIndex(where: { $0.action == #selector(AppDelegate.openSettings) }) else { return }
                menu.performActionForItem(at: index)
            }
            // NSPopover remains shown until its native close animation finishes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                let visible = self?.settingsController?.window?.isVisible == true
                let menuBarOnly = NSApp.activationPolicy() == .accessory
                let outsideClosed = self?.quickPopover.isShown == false &&
                    self?.outsideClickMonitor == nil && self?.localClickMonitor == nil
                presentationCheckPassed = presentationCheckPassed && outsideClosed
                print("Popover close completion: closedAndMonitorsRemoved=\(outsideClosed)")
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
        monitor.onManualCommand = { [weak self] in self?.performManual($0) ?? false }
        monitor.onCorrection = { [weak self] language in
            self?.settingsController?.refresh()
            self?.animateStatusIcon(to: language)
        }
        spellingIndicator.onApply = { [weak self] in _ = self?.monitor.acceptSuggestion() }
        spellingIndicator.onIgnore = { [weak self] word in
            guard let self else { return }
            let key = word.lowercased()
            self.undoIgnoredWord = self.preferences.ignoredWords.contains(key) ? nil : key
            self.monitor.ignoreSuggestion(word: word)
        }
        spellingIndicator.onUndoIgnore = { [weak self] word in
            guard let self, self.undoIgnoredWord == word.lowercased() else { return }
            self.preferences.ignoredWords.remove(word.lowercased())
            self.undoIgnoredWord = nil
        }
        spellingIndicator.onDismiss = { [weak self] in self?.monitor.dismissSuggestion() }
        monitor.isInteractingWithMenu = { [weak self] in (self?.statusMenuOpen ?? false) || (self?.quickPopover.isShown ?? false) || (self?.spellingIndicator.isMenuOpen ?? false) }
        monitor.preservesFeedbackAtPoint = { [weak self] point in
            guard let self else { return false }
            if self.statusMenuOpen || self.quickPopover.isShown || self.spellingIndicator.isMenuOpen || self.spellingIndicator.contains(eventPoint: point) { return true }
            guard let button = self.statusItem.button, let window = button.window else { return false }
            let screenPoint = NSPoint(x: point.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - point.y)
            return window.convertToScreen(button.convert(button.bounds, to: nil)).contains(screenPoint)
        }
        monitor.isFeedbackVisible = { [weak self] in self?.spellingIndicator.isVisible ?? false }
        monitor.onSuggestionResult = { [weak self] in self?.spellingIndicator.showResult(applied: $0) }
        monitor.onFeedbackInvalidated = { [weak self] in
            self?.spellingIndicator.hide()
            self?.undoIgnoredWord = nil
        }
        monitor.onSpellingIssue = { [weak self] word, suggestion in
            let context = TextInputContext.current()
            self?.spellingIndicator.show(word: word, suggestion: suggestion, screen: context?.screen)
        }
        // Programmatic focus changes do not always generate an input event.
        suggestionTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            _ = self?.monitor.validatePendingSuggestion()
        }
        if let suggestionTimer { RunLoop.main.add(suggestionTimer, forMode: .common) }
        preferences.defaults.set(Date(), forKey: "lastLaunchDate")
        lastPermissionState = monitor.isTrusted
        if monitor.isTrusted {
            monitor.start()
        }
        lastMonitorRunning = monitor.isRunning
        if CommandLine.arguments.contains("--runtime-check") {
            print("KeySwitch runtime check: trusted=\(monitor.isTrusted) running=\(monitor.isRunning) target=TextEdit isolatedPreferences=true")
            fflush(stdout)
        }
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
        menuStatusItem = header
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
        let manual = NSMenuItem(title: "Горячие клавиши", action: nil, keyEquivalent: "")
        let actions = NSMenu()
        for command in ManualCommand.allCases {
            let item = NSMenuItem(title: command.title, action: #selector(manualAction(_:)), keyEquivalent: "")
            item.target = self
            item.tag = command.rawValue
            actions.addItem(item)
        }
        manual.submenu = actions
        menu.addItem(manual)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Настройки…",
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
        let permission = NSMenuItem(title: "Доступ macOS…",
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
        contextMenu = menu
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        quickPopover.contentViewController = quickSettings
        quickPopover.behavior = .transient
        quickPopover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        quickPopover.delegate = self
        quickSettings.onToggle = { [weak self] in self?.toggleEnabled() }
        quickSettings.onSettings = { [weak self] in self?.quickPopover.performClose(nil); self?.openSettings() }
        quickSettings.onPermission = { [weak self] in self?.quickPopover.performClose(nil); self?.checkPermission() }
        quickSettings.onMore = { [weak self] in
            self?.quickPopover.performClose(nil)
            DispatchQueue.main.async { [weak self] in self?.showContextMenu() }
        }
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp { showContextMenu() }
        else { toggleQuickSettings() }
    }

    private func showContextMenu() {
        quickPopover.performClose(nil)
        guard let menu = contextMenu, let button = statusItem.button else { return }
        updateApplicationExclusionItem()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY - 4), in: button)
    }

    private func toggleQuickSettings() {
        if quickPopover.isShown { quickPopover.performClose(nil); return }
        guard let button = statusItem.button else { return }
        captureExternalApplication(NSWorkspace.shared.frontmostApplication)
        monitor.invalidateContext()
        spellingIndicator.hide()
        quickSettings.refresh(state: monitor.state, enabled: preferences.enabled)
        quickPopover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        quickPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if quickPopover.isShown { startOutsideClickMonitoring() }
    }

    private func startOutsideClickMonitoring() {
        stopOutsideClickMonitoring()
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        // Transient popovers can remain open when an accessory application was
        // never active. Observe desktop/other-app clicks without consuming them.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.dismissQuickSettingsIfOutside(NSEvent.mouseLocation)
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.dismissQuickSettingsIfOutside(NSEvent.mouseLocation)
            return event
        }
    }

    private func dismissQuickSettingsIfOutside(_ point: NSPoint) {
        guard quickPopover.isShown else { return }
        if let window = quickSettings.view.window, window.frame.contains(point) { return }
        // The status button handles its own toggle on mouse-up. Closing here on
        // mouse-down would immediately reopen the panel on the same click.
        if let button = statusItem.button, let window = button.window,
           window.convertToScreen(button.convert(button.bounds, to: nil)).contains(point) { return }
        quickPopover.performClose(nil)
    }

    private func stopOutsideClickMonitoring() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        outsideClickMonitor = nil
        localClickMonitor = nil
    }

    func popoverDidClose(_ notification: Notification) {
        stopOutsideClickMonitoring()
        statusMenuOpen = false
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopOutsideClickMonitoring()
    }

    func menuWillOpen(_ menu: NSMenu) {
        statusMenuOpen = true
        updateApplicationExclusionItem()
    }

    func menuDidClose(_ menu: NSMenu) { statusMenuOpen = false }

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
        quickSettings.refresh(state: state, enabled: preferences.enabled)
        menuStatusItem?.title = state.title
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
        let isExcluded = preferences.excludesApplication(bundleID)
        item.title = isExcluded
            ? "Исправлять в «\(name)»"
            : "Не исправлять в «\(name)»"
        item.representedObject = bundleID
        item.image = applicationMenuIcon(application)
        item.isEnabled = true
    }

    @objc private func toggleActiveApplicationExclusion(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        if preferences.excludesApplication(bundleID) {
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
        quickPopover.performClose(nil)
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
        guard settingsController?.commitPendingEdits() != false else { return }
        settingsController?.window?.orderOut(nil)
        applyPresentation()
    }

    @objc private func handleHideRequest(_ notification: Notification) {
        hideSettings()
    }

    @objc private func manualAction(_ sender: NSMenuItem) {
        guard let command = ManualCommand(rawValue: sender.tag) else { return }
        _ = performManual(command)
    }

    private func performManual(_ command: ManualCommand) -> Bool {
        let result: ManualEditResult
        switch command {
        case .layout:
            let selection = SelectionEditor.performResult(command)
            if selection == .noSelection {
                result = monitor.convertCurrentWord() ? .success : .noWord
            } else { result = selection }
        case .uppercase, .lowercase: result = SelectionEditor.performResult(command)
        case .accept: result = monitor.acceptSuggestion() ? .success : .noSuggestion
        case .undo: result = monitor.restoreLastCorrection() ? .success : .noUndo
        }
        if result != .success { ManualFeedback.shared.show(result.message) }
        return result == .success
    }

    @objc private func checkPermission() {
        openSettings()
        settingsController?.showPermissions()
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
        let name: String
        switch monitor.state {
        case .ready: name = "arrow.left.arrow.right"
        case .paused: name = "pause.circle"
        case .needsPermission, .failed: name = "exclamationmark.triangle"
        }
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
