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
        var toggled = false, settingsOpened = false, recovered = false, openedMore = false
        quick.onToggle = { toggled = true }
        quick.onSettings = { settingsOpened = true }
        quick.onPermission = { recovered = true }
        quick.onRetry = { recovered = true }
        quick.onMore = { openedMore = true }
        for state in [MonitorState.ready, .paused, .needsPermission, .failed] {
            toggled = false; settingsOpened = false; recovered = false; openedMore = false
            quick.refresh(state: state, enabled: state != .paused)
            require(quick.preferredContentSize.width == 320 && quick.preferredContentSize.height > 100, "quick settings size")
            quick.view.setFrameSize(quick.preferredContentSize)
            quick.view.layoutSubtreeIfNeeded()
            let views = descendants(quick.view)
            for control in views where control is NSControl && !control.isHiddenOrHasHiddenAncestor {
                let frame = control.convert(control.bounds, to: quick.view)
                require(quick.view.bounds.insetBy(dx: -1, dy: -1).contains(frame), "quick settings control clipped: \(frame)")
            }
            require(views.compactMap { $0 as? NSTextField }.contains { $0.stringValue == state.title }, "truthful quick state")
            let recoveryTitle = state == .failed ? "Повторить запуск" : "Открыть доступ macOS…"
            let recovery = views.compactMap { $0 as? NSButton }.first { $0.title == recoveryTitle }
            require(recovery != nil, "recovery button title must match the failure")
            require(recovery!.isHidden == (state != .failed && state != .needsPermission), "recovery action visibility")
            if !recovery!.isHidden { recovery!.performClick(nil); require(recovered, "recovery action callback") }
            views.compactMap { $0 as? NSButton }.first { $0.title == "Ещё действия…" }!.performClick(nil)
            require(openedMore, "more action callback")
            let toggle = views.compactMap { $0 as? NSSwitch }.first!
            require(toggle.state == (state == .paused ? .off : .on), "quick switch state")
            NSApp.sendAction(toggle.action!, to: toggle.target, from: toggle)
            views.compactMap { $0 as? NSButton }.first { $0.title == "Открыть настройки…" }!.performClick(nil)
            require(toggled && settingsOpened, "quick actions must work in every state")
        }
        require(toggled && settingsOpened, "quick actions")
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
