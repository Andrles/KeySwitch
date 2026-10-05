import AppKit

final class ShortcutRecorder: NSButton {
    var binding: ShortcutBinding? { didSet { if !recording { title = binding?.title ?? "Назначить…" } } }
    var onChange: ((ShortcutBinding?) -> Bool)?
    private var recording = false
    override var acceptsFirstResponder: Bool { true }
    init(command: ManualCommand, binding: ShortcutBinding?) {
        super.init(frame: .zero)
        self.binding = binding; title = binding?.title ?? "Назначить…"
        bezelStyle = .rounded; target = self; action = #selector(start)
        toolTip = "Нажмите и введите сочетание с Command или Control. Delete — убрать, Escape — отменить."
        setAccessibilityLabel("Сочетание: " + command.title)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func start() { recording = true; title = "Нажмите сочетание…"; window?.makeFirstResponder(self) }
    override func resignFirstResponder() -> Bool { recording = false; title = binding?.title ?? "Назначить…"; return super.resignFirstResponder() }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event); return true
    }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { recording = false; title = binding?.title ?? "Назначить…"; return }
        if event.keyCode == 51 {
            if onChange?(nil) == true { binding = nil; recording = false; title = "Назначить…" }
            return
        }
        let flags = UInt64(event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue) & ShortcutBinding.mask
        var name = ""
        if flags & ShortcutBinding.control != 0 { name += "⌃" }
        if flags & ShortcutBinding.option != 0 { name += "⌥" }
        if flags & ShortcutBinding.shift != 0 { name += "⇧" }
        if flags & ShortcutBinding.command != 0 { name += "⌘" }
        name += [UInt16(49): "Пробел", 36: "Return" ][event.keyCode] ?? (event.charactersIgnoringModifiers?.uppercased() ?? "Клавиша \(event.keyCode)")
        let value = ShortcutBinding(keyCode: Int64(event.keyCode), modifiers: flags, title: name)
        if onChange?(value) == true { recording = false; binding = value }
    }
}
