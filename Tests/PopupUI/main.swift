import AppKit

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fputs("PopupUI FAIL: \(message)\n", stderr); exit(1) }
}
func descendants(_ view: NSView) -> [NSView] {
    [view] + view.subviews.flatMap(descendants)
}
final class PopupTestDelegate: NSObject, NSApplicationDelegate {
    let indicator = SpellingIndicator()
    var dictionaryWindow: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let preferences = Preferences.shared
        require(CommandLine.arguments.contains("--ui-preview"), "isolated preferences required")
        var reducedTransparency = false
        var increasedContrast = false
        let surface = MaterialSurface(role: .popover, accessibility: {
            .init(reduceTransparency: reducedTransparency, increaseContrast: increasedContrast)
        })
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            surface.appearance = NSAppearance(named: appearance)
            for flags in [(false, false), (true, false), (false, true), (false, false)] {
                reducedTransparency = flags.0; increasedContrast = flags.1
                surface.refreshMaterial()
                require(surface.effect.isHidden == (flags.0 || flags.1), "material accessibility fallback")
                require(surface.layer?.backgroundColor?.alpha == (flags.0 || flags.1 ? 1 : 0), "solid fallback opacity")
            }
        }
        // Exercise all settings pages at their smallest supported size. Vertical
        // scrolling is intentional; horizontal clipping and dead switches are not.
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            NSApp.appearance = NSAppearance(named: appearance)
            for section in 0..<8 {
                let controller = SettingsWindowController(initialSection: section)
                let window = controller.window!
                window.setContentSize(NSSize(width: 760, height: 560))
                window.orderFront(nil)
                window.contentView!.layoutSubtreeIfNeeded()
                let views = descendants(window.contentView!)
                for view in views where !view.isHiddenOrHasHiddenAncestor &&
                    (view is NSControl) && view.bounds.width > 0 {
                    let frame = view.convert(view.bounds, to: window.contentView)
                    require(frame.minX >= -1 && frame.maxX <= window.contentView!.bounds.width + 1,
                            "horizontal clipping in settings section \(section): \(frame)")
                }
                if section == 5 {
                    require(views.compactMap { $0 as? NSButton }.contains { $0.title == "Завершить KeySwitch" && $0.action == NSSelectorFromString("quitApplication") && $0.keyEquivalent == "q" }, "quit remains accessible in About")
                    require(views.compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Проверять обновления автоматически" }, "automatic updates need a visible label")
                }
                if section == 0 {
                    require(views.compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Автоисправления" }, "global pause must name all automatic features")
                    let control = views.compactMap { $0 as? NSSwitch }.first!
                    let original = preferences.enabled
                    control.state = original ? .off : .on
                    require(NSApp.sendAction(control.action!, to: control.target, from: control), "native switch action")
                    require(preferences.enabled != original, "native switch must update correction preference")
                    preferences.enabled = original
                }
                if [0, 2, 5].contains(section), let content = window.contentView,
                   let image = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
                    content.cacheDisplay(in: content.bounds, to: image)
                    let theme = appearance == .aqua ? "light" : "dark"
                    if let png = image.representation(using: .png, properties: [:]) {
                        try? png.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath + "/build/tests/settings-\(section)-\(theme).png"))
                    }
                }
                window.orderOut(nil)
            }
        }
        print("Settings/material regressions: OK (8 pages, light/dark, minimum width, native switch, opaque accessibility fallback)")
        // Keep the same top/right margins as feedback changes height.
        for visible in [NSRect(x: 0, y: 0, width: 1440, height: 900),
                        NSRect(x: -1280, y: -200, width: 1280, height: 800)] {
            for height: CGFloat in [132, 180, 350, 1600] {
                let frame = SuggestionPlacement.frame(size: NSSize(width: 330, height: height), visibleFrame: visible)
                require(visible.contains(frame), "suggestion must fit chosen screen")
                require(frame.maxX == visible.maxX - 12 && frame.maxY == visible.maxY - 12,
                        "suggestion must stay in top-right corner after resizing")
            }
        }
        let quick = QuickSettingsController()
        let quickWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 350, height: 300), styleMask: [.borderless], backing: .buffered, defer: false)
        quickWindow.contentView = quick.view
        quickWindow.orderFront(nil)
        var toggled = false, recovered = false
        var actions: [QuickSettingsController.Action] = []
        quick.onToggle = { toggled = true }
        quick.onRetry = { recovered = true }
        quick.onAction = { actions.append($0) }
        let names: [String?] = ["TextEdit", "Microsoft Visual Studio Code — Insiders", nil, "Я", "👩🏽‍💻 Рабочие заметки", "محرر النصوص"]
        var scenarios = 0
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            quick.view.appearance = NSAppearance(named: appearance)
            for state in [MonitorState.ready, .paused, .needsPermission, .failed] {
                for (index, name) in names.enumerated() {
                    scenarios += 1
                    toggled = false; recovered = false; actions = []
                    quick.refresh(state: state, enabled: state != .paused)
                    quick.refreshApplication(name: name, excluded: index % 2 == 1)
                    require(quick.preferredContentSize.width == 350 && quick.preferredContentSize.height > 100 && quick.preferredContentSize.height < 420, "compact panel size")
                    quickWindow.setContentSize(quick.preferredContentSize)
                    quick.view.layoutSubtreeIfNeeded()
                    let views = descendants(quick.view)
                    for control in views where control is NSControl && !control.isHiddenOrHasHiddenAncestor {
                        let frame = control.convert(control.bounds, to: quick.view)
                        require(quick.view.bounds.insetBy(dx: -1, dy: -1).contains(frame), "tray clipped for \(name ?? "nil"): \(frame)")
                    }
                    let buttons = views.compactMap { $0 as? NSButton }
                    require(!buttons.contains { ["Ещё действия…", "Настройки…", "Завершить KeySwitch", "Горячие клавиши…", "Доступ macOS…", "Проверить обновления…", "Скрыть окно настроек"].contains($0.title) }, "no duplicated service menu")
                    let switches = views.compactMap { $0 as? NSSwitch }
                    require(switches.count == 2, "global and application rules")
                    require(switches[0].state == (state == .paused ? .off : .on), "global preference")
                    require(switches[1].isEnabled == (name != nil), "unknown application must disable rule")
                    require(switches[1].state == (index % 2 == 1 ? .off : .on), "positive application rule")
                    NSApp.sendAction(switches[0].action!, to: switches[0].target, from: switches[0])
                    require(toggled, "global callback")
                    if switches[1].isEnabled {
                        NSApp.sendAction(switches[1].action!, to: switches[1].target, from: switches[1])
                        require(actions.last == .exclusion, "application callback")
                    }
                    let open = buttons.first { $0.title == "Открыть приложение" }!
                    open.performClick(nil)
                    require(actions.last == .settings, "application entry callback")
                    let recovery = buttons.first { $0.action == NSSelectorFromString("recover") }!
                    require(recovery.isHidden == (state == .ready || state == .paused), "contextual recovery")
                    if !recovery.isHidden {
                        recovery.performClick(nil)
                        require(state == .failed ? recovered : actions.last == .permission, "recovery matches problem")
                    }
                    if let name {
                        require(views.compactMap { $0 as? NSTextField }.contains { $0.stringValue == name && $0.toolTip == name }, "full application name remains available")
                    }
                    if index == 0 {
                        // Capture the settled native NSSwitch animation, not an
                        // intermediate frame after changing its model state.
                        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
                    }
                    if index == 0, let image = quick.view.bitmapImageRepForCachingDisplay(in: quick.view.bounds) {
                        quick.view.cacheDisplay(in: quick.view.bounds, to: image)
                        let theme = appearance == .aqua ? "light" : "dark"
                        let suffix = state == .ready ? "ready" : state == .paused ? "paused" : state == .needsPermission ? "permission" : "failed"
                        try? image.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath + "/build/tests/tray-\(theme)-\(suffix).png"))
                    }
                }
            }
        }
        quickWindow.orderOut(nil)
        print("Compact tray matrix: OK (\(scenarios) scenarios, long/empty names, actions, recovery, application rule)")
        print("Glass regressions: OK (top-right positioning, negative display coordinates, resized feedback, quick settings states/actions)")
        func checkPopupContent() {
            let panel = NSApp.windows.first { $0 is NSPanel && $0.isVisible }!
            panel.contentView!.layoutSubtreeIfNeeded()
            for control in descendants(panel.contentView!) where !control.isHiddenOrHasHiddenAncestor && (control is NSTextField || control is NSButton) {
                require(panel.contentView!.bounds.insetBy(dx: -1, dy: -1).contains(control.convert(control.bounds, to: panel.contentView)), "popup feedback state must fit")
            }
        }
        var ignored = "", undone = "", dismissed = false
        indicator.onApply = { self.indicator.showResult(applied: false) }
        indicator.onIgnore = { ignored = $0 }
        indicator.onUndoIgnore = { undone = $0 }
        indicator.onDismiss = { dismissed = true }
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            NSApp.appearance = NSAppearance(named: appearance)
            for pair in [("превет", "привет"), ("электроэнцефалографическй", "электроэнцефалографический"),
                         ("antidisestablishmentarianim", "antidisestablishmentarianism"),
                         ("Rindfleischetikettierungsüberwachungsaufgabenübertragungsgeset", "Rindfleischetikettierungsüberwachungsaufgabenübertragungsgesetz")] {
                indicator.show(word: pair.0, suggestion: pair.1)
                let panel = NSApp.windows.first { $0 is NSPanel && $0.isVisible }!
                panel.contentView!.layoutSubtreeIfNeeded()
                let views = descendants(panel.contentView!)
                for view in views where !view.isHiddenOrHasHiddenAncestor && (view is NSTextField || view is NSButton) {
                    let frame = view.convert(view.bounds, to: panel.contentView)
                    require(panel.contentView!.bounds.insetBy(dx: -1, dy: -1).contains(frame), "content outside popup: \(frame)")
                }
                if pair.0 == "превет", let content = panel.contentView,
                   let image = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
                    content.cacheDisplay(in: content.bounds, to: image)
                    let name = appearance == .aqua ? "glass-popup-light.png" : "glass-popup-dark.png"
                    if let data = image.representation(using: .png, properties: [:]) {
                        try? data.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                            .appendingPathComponent("build/tests/" + name))
                    }
                }
                let replace = views.compactMap { $0 as? NSButton }.first { $0.title == "Заменить" }!
                replace.performClick(nil)
                require(indicator.isVisible, "failed replacement must stay visible")
                checkPopupContent()
                require(views.compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Не удалось подтвердить замену" }, "failure text missing")
                indicator.show(word: pair.0, suggestion: pair.1)
                let more = views.compactMap { $0 as? NSPopUpButton }.first!
                let ignoreIndex = more.menu!.items.firstIndex { $0.title == "Не предлагать это слово" }!
                more.menu!.performActionForItem(at: ignoreIndex)
                require(ignored == pair.0 && indicator.isVisible, "ignore confirmation")
                checkPopupContent()
                let undo = views.compactMap { $0 as? NSButton }.first { $0.title == "Отменить исключение" }!
                require(!undo.isHidden, "undo missing")
                undo.performClick(nil)
                require(undone == pair.0 && undo.isHidden, "undo callback/state")
                checkPopupContent()
                indicator.show(word: pair.0, suggestion: pair.1)
                views.compactMap { $0 as? NSButton }.first { $0.title == "Пропустить" }!.performClick(nil)
                require(dismissed && !indicator.isVisible, "skip must close")
            }
        }
        var failureReported = false
        KeyboardMonitor.shared.onSuggestionResult = { failureReported = !$0 }
        require(!KeyboardMonitor.shared.acceptSuggestion() && failureReported, "empty pending edit must report failure")
        let monitor = KeyboardMonitor.shared
        var visible = true, invalidated = false
        monitor.isFeedbackVisible = { visible }
        monitor.onFeedbackInvalidated = { invalidated = true }
        let escape = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true)!
        escape.flags = []
        require(monitor.consumesTestKey(escape) && invalidated, "visible feedback owns plain Escape")
        visible = false
        require(!monitor.consumesTestKey(escape), "hidden feedback must preserve editor Escape")
        visible = true; escape.flags = .maskCommand
        require(!monitor.consumesTestKey(escape), "modified Escape must reach editor")
        monitor.isFeedbackVisible = nil; monitor.onFeedbackInvalidated = nil
        preferences.learnedWords = ["аэрогель"]
        let editor = DictionaryEditor(preferences: preferences)
        let controls = descendants(editor).compactMap { $0 as? NSButton }
        let edit = controls.first { $0.title == "Изменить выбранное" }!
        let remove = controls.first { $0.title == "Удалить выбранное" }!
        require(!edit.isEnabled && !remove.isEnabled, "dictionary selection required")
        let table = descendants(editor).compactMap { $0 as? NSTableView }.first!
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        require(edit.isEnabled && remove.isEnabled, "selection enables both actions")
        table.deselectAll(nil)
        require(!edit.isEnabled && !remove.isEnabled, "deselection disables both actions")
        preferences.learnedWords = ["аэрогель"]
        preferences.wordReplacements = ["превет": "привет"]
        var undoTime: TimeInterval = 100
        let undoEditor = DictionaryEditor(preferences: preferences, now: { undoTime })
        let undoViews = descendants(undoEditor)
        let undoTable = undoViews.compactMap { $0 as? NSTableView }.first!
        let deleteRule = undoViews.compactMap { $0 as? NSButton }.first { $0.title == "Удалить выбранное" }!
        let undoDelete = undoViews.compactMap { $0 as? NSButton }.first { $0.title == "Отменить удаление" }
        require(undoDelete != nil, "deleted dictionary rules need undo")
        undoTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        deleteRule.performClick(nil)
        require(!preferences.learnedWords.contains("аэрогель") && !undoDelete!.isHidden, "delete offers undo")
        preferences.learnedWords.insert("нейросеть")
        undoDelete!.performClick(nil)
        require(preferences.learnedWords == ["аэрогель", "нейросеть"], "undo preserves later unrelated edits")
        func replacementRow() -> Int {
            (0..<undoTable.numberOfRows).first {
                (undoEditor.tableView(undoTable, viewFor: undoTable.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("word")), row: $0) as? NSTextField)?.stringValue == "превет"
            }!
        }
        undoTable.selectRowIndexes(IndexSet(integer: replacementRow()), byExtendingSelection: false)
        deleteRule.performClick(nil)
        preferences.wordReplacements["превет"] = "пресет"
        undoDelete!.performClick(nil)
        require(preferences.wordReplacements["превет"] == "пресет", "undo must not overwrite a new replacement")
        undoTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        deleteRule.performClick(nil)
        let afterDelete = preferences.learnedWords
        undoTime += 16
        undoDelete!.performClick(nil)
        require(preferences.learnedWords == afterDelete, "expired undo must not change dictionary")
        print("PopupUI regressions: OK (light/dark, RU/EN long content, failure, ignore/undo, skip, dictionary selection)")
        fflush(stdout)
        if CommandLine.arguments.contains("--interactive") {
            for window in NSApp.windows where !(window is NSPanel) { window.orderOut(nil) }
            let menu = NSMenu(); let item = NSMenuItem(title: "Тест подсказки", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for (title, action) in [("Светлая", #selector(light)), ("Тёмная", #selector(dark)), ("Отказ замены", #selector(failure))] {
                let entry = NSMenuItem(title: title, action: action, keyEquivalent: ""); entry.target = self; submenu.addItem(entry)
            }
            submenu.addItem(NSMenuItem(title: "Завершить", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            item.submenu = submenu; menu.addItem(item); NSApp.mainMenu = menu
            dark(); NSApp.activate(ignoringOtherApps: true)
        } else { exit(0) }
    }
    @objc func light() { NSApp.appearance = NSAppearance(named: .aqua); showLong() }
    @objc func dark() { NSApp.appearance = NSAppearance(named: .darkAqua); showLong() }
    @objc func failure() { indicator.showResult(applied: false) }
    func showLong() { indicator.show(word: "электроэнцефалографическй", suggestion: "электроэнцефалографический") }
}
let app = NSApplication.shared
let delegate = PopupTestDelegate()
app.setActivationPolicy(.regular)
app.delegate = delegate
withExtendedLifetime(delegate) { app.run() }
