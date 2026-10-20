import AppKit

let application = NSApplication.shared
let diagnosticsWithoutMonitoring = CommandLine.arguments.contains("--ui-preview") ||
    CommandLine.arguments.contains("--launch-check")
var instanceLock: SingleInstance?
if !diagnosticsWithoutMonitoring {
    do {
        // Also detect older builds that do not yet hold the kernel lock.
        let peers = NSRunningApplication.runningApplications(withBundleIdentifier: "local.keyswitch.app")
        guard !peers.contains(where: { $0.processIdentifier != getpid() && !$0.isTerminated }) else {
            throw SingleInstance.Failure.alreadyRunning
        }
        let directory = try FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("KeySwitch", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        instanceLock = try SingleInstance(fileURL: directory.appendingPathComponent("instance.lock"))
    } catch {
        let isDuplicate: Bool
        if case SingleInstance.Failure.alreadyRunning = error { isDuplicate = true }
        else { isDuplicate = false }
        let message = isDuplicate
            ? "KeySwitch уже запущен"
            : "Не удалось безопасно запустить KeySwitch"
        if RuntimeCheckTarget.bundleIdentifier() != nil {
            print("KeySwitch instance check: \(isDuplicate ? "already-running" : "unavailable")")
            exit(isDuplicate ? 2 : 3)
        }
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = isDuplicate
            ? "Используйте значок KeySwitch в строке меню. Чтобы запустить другую копию, сначала завершите работающую."
            : "Проверка единственного экземпляра недоступна. Повторите запуск; если ошибка сохраняется, обратитесь за помощью."
        alert.addButton(withTitle: "Закрыть")
        application.activate(ignoringOtherApps: true)
        alert.runModal()
        exit(isDuplicate ? 2 : 3)
    }
}
let applicationDelegate = AppDelegate()

application.delegate = applicationDelegate
application.setActivationPolicy(Preferences.shared.menuBarOnly ? .accessory : .regular)
// NSApplication.delegate is weak; keep the delegate alive for the whole run loop.
withExtendedLifetime((applicationDelegate, instanceLock)) {
    application.run()
}
