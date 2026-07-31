import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let monitor = KeyboardMonitor.shared
    private let preferences = Preferences.shared
    private let spellingIndicator = SpellingIndicator()
    private var settingsController: SettingsWindowController?
    private var toggleItem: NSMenuItem?
    private var applicationExclusionItem: NSMenuItem?
    private var lastExternalApplication: NSRunningApplication?
    private var permissionTimer: Timer?
    private var iconAnimationTimer: Timer?
    private var displayedLanguage: Language = .english
    private var lastPermissionState = false
    private var lastMonitorRunning = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
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
        monitor.onSpellingIssue = { [weak self] word, suggestion in
            self?.spellingIndicator.show(word: word, suggestion: suggestion)
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refreshMenu),
                                               name: .keySwitchStateChanged,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleHideRequest(_:)),
                                               name: .keySwitchHideRequested,
                                               object: nil)
        preferences.defaults.set(Date(), forKey: "lastLaunchDate")
        preferences.defaults.synchronize()
        lastPermissionState = monitor.isTrusted
        if monitor.isTrusted {
            monitor.start()
        }
        lastMonitorRunning = monitor.isRunning
        monitor.onPermissionChanged = { [weak self] _ in
            self?.pollPermission()
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            self.openSettings()
            if !self.monitor.isTrusted {
                self.showOnboarding()
            }
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

        let settings = NSMenuItem(title: "Настройки…",
                                  action: #selector(openSettings),
                                  keyEquivalent: ",")
        settings.image = menuSymbol("gearshape")
        menu.addItem(settings)
        let hide = NSMenuItem(title: "Свернуть в строку меню",
                              action: #selector(hideSettings),
                              keyEquivalent: "m")
        hide.image = menuSymbol("menubar.rectangle")
        menu.addItem(hide)
        let permission = NSMenuItem(title: "Проверить разрешение",
                                    action: #selector(checkPermission),
                                    keyEquivalent: "")
        permission.image = menuSymbol("hand.raised")
        menu.addItem(permission)
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
        quit.image = menuSymbol("xmark.square")
        menu.addItem(quit)
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateApplicationExclusionItem()
    }

    @objc private func toggleEnabled() {
        preferences.enabled.toggle()
        refreshMenu()
    }

    @objc private func refreshMenu() {
        toggleItem?.title = preferences.enabled ? "Приостановить автоматику" : "Включить автоматику"
        toggleItem?.image = menuSymbol(preferences.enabled ? "pause.circle" : "play.circle")
        statusItem.button?.image = makeStatusImage(
            enabled: preferences.enabled,
            glyph: statusGlyph(for: displayedLanguage)
        )
    }

    @objc private func activeApplicationDidChange(_ notification: Notification) {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication
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
            ? "Убрать «\(name)» из исключений"
            : "Добавить «\(name)» в исключения"
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
        settingsController?.refresh()
        updateApplicationExclusionItem()
    }

    @objc private func pollPermission() {
        let trusted = monitor.isTrusted
        if trusted && !monitor.isRunning {
            monitor.start()
        } else if !trusted && monitor.isRunning {
            monitor.stop()
        }
        if trusted != lastPermissionState || monitor.isRunning != lastMonitorRunning {
            lastPermissionState = trusted
            lastMonitorRunning = monitor.isRunning
            settingsController?.refresh()
        }
    }

    @objc private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        if settingsController == nil { settingsController = SettingsWindowController() }
        settingsController?.refresh()
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
        settingsController?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func hideSettings() {
        settingsController?.window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    @objc private func handleHideRequest(_ notification: Notification) {
        hideSettings()
    }

    @objc private func checkPermission() {
        if monitor.isTrusted {
            monitor.start()
            let alert = NSAlert()
            alert.messageText = "Всё готово"
            alert.informativeText = "Доступ разрешён, автоматическое исправление работает."
            alert.runModal()
        } else {
            showOnboarding()
        }
    }

    private func showOnboarding() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Разрешите KeySwitch исправлять ввод"
        alert.informativeText = """
        macOS требует доступ «Универсальный доступ» для глобального исправления раскладки.
        Набранный текст обрабатывается только на этом Mac и нигде не сохраняется.
        """
        alert.addButton(withTitle: "Открыть системный запрос")
        alert.addButton(withTitle: "Позже")
        if alert.runModal() == .alertFirstButtonReturn {
            monitor.requestPermission()
        }
    }

    private func animateStatusIcon(to language: Language) {
        iconAnimationTimer?.invalidate()
        guard preferences.enabled else { return }

        let startLanguage = displayedLanguage
        let frames: [(glyph: String, rotation: CGFloat)] = [
            (statusGlyph(for: startLanguage), 0),
            ("·", 50),
            (statusGlyph(for: language), 100),
            (statusGlyph(for: language), 150),
            (statusGlyph(for: language), 0)
        ]
        var frameIndex = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.075,
                                         repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let frame = frames[frameIndex]
            self.statusItem.button?.image = self.makeStatusImage(
                enabled: true,
                glyph: frame.glyph,
                rotation: frame.rotation
            )
            frameIndex += 1
            if frameIndex == frames.count {
                timer.invalidate()
                self.displayedLanguage = language
                self.statusItem.button?.image = self.makeStatusImage(
                    enabled: true,
                    glyph: self.statusGlyph(for: language)
                )
            }
        }
        iconAnimationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func statusGlyph(for language: Language) -> String {
        language == .russian ? "Я" : "A"
    }

    private func makeStatusImage(enabled: Bool,
                                 glyph: String,
                                 rotation: CGFloat = 0) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let result = NSImage(size: size)
        result.lockFocus()
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let arrows = NSImage(systemSymbolName: "arrow.triangle.2.circlepath",
                             accessibilityDescription: "KeySwitch")?
            .withSymbolConfiguration(configuration)
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: 9, yBy: 9)
        transform.rotate(byDegrees: rotation)
        transform.translateX(by: -9, yBy: -9)
        transform.concat()
        arrows?.draw(in: NSRect(x: 1, y: 1, width: 16, height: 16))
        NSGraphicsContext.restoreGraphicsState()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 7, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ]
        let glyphSize = glyph.size(withAttributes: attributes)
        glyph.draw(at: NSPoint(x: (18 - glyphSize.width) / 2,
                               y: (18 - glyphSize.height) / 2 - 0.5),
                   withAttributes: attributes)
        if !enabled {
            NSColor.labelColor.setStroke()
            let slash = NSBezierPath()
            slash.lineWidth = 1.8
            slash.move(to: NSPoint(x: 3, y: 3))
            slash.line(to: NSPoint(x: 15, y: 15))
            slash.stroke()
        }
        result.unlockFocus()
        result.isTemplate = true
        return result
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
