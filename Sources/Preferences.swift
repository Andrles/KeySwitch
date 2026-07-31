import Foundation

enum SpellingMode: String, CaseIterable {
    case off
    case suggestions
    case autoCorrect

    var displayTitle: String {
        switch self {
        case .off: return "Выключена"
        case .suggestions: return "Подсказки"
        case .autoCorrect: return "Автоисправление"
        }
    }
}

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark

    var displayTitle: String {
        switch self {
        case .system: return "Системная"
        case .light: return "Светлая"
        case .dark: return "Тёмная"
        }
    }
}

enum PreferenceKey {
    static let enabled = "enabled"
    static let playSound = "playSound"
    static let launchAtLogin = "launchAtLogin"
    static let excludedApps = "excludedApps"
    static let ignoredWords = "ignoredWords"
    static let correctionCount = "correctionCount"
    static let primaryLanguage = "primaryLanguage"
    static let spellChecking = "spellChecking"
    static let spellAutoCorrect = "spellAutoCorrect"
    static let spellingMode = "spellingMode"
    static let appTheme = "appTheme"
    static let automaticallyChecksForUpdates = "automaticallyChecksForUpdates"
    static let lastUpdateCheck = "lastUpdateCheck"
}

final class Preferences {
    static let shared = Preferences()
    let defaults = UserDefaults.standard

    private init() {
        let storedSpellingMode = defaults.string(forKey: PreferenceKey.spellingMode)
        let legacySpellChecking = defaults.object(forKey: PreferenceKey.spellChecking) as? Bool
        let legacyAutoCorrect = defaults.object(forKey: PreferenceKey.spellAutoCorrect) as? Bool
        defaults.register(defaults: [
            PreferenceKey.enabled: true,
            PreferenceKey.playSound: true,
            PreferenceKey.excludedApps: [
                "com.apple.dt.Xcode",
                "com.microsoft.VSCode",
                "com.jetbrains.intellij",
                "com.jetbrains.AppCode",
                "com.unity3d.UnityEditor5.x"
            ],
            PreferenceKey.ignoredWords: [],
            PreferenceKey.primaryLanguage: Language.russian.rawValue,
            PreferenceKey.spellChecking: true,
            PreferenceKey.spellAutoCorrect: false,
            PreferenceKey.spellingMode: SpellingMode.autoCorrect.rawValue,
            PreferenceKey.appTheme: AppTheme.system.rawValue,
            PreferenceKey.automaticallyChecksForUpdates: true
        ])
        if storedSpellingMode == nil,
           legacySpellChecking != nil || legacyAutoCorrect != nil {
            let migrated: SpellingMode
            if legacySpellChecking == false {
                migrated = .off
            } else if legacyAutoCorrect == true {
                migrated = .autoCorrect
            } else {
                migrated = .suggestions
            }
            defaults.set(migrated.rawValue, forKey: PreferenceKey.spellingMode)
        }
    }

    var enabled: Bool {
        get { defaults.bool(forKey: PreferenceKey.enabled) }
        set { defaults.set(newValue, forKey: PreferenceKey.enabled) }
    }

    var playSound: Bool {
        get { defaults.bool(forKey: PreferenceKey.playSound) }
        set { defaults.set(newValue, forKey: PreferenceKey.playSound) }
    }

    var excludedApps: [String] {
        get { defaults.stringArray(forKey: PreferenceKey.excludedApps) ?? [] }
        set { defaults.set(newValue, forKey: PreferenceKey.excludedApps) }
    }

    var ignoredWords: Set<String> {
        get { Set(defaults.stringArray(forKey: PreferenceKey.ignoredWords) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: PreferenceKey.ignoredWords) }
    }

    var correctionCount: Int {
        get { defaults.integer(forKey: PreferenceKey.correctionCount) }
        set { defaults.set(newValue, forKey: PreferenceKey.correctionCount) }
    }

    var primaryLanguage: Language {
        get {
            Language(rawValue: defaults.string(forKey: PreferenceKey.primaryLanguage) ?? "")
                ?? .russian
        }
        set { defaults.set(newValue.rawValue, forKey: PreferenceKey.primaryLanguage) }
    }

    var spellChecking: Bool {
        get { spellingMode != .off }
        set {
            if !newValue {
                spellingMode = .off
            } else if spellingMode == .off {
                spellingMode = .suggestions
            }
        }
    }

    var spellAutoCorrect: Bool {
        get { spellingMode == .autoCorrect }
        set {
            if newValue {
                spellingMode = .autoCorrect
            } else if spellingMode == .autoCorrect {
                spellingMode = .suggestions
            }
        }
    }

    var spellingMode: SpellingMode {
        get {
            SpellingMode(rawValue: defaults.string(forKey: PreferenceKey.spellingMode) ?? "")
                ?? .autoCorrect
        }
        set {
            defaults.set(newValue.rawValue, forKey: PreferenceKey.spellingMode)
            defaults.set(newValue != .off, forKey: PreferenceKey.spellChecking)
            defaults.set(newValue == .autoCorrect, forKey: PreferenceKey.spellAutoCorrect)
        }
    }

    var appTheme: AppTheme {
        get {
            AppTheme(rawValue: defaults.string(forKey: PreferenceKey.appTheme) ?? "")
                ?? .system
        }
        set { defaults.set(newValue.rawValue, forKey: PreferenceKey.appTheme) }
    }

    var automaticallyChecksForUpdates: Bool {
        get { defaults.bool(forKey: PreferenceKey.automaticallyChecksForUpdates) }
        set { defaults.set(newValue, forKey: PreferenceKey.automaticallyChecksForUpdates) }
    }

    var lastUpdateCheck: Date? {
        get { defaults.object(forKey: PreferenceKey.lastUpdateCheck) as? Date }
        set { defaults.set(newValue, forKey: PreferenceKey.lastUpdateCheck) }
    }
}
