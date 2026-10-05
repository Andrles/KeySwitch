import AppKit
import UniformTypeIdentifiers

/// Explicit row editing keeps invalid drafts separate from committed preferences.
final class DictionaryEditor: NSStackView, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    var onRulesChanged: (() -> Void)?
    private let preferences: Preferences
    private let search = NSSearchField()
    private let table = NSTableView()
    private let kind = NSPopUpButton()
    private let word = NSTextField()
    private let replacement = NSTextField()
    private let wordLabel = NSTextField(labelWithString: "Слово")
    private let limits = NSTextField(wrappingLabelWithString: "")
    private let replacementLabel = NSTextField(labelWithString: "Исправление")
    private let status = NSTextField(wrappingLabelWithString: "")
    private let remove = NSButton(title: "Удалить выбранное", target: nil, action: nil)
    private var editing: Row?
    private var rows: [Row] = []
    private struct Row: Equatable { let kind: Int; let word: String; let replacement: String }

    init(preferences: Preferences) {
        self.preferences = preferences
        super.init(frame: .zero)
        orientation = .vertical; alignment = .leading; spacing = 12
        search.placeholderString = "Найти слово или исправление"; search.delegate = self
        search.setAccessibilityLabel("Поиск в моём словаре")
        let expand = NSButton(checkboxWithTitle: "Разворачивать сокращения после пробела", target: self, action: #selector(toggleSnippets))
        expand.state = preferences.snippetsEnabled ? .on : .off
        addArrangedSubview(expand)
        addArrangedSubview(search)
        for (id, title, width) in [("kind", "Правило", 145.0), ("word", "Слово", 165.0), ("replacement", "Исправление", 170.0)] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id)); column.title = title; column.width = width
            table.addTableColumn(column)
        }
        table.dataSource = self; table.delegate = self; table.rowHeight = 28
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.setAccessibilityLabel("Слова и правила моего словаря")
        table.target = self; table.doubleAction = #selector(editSelected)
        let scroll = NSScrollView(); scroll.documentView = table; scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        scroll.heightAnchor.constraint(equalToConstant: 140).isActive = true
        addArrangedSubview(scroll)
        let buttons = NSStackView()
        buttons.spacing = 10
        buttons.addArrangedSubview(NSButton(title: "Изменить выбранное", target: self, action: #selector(editSelected)))
        remove.target = self; remove.action = #selector(removeSelected); remove.isEnabled = false
        buttons.addArrangedSubview(remove); addArrangedSubview(buttons)
        let instruction = NSTextField(wrappingLabelWithString: "Добавьте правильное слово, запрет на исправление, собственную замену или сокращение в готовую фразу.")
        instruction.textColor = .secondaryLabelColor; addArrangedSubview(instruction)
        kind.addItems(withTitles: ["Правильное слово", "Не исправлять", "Моя замена", "Сокращение → фраза"])
        kind.target = self; kind.action = #selector(changeKind); kind.setAccessibilityLabel("Тип правила")
        addArrangedSubview(kind)
        word.placeholderString = "Слово: например, аэрогель"; word.setAccessibilityLabel("Слово правила")
        replacement.placeholderString = "Исправление: например, KeySwitch"; replacement.setAccessibilityLabel("Правильное слово для замены")
        addArrangedSubview(wordLabel); addArrangedSubview(word)
        addArrangedSubview(replacementLabel); addArrangedSubview(replacement)
        status.setAccessibilityLabel("Результат изменения словаря"); addArrangedSubview(status)
        word.target = self; word.action = #selector(saveRow)
        replacement.target = self; replacement.action = #selector(saveRow)
        limits.textColor = .secondaryLabelColor; addArrangedSubview(limits)
        limits.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        let actions = NSStackView(); actions.spacing = 10
        actions.addArrangedSubview(NSButton(title: "Сохранить правило", target: self, action: #selector(saveRow)))
        actions.addArrangedSubview(NSButton(title: "Отменить ввод", target: self, action: #selector(cancelDraft)))
        addArrangedSubview(actions)
        let files = NSStackView(); files.spacing = 10
        files.addArrangedSubview(NSButton(title: "Экспорт словаря…", target: self, action: #selector(exportFile)))
        files.addArrangedSubview(NSButton(title: "Импорт словаря…", target: self, action: #selector(importFile)))
        addArrangedSubview(files)
        for view in [search, scroll, instruction, word, replacement, status] as [NSView] {
            view.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        }
        changeKind(); reload()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private var snapshot: DictionarySnapshot {
        DictionarySnapshot(words: preferences.learnedWords.sorted(), replacements: preferences.wordReplacements, ignored: preferences.ignoredWords.sorted(), snippets: preferences.snippets)
    }
    private func commit(_ value: DictionarySnapshot) {
        preferences.learnedWords = Set(value.words); preferences.wordReplacements = value.replacements; preferences.ignoredWords = Set(value.ignored); preferences.snippets = value.snippets; onRulesChanged?()
        reload()
    }
    private func message(_ text: String, error: Bool = false) {
        status.stringValue = text; status.textColor = error ? .systemRed : .secondaryLabelColor
        if error { window?.contentView?.layoutSubtreeIfNeeded(); status.scrollToVisible(status.bounds) }
        NSAccessibility.post(element: status, notification: .announcementRequested, userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }
    func commitPendingEdits() -> Bool {
        if word.stringValue.isEmpty && replacement.stringValue.isEmpty { return true }
        message("Правило ещё не сохранено. Нажмите «Сохранить правило» или «Отменить ввод».", error: true)
        return false
    }
    private func reload() {
        let query = search.stringValue.lowercased()
        let value = snapshot
        rows = value.words.map { Row(kind: 0, word: $0, replacement: "") } + value.ignored.map { Row(kind: 1, word: $0, replacement: "") } + value.replacements.map { Row(kind: 2, word: $0.key, replacement: $0.value) } + value.snippets.map { Row(kind: 3, word: $0.key, replacement: $0.value) }
        rows = rows.filter { query.isEmpty || $0.word.lowercased().contains(query) || $0.replacement.lowercased().contains(query) }.sorted { ($0.word, $0.kind) < ($1.word, $1.kind) }
        table.reloadData(); remove.isEnabled = false
        if rows.isEmpty { message(query.isEmpty ? "Словарь пуст. Добавьте первое правило ниже." : "Ничего не найдено. Измените запрос.") }
        else { message("Найдено правил: \(rows.count).") }
    }
    func controlTextDidChange(_ notification: Notification) { reload() }
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard rows.indices.contains(row) else { return nil }
        let item = rows[row]
        let text: String
        switch tableColumn?.identifier.rawValue {
        case "kind": text = ["Правильное слово", "Не исправлять", "Моя замена", "Сокращение → фраза"][item.kind]
        case "word": text = item.word
        default: text = item.replacement
        }
        let field = NSTextField(labelWithString: text); field.lineBreakMode = .byTruncatingTail; field.toolTip = text
        return field
    }
    func tableViewSelectionDidChange(_ notification: Notification) { remove.isEnabled = table.selectedRow >= 0 }
    @objc private func toggleSnippets(_ sender: NSButton) { preferences.snippetsEnabled = sender.state == .on; onRulesChanged?(); message(preferences.snippetsEnabled ? "Сокращения включены. Срабатывают после пробела; отмена доступна 15 секунд до нового ввода." : "Сокращения выключены. Правила сохранены.") }
    @objc private func changeKind() {
        let isSnippet = kind.indexOfSelectedItem == 3
        wordLabel.stringValue = isSnippet ? "Сокращение" : "Слово"
        word.setAccessibilityLabel(isSnippet ? "Сокращение для фразы" : "Слово правила")
        word.placeholderString = isSnippet ? "Например, спс" : "Слово: например, аэрогель"
        replacementLabel.stringValue = isSnippet ? "Готовая фраза" : "Исправление"
        replacement.placeholderString = isSnippet ? "Например, Спасибо, хорошего дня!" : "Исправление: например, KeySwitch"
        replacement.setAccessibilityLabel(replacementLabel.stringValue)
        limits.stringValue = isSnippet ? "Сокращение — одно слово до 64 символов. Фраза — одна строка до 256 символов. Срабатывает после пробела, если сокращения включены." : "Одно слово до 64 символов. В исправлении — буквы только русского или только английского языка. Изменения действуют после сохранения."
        replacement.isHidden = kind.indexOfSelectedItem < 2
        replacementLabel.isHidden = replacement.isHidden
        if replacement.isHidden { replacement.stringValue = "" }
    }
    @objc private func cancelDraft() { editing = nil; word.stringValue = ""; replacement.stringValue = ""; message("Ввод отменён. Сохранённые правила не изменены.") }
    @objc private func editSelected() {
        guard rows.indices.contains(table.selectedRow), commitPendingEdits() else { return }
        let row = rows[table.selectedRow]; editing = row; kind.selectItem(at: row.kind); changeKind()
        word.stringValue = row.word; replacement.stringValue = row.replacement; message("Измените правило и нажмите «Сохранить правило».")
    }
    private func removing(_ row: Row, from value: inout DictionarySnapshot) {
        switch row.kind {
        case 0: value.words.removeAll { $0 == row.word }
        case 1: value.ignored.removeAll { $0 == row.word }
        case 2: value.replacements.removeValue(forKey: row.word)
        default: value.snippets.removeValue(forKey: row.word)
        }
    }
    @objc private func saveRow() {
        let key = word.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let result = replacement.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard UserDictionaryFormat.validWord(key) else { message("Введите одно слово до 64 символов, без пробелов, запятых и знака =. Черновик сохранён в поле.", error: true); return }
        guard kind.indexOfSelectedItem != 2 || UserDictionaryFormat.validReplacement(result) else { message("Исправление: одно слово до 64 символов с буквами только русского или только английского языка. Цифры без букв и смешение языков не поддерживаются.", error: true); return }
        guard kind.indexOfSelectedItem != 3 || SnippetFormat.validPhrase(result) else { message("Фраза: одна строка до 256 символов, без табуляции и переноса строки.", error: true); return }
        var value = snapshot
        if let editing {
            // A concurrent change must not be overwritten by an older draft.
            if editing.kind == 2 && value.replacements[editing.word] != editing.replacement { message("Это правило уже изменилось. Отмените ввод и откройте его заново.", error: true); return }
            if editing.kind == 3 && value.snippets[editing.word] != editing.replacement { message("Это сокращение уже изменилось. Отмените ввод и откройте его заново.", error: true); return }
            removing(editing, from: &value)
        }
        switch kind.indexOfSelectedItem {
        case 0: value.words = Array(Set(value.words).union([key])).sorted()
        case 1: value.ignored = Array(Set(value.ignored).union([key])).sorted()
        case 2:
            if value.replacements[key] != nil && !(editing?.kind == 2 && editing?.word == key) { message("Для этого слова уже есть замена. Выберите существующее правило и нажмите «Изменить выбранное».", error: true); return }
            value.replacements[key] = result
        default:
            if value.snippets[key] != nil && !(editing?.kind == 3 && editing?.word == key) { message("Такое сокращение уже есть. Измените существующее правило.", error: true); return }
            value.snippets[key] = result
        }
        do { _ = try value.encoded(); commit(value); editing = nil; word.stringValue = ""; replacement.stringValue = ""; message(kind.indexOfSelectedItem == 3 ? (preferences.snippetsEnabled ? "Сокращение сохранено. Введите его и нажмите пробел." : "Сокращение сохранено. Включите сокращения над списком, чтобы оно работало.") : "Правило сохранено. Оно применяется при следующем вводе слова.") }
        catch { message(error.localizedDescription, error: true) }
    }
    @objc private func removeSelected() {
        guard rows.indices.contains(table.selectedRow), commitPendingEdits() else { return }
        var value = snapshot; removing(rows[table.selectedRow], from: &value); commit(value); message("Выбранное правило удалено.")
    }
    @objc private func exportFile() {
        guard commitPendingEdits() else { return }
        do {
            let data = try snapshot.encoded()
            let panel = NSSavePanel(); panel.nameFieldStringValue = "KeySwitch-dictionary.json"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try data.write(to: url, options: .atomic); message("Словарь экспортирован.")
        } catch { message("Экспорт не выполнен. " + error.localizedDescription, error: true) }
    }
    @objc private func importFile() {
        guard commitPendingEdits() else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
            guard size <= 1_000_000 else { throw DictionaryError("Файл больше 1 МБ.") }
            let incoming = try DictionarySnapshot.decode(Data(contentsOf: url))
            _ = try snapshot.merging(incoming)
            let confirm = NSAlert(); confirm.messageText = "Объединить словари?"
            confirm.informativeText = "Новые записи будут добавлены. Совпадающие замены и сокращения будут взяты из файла. Текущие данные не меняются до подтверждения."
            confirm.addButton(withTitle: "Объединить"); confirm.addButton(withTitle: "Отмена")
            guard confirm.runModal() == .alertFirstButtonReturn else { return }
            commit(try snapshot.merging(incoming)); message("Словарь импортирован. Существующие слова сохранены.")
        } catch { message("Импорт не выполнен. " + error.localizedDescription, error: true) }
    }
}
