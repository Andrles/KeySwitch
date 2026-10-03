import AppKit

let application = NSApplication.shared
let applicationDelegate = AppDelegate()

application.delegate = applicationDelegate
application.setActivationPolicy(Preferences.shared.menuBarOnly ? .accessory : .regular)
// NSApplication.delegate is weak; keep the delegate alive for the whole run loop.
withExtendedLifetime(applicationDelegate) {
    application.run()
}
