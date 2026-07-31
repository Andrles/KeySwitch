import AppKit

enum AppearanceController {
    static func apply(_ theme: AppTheme) {
        switch theme {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        NotificationCenter.default.post(name: .keySwitchAppearanceChanged,
                                        object: theme)
    }
}

extension Notification.Name {
    static let keySwitchAppearanceChanged = Notification.Name("keySwitchAppearanceChanged")
}
