import AppKit
import WebKit
import ApplicationServices

// This lab owns its window and HTML. AX writes are restricted to this process;
// no event tap, clipboard, other applications or network. A separate explicit
// fixture action can select English before keyboard-path tests.
final class BrowserLab: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    var window: NSWindow!
    var web: WKWebView!
    var button: NSButton!
    var rows = [[String: Any]]()
    var running = false
    let output = CommandLine.arguments.dropFirst().first ?? "build/browser-replacement/results.json"

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 150, y: 200, width: 850, height: 560),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "KeySwitch — Browser Replacement Lab"
        let content = window.contentView!
        web = WKWebView(frame: NSRect(x: 0, y: 55, width: 850, height: 505))
        web.autoresizingMask = [.width, .height]
        web.navigationDelegate = self
        content.addSubview(web)
        button = NSButton(title: "Запустить изолированный тест", target: self, action: #selector(start))
        button.frame = NSRect(x: 20, y: 10, width: 330, height: 32)
        button.isEnabled = false
        content.addSubview(button)
        let typing = NSButton(title: "Подготовить ввод — English", target: self, action: #selector(prepareTyping))
        typing.frame = NSRect(x: 380, y: 10, width: 390, height: 32)
        content.addSubview(typing)
        web.loadHTMLString("""
        <!doctype html><meta charset="utf-8"><style>
        body{font:16px system-ui;padding:24px;background:#f5f5f7}input,[contenteditable]{display:block;margin:12px 0;padding:12px;width:650px;border:1px solid #bbb;background:white;border-radius:8px}pre{white-space:pre-wrap}
        </style><h2>Изолированные поля KeySwitch</h2>
        <p>Только тестовый текст. Нет подключения к сети.</p>
        <label>Обычное поле<input id="plain" aria-label="Обычное тестовое поле" spellcheck="false"></label>
        <label>Поле со состоянием<input id="controlled" aria-label="Тестовое поле со состоянием" spellcheck="false"></label>
        <div id="editor" contenteditable="true" role="textbox" aria-label="Тестовый редактор сообщения" spellcheck="false"></div>
        <pre id="status">Готовится…</pre>
        <script>
        let events=[],state='';
        const controlled=document.querySelector('#controlled');
        for(const id of ['plain','controlled','editor']) for(const type of ['beforeinput','input','change','selectionchange'])
          document.getElementById(id).addEventListener(type,e=>{events.push({type:e.type,inputType:e.inputType||'',id});if(id==='controlled'&&type==='input')state=controlled.value});
        window.prepare=(id)=>{events=[];const e=document.getElementById(id);if(id==='editor'){e.textContent='lbhtrnjh';const r=document.createRange();r.selectNodeContents(e);r.collapse(false);const s=getSelection();s.removeAllRanges();s.addRange(r)}else{e.value='lbhtrnjh';e.setSelectionRange(8,8)}if(id==='controlled')state=e.value;e.focus();document.getElementById('status').textContent='Проверка: '+id;return true};
        window.snapshot=(id)=>{const e=document.getElementById(id);return {value:id==='editor'?e.textContent:e.value,events:events.slice(),state,selection:id==='editor'?getSelection().toString():[e.selectionStart,e.selectionEnd]}};
        window.rerender=()=>{controlled.value=state;return true};
        document.getElementById('status').textContent='Готово. Нажмите кнопку запуска.';
        </script>
        """, baseURL: nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { button.isEnabled = true }

    @objc func prepareTyping() {
        guard !running else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(web)
        let result = InputSourceController.select(language: .english)
        guard result.succeeded else {
            print("BrowserLab English source unavailable"); fflush(stdout); return
        }
        web.evaluateJavaScript("prepare('plain');document.getElementById('plain').value='';document.getElementById('plain').setSelectionRange(0,0)")
    }

    @objc func start() {
        guard !running else { return }
        running = true; button.isEnabled = false; rows = []
        runCase(0)
    }

    func runCase(_ index: Int) {
        let ids = ["plain", "controlled", "editor"]
        guard index < ids.count else { finish(); return }
        let id = ids[index]
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(web)
        web.evaluateJavaScript("prepare('\(id)')") { _, error in
            guard error == nil else { self.rows.append(["id": id, "error": "prepare"]); self.runCase(index + 1); return }
            // Give WebKit's AX tree time to reflect focus; this delay is a fixture
            // setup step, not a proposed production replacement delay.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let pid = ProcessInfo.processInfo.processIdentifier
                do {
                    // Carbon input-source APIs and the production context
                    // checks require the main queue on current macOS.
                    let result = Self.probeOwnField(pid: pid)
                    do {
                        self.web.evaluateJavaScript("snapshot('\(id)')") { immediate, _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                self.web.evaluateJavaScript("snapshot('\(id)')") { settled, _ in
                                    self.web.evaluateJavaScript("rerender();snapshot('\(id)')") { rerendered, _ in
                                        self.rows.append(["id": id, "ax": result, "immediate": immediate ?? NSNull(),
                                                          "settled": settled ?? NSNull(), "rerendered": rerendered ?? NSNull()])
                                        self.runCase(index + 1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    static func probeOwnField(pid: pid_t) -> [String: Any] {
        guard pid == ProcessInfo.processInfo.processIdentifier else { return ["error": "foreign_pid"] }
        guard AXIsProcessTrusted() else { return ["error": "permission_unavailable"] }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.2)
        var focused: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusResult == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return ["error": "no_focus", "ax_code": focusResult.rawValue]
        }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.2)
        let context = TextInputContext(processID: pid, element: element, selection: NSRange(location: 8, length: 0),
                                       inputSourceID: InputSourceController.currentIdentifier())
        let backend = AXSuffixEditor(context: context)
        let before = backend.text(in: NSRange(location: 0, length: 8)) ?? "unavailable"
        let selection = backend.selection().map(NSStringFromRange) ?? "unavailable"
        // Uses the same production transaction as the rejected experiment, but
        // deliberately never selects an input source or injects keyboard events.
        let started = ProcessInfo.processInfo.systemUptime
        let result = SuffixReplacement.apply(VerifiedTextSuffix(text: "lbhtrnjh", caret: 8),
                                              replacement: "директор", using: backend)
        return ["result": String(describing: result), "before": before, "selection": selection,
                "elapsed_ms": (ProcessInfo.processInfo.systemUptime - started) * 1000]
    }

    func finish() {
        do {
            let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: output), options: .atomic)
            let text = String(decoding: data, as: UTF8.self)
            print(text); fflush(stdout)
            button.title = "Тест завершён — результат сохранён"
            button.isEnabled = true; running = false
        } catch { print("Browser lab output failure: \(error)"); fflush(stdout) }
    }
}
let app = NSApplication.shared
let delegate = BrowserLab()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
