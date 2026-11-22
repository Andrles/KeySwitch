import AppKit
import Carbon

// Exercise the production notification handler without starting keyboard capture.
// --ui-preview gives the delegate an isolated preference suite and skips services.
let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let delegate = AppDelegate()
application.delegate = delegate
let preferences = Preferences.shared
let originalSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
let originalApplication = NSWorkspace.shared.frontmostApplication
var finished = false
var passed = 0
var launchedTextEdit: NSRunningApplication?

func finish(_ error: String? = nil) {
    guard !finished else { return }
    finished = true
    NSWorkspace.shared.notificationCenter.removeObserver(delegate)
    if let launchedTextEdit { launchedTextEdit.terminate() }
    originalApplication?.activate(options: [])
    let restoreStatus = TISSelectInputSource(originalSource)
    preferences.defaults.removePersistentDomain(forName: "local.keyswitch.preview.\(ProcessInfo.processInfo.processIdentifier)")
    if let error {
        fputs("Application entry integration FAIL: \(error)\n", stderr)
        exit(1)
    }
    guard restoreStatus == 0 else {
        fputs("Application entry integration FAIL: could not restore original input source\n", stderr)
        exit(1)
    }
    print("Application entry integration: OK (\(passed) scenarios; original input source restored)")
    fflush(stdout)
    exit(0)
}

func expect(_ condition: Bool, _ message: String) {
    if !condition { finish(message) }
    passed += 1
    print("PASS: \(message)")
    fflush(stdout)
}

func activate(_ target: NSRunningApplication, then check: @escaping () -> Void) {
    guard target.activate(options: []) else { finish("application activation rejected"); return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else {
            finish("target application did not become frontmost"); return
        }
        check()
    }
}

func exercise(textEdit: NSRunningApplication, finder: NSRunningApplication) {
    preferences.enabled = true
    preferences.excludedApps = []
    preferences.setEntryLanguage(.english, for: "com.apple.TextEdit")
    preferences.setEntryLanguage(.russian, for: "com.apple.finder")
    guard InputSourceController.select(language: .english).succeeded,
          InputSourceController.select(language: .russian).succeeded else {
        finish("both English and Russian input sources must be enabled in macOS"); return
    }
    NSWorkspace.shared.notificationCenter.addObserver(
        delegate, selector: NSSelectorFromString("activeApplicationDidChange:"),
        name: NSWorkspace.didActivateApplicationNotification, object: nil)
    activate(finder) {
        expect(InputSourceController.currentLanguage() == .russian, "Finder entry selects Russian")
        activate(textEdit) {
            expect(InputSourceController.currentLanguage() == .english, "TextEdit entry selects English")
            expect(InputSourceController.select(language: .russian).succeeded, "manual language selection succeeds")
            NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didActivateApplicationNotification,
                object: nil, userInfo: [NSWorkspace.applicationUserInfoKey: textEdit])
            expect(InputSourceController.currentLanguage() == .russian, "duplicate notification preserves manual selection")
            preferences.setEntryLanguage(.english, for: "com.apple.finder")
            NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didActivateApplicationNotification,
                object: nil, userInfo: [NSWorkspace.applicationUserInfoKey: finder])
            expect(InputSourceController.currentLanguage() == .russian, "stale notification cannot change frontmost app language")
            preferences.enabled = false
            activate(finder) {
                expect(InputSourceController.currentLanguage() == .russian, "pause blocks real application entry switch")
                preferences.enabled = true
                activate(textEdit) {
                    expect(InputSourceController.currentLanguage() == .english, "return to TextEdit reapplies entry rule")
                    guard InputSourceController.select(language: .russian).succeeded else {
                        finish("manual reset failed"); return
                    }
                    preferences.excludedApps = ["com.apple.finder"]
                    activate(finder) {
                        expect(InputSourceController.currentLanguage() == .russian, "full exclusion blocks entry switch")
                        preferences.excludedApps = []
                        preferences.setEntryLanguage(nil, for: "com.apple.TextEdit")
                        // macOS may restore a document's own input source on entry.
                        // Compare against that native behavior, not a forced Russian expectation.
                        NSWorkspace.shared.notificationCenter.removeObserver(delegate)
                        activate(textEdit) {
                            let nativeLanguage = InputSourceController.currentLanguage()
                            activate(finder) {
                                NSWorkspace.shared.notificationCenter.addObserver(
                                    delegate, selector: NSSelectorFromString("activeApplicationDidChange:"),
                                    name: NSWorkspace.didActivateApplicationNotification, object: nil)
                                activate(textEdit) {
                                    expect(InputSourceController.currentLanguage() == nativeLanguage,
                                           "no rule preserves native macOS entry behavior")
                                    finish()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

let launchedObserver = NotificationCenter.default.addObserver(
    forName: NSApplication.didFinishLaunchingNotification, object: nil, queue: .main) { _ in
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        guard CommandLine.arguments.contains("--ui-preview"),
              let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else {
            finish("isolated preview and running Finder are required"); return
        }
        if let textEdit = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first {
            exercise(textEdit: textEdit, finder: finder)
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { target, error in
                DispatchQueue.main.async {
                    guard let target else { finish("could not open TextEdit: \(String(describing: error))"); return }
                    launchedTextEdit = target
                    exercise(textEdit: target, finder: finder)
                }
            }
        } else { finish("TextEdit is unavailable") }
    }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 20) { finish("test timed out") }
application.run()
